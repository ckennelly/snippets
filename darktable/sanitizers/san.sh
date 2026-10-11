# san.sh: (1) plain ctest per branch, (2) ASan+UBSan build + ctest + harness for base and all branches merged.
# Resumable: each step leaves a .done marker.
set -u
cd ~/darktable
R=~/results/san; mkdir -p $R
BR="perf/map-proxy-view perf/culling-keep-native-surface perf/rating-flags-only-write perf/sqlite-cache-size fix/sqlite-stmt-leaks"

# (1) plain ctest
cmake -S . -B build -DBUILD_TESTING=ON > $R/cmake-plain.log 2>&1 || exit 1
for b in ef98688fc $BR; do
  n=plain_$(echo $b | tr / _)
  [ -f $R/$n.done ] && continue
  git checkout -q $b || exit 1
  ninja -C build > $R/$n.build.log 2>&1 || { echo "BUILD FAILED $b"; exit 1; }
  (cd build && timeout 1800 ctest --output-on-failure) > $R/$n.ctest.log 2>&1; echo "ctest rc=$?" >> $R/$n.ctest.log
  tail -4 $R/$n.ctest.log
  touch $R/$n.done
done

# merged branch for the sanitizer pass
if ! git rev-parse -q --verify san/all >/dev/null; then
  git checkout -q -b san/all ef98688fc
  for b in $BR; do git merge -q --no-edit $b || { echo "MERGE CONFLICT $b"; git merge --abort; exit 1; }; done
fi

# (2) ASan + UBSan
SAN="-fsanitize=address,undefined -fsanitize-recover=address -fno-omit-frame-pointer -gz"
cmake -S . -B build-asan -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
  -DCMAKE_C_FLAGS="$SAN" -DCMAKE_CXX_FLAGS="$SAN" \
  -DCMAKE_EXE_LINKER_FLAGS="-fsanitize=address,undefined" \
  -DCMAKE_SHARED_LINKER_FLAGS="-fsanitize=address,undefined" \
  -DUSE_OPENCL=OFF -DBUILD_TESTING=ON > $R/cmake-asan.log 2>&1 || exit 1
for b in ef98688fc san/all; do
  n=asan_$(echo $b | tr / _)
  [ -f $R/$n.done ] && continue
  git checkout -q $b || exit 1
  ninja -C build-asan > $R/$n.build.log 2>&1 || { echo "ASAN BUILD FAILED $b"; exit 1; }
  rm -rf ~/dt-asan/$n; cmake --install build-asan --prefix ~/dt-asan/$n > /dev/null
  rm -rf $R/$n; mkdir -p $R/$n
  export ASAN_OPTIONS="detect_leaks=1:halt_on_error=0:log_path=$R/$n/asan"
  export UBSAN_OPTIONS="print_stacktrace=1:log_path=$R/$n/ubsan"
  (cd build-asan && timeout 3600 ctest --output-on-failure) > $R/$n.ctest.log 2>&1; echo "ctest rc=$?" >> $R/$n.ctest.log
  tail -4 $R/$n.ctest.log
  for layout in filemanager culling; do
    export ASAN_OPTIONS="detect_leaks=1:halt_on_error=0:log_path=$R/$n/dt-$layout"
    export UBSAN_OPTIONS="print_stacktrace=1:log_path=$R/$n/dt-$layout"
    python3 ~/rl/run.py --bin ~/dt-asan/$n/bin/darktable --lib ~/libs/syn-1000 --layout $layout \
      --keys 20 --settle-ms 30000 --quit --log $R/$n/dt-$layout.log --label $n
    echo "run rc=$?"
  done
  unset ASAN_OPTIONS UBSAN_OPTIONS
  ls -la $R/$n
  touch $R/$n.done
done
echo SAN_DONE
