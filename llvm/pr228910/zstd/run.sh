#!/bin/bash
# End-to-end check for the AggressiveInstCombine low-bits-mask fold on zstd.
#
# Builds zstd twice and runs zstd's own in-memory benchmark on enwik8,
# alternating the two builds. Two ways to get a build with and without the fold:
#
#   CC_FOLD=.../clang CC_NOFOLD=.../clang ./run.sh
#       Two compilers, pristine zstd source: clang at the fold's commit
#       (394c8dd14933) and at its parent. The cleanest A/B.
#   CC=/path/to/clang ./run.sh
#       One compiler that has the fold. The no-fold build turns BIT_mask into a
#       non-const array with external linkage, defined in its own file; the
#       fold needs a constant table and GlobalOpt cannot prove an externally
#       visible array is never written, so the load stays. (A static non-const
#       table is not enough: GlobalOpt re-marks it constant and the fold fires.)
#
#   VARIANTS="nofold=.../clang fold=.../clang pr=.../clang alt=.../clang" ./run.sh
#       Any number of compilers, pristine zstd source, one build each.
#
#   ROUNDS=3 LEVELS="1 3 9" SECS=5 ./run.sh
set -euo pipefail
cd "$(dirname "$0")"
CC=${CC:-clang}
CC_FOLD=${CC_FOLD:-$CC}
CC_NOFOLD=${CC_NOFOLD:-}
VARIANTS=${VARIANTS:-}
ROUNDS=${ROUNDS:-3}
PIN=${PIN:-}          # e.g. "taskset -c 7" to pin the single-threaded runs
LEVELS=${LEVELS:-1 3 9}
SECS=${SECS:-5}
ZSTD_TAG=${ZSTD_TAG:-v1.5.7}
W=${WORK:-$PWD/work-$(uname -m)}
mkdir -p "$W" results

# corpus: enwik8 (100 MB of Wikipedia XML), the usual zstd/lz benchmark input
if [ ! -s "$W/enwik8" ]; then
  curl -sfL -o "$W/enwik8.zip" https://mattmahoney.net/dc/enwik8.zip
  (cd "$W" && unzip -oq enwik8.zip && rm enwik8.zip)
fi
sha256sum "$W/enwik8" | cut -c1-16

case $(uname -m) in
  aarch64) ARCHFLAGS="-mcpu=native" ;;
  *)       ARCHFLAGS="-march=native" ;;
esac

# Move the BIT_mask table out of the header into lib/common/bit_mask.c as a
# plain (non-const, external) array.
unfold_table() { # srcdir
  local h=$1/lib/common/bitstream.h c=$1/lib/common/bit_mask.c
  python3 - "$h" "$c" <<'PY'
import re, sys
h, c = sys.argv[1:]
s = open(h).read()
m = re.search(r"static const unsigned BIT_mask\[\] = \{(.*?)\};[^\n]*\n", s, re.S)
assert m, "BIT_mask definition not found"
n = len([x for x in m.group(1).replace("\n", " ").split(",") if x.strip()])
open(c, "w").write("/* BIT_mask as a writable, externally visible array: not foldable. */\n"
                   "unsigned BIT_mask[%d] = {%s};\n" % (n, m.group(1)))
s = s[:m.start()] + "extern unsigned BIT_mask[%d];\n" % n + s[m.end():]
open(h, "w").write(s)
PY
}

build() { # name compiler [unfold]
  local name=$1 cc=$2 mode=${3:-}
  local src=$W/zstd-$name
  if [ ! -x "$src/zstd" ]; then
    rm -rf "$src"
    git clone -q --depth 1 --branch "$ZSTD_TAG" https://github.com/facebook/zstd.git "$src" 2>/dev/null
    [ "$mode" = unfold ] && unfold_table "$src"
    make -s -C "$src" -j"$(nproc)" zstd CC="$cc" MOREFLAGS="$ARCHFLAGS" >/dev/null
  fi
  # a defined BIT_mask symbol means the table survived, i.e. its uses were not folded
  echo "$name: BIT_mask symbol: $(nm "$src/zstd" | grep -c ' BIT_mask' || true), .text $(size -A "$src/zstd" | awk '/\.text/{print $2}') bytes"
}

cpu=$(lscpu | sed -n 's/^Model name:[ ]*//p' | head -1 | tr ' ' '_' | tr -cd 'A-Za-z0-9_.-')
md() { curl -sf -H Metadata-Flavor:Google "http://metadata.google.internal/computeMetadata/v1/instance/$1" 2>/dev/null; }
family=${VM_FAMILY:-$(md machine-type | sed 's|.*/||' || true)}
[ -n "$family" ] && [ "$(md scheduling/preemptible)" = TRUE ] && family="$family (Spot)"
out=results/zstd-$(uname -m)-${cpu:-unknown}.txt
{
  echo "# $(date -u +%Y-%m-%dT%H:%MZ) $(uname -m) $(lscpu | sed -n 's/^Model name:[ ]*//p' | head -1)"
  echo "# VM: ${family:-unknown}"
  if [ -n "$VARIANTS" ]; then
    NAMES=""
    for v in $VARIANTS; do
      name=${v%%=*}; cc=${v#*=}; NAMES="$NAMES $name"
      echo "# $name: $($cc --version | head -1)"
    done
    echo "# zstd $ZSTD_TAG unmodified, CFLAGS -O3 $ARCHFLAGS; enwik8; zstd -b<level> -i$SECS; $ROUNDS rounds, builds alternated"
    echo
    for v in $VARIANTS; do build "${v%%=*}" "${v#*=}"; done
  elif [ -n "$CC_NOFOLD" ]; then
    NAMES="fold nofold"
    echo "# fold:   $($CC_FOLD --version | head -1)"
    echo "# nofold: $($CC_NOFOLD --version | head -1)"
    echo "# zstd $ZSTD_TAG unmodified, CFLAGS -O3 $ARCHFLAGS; enwik8; zstd -b<level> -i$SECS; $ROUNDS rounds, builds alternated"
    echo
    build fold "$CC_FOLD"
    build nofold "$CC_NOFOLD"
  else
    NAMES="fold nofold"
    echo "# $($CC --version | head -1)"
    echo "# zstd $ZSTD_TAG (nofold: BIT_mask made extern non-const), CFLAGS -O3 $ARCHFLAGS; enwik8; zstd -b<level> -i$SECS; $ROUNDS rounds, builds alternated"
    echo
    build fold "$CC"
    build nofold "$CC" unfold
  fi
  # scaled-index loads of the table vs. the arithmetic the fold produces
  for name in $NAMES; do
    case $(uname -m) in
      aarch64) echo "$name: $(objdump -d "$W/zstd-$name/zstd" | grep -c 'uxtw #2\]') ldr-uxtw#2, $(objdump -d "$W/zstd-$name/zstd" | grep -cE '^\s*[0-9a-f]+:\s+bic\s') bic, $(objdump -d "$W/zstd-$name/zstd" | grep -cE '^\s*[0-9a-f]+:\s+mvn\s') mvn" ;;
      *)       echo "$name: $(objdump -d "$W/zstd-$name/zstd" | grep -c 'bzhi') bzhi" ;;
    esac
  done
  echo
  echo "# build  zstd -b output: level  compressed-size  (ratio)  compress-MB/s  decompress-MB/s"
  for r in $(seq 1 "$ROUNDS"); do
    for name in $NAMES; do
      for l in $LEVELS; do
        echo "$name $($PIN "$W/zstd-$name/zstd" -b"$l" -i"$SECS" -q "$W/enwik8" 2>&1 | tail -1 | tr -s ' ')"
      done
    done
  done
} | tee "$out"
echo "wrote $out"
