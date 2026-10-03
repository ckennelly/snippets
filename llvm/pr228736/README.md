# llvm/llvm-project#228736: low-bits mask, table load vs. arithmetic

[PR 228736](https://github.com/llvm/llvm-project/pull/228736) gates the
AggressiveInstCombine fold of a low-bits mask table (`x & tbl[n]` with
`tbl[n] == (1 << n) - 1`, as in zstd's `BIT_mask`) on a TTI cost comparison.
With the generic cost model a load costs 1 and the shift plus subtract cost 2,
so the fold is kept only on x86 with BMI2 (where the AND becomes one `bzhi`)
and dropped everywhere else, AArch64 included.

This measures the two forms directly, as fixed instruction sequences in inline
asm, so the result does not depend on which compiler is installed:

| kernel | x86-64 | AArch64 |
|---|---|---|
| table | `and (tbl,n,4), x` | `ldr w, [tbl, n, uxtw #2]; and` |
| arithmetic (what LLVM emits) | `bzhi` (BMI2) | `lsl; bic` (`x & ~(-1 << n)`, -1 hoisted) |
| arithmetic, no BMI2 | `mov 1; shl %cl; dec; and` | `lsl; sub; and` (1 hoisted) |
| arithmetic, nothing hoisted | — | `mov 1; lsl; sub; and` |

in three harnesses:

- **Throughput**: independent elements, results xor-accumulated.
- **LatencyX**: the result is the next element's `x`.
- **LatencyN**: the result selects the next element's `n`, so the table index
  (an address dependency) or the shift amount depends on the previous result.
  This is the bit-reader shape: the next field width comes from decoded state.

`ref_cxx_table` / `ref_cxx_arith` are the plain C++ forms, left out of line so
`run.sh` can record what the local compiler emits for them.

```
./run.sh            # builds into build-$(uname -m)/, writes results/<arch>-<cpu>.txt
```

Results: `results/SUMMARY.md`, raw output per machine alongside.
