#!/usr/bin/env python3
"""fb4_report.py <results dir>: per-benchmark fold/base speed ratio (>1 = fold faster),
geomean over rounds, with the spread of per-round ratios; grouped by codec."""
import csv, glob, io, math, os, re, sys
from collections import defaultdict
D = sys.argv[1]
def load(p):
    raw = open(p).read().splitlines()
    h = next((i for i, l in enumerate(raw) if l.startswith('name,')), None)
    out = {}
    if h is None: return out
    for row in csv.DictReader(io.StringIO('\n'.join(raw[h:]))):
        n = (row.get('name') or '').strip()
        try: t = float(row['real_time'])
        except Exception: continue
        if n.startswith('BM_') and t > 0 and not row.get('error_occurred'): out[n] = t
    return out
def gm(xs):
    xs = [x for x in xs if x > 0]
    return math.exp(sum(map(math.log, xs)) / len(xs)) if xs else float('nan')
data = defaultdict(dict)
for p in glob.glob(f'{D}/compression-*-*.csv'):
    _, side, r = os.path.basename(p)[:-4].rsplit("-", 2)
    data[int(r)][side] = load(p)
rounds = sorted(r for r in data if 'base' in data[r] and 'fold' in data[r])
ratios = defaultdict(list)
for r in rounds:
    b, f = data[r]['base'], data[r]['fold']
    for n in b:
        if n in f: ratios[n].append(b[n] / f[n])
print(f"{len(rounds)} complete rounds: {rounds}\n")
print("| benchmark | fold/base speed (geomean) | per-round min..max | rounds |")
print("|---|---:|---:|---:|")
groups = defaultdict(list)
for n in sorted(ratios):
    rs = ratios[n]
    codec = re.sub(r'^BM_COMPRESSION_([A-Za-z0-9]+)_.*', r'\1', n)
    groups[codec].append(gm(rs))
    print(f"| {n} | {gm(rs)-1:+.2%} | {min(rs)-1:+.2%}..{max(rs)-1:+.2%} | {len(rs)} |")
print("\n| codec | benchmarks | fold/base geomean |")
print("|---|---:|---:|")
for c in sorted(groups):
    print(f"| {c} | {len(groups[c])} | {gm(groups[c])-1:+.2%} |")
allr = [gm(v) for v in ratios.values()]
print(f"| **all** | {len(allr)} | **{gm(allr)-1:+.2%}** |")
