# llvm/llvm-project#228910: widen zero-extended low-bits masks to select and-not

[PR 228910](https://github.com/llvm/llvm-project/pull/228910) rewrites
`and X, zext(~(-1 << n))` into the same mask built in the wide type, so that
on AArch64 a 32-bit low-bits mask applied to a 64-bit value is `lsl; bic`
instead of `lsl; mvn; and`. The shape comes from `x & ((1u << n) - 1)` in
source (brotli's hashers, zlib's inflate) and from the AggressiveInstCombine
mask-table fold (394c8dd14933) applied to zstd's `BIT_mask` on AArch64.

End-to-end measurements of the fold, each comparing clang at upstream main
(4428e953e2a5) against main plus the fold, built and run alternately:

| harness | what it runs |
|---|---|
| `fleetbench/run.sh` | Fleetbench's compression family (Snappy, ZSTD), ThinLTO, Fleetbench's own flags; `report.py` summarises |
| `zstd/run.sh` | zstd 1.5.7 CLI, `zstd -b1 -b3 -b9 -i5` on enwik8 |
| `brotli/run.sh` | brotli 1.1.0 CLI, `-q 5` and `-q 9` compress and decompress of enwik8 |
| `snappy/run.sh` | snappy 1.2.2 `snappy_benchmark` (`BM_UFlat*`, `BM_ZFlat*`, 77 benchmarks) |

The three codec harnesses take `VARIANTS="name=/path/to/clang ..."` and
`ROUNDS`, and `PIN="taskset -c 7"` to pin the single-threaded runs; `zstd/run.sh`
also has the older `CC_FOLD`/`CC_NOFOLD` and single-compiler modes used before
the fold existed. `final_table.py` renders `results/FINAL-TABLE.txt` from
`results/` (first 10 rounds, mean +/- sd of the per-round speed ratio).

`sweep/mvnscan.py` counts the `lsl w; mvn w; and x` signature in AArch64
assembly or disassembly, to see where the shape occurs; it found it only in
bit-packing codecs (zstd/FSE bit I/O, zlib inflate, brotli hashers), not in
tcmalloc, protobuf, swissmap or LLVM itself.

Machines: GCE `c4a-standard-16` (Neoverse-V2, Spot) and `n2d-standard-16`
(Zen 3; Spot, switched to on-demand for the final x86 rounds after repeated
preemptions). Both machines' results carry the machine type in their headers.

Also in `results/zstd/`: the earlier runs that led here, named by stage —
the 4-way comparison (`nofold` = parent of the mask-table fold, `fold`,
`pr` = fold + PR 228736's code, `alt` = fold + the AArch64-only prototype of
this combine) in `zstd-<arch>.txt`, the 7-round re-check in `*-recheck.txt`,
and the final pinned 10 rounds in `*-10r.txt`.

See `../pr228736/` for the microbenchmark of the table load against the
arithmetic forms that motivated looking at this shape.
