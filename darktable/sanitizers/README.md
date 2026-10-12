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
* `import-base`, `import-stmtfix`: `sanimport.sh` on base and with the
  statement fix. darktable's own log of these two runs is left out.
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
| color label undo entries: same as the rating ones | 80 B in 10 objects -> none | `fix/lsan-leaks` |
| duplicate undo entries are recorded without a free function | 36 B in 3 objects -> none | `fix/lsan-leaks` |
| act-on hover queries finalize their statement only on a row | 4 statement reports, 35856 B -> none | `fix/sqlite-stmt-leaks` |
| `_image_get_set_name_id()` re-prepares into `stmt` without finalizing the SELECT | 14 statement reports, 9296 B -> none | `fix/sqlite-stmt-leaks` |
| `dt_iop_default_init()` stores int8 defaults through `short *` (UBSan: misaligned store, liquify's `idx`) | one UBSan report in each of 3 runs -> none | `fix/introspection-int8-default` |

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
* a review also found partial frees of the sorted tag list in
  `dt_tag_get_list_export()` and `dt_tag_export()`. Neither the Lua export nor
  `darktable-cli` (with its default metadata flags) reaches them, so there is
  no report to back a fix yet.
