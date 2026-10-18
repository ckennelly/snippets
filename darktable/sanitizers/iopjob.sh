# iopjob.sh: per-commit plain builds of fix/iop-leaks, an ASan build of its
# tip with ctest, then a few integration tests on master and the fix with
# dlclose disabled so that module frames symbolize, and the leak counts
set -u
R=~/results/san; BASE=c24afcc4a9
A=$(gcc -print-file-name=libasan.so)
cd ~/darktable
git fetch -q -f ~/iop.bundle "refs/heads/*:refs/heads/ib/*" || exit 1
for c in $(git rev-list --reverse $BASE..ib/fix/iop-leaks); do
  git checkout -q --detach $c
  ninja -C build > $R/iop-plain-$(git rev-parse --short=10 $c).build.log 2>&1 \
    && echo "plain ok $(git log -1 --format='%h %s')" || { echo "PLAIN BUILD FAILED $c"; exit 1; }
done
(cd build && timeout 3600 ctest) > $R/iop-plain.ctest.log 2>&1; echo "plain ctest: $(grep 'tests passed' $R/iop-plain.ctest.log)"
i=m_iop-leaks
if [ ! -f $R/$i.done ]; then
  ninja -C build-asan > $R/$i.build.log 2>&1 || { echo "ASAN BUILD FAILED"; tail -20 $R/$i.build.log; exit 1; }
  rm -rf ~/dt-asan/$i; cmake --install build-asan --prefix ~/dt-asan/$i > /dev/null
  rm -rf $R/$i-ctest; mkdir -p $R/$i-ctest
  (cd build-asan && ASAN_OPTIONS="detect_leaks=1:halt_on_error=0:log_path=$R/$i-ctest/asan" UBSAN_OPTIONS="print_stacktrace=1:log_path=$R/$i-ctest/asan" \
    timeout 3600 ctest --output-on-failure) > $R/$i.ctest.log 2>&1; echo "ctest rc=$?" >> $R/$i.ctest.log
  echo "asan ctest: $(grep 'tests passed' $R/$i.ctest.log)"
  touch $R/$i.done
fi
cd ~/dt-tests
for b in master iop-leaks; do
  O=$R/iop-$b; rm -rf $O; mkdir -p $O
  for t in 0001-exposure 0013-denoiseprofile-wavelets 0027-denoiseprofile-nlmeans 0032-watermark 0103-almost-all 0160-overlay; do
    git clean -q -fdx -e .venv $t 2>/dev/null; mkdir -p $O/$t
    LD_PRELOAD=$A:$HOME/sanx/nodlclose.so \
      ASAN_OPTIONS="detect_leaks=1:halt_on_error=0:log_path=$O/$t/asan" UBSAN_OPTIONS="print_stacktrace=1:halt_on_error=0:log_path=$O/$t/asan" \
      DARKTABLE_CLI=~/dt-asan/m_$b/bin/darktable-cli timeout 3600 ./run --disable-opencl --disable-timing $t > $O/$t/run.log 2>&1
    rc=$?
    L=$(cat $O/$t/asan* 2>/dev/null)
    echo "$b $t rc=$rc $(grep -c '^  OK' $O/$t/run.log)ok" \
      "noiseprofile=$(echo "$L" | awk 'BEGIN{RS="\n\n"} /leak of/ && /noiseprofiles.c/' | grep -c 'leak of')" \
      "cacorrect=$(echo "$L" | awk 'BEGIN{RS="\n\n"} /leak of/ && /cacorrect.c/' | grep -c 'leak of')" \
      "watermark=$(echo "$L" | awk 'BEGIN{RS="\n\n"} /leak of/ && /watermark.c/' | grep -c 'leak of')" \
      "errors=$(echo "$L" | grep -c 'ERROR: AddressSanitizer\|runtime error')" \
      "$(echo "$L" | grep SUMMARY)"
  done
done
echo IOPJOB_DONE
