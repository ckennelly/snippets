# darktable under ASan, UBSan and LeakSanitizer

darktable's CI builds without sanitizers and has no GUI tests. These scripts
build darktable with `-fsanitize=address,undefined`, then drive the lighttable
through Lua (see `../rating-latency`). darktable leaves through its quit
action, so LeakSanitizer gets to report at exit. Each candidate fix is backed
by a report from the base build that is gone in a build with the fix
(`results/EVIDENCE.md`).

## Files

* `san.sh`: plain `ctest` on base and on each branch, then an ASan+UBSan
  build (`build-asan`, with `BUILD_TESTING=ON`) of base and of all branches
  merged, with `ctest` under the sanitizers. GCC's `-Wformat-overflow` and
  related warnings misfire under the sanitizers, and `src/CMakeLists.txt`
  adds `-Werror` for git checkouts, so the sanitizer flags demote those
  warnings with `-Wno-error=...`.
* `sanrun.sh`: `../rating-latency/run.py --quit` under the sanitizers, in the
  filemanager and culling layouts, plus a hover pass that moves the pointer
  over the thumbnails while the ratings are applied.
* `extra.lua`, `sanx.sh`: toggles color labels, duplicates an image, attaches
  tags and exports through Lua, then exports through `darktable-cli`.
* `undo.lua`, `sanundo.sh`: rates, color-labels and duplicates three images,
  then steps through the lighttable undo and redo actions (ctrl+z, ctrl+y),
  dropping the redo list with a new action partway through. It checks the
  images after every step (25 checks).
* `santip.sh`: one branch by itself at its pushed tip: plain and ASan
  builds, `ctest` on each, `sanrun.sh`'s three passes and `undo.lua`.
* `import.lua`, `sanimport.sh`: imports a JPEG whose maker, model and lens
  are new to the library.
* `sansum.py`, `sandirect.py`: dedupe the reports, by first darktable frame
  and by direct-leak stack.
* `evidence.py`: writes `results/EVIDENCE.md` from `results/raw`. For each
  fix, it gives the number of matching reports before and after, the two
  log files compared, and the first base report.
* `integ.sh`, `det.sh`: the integration suite (`darktable-org/darktable-tests`,
  CPU path) on base and on a candidate, then a pixel comparison of every
  output. `det.sh` reruns the tests whose pixels differ, to separate
  run-to-run noise from the change.
* `santags.sh`: exports one CR3 with six tags through `darktable-cli`, with
  the default metadata flags and then with private tags on and off, and
  records the exported `dc:subject` keywords.
* `tagexport.lua`, `sanexport.sh`: attaches tags whose sort order moves the
  list head, then runs the tagging module's "export..." action and accepts
  the file dialog with `xdotool`.
* `santests.sh`: the whole integration suite under ASan+UBSan+LSan, one
  test at a time, one log directory per test.
* `tagjob.sh`, `iopjob.sh`: the build and run jobs for the two fix branches
  below (per-commit plain builds, ASan build and `ctest`, then the runs).
* `santests-ubsan.sh`: the suite again, keeping darktable-cli's stderr for
  UBSan. `tagtip.sh`: `fix/tag-export-leaks` rechecked at its pushed tip.
* `nodlclose.c`, `sym.sh`: darktable dlcloses its modules before LSan
  reports, so every frame in `src/iop` prints as `<unknown module>`. This
  preload makes `dlclose()` a no-op so that they symbolize. libasan has to
  come first: `LD_PRELOAD=$(gcc -print-file-name=libasan.so):nodlclose.so`.

ASan and UBSan share the `log_path` flag, and whichever options string is
parsed last wins, so the scripts set the same `log_path` in both. ASan and
LSan reports follow it; UBSan's runtime errors still go to stderr.

## Raw logs

`results/raw` holds every sanitizer log from these runs, gzipped (`zless`,
`zgrep`; the scripts read them as they are). One directory per run:

* `asan_ef98688fc`: base, ASan+UBSan+LSan, `sanrun.sh` (filemanager,
  culling, hover). `asan_san_all` is the same with all branches merged, and
  `asan_san_fixes` with the fix branches only. `ubsan-*` and `asan-*` are
  the sanitizer logs, one per darktable process; `dt-*.log` is darktable's
  own output, where UBSan's runtime errors also go.
* `sanx-base`, `sanx-fixes`, `sanx-fixes2`: `sanx.sh` (color labels,
  duplicates, tags and exports through Lua and `darktable-cli`) on base,
  on the fixes, and on the fixes with the color label and duplicate ones.
* `asan_fix_lsan-leaks`, `plain_fix_lsan-leaks.*`: `santip.sh` on
  `fix/lsan-leaks` alone at 816443dfa. `undo-base` and `undo-tip` are
  `undo.lua` on base and on that tip.
* `import-base`, `import-stmtfix`: `sanimport.sh` on base and with the
  statement fix. darktable's own log of these two runs is left out.
* `tagrun`: on `c24afcc4a`, `santags.sh` on master, on
  `fix/tag-export-leaks` and on a probe of the private flag loop,
  `sanexport.sh` on master and the fix, and `tests-master`: the full
  integration suite under the sanitizers, one directory per test (the
  sanitizer reports are in its `ubsan.*` files, see above).
* `ioprun`: `iopjob.sh`: six integration tests with `nodlclose.so` on
  master (`iop-master`) and on `fix/iop-leaks` (`iop-iop-leaks`), with the
  `ctest` runs, and `sym`, the first symbolized runs. The preload also
  reaches the test harness's own `date`, `sort` and `python3`, whose leak
  reports sit next to darktable-cli's.
* `ubrun`: `santests-ubsan.sh` on master (`ubtests-master`), and
  `tagtip.sh`'s results.
* `*.build.log`, `*.ctest.log`: the builds and the `ctest` runs, plain
  (`plain_*`) and under the sanitizers (`asan_*`).

`./evidence.py` regenerates `results/EVIDENCE.md` from them. To look
further, `./sansum.py` and `./sandirect.py` take any of the logs and print
every distinct report, by first darktable frame or by direct-leak stack.

## Findings and fixes

All on darktable `ef98688fc`, GCC 13, Ubuntu 24.04. `ctest` (13 tests)
passes on every branch with and without sanitizers. No ASan memory errors
showed up in any run.

| finding | report (base -> fixed) | branch |
|---|---|---|
| `dt_thumbnail_reload_infos()` replaces `thumb->filename` without freeing it, once per visible thumbnail per metadata change | 266 B -> none | `fix/lsan-leaks` |
| rating undo entries are freed with `g_list_free()`, not `g_list_free_full()` | 240 B in 20 objects -> none | `fix/lsan-leaks` |
| range filter blocks are freed with `g_free()`, leaking `block->txt` on every refresh | 54 reports, 5280 B -> none | `fix/lsan-leaks` |
| `dt_tag_get_list()` advances the list head to NULL, then frees it, i.e. frees nothing | 240 B -> none | `fix/lsan-leaks` |
| color label undo entries: same as the rating ones | 96 B in 12 objects -> none | `fix/lsan-leaks` |
| duplicate undo entries are recorded without a free function | 24 B in 2 objects -> none | `fix/lsan-leaks` |
| act-on hover queries finalize their statement only on a row | 4 statement reports, 35856 B -> none | `fix/sqlite-stmt-leaks` |
| `_image_get_set_name_id()` re-prepares into `stmt` without finalizing the SELECT | 14 statement reports, 9296 B -> none | `fix/sqlite-stmt-leaks` |
| `dt_iop_default_init()` stores int8 defaults through `short *` (UBSan: misaligned store, liquify's `idx`) | one UBSan report in each of 3 runs -> none | `fix/introspection-int8-default` |

The rating, color label and duplicate fixes change how undo entries are
freed, so `undo.lua` replays them through undo and redo, and drops some of
them from the redo list mid-session as well as at exit. On base and on the
`fix/lsan-leaks` tip, all 25 checks pass and ASan reports no errors; the
three undo leaks are gone on the tip. The first four rows above compare
base with that tip, and the color label and duplicate rows compare the two
`undo.lua` runs.

The int8 change touches how module defaults are built, so the integration
suite ran on base and on the fix. Both give 169 OK and the same 12 failures,
and the pixel comparison of the 181 outputs differs in two. Rerunning them
shows that `0103-almost-all` differs between two base runs by the same 11773
pixels, and that `0168-lut3d-srgb-pyramid` is identical in three reruns and
in the candidate's suite run, so neither difference comes from the change.

Not fixed:

* `_camctl_update_cameras()` leaks about 20 KB in a one-minute run, growing
  for as long as the camera poller runs: `libusb_get_device_list()` under libgphoto2's usb port driver,
  outside darktable.
* the library's sqlite connection is never fully closed at exit, so its
  page cache shows up as about 4 MB of indirect leaks; the act-on cache's
  last list (24 B) is not freed at exit either. Neither grows.
* `dt_gui_style_content_dialog()` calls `memcmp(NULL, NULL, 0)`
  (`styles_dialog.c:930`, UBSan `nonnull-attribute`), defined in C2y and
  harmless with glibc.

## Second round: the integration suite

On darktable `c24afcc4a`, the full integration suite (181 tests, CPU path)
under ASan+UBSan+LSan shows no ASan memory errors. 159 tests pass; the
other 22 fail the pixel comparison in both sanitizer runs, the same 22 each
time, while a plain build fails 12 of them (11 in common), so the extra
failures come with the sanitizer build. `./run` exits 0 either way, so count
the `OK` lines in its output.

UBSan prints its runtime errors to stderr whatever `log_path` says, and
`./run` discards darktable-cli's stderr, so the first suite run
(`santests.sh`) shows none. `santests-ubsan.sh` keeps it through a wrapper
(`ubrun/ubtests-master/*/stderr.log`): 597 reports, all at five places. Three
come in every test: `imageop.c:275`, the int8 store
(`fix/introspection-int8-default`), and `styles_dialog.c:930`, both
arguments of `memcmp(NULL, NULL, 0)`. The others are in X-Trans
demosaicing (`xtrans.c:437-439` and `1430-1432`, 9 tests): row offsets of
±`TS` through a `float[122]` row, which the code comments on as staying
inside the padded multi-dimensional array, and ASan agrees. `ctest` (32 tests) passes plain and under the sanitizers on
master and on both branches below, and every commit builds.

Most of the leaks it reports are allocations made once at startup and not
freed at exit (accelerators, module `.so` data, Lua, l10n). Four grow with
the work done:

| finding | report (master -> fixed) | branch |
|---|---|---|
| `dt_tag_get_list_export()` frees the sorted, reversed tag list from its old head, leaking every tag before it; this runs on every export with tags in the metadata, as with the default settings | `santags.sh`: 3 reports -> none; also in 13 suite tests | `fix/tag-export-leaks` |
| `dt_tag_export()` frees the sorted list from its old head | `sanexport.sh`: 3 reports -> none | `fix/tag-export-leaks` |
| denoiseprofile's `reload_defaults()` drops the matching noise profile list without a GUI: every export, thumbnail and `darktable-cli` run of an image with a noise profile | 5 reports per pipe, 1740 B -> none; in 180 of 181 suite tests | `fix/iop-leaks` |
| cacorrect's `cleanup_pipe()` clears `piece->data` without freeing it, on every pipe | 8 B per pipe -> none; in every suite test | `fix/iop-leaks` |
| watermark leaks `gdk_rgba_to_string()`'s string on every SVG render | 11 B -> none | `fix/iop-leaks` |

Per darktable-cli process, `fix/iop-leaks` takes 1736 B in 71 allocations
off each pipe (1747 B with a watermark; the overlay test runs two pipes).
The six tests' outputs still match.

The private-tag loop in `dt_tag_get_list_export()` reads
`sorted_tags->data` instead of the loop's `tagt`, so it clears the flag on
one tag only. Fixing it (`probe/private-loop`) changes no exported keyword
in any of `santags.sh`'s five runs: the parents come back from
`_tag_get_attached_export()` as rows of their own, so the loop has no
visible effect. It is left out of the branch.

Also not fixed: lens's `init_global()` (128 B once per process), and
pango and fontconfig caches in the two text overlay tests.
