#!/usr/bin/env python3
"""Interleaved A/B: for each repetition and each (library, layout), run every
build once, alternating the order between repetitions, so host drift lands on
all builds alike. Resumable: runs whose result file exists are skipped.

  ab.py --out results/ --rep 5 --lib ~/libs/lib-1000 --lib ~/libs/lib-50000 \\
        --layout filemanager --layout culling \\
        base=~/dt-ab/base/bin/darktable map=~/dt-ab/map/bin/darktable ...

The first build is the baseline. Prints per-candidate paired deltas of the
per-run median GUI-thread and process CPU per rating action."""
import argparse, glob, json, os, statistics, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))


def name_of(lib):
    return os.path.basename(os.path.normpath(lib))


def runs(a, builds):
    for rep in range(1, a.rep + 1):
        for lib in a.lib:
            for layout in a.layout:
                order = builds if rep % 2 else builds[::-1]
                for name, binary in order:
                    yield rep, lib, layout, name, binary


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", required=True)
    ap.add_argument("--rep", type=int, default=5)
    ap.add_argument("--lib", action="append", required=True)
    ap.add_argument("--layout", action="append", required=True)
    ap.add_argument("--keys", type=int, default=60)
    ap.add_argument("--gap-ms", type=int, default=500)
    ap.add_argument("--summary-only", action="store_true")
    ap.add_argument("builds", nargs="+", help="name=path/to/bin/darktable; the first is the baseline")
    a = ap.parse_args()
    builds = [b.split("=", 1) for b in a.builds]
    os.makedirs(a.out, exist_ok=True)

    if not a.summary_only:
        for rep, lib, layout, name, binary in runs(a, builds):
            f = os.path.join(a.out, f"{name_of(lib)}_{layout}_{name}_r{rep}.json")
            if os.path.exists(f):
                continue
            cmd = [sys.executable, os.path.join(HERE, "run.py"), "--bin", binary, "--lib", lib,
                   "--layout", layout, "--keys", str(a.keys), "--gap-ms", str(a.gap_ms),
                   "--label", name, "--out", f]
            if subprocess.run(cmd).returncode:
                print("FAILED", " ".join(cmd), flush=True)
    summarize(a, builds)


def summarize(a, builds):
    base = builds[0][0]
    print(f"\npaired deltas vs {base}: median over repetitions of (candidate - {base}) "
          f"per-run p50, ms per rating action [min, max]")
    for lib in a.lib:
        for layout in a.layout:
            def load(name):
                r = {}
                for f in glob.glob(os.path.join(a.out, f"{name_of(lib)}_{layout}_{name}_r*.json")):
                    j = json.load(open(f))
                    r[int(f.rsplit("_r", 1)[1][:-5])] = j
                return r
            b = load(base)
            if not b:
                continue
            gb = statistics.median(j["gui_ms_p50"] for j in b.values())
            pb = statistics.median(j["proc_ms_p50"] for j in b.values())
            print(f"{name_of(lib)} {layout}: {base} gui {gb:.2f}  process {pb:.2f}  (n={len(b)})")
            for name, _ in builds[1:]:
                c = load(name)
                reps = sorted(set(b) & set(c))
                if not reps:
                    continue
                dg = [c[r]["gui_ms_p50"] - b[r]["gui_ms_p50"] for r in reps]
                dp = [c[r]["proc_ms_p50"] - b[r]["proc_ms_p50"] for r in reps]
                print(f"  {name:10s} gui {statistics.median(dg):+7.2f} [{min(dg):+.2f}, {max(dg):+.2f}] "
                      f"({100 * statistics.median(dg) / gb:+.1f}%)   process {statistics.median(dp):+7.2f} "
                      f"[{min(dp):+.2f}, {max(dp):+.2f}] ({100 * statistics.median(dp) / pb:+.1f}%)  n={len(reps)}")


if __name__ == "__main__":
    main()
