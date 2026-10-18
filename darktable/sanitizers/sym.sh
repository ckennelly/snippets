# sym.sh: rerun a few integration tests on m_master with dlclose disabled
set -u
A=$(gcc -print-file-name=libasan.so)  # libasan must come first in LD_PRELOAD
BIN=~/dt-asan/m_master/bin/darktable-cli; R=~/results/san/sym; mkdir -p $R
cd ~/dt-tests
for t in 0001-exposure 0032-watermark 0160-overlay; do
  git clean -q -fdx -e .venv $t 2>/dev/null; mkdir -p $R/$t
  LD_PRELOAD=$A:$HOME/sanx/nodlclose.so ASAN_OPTIONS="detect_leaks=1:halt_on_error=0:log_path=$R/$t/asan" UBSAN_OPTIONS="print_stacktrace=1:halt_on_error=0:log_path=$R/$t/asan" \
    DARKTABLE_CLI=$BIN timeout 3600 ./run --disable-opencl --disable-timing $t > $R/$t/run.log 2>&1
  echo "$t rc=$? $(ls $R/$t)"
done
echo SYM_DONE
