# santip.sh: fix/lsan-leaks by itself at its pushed tip: plain build and
# ctest, ASan+UBSan build and ctest, sanrun.sh's three passes, and undo.lua
# on base and on the tip
set -u
R=~/results/san; n=asan_fix_lsan-leaks
pgrep -x Xvfb > /dev/null || { setsid Xvfb :99 -screen 0 2560x1440x24 -nolisten tcp -noreset > /dev/null 2>&1 < /dev/null & sleep 3; }
cd ~/darktable
git fetch -q origin fix/lsan-leaks || exit 1
git checkout -q --detach FETCH_HEAD; echo "tip $(git log -1 --format='%h %s')"
if [ ! -f $R/plain_fix_lsan-leaks.done ]; then
  ninja -C build > $R/plain_fix_lsan-leaks.build.log 2>&1 || { echo "PLAIN BUILD FAILED"; exit 1; }
  (cd build && timeout 3600 ctest --output-on-failure) > $R/plain_fix_lsan-leaks.ctest.log 2>&1; echo "ctest rc=$?" >> $R/plain_fix_lsan-leaks.ctest.log
  touch $R/plain_fix_lsan-leaks.done
fi
echo "plain: $(grep 'tests passed' $R/plain_fix_lsan-leaks.ctest.log) $(tail -1 $R/plain_fix_lsan-leaks.ctest.log)"
if [ ! -f $R/$n.done ]; then
  ninja -C build-asan > $R/$n.build.log 2>&1 || { echo "ASAN BUILD FAILED"; exit 1; }
  rm -rf ~/dt-asan/$n; cmake --install build-asan --prefix ~/dt-asan/$n > /dev/null
  rm -rf $R/$n-ctest; mkdir -p $R/$n-ctest
  (cd build-asan && ASAN_OPTIONS="detect_leaks=1:halt_on_error=0:log_path=$R/$n-ctest/asan" UBSAN_OPTIONS="print_stacktrace=1:log_path=$R/$n-ctest/ubsan" \
    timeout 3600 ctest --output-on-failure) > $R/$n.ctest.log 2>&1; echo "ctest rc=$?" >> $R/$n.ctest.log
  touch $R/$n.done
fi
echo "asan: $(grep 'tests passed' $R/$n.ctest.log) $(tail -1 $R/$n.ctest.log)"
if [ ! -f $R/$n.run.done ]; then
  rm -rf $R/$n; mkdir -p $R/$n
  for layout in filemanager culling hover; do
    l=$layout; [ $layout = hover ] && l=filemanager
    export ASAN_OPTIONS="detect_leaks=1:halt_on_error=0:log_path=$R/$n/asan-$layout"
    export UBSAN_OPTIONS="print_stacktrace=1:log_path=$R/$n/ubsan-$layout"
    if [ $layout = hover ]; then
      ( sleep 45; for i in $(seq 1 120); do DISPLAY=:99 xdotool mousemove $((200 + (i % 10) * 220)) $((200 + (i / 10 % 5) * 220)); sleep 0.25; done ) &
      mover=$!
    fi
    python3 ~/rl/run.py --bin ~/dt-asan/$n/bin/darktable --lib ~/libs/syn-1000 --layout $l \
      --keys 20 --settle-ms 30000 --quit --log $R/$n/dt-$layout.log --label $n-$layout
    echo "$n $layout run rc=$?"
    [ $layout = hover ] && { kill $mover 2>/dev/null; wait $mover 2>/dev/null; }
  done
  unset ASAN_OPTIONS UBSAN_OPTIONS
  touch $R/$n.run.done
fi
bash ~/sanx/sanundo.sh ~/dt-asan/asan_ef98688fc/bin/darktable base
bash ~/sanx/sanundo.sh ~/dt-asan/$n/bin/darktable tip
echo SANTIP_DONE
