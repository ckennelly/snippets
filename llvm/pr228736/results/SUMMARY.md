# Results, 2026-10-03

ns per element, mean of 10 repetitions (CV ≤ 0.3% everywhere), clang 18.1.3,
`-O2`. Raw output with the Google Benchmark headers and the compiler's codegen
for the C++ forms is in the two `.txt` files.

## x86-64: AMD EPYC 7B13 (Zen 3), GCE `n2d-standard-16` (Spot)

| kernel | Throughput | LatencyX | LatencyN |
|---|---:|---:|---:|
| table `and (tbl,n,4), x` | 0.481 | 0.630 | **2.187** |
| `bzhi` (BMI2) | 0.509 | 0.626 | **0.629** |
| `mov 1; shl %cl; dec; and` (no BMI2) | 0.653 | 0.635 | **1.250** |

## AArch64: Neoverse-V2, GCE `c4a-standard-16` (Spot)

| kernel | Throughput | LatencyX | LatencyN |
|---|---:|---:|---:|
| table `ldr [tbl, n, uxtw #2]; and` | 0.513 | 0.729 | **2.012** |
| `lsl; bic` (-1 hoisted; what clang emits) | 0.555 | 0.717 | **1.037** |
| `lsl; sub; and` (1 hoisted) | 0.614 | 0.718 | **1.362** |
| `mov 1; lsl; sub; and` | 0.618 | 0.722 | **1.358** |

## Reading

- **Throughput** (independent elements): the table load is slightly ahead on
  both machines, by 0.03–0.04 ns per element on the arithmetic form clang
  actually emits (`bzhi`, `lsl; bic`), i.e. about a tenth of a cycle.
- **LatencyX** (result feeds the next `x`): identical within noise. The load's
  address does not depend on the previous result, so its latency is hidden.
- **LatencyN** (result selects the next mask): the table load costs **2.0–2.2 ns**
  per element against **0.63 ns** for `bzhi` and **1.04 ns** for `lsl; bic` — a
  dependent load is 2× to 3.5× slower than the arithmetic. This is the shape
  of a bit reader whose next field width comes from decoded state.
- On AArch64, hoisting the constant makes no measurable difference
  (`lsl; sub; and` with and without the `mov`).

The generic TTI cost model in PR 228736 scores the load at 1 and the shift plus
subtract at 2, and so keeps the load on every target without an override. On
these two machines that is the wrong call wherever the mask is on a dependency
chain and a wash (~0.1 cycle) where it is not. The table also costs a cache line
and, under PIC, an address materialization per site, which this microbenchmark
hoists and therefore does not charge to the load.
