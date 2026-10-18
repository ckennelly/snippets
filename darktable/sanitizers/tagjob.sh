# tagjob.sh: ASan builds of master, the tag export fix and the private flag
# probe, then santags.sh on all three and sanexport.sh on master and the fix
set -u
R=~/results/san; BASE=c24afcc4a9
pgrep -x Xvfb > /dev/null || { setsid Xvfb :99 -screen 0 2560x1440x24 -nolisten tcp -noreset > /dev/null 2>&1 < /dev/null & sleep 3; }
cd ~/darktable
git cat-file -e $BASE 2>/dev/null || git fetch -q upstream master || exit 1
git fetch -q -f ~/tags.bundle "refs/heads/*:refs/heads/tb/*" || exit 1
for n in $BASE tb/fix/tag-export-leaks tb/probe/private-loop; do
  i=m_$(basename $n); [ $n = $BASE ] && i=m_master
  [ -f $R/$i.done ] && continue
  git checkout -q --detach $n; echo "build $i $(git log -1 --format='%h %s')"
  ninja -C build-asan > $R/$i.build.log 2>&1 || { echo "ASAN BUILD FAILED $i"; tail -20 $R/$i.build.log; exit 1; }
  rm -rf ~/dt-asan/$i; cmake --install build-asan --prefix ~/dt-asan/$i > /dev/null
  if [ $i = m_master ]; then
    rm -rf $R/$i-ctest; mkdir -p $R/$i-ctest
    (cd build-asan && ASAN_OPTIONS="detect_leaks=1:halt_on_error=0:log_path=$R/$i-ctest/asan" UBSAN_OPTIONS="print_stacktrace=1:log_path=$R/$i-ctest/ubsan" \
      timeout 3600 ctest --output-on-failure) > $R/$i.ctest.log 2>&1; echo "ctest rc=$?" >> $R/$i.ctest.log
    echo "ctest: $(grep 'tests passed' $R/$i.ctest.log)"
  fi
  touch $R/$i.done
done
for i in master tag-export-leaks private-loop; do bash ~/sanx/santags.sh ~/dt-asan/m_$i/bin/darktable $i; done
for i in master tag-export-leaks; do bash ~/sanx/sanexport.sh ~/dt-asan/m_$i/bin/darktable $i; done
bash ~/sanx/santests.sh ~/dt-asan/m_master/bin/darktable master
echo TAGJOB_DONE
