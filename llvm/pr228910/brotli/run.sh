#!/bin/bash
# brotli A/B between compilers: build the brotli CLI from a pinned tag with each
# compiler and time compression and decompression of enwik8, alternating
# builds every round.
#
#   VARIANTS="base=.../clang fold=.../clang" ./run.sh
#   ROUNDS=5 QUALITIES="5 9" ./run.sh
set -euo pipefail
cd "$(dirname "$0")"
VARIANTS=${VARIANTS:?set VARIANTS="name=/path/to/clang ..."}
ROUNDS=${ROUNDS:-5}
PIN=${PIN:-}          # e.g. "taskset -c 7"
QUALITIES=${QUALITIES:-5 9}
TAG=${TAG:-v1.1.0}
W=${WORK:-$PWD/work-$(uname -m)}
mkdir -p "$W" results
case $(uname -m) in aarch64) ARCHFLAGS="-mcpu=native" ;; *) ARCHFLAGS="-march=native" ;; esac

if [ ! -s "$W/enwik8" ]; then
  if [ -s ../zstd/work-$(uname -m)/enwik8 ]; then ln -sf "$(realpath ../zstd/work-$(uname -m)/enwik8)" "$W/enwik8"
  else curl -sfL -o "$W/enwik8.zip" https://mattmahoney.net/dc/enwik8.zip && (cd "$W" && unzip -oq enwik8.zip && rm enwik8.zip); fi
fi

build() { # name cc
  local name=$1 cc=$2
  local src=$W/brotli-$name
  if [ ! -x "$src/build/brotli" ]; then
    rm -rf "$src"
    git clone -q --depth 1 --branch "$TAG" https://github.com/google/brotli.git "$src" 2>/dev/null
    cmake -S "$src" -B "$src/build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER="$cc" \
          -DCMAKE_C_FLAGS="-O3 $ARCHFLAGS" -DBUILD_SHARED_LIBS=OFF -DBROTLI_DISABLE_TESTS=ON >/dev/null
    cmake --build "$src/build" -j"$(nproc)" --target brotli >/dev/null
  fi
  echo "$name: .text $(size -A "$src/build/brotli" | awk '/\.text/{print $2}')"
}

NAMES=""
md() { curl -sf -H Metadata-Flavor:Google "http://metadata.google.internal/computeMetadata/v1/instance/$1" 2>/dev/null; }
family=${VM_FAMILY:-$(md machine-type | sed 's|.*/||' || true)}
[ -n "$family" ] && [ "$(md scheduling/preemptible)" = TRUE ] && family="$family (Spot)"
cpu=$(lscpu | sed -n 's/^Model name:[ ]*//p' | head -1 | tr ' ' '_' | tr -cd 'A-Za-z0-9_.-')
out=results/brotli-$(uname -m)-${cpu:-unknown}.txt
{
  echo "# $(date -u +%Y-%m-%dT%H:%MZ) $(uname -m) $(lscpu | sed -n 's/^Model name:[ ]*//p' | head -1)"
  echo "# VM: ${family:-unknown}"
  for v in $VARIANTS; do NAMES="$NAMES ${v%%=*}"; echo "# ${v%%=*}: $(${v#*=} --version | head -1)"; done
  echo "# brotli $TAG, CFLAGS -O3 $ARCHFLAGS; enwik8; qualities $QUALITIES; $ROUNDS rounds, builds alternated; seconds, lower is better"
  echo
  for v in $VARIANTS; do build "${v%%=*}" "${v#*=}"; done
  # compressed inputs for the decompression timing (identical across builds)
  set -- $NAMES; first=$1
  for q in $QUALITIES; do [ -s "$W/enwik8.q$q.br" ] || "$W/brotli-$first/build/brotli" -q "$q" -c "$W/enwik8" > "$W/enwik8.q$q.br"; done
  echo
  echo "# build quality compress_s decompress_s(3 runs)"
  for r in $(seq 1 "$ROUNDS"); do
    for name in $NAMES; do
      b=$W/brotli-$name/build/brotli
      for q in $QUALITIES; do
        t0=$(date +%s.%N); $PIN "$b" -q "$q" -c "$W/enwik8" > /dev/null; t1=$(date +%s.%N)
        for _ in 1 2 3; do $PIN "$b" -d -c "$W/enwik8.q$q.br" > /dev/null; done; t2=$(date +%s.%N)
        awk -v n="$name" -v q="$q" -v a="$t0" -v b="$t1" -v c="$t2" 'BEGIN{printf "%s %s %.3f %.3f\n", n, q, b-a, c-b}' 
      done
    done
  done
} | tee "$out"
echo "wrote $out"
