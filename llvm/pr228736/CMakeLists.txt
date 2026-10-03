cmake_minimum_required(VERSION 3.22)
project(lowbits_mask CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

# Google Benchmark, pinned. (Ubuntu's libbenchmark-dev is built without NDEBUG
# and warns that timings may be affected, so it is not used.)
include(FetchContent)
set(BENCHMARK_ENABLE_TESTING OFF)
set(BENCHMARK_ENABLE_GTEST_TESTS OFF)
FetchContent_Declare(benchmark
  GIT_REPOSITORY https://github.com/google/benchmark.git
  GIT_TAG v1.9.4)
FetchContent_MakeAvailable(benchmark)

add_executable(lowbits_mask lowbits_mask.cc)
target_link_libraries(lowbits_mask benchmark::benchmark)
# Tune for the machine the numbers are collected on; the asm kernels do not
# depend on it, the ref_cxx_* functions do.
if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
  target_compile_options(lowbits_mask PRIVATE -mcpu=native)
  # Apple clang runs the MachineOutliner at -O2 on arm64, which pulls the
  # shared tail of each inner loop (next load, & 31, increment, compare) into a
  # function called once per element. Upstream clang on Linux does not.
  if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    target_compile_options(lowbits_mask PRIVATE -mno-outline)
  endif()
else()
  target_compile_options(lowbits_mask PRIVATE -march=native)
endif()
