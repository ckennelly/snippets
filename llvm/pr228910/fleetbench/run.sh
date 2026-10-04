#!/bin/bash
# Fleetbench compression family A/B: clang @ main (4428e953e2a5) vs @ dag-and-zext-lowmask (425987637c69).
# Works on both boxes. Resumable: toolchains skip when REV matches, bazel is incremental, rounds skip .done files.
#   nohup bash ~/fb4.sh > ~/fb4.log 2>&1 &
set -uo pipefail
BASE=4428e953e2a5; FOLD=425987637c69
case $(uname -m) in
  aarch64) REPO=$HOME/llvm-project; SRC=$HOME/bench2/src; B=$HOME/bench2/build; LOCK=$HOME/arm.lock; CFG="--config=arm"; CORE=7 ;;
  *)       REPO=$HOME/llvm-project; SRC=$HOME/llvm-project; B=$HOME/llvm-project/build; LOCK=$HOME/x86.lock; CFG="--config=haswell"; CORE=7 ;;
esac
ROUNDS=${ROUNDS:-6}
W=$HOME/bench4; mkdir -p $W/fb/bin $W/results $W/logs
FILES="clang-24 clang clang++ clang-cpp lld ld.lld llvm-ar llvm-nm llvm-objdump llvm-size llvm-ranlib llvm-objcopy llvm-readobj llvm-readelf llvm-strip llvm-profdata llvm-dwp llvm-config"
TOOLS="clang lld llvm-ar llvm-nm llvm-objdump llvm-size llvm-ranlib llvm-objcopy llvm-readobj llvm-readelf llvm-strip llvm-profdata llvm-dwp llvm-config"

echo "=== $(date -u +%T) fb4 start on $(uname -m)"
git -C $REPO fetch -q https://github.com/ckennelly/llvm-project.git dag-and-zext-lowmask 2>&1 | tail -1
git -C $REPO rev-parse --verify -q $FOLD^{commit} >/dev/null || { echo FETCH_FAIL; exit 2; }

mk() { # side rev
  local side=$1 rev=$2
  if [ -f $HOME/tc4/$side/REV ] && [ "$(cat $HOME/tc4/$side/REV)" = "$rev" ] && [ -x $HOME/tc4/$side/bin/clang ]; then echo "SKIP tc $side"; return; fi
  echo "=== $(date -u +%T) toolchain $side @ $rev"
  git -C $SRC checkout -f -q --detach $rev || { echo CHECKOUT_FAIL; exit 3; }
  local t0=$(date +%s)
  flock $LOCK ninja -C $B $TOOLS > $W/logs/tc-$side.log 2>&1 || { echo "BUILD_FAIL $side"; tail -20 $W/logs/tc-$side.log; exit 4; }
  echo "BUILD_SECONDS $side $(( $(date +%s) - t0 ))"
  rm -rf $HOME/tc4/$side; mkdir -p $HOME/tc4/$side/bin $HOME/tc4/$side/lib
  for f in $FILES; do [ -e $B/bin/$f ] && cp -a $B/bin/$f $HOME/tc4/$side/bin/; done
  cp -a $B/lib/clang $HOME/tc4/$side/lib/
  echo "$rev" > $HOME/tc4/$side/REV
  echo "$side: $($HOME/tc4/$side/bin/clang --version | head -1)"
}
mk base $BASE
mk fold $FOLD
git -C $SRC checkout -f -q --detach $BASE

build() { # side
  local side=$1 TC=$HOME/tc4/$1 OUT=$W/fb/bin/$1 OB=$HOME/.cache/bazel-b4-$1 LOG=$W/logs/build-$1.log
  if [ -x $OUT/compression/compression_benchmark ] && [ "$(cat $OUT/compression/REV 2>/dev/null)" = "$(cat $TC/REV)" ]; then echo "SKIP build $side"; return; fi
  echo "=== $(date -u +%T) fleetbench build $side"
  export PATH=$TC/bin:$HOME/bin:$PATH GLIBC_TUNABLES=glibc.pthread.rseq=0
  local COMMON="--config=clang --config=opt $CFG --copt=-gmlt --strip=never --copt=-Wno-error --copt=-Wno-deprecated-attributes --copt=-Wno-attribute-alias --copt=-Wno-c++20-extensions"
  local LTO="--copt=-flto=thin --linkopt=-flto=thin --linkopt=-O3 --linkopt=-fuse-ld=lld --linkopt=-Wl,--thinlto-jobs=16"
  local KEEP=""; for f in memcpy memmove memset memcmp bcmp bzero; do KEEP="$KEEP --linkopt=-Wl,-u,$f --linkopt=-Wl,--export-dynamic-symbol=$f"; done
  local REPOENV="--repo_env=CC=$TC/bin/clang --repo_env=CXX=$TC/bin/clang++"
  local T=//fleetbench/compression:compression_benchmark
  local t0=$(date +%s) ok=0
  cd $HOME/fleetbench || exit 2
  for attempt in 1 2; do
    if flock -o $LOCK bazel --output_base=$OB build $COMMON $REPOENV $LTO $KEEP --action_env=B4_TAG=$side $T >> $LOG 2>&1; then ok=1; break; fi
    echo "attempt $attempt failed"; tail -10 $LOG
  done
  local BB; BB=$(bazel --output_base=$OB info $COMMON $REPOENV bazel-bin 2>/dev/null)
  rm -rf $OUT/compression; mkdir -p $OUT/compression
  cp -L $BB/fleetbench/compression/compression_benchmark $OUT/compression/ && cp -rL $BB/fleetbench/compression/compression_benchmark.runfiles $OUT/compression/ 2>/dev/null
  cp $TC/REV $OUT/compression/REV
  bazel --output_base=$OB shutdown
  [ $ok = 1 ] && [ -x $OUT/compression/compression_benchmark ] && echo "BUILD_OK $side $(( $(date +%s) - t0 ))s" || { echo "BUILD_FAIL $side"; exit 5; }
}
build base
build fold
for side in base fold; do
  d=$W/fb/bin/$side/compression/compression_benchmark
  echo "$side: .text $(size -A $d | awk '/\.text/{print $2}') $(objdump -d --no-show-raw-insn $d | grep -cE '^\s*[0-9a-f]+:\s+(mvn|bic|bzhi|andn)' ) mvn/bic/bzhi/andn"
done

echo "=== $(date -u +%T) A/B $ROUNDS rounds"
export GLIBC_TUNABLES=glibc.pthread.rseq=0
for r in $(seq 1 $ROUNDS); do
  for k in 0 1; do
    sides=(base fold); side=${sides[$(( (k + r - 1) % 2 ))]}
    f=$W/results/compression-$side-$r.csv
    [ -f $f.done ] && continue
    cd $W/fb/bin/$side/compression
    flock $LOCK timeout 1800 taskset -c $CORE ./compression_benchmark --benchmark_format=csv > $f 2> $f.err
    rc=$?; [ $rc = 0 ] && touch $f.done
    echo "exit=$rc ($side r$r) $(date -u +%T) rows=$(grep -c '^\"BM_' $f)"
  done
done
echo "=== $(date -u +%T) FB4_DONE"
