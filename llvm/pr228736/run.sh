#!/bin/bash
# Build and run, writing results/<arch>-<cpu>.txt with the environment, the
# benchmark output and the compiler's codegen for the two C++ reference forms.
set -euo pipefail
cd "$(dirname "$0")"
CXX=${CXX:-clang++}
B=build-$(uname -m)
cmake -S . -B "$B" -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER="$CXX" >/dev/null
cmake --build "$B" -j >/dev/null
# CPU model name: lscpu on Linux, sysctl on macOS. arm64 (macOS) is reported
# as aarch64 to match the Linux results.
cpuname() {
  if command -v lscpu >/dev/null; then lscpu | sed -n 's/^Model name:[ ]*//p' | head -1
  else sysctl -n machdep.cpu.brand_string; fi
}
arch=$(uname -m); [ "$arch" = arm64 ] && arch=aarch64
cpu=$(cpuname | tr ' ' '_' | tr -cd 'A-Za-z0-9_.-')
out=results/${arch}-${cpu:-unknown}.txt
mkdir -p results
# GCE machine type, when running on GCE; otherwise whatever VM_FAMILY says.
md() { curl -sf -m 2 -H Metadata-Flavor:Google "http://metadata.google.internal/computeMetadata/v1/instance/$1" 2>/dev/null; }
family=${VM_FAMILY:-$(md machine-type | sed 's|.*/||' || true)}
[ -n "$family" ] && [ "$(md scheduling/preemptible)" = TRUE ] && family="$family (Spot)"
{
  echo "# $(date -u +%Y-%m-%dT%H:%MZ) $arch $(cpuname)"
  echo "# VM: ${family:-unknown}"
  echo "# $($CXX --version | head -1)"
  echo
  "$B/lowbits_mask" --benchmark_repetitions=${REPS:-10} --benchmark_report_aggregates_only=true \
                    --benchmark_counters_tabular=true "$@"
  echo
  echo "## ref_cxx_table / ref_cxx_arith as compiled here"
  objdump -d --no-show-raw-insn "$B/lowbits_mask" | awk '/<_?ref_cxx_(table|arith)>:/{p=1} p{print} p&&/ret/{p=0; print ""}'
} | tee "$out"
echo "wrote $out"
