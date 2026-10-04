#!/usr/bin/env python3
"""Final results table: mean +/- sd of the per-round speed ratio (and-not vs main), first 10 rounds.
usage: final_table.py [dir]   (dir defaults to this script's directory; expects results/{zstd,brotli,snappy,fleetbench})"""
import re, glob, csv, io, math, os, statistics as st
from collections import defaultdict
import sys as _s
R = _s.argv[1] if len(_s.argv) > 1 else __import__("os").path.dirname(__import__("os").path.abspath(__file__))
N = 10
def pm(rs):
    rs = rs[:N]
    if not rs: return "      (pending)"
    xs = [(r - 1) * 100 for r in rs]
    return f"{st.mean(xs):+6.2f}% +/- {st.pstdev(xs) if len(xs) > 1 else 0:5.2f}%"
def load(p):
    raw = open(p).read().splitlines(); h = next((i for i, l in enumerate(raw) if l.startswith('name,')), None); out = {}
    if h is None: return out
    for row in csv.DictReader(io.StringIO('\n'.join(raw[h:]))):
        n = (row.get('name') or '').strip()
        try: t = float(row['real_time'])
        except Exception: continue
        if n.startswith('BM_') and t > 0: out[n] = t
    return out
def gm(xs): return math.exp(sum(map(math.log, xs)) / len(xs))
T = defaultdict(dict)
for arch, a, zf in (("V2", "aarch64", "zstd-aarch64-Neoverse-V2-10r.txt"), ("Zen3", "x86_64", "zstd-x86_64-AMD_EPYC_7B13-10r.txt")):
    # fleetbench
    dirn = f"{R}/results/fleetbench/aarch64-Neoverse-V2" if arch == "V2" else f"{R}/results/fleetbench/x86_64-AMD_EPYC_7B13"
    per = defaultdict(dict)
    for p in glob.glob(f"{dirn}/compression-*-*.csv"):
        _, side, r = os.path.basename(p)[:-4].rsplit('-', 2); per[int(r)][side] = load(p)
    rounds = sorted(r for r in per if 'base' in per[r] and 'fold' in per[r])[:N]
    names = sorted({n for r in rounds for n in per[r]['base']})
    T["Fleetbench compression (geomean)"][arch] = pm([gm([per[r]['base'][n] / per[r]['fold'][n] for n in names]) for r in rounds])
    for n in names:
        lab = "  " + re.sub(r'^BM_COMPRESSION_', '', n).split('/')[0].replace('_Fleet', '').replace('_', ' ').lower().replace('zstd', 'ZSTD').replace('snappy', 'Snappy')
        T[lab][arch] = pm([per[r]['base'][n] / per[r]['fold'][n] for r in rounds])
    # zstd
    d = defaultdict(list)
    for l in open(f"{R}/results/zstd/{zf}"):
        m = re.match(r"(main|andnot) -(\d+) \d+ \([\d.]+\) ([\d.]+) MB/s ([\d.]+) MB/s", l)
        if m: d[(m[1], int(m[2]))].append((float(m[3]), float(m[4])))
    for lvl in (1, 3, 9):
        for i, nm in ((0, "compress"), (1, "decompress")):
            T[f"  zstd {nm:<10} L{lvl}"][arch] = pm([b[i] / a[i] for a, b in zip(d[("main", lvl)], d[("andnot", lvl)])])
    # brotli
    d = defaultdict(list)
    for l in open(glob.glob(f"{R}/results/brotli/brotli-{a}-*.txt")[0]):
        m = re.match(r"(main|andnot) (\d+) ([\d.]+) ([\d.]+)$", l.strip())
        if m: d[(m[1], int(m[2]))].append((float(m[3]), float(m[4])))
    for q in (5, 9):
        for i, nm in ((0, "compress"), (1, "decompress")):
            T[f"  brotli {nm:<10} q{q}"][arch] = pm([x[i] / y[i] for x, y in zip(d[("main", q)], d[("andnot", q)])])
    # snappy
    per = defaultdict(dict)
    for p in glob.glob(f"{R}/results/snappy/snappy-{a}-*-*.csv"):
        _, _, side, r = os.path.basename(p)[:-4].rsplit('-', 3); per[int(r)][side] = load(p)
    rounds = sorted(r for r in per if 'main' in per[r] and 'andnot' in per[r])
    T["snappy, 77 benchmarks (geomean)"][arch] = pm([gm([per[r]['main'][n] / per[r]['andnot'][n] for n in per[r]['main'] if n in per[r]['andnot']]) for r in rounds])
order = ["Fleetbench compression (geomean)", "  ZSTD compress", "  ZSTD decompress", "  Snappy compress", "  Snappy decompress",
         "zstd 1.5.7, enwik8", "  zstd compress   L1", "  zstd compress   L3", "  zstd compress   L9", "  zstd decompress L1", "  zstd decompress L3", "  zstd decompress L9",
         "brotli 1.1.0, enwik8", "  brotli compress   q5", "  brotli compress   q9", "  brotli decompress q5", "  brotli decompress q9",
         "snappy, 77 benchmarks (geomean)"]
print(f"{'benchmark (10 rounds, pinned)':<34} {'Neoverse-V2':<22} {'Zen 3':<22}")
print(f"{'-'*34} {'-'*22} {'-'*22}")
for k in order:
    v = T.get(k, {})
    print(f"{k:<34} {v.get('V2', ''):<22} {v.get('Zen3', ''):<22}")
