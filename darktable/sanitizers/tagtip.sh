# tagtip.sh: fix/tag-export-leaks at its pushed tip: per-commit plain builds,
# plain and ASan ctest, then santags.sh and sanexport.sh on the tip
set -u
R=~/results/san; TIP=f69c2a5ef3
pgrep -x Xvfb > /dev/null || { setsid Xvfb :99 -screen 0 2560x1440x24 -nolisten tcp -noreset > /dev/null 2>&1 < /dev/null & sleep 3; }
cd ~/darktable
git fetch -q upstream master && git fetch -q origin fix/tag-export-leaks || exit 1
[ "$(git rev-parse --short=10 FETCH_HEAD)" = $TIP ] || { echo "tip mismatch $(git rev-parse FETCH_HEAD)"; exit 1; }
for c in $(git rev-list --reverse upstream/master..$TIP); do
  git checkout -q --detach $c
  ninja -C build > $R/tagtip-plain-$(git rev-parse --short=10 $c).build.log 2>&1 \
    && echo "plain ok $(git log -1 --format='%h %s')" || { echo "PLAIN BUILD FAILED $c"; exit 1; }
done
(cd build && timeout 3600 ctest) > $R/tagtip-plain.ctest.log 2>&1; echo "plain ctest: $(grep 'tests passed' $R/tagtip-plain.ctest.log)"
i=m_tagtip
ninja -C build-asan > $R/$i.build.log 2>&1 || { echo "ASAN BUILD FAILED"; tail -20 $R/$i.build.log; exit 1; }
rm -rf ~/dt-asan/$i; cmake --install build-asan --prefix ~/dt-asan/$i > /dev/null
rm -rf $R/$i-ctest; mkdir -p $R/$i-ctest
(cd build-asan && ASAN_OPTIONS="detect_leaks=1:halt_on_error=0:log_path=$R/$i-ctest/asan" UBSAN_OPTIONS="print_stacktrace=1:log_path=$R/$i-ctest/asan" \
  timeout 3600 ctest --output-on-failure) > $R/$i.ctest.log 2>&1
echo "asan ctest: $(grep 'tests passed' $R/$i.ctest.log)"
bash ~/sanx/santags.sh ~/dt-asan/$i/bin/darktable tagtip
bash ~/sanx/sanexport.sh ~/dt-asan/$i/bin/darktable tagtip
echo TAGTIP_DONE
