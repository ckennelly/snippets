# Results, 2026-10-03

ns per element, mean of 10 repetitions (CV ≤ 0.3% everywhere), clang 18.1.3 on Linux,
`-O2`, inputs from `std::mt19937_64(42)`. Raw output with the Google Benchmark
headers and the compiler's codegen for the C++ forms is in the `.txt`
files.

The inner loops were disassembled and reviewed for artifacts of the inline-asm
constraints: no spills, no re-materialized constants, identical induction and
addressing across kernels. Two harness artifacts were found and fixed before
these numbers were taken (a per-element store of the loop-carried value from
`DoNotOptimize`'s `"+m,r"` constraint, and on x86 a zero-extension of the table
index on the LatencyN chain). What remains on the LatencyN chain besides the
kernel is the `& 31` and, on x86, one register copy that applies equally to all
kernels.

**The Zen 3 and Neoverse-V2 LatencyN columns predate the LatencyN fix
described under the M5 Pro.** Those cores do not predict load values, so the
collapsed recurrence still measured a real dependent load each iteration.
Their numbers are valid latencies for the old chain (kernel + `& 31`). They
are about one cycle lower than a re-run with the current harness would give,
since the fix adds an `eor` to the chain.

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

## AArch64: Apple M5 Pro, MacBook Pro (bare metal, AC power)

Apple clang 21.0.0, `-mcpu=native -mno-outline`; CV ≤ 2.1%. Codegen for the
C++ forms matches clang 18 on Neoverse-V2 (`mov -1; lsl; bic`). Taken with
the revised LatencyN harness (below); at about 4.1 GHz, one cycle is 0.24 ns.

| kernel | Throughput | LatencyX | LatencyN |
|---|---:|---:|---:|
| table `ldr [tbl, n, uxtw #2]; and` | **0.277** | 0.485 | **1.799** |
| `lsl; bic` (-1 hoisted; what clang emits) | 0.306 | 0.486 | **0.961** |
| `lsl; sub; and` (1 hoisted) | 0.349 | 0.486 | **1.198** |
| `mov 1; lsl; sub; and` | 0.348 | 0.481 | **1.189** |

In cycles, LatencyN is 4 (`lsl; bic`), 5 (`lsl; sub; and`) and about 7.4
(table) per element. Each count includes the harness's `eor; and #31`. That
puts the dependent scaled-index load at about 4.4 cycles.

Two harness problems showed up on this machine, and both are fixed:

- **LatencyN collapsed to `n = 0`.** The original recurrence
  `n = x[i] & mask(n) & 31` has an absorbing state at `n = 0`
  (`mask(0) == 0`) and reaches it within a few elements. From then on, every
  iteration loaded `tbl[0] == 0`, a constant address and value. The M-series
  load address/value predictors broke the chain, and the table measured
  0.48 ns (about 2 cycles), faster than an L1 hit. The recurrence is now
  `n = (K(x[i], n) ^ n[i]) & 31`, which keeps `n` uniform at the cost of one
  `eor` on the chain for every kernel.
- **Apple clang outlines at `-O2` on arm64.** The MachineOutliner pulled each
  inner loop's shared tail (next load, `& 31`, increment, compare) into a
  function called once per element. That flattened every column to about
  0.48 ns. CMakeLists.txt now passes `-mno-outline` to clang on AArch64.
  Upstream clang 18 on Linux does not outline here, so the other two
  machines are unaffected.

## Reading

- **LatencyN** (the result selects the next mask, a bit reader's shape): the
  dependent table load costs **2.0–2.2 ns** per element against **0.62 ns** for
  `bzhi` and **1.02 ns** for `lsl; bic` — 2× to 3.5× slower on both machines.
  On the M5 Pro it costs 1.80 ns against 0.96 ns for `lsl; bic`, about 1.9×
  (3.4 extra cycles).
- **LatencyX** (the result feeds the next `x`): identical within noise. The
  load's address does not depend on the previous result, so its latency hides.
- **Throughput** (independent elements): on Zen 3 `bzhi` is clearly ahead
  (0.33 vs 0.52 ns; the table form is a third load per element next to the two
  input loads). On Neoverse-V2 the table is ahead of `lsl; bic` by 0.1 ns,
  about a fifth of a cycle at 2 GHz. On the M5 Pro the table is ahead of
  `lsl; bic` by 0.03 ns, about an eighth of a cycle.
- On AArch64, hoisting the constant makes no measurable difference
  (`lsl; sub; and` with and without the `mov`).

The microbenchmark is generous to the table: the address materialization
(`adrp; add`, or a GOT load under PIC) and the cache line the table occupies
are hoisted and warm here.
