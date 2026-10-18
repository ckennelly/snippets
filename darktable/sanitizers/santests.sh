# santests.sh BIN NAME: the integration suite (darktable-org/darktable-tests,
# CPU path) under ASan+UBSan+LSan, one test at a time so that each sanitizer
# log names its test. Resumable: finished tests are skipped.
set -u
BIN=$1; NAME=$2; R=~/results/san/tests-$NAME; mkdir -p $R
cd ~/dt-tests
for t in $(ls -d [0-9]*); do
  [ -f $R/$t.done ] && continue
  git clean -q -fdx -e .venv $t 2>/dev/null
  mkdir -p $R/$t
  ASAN_OPTIONS="detect_leaks=1:halt_on_error=0:log_path=$R/$t/asan" UBSAN_OPTIONS="print_stacktrace=1:halt_on_error=0:log_path=$R/$t/ubsan" \
    DARKTABLE_CLI=$(dirname $BIN)/darktable-cli timeout 3600 ./run --disable-opencl --disable-timing $t > $R/$t/run.log 2>&1
  echo "$t rc=$? $(grep -c 'ERROR: AddressSanitizer: [^d]' $R/$t/* 2>/dev/null | awk -F: '{s+=$2} END {print "asan_errors=" s+0}') $(cat $R/$t/* 2>/dev/null | grep -c 'runtime error') ubsan" >> $R/summary.txt
  touch $R/$t.done
done
echo "$NAME: $(wc -l < $R/summary.txt) tests, $(grep -c ' rc=0' $R/summary.txt) rc=0, asan errors in $(grep -vc 'asan_errors=0' $R/summary.txt), ubsan reports $(awk '{s+=$4} END {print s}' $R/summary.txt)"
