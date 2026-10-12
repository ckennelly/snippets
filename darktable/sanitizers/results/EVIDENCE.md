## fix/lsan-leaks thumbnail filename

reports matching `thumbnail.c:2418`: base 1 (266 B), with the fix 0
base: `asan_ef98688fc/ubsan-filemanager.29027.gz`, fixed: `asan_fix_lsan-leaks/ubsan-filemanager.4682.gz`

```
Direct leak of 266 byte(s) in 19 object(s) allocated from:
    #0 0x7d5ba72fd9c7 in malloc ../../../../src/libsanitizer/asan/asan_malloc_linux.cpp:69
    #1 0x7d5b9c319b79 in g_malloc (/lib/x86_64-linux-gnu/libglib-2.0.so.0+0x62b79) (BuildId: 559554a70029e72a04fb73e3b34fc142e8383293)
    #2 0x7d5b9c32f988 in g_strdup (/lib/x86_64-linux-gnu/libglib-2.0.so.0+0x78988) (BuildId: 559554a70029e72a04fb73e3b34fc142e8383293)
    #3 0x7d5ba27cbf05 in g_strdup_inline /usr/include/glib-2.0/glib/gstrfuncs.h:321
    #4 0x7d5ba27cbf05 in dt_thumbnail_reload_infos /home/exedev/darktable/src/dtgtk/thumbnail.c:2418
    #5 0x7d5ba27cbf05 in dt_thumbnail_reload_infos /home/exedev/darktable/src/dtgtk/thumbnail.c:2409
    #6 0x7d5ba27e90e3 in _dt_metadata_change_callback /home/exedev/darktable/src/dtgtk/thumbtable.c:2050
    #7 0x7d5b9e1842f9 in g_closure_invoke (/lib/x86_64-linux-gnu/libgobject-2.0.so.0+0x152f9) (BuildId: dcd75e756070510e18346edaed1a601e1f41f8f5)
    #8 0x7d5b9e1b390b  (/lib/x86_64-linux-gnu/libgobject-2.0.so.0+0x4490b) (BuildId: dcd75e756070510e18346edaed1a601e1f41f8f5)
    #9 0x7d5b9e1a163a in g_signal_emitv (/lib/x86_64-linux-gnu/libgobject-2.0.so.0+0x3263a) (BuildId: dcd75e756070510e18346edaed1a601e1f41f8f5)
    #10 0x7d5ba22a0deb in _signal_raise /home/exedev/darktable/src/control/signal.c:268
    #11 0x7d5b9c314dac in g_main_context_invoke_full (/lib/x86_64-linux-gnu/libglib-2.0.so.0+0x5ddac) (BuildId: 559554a70029e72a04fb73e3b34fc142e8383293)
    #12 0x7d5ba22a370a in dt_control_signal_raise /home/exedev/darktable/src/control/signal.c:378
    #13 0x7d5ba20bc13d in _ratings_apply /home/exedev/darktable/src/common/ratings.c:232
    #14 0x7d5ba20bc8fe in dt_ratings_apply_on_list /home/exedev/darktable/src/common/ratings.c:247
    #15 0x7d5ba20bc8fe in dt_ratings_apply_on_list /home/exedev/darktable/src/common/ratings.c:236
    #16 0x7d5ba20bcba0 in _action_process_rating /home/exedev/darktable/src/common/ratings.c:331
    #17 0x7d5ba284e94c in _process_action /home/exedev/darktable/src/gui/accelerators.c:4148
    #18 0x7d5ba2850f2f in dt_action_process /home/exedev/darktable/src/gui/accelerators.c:4381
    #19 0x7d5ba2a2cdc9 in _action_cb /home/exedev/darktable/src/lua/gui.c:137
    #20 0x7d5b9aa825e9  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x115e9) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #21 0x7d5b9aa830fc  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x120fc) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #22 0x7d5b9aa7df34  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0xcf34) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #23 0x7d5b9aaa1a85  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x30a85) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #24 0x7d5b9aa8323f in lua_pcallk (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x1223f) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #25 0x7d5ba2a1c688 in dt_lua_gtk_wrap_callback /home/exedev/darktable/src/lua/call.c:641
    #26 0x7d5b9c31450d  (/lib/x86_64-linux-gnu/libglib-2.0.so.0+0x5d50d) (BuildId: 559554a70029e72a04fb73e3b34fc142e8383293)
    #27 0x7d5b9c373bf6  (/lib/x86_64-linux-gnu/libglib-2.0.so.0+0xbcbf6) (BuildId: 559554a70029e72a04fb73e3b34fc142e8383293)
    #28 0x7d5b9c314ff6 in g_main_loop_run (/lib/x86_64-linux-gnu/libglib-2.0.so.0+0x5dff6) (BuildId: 559554a70029e72a04fb73e3b34fc142e8383293)
    #29 0x7d5ba287a254 in dt_gui_gtk_run /home/exedev/darktable/src/gui/gtk.c:2244
    #30 0x632c2e645584 in main /home/exedev/darktable/src/main.c:246
    #31 0x7d5b9842a1c9 in __libc_start_call_main ../sysdeps/nptl/libc_start_call_main.h:58
    #32 0x7d5b9842a28a in __libc_start_main_impl ../csu/libc-start.c:360
```

## fix/lsan-leaks ratings undo

reports matching `ratings.c:225`: base 1 (240 B), with the fix 0
base: `asan_ef98688fc/ubsan-filemanager.29027.gz`, fixed: `asan_fix_lsan-leaks/ubsan-filemanager.4682.gz`

```
Direct leak of 240 byte(s) in 20 object(s) allocated from:
    #0 0x7d5ba72fd9c7 in malloc ../../../../src/libsanitizer/asan/asan_malloc_linux.cpp:69
    #1 0x7d5ba20bc1e2 in _ratings_apply /home/exedev/darktable/src/common/ratings.c:225
    #2 0x7d5ba20bc8fe in dt_ratings_apply_on_list /home/exedev/darktable/src/common/ratings.c:247
    #3 0x7d5ba20bc8fe in dt_ratings_apply_on_list /home/exedev/darktable/src/common/ratings.c:236
    #4 0x7d5ba20bcba0 in _action_process_rating /home/exedev/darktable/src/common/ratings.c:331
    #5 0x7d5ba284e94c in _process_action /home/exedev/darktable/src/gui/accelerators.c:4148
    #6 0x7d5ba2850f2f in dt_action_process /home/exedev/darktable/src/gui/accelerators.c:4381
    #7 0x7d5ba2a2cdc9 in _action_cb /home/exedev/darktable/src/lua/gui.c:137
    #8 0x7d5b9aa825e9  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x115e9) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #9 0x7d5b9aa830fc  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x120fc) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #10 0x7d5b9aa7df34  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0xcf34) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #11 0x7d5b9aaa1a85  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x30a85) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #12 0x7d5b9aa8323f in lua_pcallk (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x1223f) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #13 0x7d5ba2a1c688 in dt_lua_gtk_wrap_callback /home/exedev/darktable/src/lua/call.c:641
    #14 0x7d5b9c31450d  (/lib/x86_64-linux-gnu/libglib-2.0.so.0+0x5d50d) (BuildId: 559554a70029e72a04fb73e3b34fc142e8383293)
    #15 0x7d5b9c373bf6  (/lib/x86_64-linux-gnu/libglib-2.0.so.0+0xbcbf6) (BuildId: 559554a70029e72a04fb73e3b34fc142e8383293)
    #16 0x7d5b9c314ff6 in g_main_loop_run (/lib/x86_64-linux-gnu/libglib-2.0.so.0+0x5dff6) (BuildId: 559554a70029e72a04fb73e3b34fc142e8383293)
    #17 0x7d5ba287a254 in dt_gui_gtk_run /home/exedev/darktable/src/gui/gtk.c:2244
    #18 0x632c2e645584 in main /home/exedev/darktable/src/main.c:246
    #19 0x7d5b9842a1c9 in __libc_start_call_main ../sysdeps/nptl/libc_start_call_main.h:58
    #20 0x7d5b9842a28a in __libc_start_main_impl ../csu/libc-start.c:360
    #21 0x632c2e645734 in _start (/home/exedev/dt-asan/asan_ef98688fc/bin/darktable+0x2734) (BuildId: 8de374a3db26251a224f929ef8a020be0c4ad649)
```

## fix/lsan-leaks range block txt

reports matching `range.c:1901`: base 54 (5280 B), with the fix 0
base: `asan_ef98688fc/ubsan-filemanager.29027.gz`, fixed: `asan_fix_lsan-leaks/ubsan-filemanager.4682.gz`

```
Direct leak of 400 byte(s) in 20 object(s) allocated from:
    #0 0x7d5ba72fd9c7 in malloc ../../../../src/libsanitizer/asan/asan_malloc_linux.cpp:69
    #1 0x7d5b9c319b79 in g_malloc (/lib/x86_64-linux-gnu/libglib-2.0.so.0+0x62b79) (BuildId: 559554a70029e72a04fb73e3b34fc142e8383293)
    #2 0x7d5b9c32f988 in g_strdup (/lib/x86_64-linux-gnu/libglib-2.0.so.0+0x78988) (BuildId: 559554a70029e72a04fb73e3b34fc142e8383293)
    #3 0x7d5ba2762d9e in g_strdup_inline /usr/include/glib-2.0/glib/gstrfuncs.h:321
    #4 0x7d5ba2762d9e in dtgtk_range_select_add_range_block /home/exedev/darktable/src/dtgtk/range.c:1901
    #5 0x7d5b38ba5e4a  (<unknown module>)
    #6 0x7d5b38bb59bc  (<unknown module>)
    #7 0x7d5b9719ab15  (/lib/x86_64-linux-gnu/libffi.so.8+0x7b15) (BuildId: c9149b6e99105aa4321ddd4a10ee4b90de7b7d49)
    #8 0x7ffe9e06702f  ([stack]+0x2302f)
```

## fix/lsan-leaks dt_tag_get_list

reports matching `tags.c:792`: base 1 (240 B), with the fix 0
base: `asan_ef98688fc/ubsan-filemanager.29027.gz`, fixed: `asan_fix_lsan-leaks/ubsan-filemanager.4682.gz`

```
Direct leak of 240 byte(s) in 10 object(s) allocated from:
    #0 0x7d5ba72fd9c7 in malloc ../../../../src/libsanitizer/asan/asan_malloc_linux.cpp:69
    #1 0x7d5b9c319b79 in g_malloc (/lib/x86_64-linux-gnu/libglib-2.0.so.0+0x62b79) (BuildId: 559554a70029e72a04fb73e3b34fc142e8383293)
    #2 0x7d5b9c30eea0 in g_list_append (/lib/x86_64-linux-gnu/libglib-2.0.so.0+0x57ea0) (BuildId: 559554a70029e72a04fb73e3b34fc142e8383293)
    #3 0x7d5ba2215699 in dt_tag_get_attached /home/exedev/darktable/src/common/tags.c:792
    #4 0x7d5ba221da86 in dt_tag_get_list /home/exedev/darktable/src/common/tags.c:902
    #5 0x7d5ba1e16b62 in _exif_xmp_read_data /home/exedev/darktable/src/common/exif.cc:5698
    #6 0x7d5ba1e1e10d in dt_exif_xmp_write /home/exedev/darktable/src/common/exif.cc:6605
    #7 0x7d5ba1f1b4e8 in dt_image_write_sidecar_file /home/exedev/darktable/src/common/image.c:3117
    #8 0x7d5ba229b764 in _control_write_sidecars_job_run /home/exedev/darktable/src/control/jobs/sidecar_jobs.c:93
    #9 0x7d5ba2270ebf in _control_job_execute /home/exedev/darktable/src/control/jobs.c:321
    #10 0x7d5ba2273ea7 in _control_run_job /home/exedev/darktable/src/control/jobs.c:336
    #11 0x7d5ba2273ea7 in _control_work /home/exedev/darktable/src/control/jobs.c:565
    #12 0x7d5ba725ea41 in asan_thread_start ../../../../src/libsanitizer/asan/asan_interceptors.cpp:234
    #13 0x7d5b9849cb83 in start_thread nptl/pthread_create.c:447
```

## fix/lsan-leaks colorlabels undo

reports matching `colorlabels.c:223`: base 1 (96 B), with the fix 0
base: `undo-base/asan.6380.gz`, fixed: `undo-tip/asan.6935.gz`

```
Direct leak of 96 byte(s) in 12 object(s) allocated from:
    #0 0x741f698fd9c7 in malloc ../../../../src/libsanitizer/asan/asan_malloc_linux.cpp:69
    #1 0x741f64296097 in _colorlabels_execute /home/exedev/darktable/src/common/colorlabels.c:223
    #2 0x741f64296b55 in dt_colorlabels_toggle_label_on_list /home/exedev/darktable/src/common/colorlabels.c:274
    #3 0x741f6429753e in _action_process_color_label /home/exedev/darktable/src/common/colorlabels.c:332
    #4 0x741f64e4e94c in _process_action /home/exedev/darktable/src/gui/accelerators.c:4148
    #5 0x741f64e50f2f in dt_action_process /home/exedev/darktable/src/gui/accelerators.c:4381
    #6 0x741f6502cdc9 in _action_cb /home/exedev/darktable/src/lua/gui.c:137
    #7 0x741f5d2885e9  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x115e9) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #8 0x741f5d2890fc  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x120fc) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #9 0x741f5d283f34  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0xcf34) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #10 0x741f5d2a7a85  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x30a85) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #11 0x741f5d28923f in lua_pcallk (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x1223f) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #12 0x741f6501c688 in dt_lua_gtk_wrap_callback /home/exedev/darktable/src/lua/call.c:641
    #13 0x741f60c2a50d  (/lib/x86_64-linux-gnu/libglib-2.0.so.0+0x5d50d) (BuildId: 559554a70029e72a04fb73e3b34fc142e8383293)
    #14 0x741f60c89bf6  (/lib/x86_64-linux-gnu/libglib-2.0.so.0+0xbcbf6) (BuildId: 559554a70029e72a04fb73e3b34fc142e8383293)
    #15 0x741f60c2aff6 in g_main_loop_run (/lib/x86_64-linux-gnu/libglib-2.0.so.0+0x5dff6) (BuildId: 559554a70029e72a04fb73e3b34fc142e8383293)
    #16 0x741f64e7a254 in dt_gui_gtk_run /home/exedev/darktable/src/gui/gtk.c:2244
    #17 0x6368a8f49584 in main /home/exedev/darktable/src/main.c:246
    #18 0x741f5aa2a1c9 in __libc_start_call_main ../sysdeps/nptl/libc_start_call_main.h:58
    #19 0x741f5aa2a28a in __libc_start_main_impl ../csu/libc-start.c:360
    #20 0x6368a8f49734 in _start (/home/exedev/dt-asan/asan_ef98688fc/bin/darktable+0x2734) (BuildId: 8de374a3db26251a224f929ef8a020be0c4ad649)
```

## fix/lsan-leaks duplicate undo

reports matching `image.c:1556`: base 1 (24 B), with the fix 0
base: `undo-base/asan.6380.gz`, fixed: `undo-tip/asan.6935.gz`

```
Direct leak of 24 byte(s) in 2 object(s) allocated from:
    #0 0x741f698fd9c7 in malloc ../../../../src/libsanitizer/asan/asan_malloc_linux.cpp:69
    #1 0x741f6450ee19 in _image_duplicate_with_version /home/exedev/darktable/src/common/image.c:1556
    #2 0x741f65021b86 in dt_lua_duplicate_image /home/exedev/darktable/src/lua/database.c:40
    #3 0x741f5d2885e9  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x115e9) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #4 0x741f5d295672  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x1e672) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #5 0x741f5d288f6d in lua_callk (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x11f6d) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #6 0x741f5d29e104  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x27104) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #7 0x741f5d2885e9  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x115e9) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #8 0x741f5d295672  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x1e672) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #9 0x741f5d289115  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x12115) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #10 0x741f5d283f34  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0xcf34) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #11 0x741f5d2a7a85  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x30a85) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #12 0x741f5d28923f in lua_pcallk (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x1223f) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #13 0x741f65035fe6 in run_early_script /home/exedev/darktable/src/lua/init.c:128
    #14 0x741f5d2885e9  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x115e9) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #15 0x741f5d2890fc  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x120fc) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #16 0x741f5d283f34  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0xcf34) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #17 0x741f5d2a7a85  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x30a85) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #18 0x741f5d28923f in lua_pcallk (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x1223f) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #19 0x741f6501eaea in run_async_thread_main /home/exedev/darktable/src/lua/call.c:136
    #20 0x741f60c5e6a1  (/lib/x86_64-linux-gnu/libglib-2.0.so.0+0x916a1) (BuildId: 559554a70029e72a04fb73e3b34fc142e8383293)
    #21 0x741f60c590e1  (/lib/x86_64-linux-gnu/libglib-2.0.so.0+0x8c0e1) (BuildId: 559554a70029e72a04fb73e3b34fc142e8383293)
    #22 0x741f6985ea41 in asan_thread_start ../../../../src/libsanitizer/asan/asan_interceptors.cpp:234
    #23 0x741f5aa9cb83 in start_thread nptl/pthread_create.c:447
```

## fix/sqlite-stmt-leaks act_on statements

reports matching `act_on.c + sqlite3VdbeCreate`: base 4 (35856 B), with the fix 0
base: `asan_ef98688fc/ubsan-hover.30041.gz`, fixed: `asan_san_all/ubsan-hover.31890.gz`

```
Indirect leak of 14224 byte(s) in 14 object(s) allocated from:
    #0 0x77d9596fd9c7 in malloc ../../../../src/libsanitizer/asan/asan_malloc_linux.cpp:69
    #1 0x77d950baeb3a  (/lib/x86_64-linux-gnu/libsqlite3.so.0+0xa5b3a) (BuildId: 5701975a7ab1644d59e6b20df0257e183eafa78e)
    #2 0x77d950bb3cd5 in sqlite3Malloc (/lib/x86_64-linux-gnu/libsqlite3.so.0+0xaacd5) (BuildId: 5701975a7ab1644d59e6b20df0257e183eafa78e)
    #3 0x77d950bba011  (/lib/x86_64-linux-gnu/libsqlite3.so.0+0xb1011) (BuildId: 5701975a7ab1644d59e6b20df0257e183eafa78e)
    #4 0x77d950c2d603  (/lib/x86_64-linux-gnu/libsqlite3.so.0+0x124603) (BuildId: 5701975a7ab1644d59e6b20df0257e183eafa78e)
    #5 0x77d950c08fc4  (/lib/x86_64-linux-gnu/libsqlite3.so.0+0xfffc4) (BuildId: 5701975a7ab1644d59e6b20df0257e183eafa78e)
    #6 0x77d950c09f41 in sqlite3VdbeCreate (/lib/x86_64-linux-gnu/libsqlite3.so.0+0x100f41) (BuildId: 5701975a7ab1644d59e6b20df0257e183eafa78e)
    #7 0x77d950bed894 in sqlite3Select (/lib/x86_64-linux-gnu/libsqlite3.so.0+0xe4894) (BuildId: 5701975a7ab1644d59e6b20df0257e183eafa78e)
    #8 0x77d950bc39c1 in sqlite3Parser (/lib/x86_64-linux-gnu/libsqlite3.so.0+0xba9c1) (BuildId: 5701975a7ab1644d59e6b20df0257e183eafa78e)
    #9 0x77d950bf3115 in sqlite3RunParser (/lib/x86_64-linux-gnu/libsqlite3.so.0+0xea115) (BuildId: 5701975a7ab1644d59e6b20df0257e183eafa78e)
    #10 0x77d950bc70d4  (/lib/x86_64-linux-gnu/libsqlite3.so.0+0xbe0d4) (BuildId: 5701975a7ab1644d59e6b20df0257e183eafa78e)
    #11 0x77d950bc750e  (/lib/x86_64-linux-gnu/libsqlite3.so.0+0xbe50e) (BuildId: 5701975a7ab1644d59e6b20df0257e183eafa78e)
    #12 0x77d950bc75fd in sqlite3_prepare_v2 (/lib/x86_64-linux-gnu/libsqlite3.so.0+0xbe5fd) (BuildId: 5701975a7ab1644d59e6b20df0257e183eafa78e)
    #13 0x77d953fecef6 in _cache_update_hover /home/exedev/darktable/src/common/act_on.c:255
    #14 0x77d953fecef6 in _cache_update /home/exedev/darktable/src/common/act_on.c:374
    #15 0x77d953fee061 in dt_act_on_get_images /home/exedev/darktable/src/common/act_on.c:385
    #16 0x77d954be909c in _dt_metadata_change_callback /home/exedev/darktable/src/dtgtk/thumbtable.c:2041
    #17 0x77d94e6692f9 in g_closure_invoke (/lib/x86_64-linux-gnu/libgobject-2.0.so.0+0x152f9) (BuildId: dcd75e756070510e18346edaed1a601e1f41f8f5)
    #18 0x77d94e69890b  (/lib/x86_64-linux-gnu/libgobject-2.0.so.0+0x4490b) (BuildId: dcd75e756070510e18346edaed1a601e1f41f8f5)
    #19 0x77d94e68663a in g_signal_emitv (/lib/x86_64-linux-gnu/libgobject-2.0.so.0+0x3263a) (BuildId: dcd75e756070510e18346edaed1a601e1f41f8f5)
    #20 0x77d9546a0deb in _signal_raise /home/exedev/darktable/src/control/signal.c:268
    #21 0x77d94e714dac in g_main_context_invoke_full (/lib/x86_64-linux-gnu/libglib-2.0.so.0+0x5ddac) (BuildId: 559554a70029e72a04fb73e3b34fc142e8383293)
    #22 0x77d9546a370a in dt_control_signal_raise /home/exedev/darktable/src/control/signal.c:378
    #23 0x77d9544bc13d in _ratings_apply /home/exedev/darktable/src/common/ratings.c:232
    #24 0x77d9544bc8fe in dt_ratings_apply_on_list /home/exedev/darktable/src/common/ratings.c:247
    #25 0x77d9544bc8fe in dt_ratings_apply_on_list /home/exedev/darktable/src/common/ratings.c:236
    #26 0x77d9544bcba0 in _action_process_rating /home/exedev/darktable/src/common/ratings.c:331
    #27 0x77d954c4e94c in _process_action /home/exedev/darktable/src/gui/accelerators.c:4148
    #28 0x77d954c50f2f in dt_action_process /home/exedev/darktable/src/gui/accelerators.c:4381
    #29 0x77d954e2cdc9 in _action_cb /home/exedev/darktable/src/lua/gui.c:137
    #30 0x77d94ce825e9  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x115e9) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
    #31 0x77d94ce830fc  (/lib/x86_64-linux-gnu/liblua5.4.so.0+0x120fc) (BuildId: a97f440d293605d238d6088107182b4aabf457e8)
```

## fix/sqlite-stmt-leaks _image_get_set_name_id SELECT

reports matching `_image_get_set_name_id + sqlite3VdbeCreate`: base 14 (9296 B), with the fix 0
base: `import-base/asan.107982.gz`, fixed: `import-stmtfix/asan.108803.gz`

```
Indirect leak of 1016 byte(s) in 1 object(s) allocated from:
    #0 0x7ef59acfd9c7 in malloc ../../../../src/libsanitizer/asan/asan_malloc_linux.cpp:69
    #1 0x7ef5921aeb3a  (/lib/x86_64-linux-gnu/libsqlite3.so.0+0xa5b3a) (BuildId: 5701975a7ab1644d59e6b20df0257e183eafa78e)
    #2 0x7ef5921b3cd5 in sqlite3Malloc (/lib/x86_64-linux-gnu/libsqlite3.so.0+0xaacd5) (BuildId: 5701975a7ab1644d59e6b20df0257e183eafa78e)
    #3 0x7ef5921ba011  (/lib/x86_64-linux-gnu/libsqlite3.so.0+0xb1011) (BuildId: 5701975a7ab1644d59e6b20df0257e183eafa78e)
    #4 0x7ef59222d603  (/lib/x86_64-linux-gnu/libsqlite3.so.0+0x124603) (BuildId: 5701975a7ab1644d59e6b20df0257e183eafa78e)
    #5 0x7ef592208fc4  (/lib/x86_64-linux-gnu/libsqlite3.so.0+0xfffc4) (BuildId: 5701975a7ab1644d59e6b20df0257e183eafa78e)
    #6 0x7ef592209f41 in sqlite3VdbeCreate (/lib/x86_64-linux-gnu/libsqlite3.so.0+0x100f41) (BuildId: 5701975a7ab1644d59e6b20df0257e183eafa78e)
    #7 0x7ef5921ed894 in sqlite3Select (/lib/x86_64-linux-gnu/libsqlite3.so.0+0xe4894) (BuildId: 5701975a7ab1644d59e6b20df0257e183eafa78e)
    #8 0x7ef5921c39c1 in sqlite3Parser (/lib/x86_64-linux-gnu/libsqlite3.so.0+0xba9c1) (BuildId: 5701975a7ab1644d59e6b20df0257e183eafa78e)
    #9 0x7ef5921f3115 in sqlite3RunParser (/lib/x86_64-linux-gnu/libsqlite3.so.0+0xea115) (BuildId: 5701975a7ab1644d59e6b20df0257e183eafa78e)
    #10 0x7ef5921c70d4  (/lib/x86_64-linux-gnu/libsqlite3.so.0+0xbe0d4) (BuildId: 5701975a7ab1644d59e6b20df0257e183eafa78e)
    #11 0x7ef5921c750e  (/lib/x86_64-linux-gnu/libsqlite3.so.0+0xbe50e) (BuildId: 5701975a7ab1644d59e6b20df0257e183eafa78e)
    #12 0x7ef5921c75fd in sqlite3_prepare_v2 (/lib/x86_64-linux-gnu/libsqlite3.so.0+0xbe5fd) (BuildId: 5701975a7ab1644d59e6b20df0257e183eafa78e)
    #13 0x7ef59590780d in _image_get_set_name_id /home/exedev/darktable/src/common/image.c:3440
    #14 0x7ef59592fa16 in dt_image_cache_write_release_info /home/exedev/darktable/src/common/image_cache.c:366
    #15 0x7ef595925a83 in _image_import_internal /home/exedev/darktable/src/common/image.c:2067
    #16 0x7ef595c993d4 in _film_import1 /home/exedev/darktable/src/control/jobs/film_jobs.c:336
    #17 0x7ef595c9a0cd in dt_film_import1_run /home/exedev/darktable/src/control/jobs/film_jobs.c:35
    #18 0x7ef595c70ebf in _control_job_execute /home/exedev/darktable/src/control/jobs.c:321
    #19 0x7ef595c73ea7 in _control_run_job /home/exedev/darktable/src/control/jobs.c:336
    #20 0x7ef595c73ea7 in _control_work /home/exedev/darktable/src/control/jobs.c:565
    #21 0x7ef59ac5ea41 in asan_thread_start ../../../../src/libsanitizer/asan/asan_interceptors.cpp:234
    #22 0x7ef58be9cb83 in start_thread nptl/pthread_create.c:447
```

## fix/introspection-int8-default

reports matching `imageop.c:273`: base 1, with the fix 0
base: `asan_ef98688fc/dt-filemanager.log`, fixed: `asan_san_fixes/dt-filemanager.log`

```
/home/exedev/darktable/src/develop/imageop.c:273:71: runtime error: store to misaligned address 0x524000be2111 for type 'short int', which requires 2 byte alignment
0x524000be2111: note: pointer points here
 00 00 00  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  00 00 00 00 00
              ^ 
    #0 0x7d5ba246ab7f in dt_iop_default_init /home/exedev/darktable/src/develop/imageop.c:273
    #1 0x7d5ba248c0fa in dt_iop_load_module_by_so /home/exedev/darktable/src/develop/imageop.c:445
    #2 0x7d5ba2491502 in _init_module_so /home/exedev/darktable/src/develop/imageop.c:1870
    #3 0x7d5ba20204f9 in dt_module_load_modules /home/exedev/darktable/src/common/module.c:65
    #4 0x7d5ba246fc8e in dt_iop_load_modules_so /home/exedev/darktable/src/develop/imageop.c:1939
    #5 0x7d5ba1cd97e9 in dt_init /home/exedev/darktable/src/common/darktable.c:2139
    #6 0x632c2e6452c0 in main /home/exedev/darktable/src/main.c:205
    #7 0x7d5b9842a1c9 in __libc_start_call_main ../sysdeps/nptl/libc_start_call_main.h:58
    #8 0x7d5b9842a28a in __libc_start_main_impl ../csu/libc-start.c:360
    #9 0x632c2e645734 in _start (/home/exedev/dt-asan/asan_ef98688fc/bin/darktable+0x2734) (BuildId: 8de374a3db26251a224f929ef8a020be0c4ad649)
```
