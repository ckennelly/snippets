// Low-bits mask: table load vs. arithmetic, for llvm/llvm-project#228736.
//
// zstd's bit reader masks a value with `x & BIT_mask[n]`, where
// BIT_mask[n] == (1u << n) - 1. LLVM's AggressiveInstCombine rewrites such a
// table load into the arithmetic form; PR 228736 proposes gating that on a TTI
// cost comparison that, with the generic cost model, keeps the table load on
// every target except x86 with BMI2. This measures the two forms directly, as
// exact instruction sequences, in three settings:
//
//   Throughput  independent elements, results xor-accumulated
//   LatencyX    the result is the next element's x (value dependency)
//   LatencyN    the result selects the next element's n (the table index or
//               shift amount depends on the previous result -- the shape of
//               a bit reader whose next field width comes from decoded state)
//
// The architecture-specific part is the inline asm in the Kernel structs; the
// harness is generic. Build with CMakeLists.txt in this directory.

#include <benchmark/benchmark.h>

#include <cstdint>
#include <random>
#include <vector>

namespace {

constexpr int kN = 4096;        // elements per benchmark iteration
constexpr uint32_t kBits = 32;  // table has kBits entries: masks for n in [0, 32)

struct Inputs {
  std::vector<uint32_t> x, n;
  uint32_t table[kBits];
  Inputs() : x(kN), n(kN) {
    // Fixed seed; the engine's output is specified by the standard, so every
    // machine sees the same inputs. (uniform_int_distribution is not.)
    std::mt19937_64 rng(42);
    for (int i = 0; i < kN; ++i) {
      uint64_t r = rng();
      x[i] = static_cast<uint32_t>(r);
      n[i] = static_cast<uint32_t>(r >> 32) % kBits;
    }
    for (uint32_t j = 0; j < kBits; ++j) table[j] = (1u << j) - 1;
  }
};
const Inputs& inputs() {
  static const Inputs in;
  return in;
}

// Every kernel computes x & mask(n) for 0 <= n < 32. `one` and `allones` are
// loop-invariant constants the compiler keeps in registers, standing in for
// the materialization that gets hoisted out of a real loop.
struct Args {
  const uint32_t* table;
  uint32_t one;
  uint32_t allones;
};

#if defined(__x86_64__)

// x & tbl[n]: the load folds into the AND.
struct Table {
  static const char* name() { return "table(and mem)"; }
  static inline uint32_t Apply(uint32_t x, uint32_t n, const Args& a) {
    uint64_t idx = n;
    asm("andl (%[tbl],%[idx],4), %[x]"
        : [x] "+r"(x)
        : [tbl] "r"(a.table), [idx] "r"(idx),
          "m"(*reinterpret_cast<const uint32_t(*)[kBits]>(a.table)));
    return x;
  }
};

// BMI2: one instruction.
struct Bzhi {
  static const char* name() { return "bzhi"; }
  static inline uint32_t Apply(uint32_t x, uint32_t n, const Args&) {
    asm("bzhil %[n], %[x], %[x]" : [x] "+r"(x) : [n] "r"(n));
    return x;
  }
};

// No BMI2: mov 1; shl %cl; dec; and.
struct ShiftSub {
  static const char* name() { return "shl/dec/and"; }
  static inline uint32_t Apply(uint32_t x, uint32_t n, const Args&) {
    uint32_t t;
    asm("movl $1, %[t]\n\t"
        "shll %%cl, %[t]\n\t"
        "decl %[t]\n\t"
        "andl %[t], %[x]"
        : [x] "+r"(x), [t] "=&r"(t)
        : "c"(n));
    return x;
  }
};

#define SNIPPET_KERNELS(M) M(Table) M(Bzhi) M(ShiftSub)

#elif defined(__aarch64__)

// x & tbl[n]: scaled-index load, then AND.
struct Table {
  static const char* name() { return "table(ldr+and)"; }
  static inline uint32_t Apply(uint32_t x, uint32_t n, const Args& a) {
    uint32_t t;
    asm("ldr %w[t], [%[tbl], %w[n], uxtw #2]\n\t"
        "and %w[x], %w[x], %w[t]"
        : [x] "+r"(x), [t] "=&r"(t)
        : [tbl] "r"(a.table), [n] "r"(n),
          "m"(*reinterpret_cast<const uint32_t(*)[kBits]>(a.table)));
    return x;
  }
};

// x & ~(-1 << n), the canonical LLVM form: lsl; bic, with -1 hoisted.
struct LslBic {
  static const char* name() { return "lsl/bic"; }
  static inline uint32_t Apply(uint32_t x, uint32_t n, const Args& a) {
    uint32_t t;
    asm("lsl %w[t], %w[m1], %w[n]\n\t"
        "bic %w[x], %w[x], %w[t]"
        : [x] "+r"(x), [t] "=&r"(t)
        : [m1] "r"(a.allones), [n] "r"(n));
    return x;
  }
};

// x & ((1 << n) - 1) as written: lsl; sub; and, with 1 hoisted.
struct LslSubAnd {
  static const char* name() { return "lsl/sub/and"; }
  static inline uint32_t Apply(uint32_t x, uint32_t n, const Args& a) {
    uint32_t t;
    asm("lsl %w[t], %w[one], %w[n]\n\t"
        "sub %w[t], %w[t], #1\n\t"
        "and %w[x], %w[x], %w[t]"
        : [x] "+r"(x), [t] "=&r"(t)
        : [one] "r"(a.one), [n] "r"(n));
    return x;
  }
};

// Same, with the constant materialized every time (nothing hoisted).
struct MovLslSubAnd {
  static const char* name() { return "mov/lsl/sub/and"; }
  static inline uint32_t Apply(uint32_t x, uint32_t n, const Args&) {
    uint32_t t;
    asm("mov %w[t], #1\n\t"
        "lsl %w[t], %w[t], %w[n]\n\t"
        "sub %w[t], %w[t], #1\n\t"
        "and %w[x], %w[x], %w[t]"
        : [x] "+r"(x), [t] "=&r"(t)
        : [n] "r"(n));
    return x;
  }
};

#define SNIPPET_KERNELS(M) M(Table) M(LslBic) M(LslSubAnd) M(MovLslSubAnd)

#else
#error "x86_64 or aarch64 only"
#endif

// The compiler's own codegen for both C++ forms, built with this directory's
// flags. Not inlined, so run.sh can disassemble them for the results file.
extern "C" __attribute__((noinline)) uint32_t ref_cxx_table(uint32_t x, uint32_t n,
                                                             const uint32_t* t) {
  return x & t[n];
}
extern "C" __attribute__((noinline)) uint32_t ref_cxx_arith(uint32_t x, uint32_t n) {
  return x & ((1u << n) - 1);
}

template <class K>
void Throughput(benchmark::State& state) {
  const Inputs& in = inputs();
  Args a{in.table, 1u, ~0u};
  for (auto _ : state) {
    uint32_t acc = 0;
    for (int i = 0; i < kN; ++i) acc ^= K::Apply(in.x[i], in.n[i], a);
    benchmark::DoNotOptimize(acc);
  }
  state.SetLabel(K::name());
  state.counters["ns/elem"] = benchmark::Counter(
      kN, benchmark::Counter::kIsIterationInvariantRate | benchmark::Counter::kInvert,
      benchmark::Counter::kIs1000);
}

// x = K(x, n[i]) + x[i]: a value chain through the result.
template <class K>
void LatencyX(benchmark::State& state) {
  const Inputs& in = inputs();
  Args a{in.table, 1u, ~0u};
  uint32_t x = 0xFFFFFFFFu;
  for (auto _ : state) {
    for (int i = 0; i < kN; ++i) x = K::Apply(x, in.n[i], a) + in.x[i];
    benchmark::DoNotOptimize(x);
  }
  state.SetLabel(K::name());
  state.counters["ns/elem"] = benchmark::Counter(
      kN, benchmark::Counter::kIsIterationInvariantRate | benchmark::Counter::kInvert,
      benchmark::Counter::kIs1000);
}

// n = K(x[i], n) & 31: the result selects the next mask, so the table index
// (an address dependency) or the shift amount depends on the previous result.
template <class K>
void LatencyN(benchmark::State& state) {
  const Inputs& in = inputs();
  Args a{in.table, 1u, ~0u};
  uint32_t n = 7;
  for (auto _ : state) {
    for (int i = 0; i < kN; ++i) n = K::Apply(in.x[i], n, a) & (kBits - 1);
    benchmark::DoNotOptimize(n);
  }
  state.SetLabel(K::name());
  state.counters["ns/elem"] = benchmark::Counter(
      kN, benchmark::Counter::kIsIterationInvariantRate | benchmark::Counter::kInvert,
      benchmark::Counter::kIs1000);
}

#define SNIPPET_REGISTER(K)              \
  BENCHMARK_TEMPLATE(Throughput, K);     \
  BENCHMARK_TEMPLATE(LatencyX, K);       \
  BENCHMARK_TEMPLATE(LatencyN, K);
SNIPPET_KERNELS(SNIPPET_REGISTER)

}  // namespace

BENCHMARK_MAIN();
