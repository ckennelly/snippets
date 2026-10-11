# darktable: CPU cost of a lighttable rating keystroke

Each rating keystroke in the lighttable runs `_action_process_rating()`
(`src/common/ratings.c`), which applies the rating and then reloads the whole
collection with `dt_collection_update_query(..., DT_COLLECTION_CHANGE_RELOAD,
...)`. The reload and the signal handlers it triggers all run on the GUI
thread, so the cost grows with the size of the collection. This harness
measures that cost per keystroke, without patching darktable, so a change can
be A/B tested against its base.

## What it measures

`bench.lua` runs inside darktable (`--luacmd`). It selects the first image of
the collection and applies `views/thumbtable/rating` through
`darktable.gui.action()`. That is `dt_action_process()`, the same path a
keyboard shortcut takes after the key lookup. Lua's call blocks until the
action has run on the GUI thread. bench.lua alternates two and four stars, so
every action is a real change, and waits a fixed gap after each one so that
the redraw it queued has run. For every action it records:

* **GUI-thread CPU**: first field of `/proc/<pid>/task/<pid>/schedstat`. The
  GUI thread is the main thread, so its tid is the pid. This is the time the
  UI is unresponsive for, provided nothing else is queued.
* **Process CPU**: `os.clock()`, which is `clock()` and so covers all
  threads, including OpenMP workers used for color conversion and the
  sidecar writer.

Both are taken over the window [action, action + gap]. A 10 s idle window
before the first action gives the background floor, which is about 0.15 ms
GUI and 0.35 ms process per 500 ms gap.

## Files

* `mklib.py`: builds a library of N images from a few raw files. It
  hard-links them as `roll/img000000.ext`... and imports one link per raw
  through darktable (the seed). It then clones the seed's `images`,
  `tagged_images` and `meta_data` rows in SQL up to N. 50k images take 15 s
  instead of about 40 minutes of import, and the rows match a real import
  apart from the ids.
* `run.py`: one run. It starts Xvfb (`-noreset`, so the pointer stays where
  it is put) and parks the pointer at (5, 5). Otherwise the rating applies to
  the hovered thumbnail instead of the selection. It copies `library.db` and
  `data.db` to a fresh config directory, so every run starts from the same
  database, then starts darktable with a fixed darktablerc (layout, sort,
  2560x1440 window, no crawler). Thumbnails come from the library's shared
  `cache/`. At the end it checks that the image has the expected rating and
  prints the per-run medians.
* `ab.py`: interleaved A/B. For each repetition and each (library, layout) it
  runs every build once, reversing the order on alternate repetitions. It
  then reports the median over repetitions of the paired difference
  `candidate - base` in per-run median CPU per action, with its range. It is
  resumable: runs whose JSON exists are skipped, so a Spot preemption costs
  one run.

## Requirements

darktable built with Lua (the default), Xvfb, xdotool, xdpyinfo, Python 3.
The results below used RelWithDebInfo builds with `-DUSE_OPENCL=OFF`, on raws
from raw.pixls.us (CC0; 37 files from Sony, Canon, Nikon and Fujifilm
bodies, 7 of them X-Trans).

```
./mklib.py --bin $BASE/bin/darktable --raws raws/ --n 1000  --out libs/syn-1000
./mklib.py --bin $BASE/bin/darktable --raws raws/ --n 50000 --out libs/syn-50000
./ab.py --out results/ --rep 5 --keys 60 \
    --lib libs/syn-1000 --lib libs/syn-50000 --layout filemanager --layout culling \
    base=$BASE/bin/darktable candidate=$CAND/bin/darktable
```

## Caveats

* CPU time, not wall latency. The window also catches work that runs after
  the UI first goes idle, such as deferred redraws and timeouts, so it reads
  higher than the time to the first idle. At 1k images, a probe patch that
  timestamped the action and a `G_PRIORITY_LOW` idle callback measured about
  8 ms (filemanager) and 24 ms (culling) to idle, against 21 and 38 ms of
  GUI-thread CPU here. Work deferred past the gap is missed. Work on other
  threads only shows in the process column.
* darktable is killed at the end of a run, so thumbnails generated during a
  run are not written to the disk cache. The 15 s settle covers regenerating
  the visible ones, which are embedded JPEGs by default.
* Rating sort, collect or filter rules on rating, grouping and the
  "act on" algorithm all change the path; the harness fixes filename sort and
  the default "all except rejected" rating filter.

## Results

GCP c3d-highcpu-16 (Spot), darktable `ef98688fc`, RelWithDebInfo, no OpenCL;
5 repetitions of 60 actions per (library, layout, build). Every number below is
the median over repetitions of the paired difference `candidate - base` in the
per-run median, in ms per rating action, with [min, max] over repetitions.
Each run's JSON is in `results/`.

`base` is a clean build of `ef98688fc`, made the same way as the candidates:
an incremental `ninja` in one build directory, installed to its own prefix.
Two controls run in the same interleaved A/B:

* `base2`: the base binary under another name. It catches order and position
  bias.
* `dirty`: the same commit built from a dirty tree. Its `.text` matches the
  base's except for RIP-relative displacements into `.rodata`, which moved
  because the version string is 6 bytes longer (`-dirty`). It shows how far
  code and heap layout alone move a cell.

**Baseline** GUI-thread / process CPU per action: 1k filemanager 16.0 / 17.2,
1k culling 28.7 / 68.6, 50k filemanager 139.8 / 140.4, 50k culling 108.9 /
148.8.

| build | 1k filemanager | 1k culling | 50k filemanager | 50k culling |
|---|---|---|---|---|
| `base2` (A/A) | gui -0.06 [-0.10, +0.31] | gui +0.26 [-0.34, +0.35] | gui -0.11 [-3.88, +1.11] | gui +0.00 [-0.53, +0.36] |
| `dirty` (layout) | gui -0.91 [-1.07, -0.02] | gui -0.23 [-0.49, +0.09] | gui -4.08 [-6.84, -1.89] | gui -1.11 [-2.16, -0.95] |
| `perf/map-proxy-view` | gui -0.30 [-0.40, +0.15] | gui -0.15 [-0.54, +0.97] | gui -7.47 [-10.65, -5.68] (-5.3%) | gui -4.73 [-6.89, -3.33] (-4.3%) |
| `perf/sqlite-cache-size` | gui +0.03 [-0.37, +0.10] | gui +0.30 [+0.05, +2.27] | gui -6.99 [-11.41, -5.82] (-5.0%) | gui -4.41 [-6.46, -3.06] (-4.0%) |
| `perf/culling-keep-native-surface` | gui -0.02 [-0.04, +0.19] | gui -6.87 [-8.11, -6.60] (-23.8%); process -45.6 [-46.6, -44.8] (-66%) | gui -0.71 [-1.91, +3.85] | gui -6.92 [-8.27, -4.53] (-6.3%); process -45.6 [-47.6, -45.5] (-30%) |
| `perf/rating-flags-only-write` | gui -0.45 [-0.52, +0.30] | gui +0.05 [-0.08, +0.36] | gui -0.70 [-4.22, +0.69] | gui +2.42 [-0.20, +4.05] |

All rows but the culling one are from `results/ab5`. The culling branch was
reworked after ab5, so its row is from `results/ab6`, which measured the
pushed branch against the same clean base, with its own A/A control (within
±0.4 ms GUI in every cell). ab6 also re-ran the previous version of the
branch, which ab5 measured: the two agree within 0.2 ms in the culling cells
and within 0.7 ms at 50k filemanager, inside that cell's A/A range.

Reading it:

* The culling branch saves about 7 ms of GUI-thread CPU and 45 ms of process
  CPU per action in the culling layout, mostly display color conversion on
  OpenMP workers, far outside the layout control. It costs nothing in the
  filemanager.
* The map and SQLite cache branches save 4-7 ms (4-5%) at 50k images and
  nothing measurable at 1k. The `dirty` row moves the 50k filemanager cell
  by 4 ms on its own, so those two cells carry about that much layout
  uncertainty.
* The flags-only write has no consistent effect.

### Earlier runs

`results/ab1` to `ab3` compared against the `dirty` build, which was the only
base build at the time. That made every candidate read +0.5 to +1.1 ms at 1k
filemanager while the same-binary A/A read zero, and gave the culling branch
an apparent +3 ms at 50k filemanager, which a `perf record -e page-faults`
pinned on SQLite's own allocations (51K faults against 19K): a heap layout
difference, not work the patch does. `results/ab4` measured `dirty` against
the clean build directly: +0.95 [+0.60, +1.03] ms at 1k filemanager for the
clean one. A same-binary A/A doesn't control for layout, so compare against a
clean rebuild made the same way as the candidates.

`results/ab5/preempted` holds the one group that a Spot preemption split
across two boots; it was rerun from scratch and is not in the table.
