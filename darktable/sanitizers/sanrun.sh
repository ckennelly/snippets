# sanrun.sh: harness under ASan+UBSan with a clean quit so LeakSanitizer reports
R=~/results/san
for n in asan_ef98688fc asan_san_all; do
  [ -f $R/$n.run.done ] && continue
  rm -rf $R/$n; mkdir -p $R/$n
  for layout in filemanager culling hover; do
    l=$layout; [ $layout = hover ] && l=filemanager
    export ASAN_OPTIONS="detect_leaks=1:halt_on_error=0:log_path=$R/$n/asan-$layout"
    export UBSAN_OPTIONS="print_stacktrace=1:log_path=$R/$n/ubsan-$layout"
    if [ $layout = hover ]; then
      # move the pointer across the thumbnail grid while the actions run
      ( sleep 45; for i in $(seq 1 120); do DISPLAY=:99 xdotool mousemove $((200 + (i % 10) * 220)) $((200 + (i / 10 % 5) * 220)); sleep 0.25; done ) &
      mover=$!
    fi
    python3 ~/rl/run.py --bin ~/dt-asan/$n/bin/darktable --lib ~/libs/syn-1000 --layout $l \
      --keys 20 --settle-ms 30000 --quit --log $R/$n/dt-$layout.log --label $n-$layout
    echo "$n $layout run rc=$?"
    [ $layout = hover ] && { kill $mover 2>/dev/null; wait $mover 2>/dev/null; }
  done
  unset ASAN_OPTIONS UBSAN_OPTIONS
  ls -la $R/$n
  touch $R/$n.run.done
done
echo SANRUN_DONE
