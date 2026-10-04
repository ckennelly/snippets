#!/bin/bash
# snappy A/B between compilers: build snappy's own Google Benchmark binary
# (BM_UFlat / BM_ZFlat over its test inputs) with each compiler and run them
# alternately.
#
#   VARIANTS="base=.../clang fold=.../clang" ./run.sh
#   ROUNDS=5 ./run.sh
set -euo pipefail
cd "$(dirname "$0")"
VARIANTS=${VARIANTS:?set VARIANTS="name=/path/to/clang ..."}
ROUNDS=${ROUNDS:-5}
PIN=${PIN:-}          # e.g. "taskset -c 7"
TAG=${TAG:-1.2.2}
W=${WORK:-$PWD/work-$(uname -m)}
mkdir -p "$W" results
case $(uname -m) in aarch64) ARCHFLAGS="-mcpu=native" ;; *) ARCHFLAGS="-march=native" ;; esac

build() { # name cc
  local name=$1 cc=$2
  local src=$W/snappy-$name
  if [ ! -x "$src/build/snappy_benchmark" ]; then
    rm -rf "$src"
    git clone -q --depth 1 --recursive --shallow-submodules --branch "$TAG" https://github.com/google/snappy.git "$src" 2>/dev/null
    cmake -S "$src" -B "$src/build" -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_C_COMPILER="$cc" -DCMAKE_CXX_COMPILER="${cc}++" \
          -DCMAKE_CXX_FLAGS="-O3 $ARCHFLAGS -w" -DCMAKE_C_FLAGS="-O3 $ARCHFLAGS -w" \
          -DSNAPPY_BUILD_TESTS=OFF -DSNAPPY_BUILD_BENCHMARKS=ON -DBENCHMARK_ENABLE_TESTING=OFF >/dev/null
    cmake --build "$src/build" -j"$(nproc)" --target snappy_benchmark >/dev/null
  fi
  echo "$name: .text $(size -A "$src/build/snappy_benchmark" | awk '/\.text/{print $2}')"
}

NAMES=""
md() { curl -sf -H Metadata-Flavor:Google "http://metadata.google.internal/computeMetadata/v1/instance/$1" 2>/dev/null; }
family=${VM_FAMILY:-$(md machine-type | sed 's|.*/||' || true)}
[ -n "$family" ] && [ "$(md scheduling/preemptible)" = TRUE ] && family="$family (Spot)"
cpu=$(lscpu | sed -n 's/^Model name:[ ]*//p' | head -1 | tr ' ' '_' | tr -cd 'A-Za-z0-9_.-')
out=results/snappy-$(uname -m)-${cpu:-unknown}.txt
{
  echo "# $(date -u +%Y-%m-%dT%H:%MZ) $(uname -m) $(lscpu | sed -n 's/^Model name:[ ]*//p' | head -1)"
  echo "# VM: ${family:-unknown}"
  for v in $VARIANTS; do NAMES="$NAMES ${v%%=*}"; echo "# ${v%%=*}: $(${v#*=} --version | head -1)"; done
  echo "# snappy $TAG snappy_benchmark, CXXFLAGS -O3 $ARCHFLAGS; $ROUNDS rounds, builds alternated; CSV per run below"
  echo
  for v in $VARIANTS; do build "${v%%=*}" "${v#*=}"; done
  for r in $(seq 1 "$ROUNDS"); do
    for name in $NAMES; do
      f=results/snappy-$(uname -m)-$name-$r.csv
      (cd "$W/snappy-$name" && $PIN "./build/snappy_benchmark" --benchmark_format=csv --benchmark_filter='BM_[UZ]Flat' > "$OLDPWD/$f" 2>/dev/null)
      echo "round $r $name: $(grep -c '^"BM_' "$f") rows -> $f"
    done
  done
} | tee "$out"
echo "wrote $out"
