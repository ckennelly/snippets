# santests-ubsan.sh BIN NAME: the integration suite under UBSan (and ASan,
# without leak checks), keeping darktable-cli's stderr. UBSan prints its
# runtime errors to stderr whatever log_path says, and the suite's ./run
# discards darktable-cli's stderr, so a wrapper saves it for each test.
set -u
BIN=$1; NAME=$2; R=~/results/san/ubtests-$NAME; mkdir -p $R
W=$R/darktable-cli; CUR=$R/current
cat > $W <<EOW
#!/bin/bash
exec $(dirname $BIN)/darktable-cli "\$@" 2>> "\$(cat $CUR)/stderr.log"
EOW
chmod +x $W
cd ~/dt-tests
for t in $(ls -d [0-9]*); do
  [ -f $R/$t.done ] && continue
  git clean -q -fdx -e .venv $t 2>/dev/null
  mkdir -p $R/$t; echo $R/$t > $CUR
  ASAN_OPTIONS="detect_leaks=0:halt_on_error=0:log_path=$R/$t/asan" UBSAN_OPTIONS="print_stacktrace=1:halt_on_error=0:log_path=$R/$t/asan" \
    DARKTABLE_CLI=$W timeout 3600 ./run --disable-opencl --disable-timing $t > $R/$t/run.log 2>&1
  echo "$t rc=$? ok=$(grep -c '^  OK' $R/$t/run.log) ubsan=$(cat $R/$t/stderr.log $R/$t/asan* 2>/dev/null | grep -c 'runtime error') asan=$(cat $R/$t/asan* 2>/dev/null | grep -c 'ERROR: AddressSanitizer')" >> $R/summary.txt
  touch $R/$t.done
done
git -C ~/dt-tests checkout -q -- logs
echo "$NAME: $(wc -l < $R/summary.txt) tests, ok in $(grep -vc 'ok=0' $R/summary.txt), ubsan reports $(awk -F'ubsan=' '{split($2,a," "); s+=a[1]} END {print s}' $R/summary.txt), asan errors $(awk -F'asan=' '{s+=$2} END {print s}' $R/summary.txt)"
echo UBTESTS_DONE
