# Results, 2026-10-03

ns per element, mean of 10 repetitions (CV ≤ 0.3% everywhere), clang 18.1.3,
`-O2`, inputs from `std::mt19937_64(42)`. Raw output with the Google Benchmark
headers and the compiler's codegen for the C++ forms is in the two `.txt`
files.

The inner loops were disassembled and reviewed for artifacts of the inline-asm
constraints: no spills, no re-materialized constants, identical induction and
addressing across kernels. Two harness artifacts were found and fixed before
these numbers were taken (a per-element store of the loop-carried value from
`DoNotOptimize`'s `"+m,r"` constraint, and on x86 a zero-extension of the table
index on the LatencyN chain). What remains on the LatencyN chain besides the
kernel is the `& 31` and, on x86, one register copy that applies equally to all
kernels.

## x86-64: AMD EPYC 7B13 (Zen 3), GCE `n2d-standard-16` (Spot)

| kernel | Throughput | LatencyX | LatencyN |
|---|---:|---:|---:|
| table `and (tbl,n,4), x` | 0.522 | 0.623 | **2.184** |
| `bzhi` (BMI2) | **0.331** | 0.625 | **0.623** |
| `mov 1; shl %cl; dec; and` (no BMI2) | 0.626 | 0.625 | **1.246** |

## AArch64: Neoverse-V2, GCE `c4a-standard-16` (Spot)

| kernel | Throughput | LatencyX | LatencyN |
|---|---:|---:|---:|
| table `ldr [tbl, n, uxtw #2]; and` | **0.478** | 0.715 | **2.013** |
| `lsl; bic` (-1 hoisted; what clang emits) | 0.574 | 0.717 | **1.020** |
| `lsl; sub; and` (1 hoisted) | 0.624 | 0.772 | **1.354** |
| `mov 1; lsl; sub; and` | 0.625 | 0.721 | **1.355** |

## Reading

- **LatencyN** (the result selects the next mask, a bit reader's shape): the
  dependent table load costs **2.0–2.2 ns** per element against **0.62 ns** for
  `bzhi` and **1.02 ns** for `lsl; bic` — 2× to 3.5× slower on both machines.
- **LatencyX** (the result feeds the next `x`): identical within noise. The
  load's address does not depend on the previous result, so its latency hides.
- **Throughput** (independent elements): on Zen 3 `bzhi` is clearly ahead
  (0.33 vs 0.52 ns; the table form is a third load per element next to the two
  input loads). On Neoverse-V2 the table is ahead of `lsl; bic` by 0.1 ns,
  about a fifth of a cycle at 2 GHz.
- On AArch64, hoisting the constant makes no measurable difference
  (`lsl; sub; and` with and without the `mov`).

The microbenchmark is generous to the table: the address materialization
(`adrp; add`, or a GOT load under PIC) and the cache line the table occupies
are hoisted and warm here.
