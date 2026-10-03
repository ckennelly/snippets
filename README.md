# snippets

Small, self-contained code snippets and microbenchmarks, mostly to pin down
compiler codegen questions with numbers instead of cost-model arguments.

Layout is hierarchical by the project the question came from:

```
llvm/prNNNNNN/   one directory per LLVM pull request or issue
  README.md      what is being measured and why
  *.cc           the benchmark (Google Benchmark); one source for all
                 architectures, with the arch-specific part in inline asm
  CMakeLists.txt
  results/       raw output per machine, plus a short summary
```

Build a directory with

```
cmake -S llvm/prNNNNNN -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
./build/<name> --benchmark_repetitions=5 --benchmark_report_aggregates_only=true
```


Google Benchmark is fetched and pinned by each directory's CMakeLists.txt.

MIT license.
