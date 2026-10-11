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
per-run median, in ms per rating action, with [min, max] over repetitions. Each
run's JSON is in `results/`.

**A/A control** (`results/ab2`, base against itself under another name): every
cell is within ±0.2 ms GUI-thread / ±0.8 ms process, i.e. no order or
position bias at n=5.

**Baseline** GUI-thread / process CPU per action: 1k filemanager 15.5 / 16.6,
1k culling 30.1 / 72.2, 50k filemanager 136.5 / 137.7, 50k culling 109.2 /
151.6 (`ab2`; `ab1` read 10-20% higher on another boot of the same VM type,
which the pairing cancels).

| branch | 1k filemanager | 1k culling | 50k filemanager | 50k culling |
|---|---|---|---|---|
| `perf/map-proxy-view` (ab1) | gui +0.71 [+0.54, +1.94] | gui -0.26 [-1.50, +1.29] | gui -4.40 [-7.20, -0.94] (-2.8%) | gui -5.53 [-6.50, -4.74] (-4.4%) |
| `perf/culling-keep-native-surface` (ab2) | gui +1.05 [+0.86, +2.18] (+6.8%) | gui -7.41 [-8.40, -7.24] (-24.7%); process -48.5 [-50.3, -46.6] (-67%) | gui +3.08 [+2.36, +3.94] (+2.3%) | gui -5.53 [-5.73, -4.65] (-5.1%); process -46.3 [-46.6, -44.3] (-31%) |
| `perf/rating-flags-only-write` (ab1) | gui +0.56 [+0.02, +0.59] | gui +0.10 [-0.64, +0.42] | gui +1.80 [-1.12, +5.23] | gui +2.09 [-1.91, +5.74] |
| `perf/sqlite-cache-size` (ab1) | gui +0.91 [+0.33, +2.15] | gui -0.35 [-0.44, +0.16] | gui -6.25 [-9.04, -4.50] (-4.1%) | gui -5.80 [-9.79, -2.61] (-4.7%) |

`ab1` ran before the A/A control existed. Its 1k filemanager column is
+0.5-1.0 ms for all four candidates, including ones that cannot touch that
path; treat that column as noise of about that size.

The culling branch's filemanager cost is not work done by the patch. A
`perf record -e page-faults` of the key loop (50k filemanager) counts 51K
faults against 19K for the base, and nearly all of them are under SQLite's
own `sqlite3Malloc`/`realloc` (sorter and b-tree inserts in
`_dt_collection_compute_count` and `_rating_range_update`). Keeping the
native surfaces alive changes the glibc heap layout so that the per-query
scratch memory is returned to the kernel and faulted in again on every
action.

`results/ab1/BUILDS` lists the revisions measured. `flags` (`e686dbe64`) and
`cache` (`1052d2aa0`) were later split or reworded into the pushed commits
with no code change; `culling` (`5539b7639`) is v1 of the culling branch,
superseded by `culling2` in `ab2`, which adds the stale-surface and focus
peaking checks.
