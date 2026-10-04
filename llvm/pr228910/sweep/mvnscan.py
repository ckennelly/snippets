#!/usr/bin/env python3
"""Count AArch64 sites where a 32-bit low-bits mask is zero-extended into a
64-bit AND:  lsl wA, wB, wC  ...  mvn wA, wA  ...  and xD, xE, xA.
This is the 3-instruction form the AIC low-bits-mask fold (and hand-written
`x64 & ((1u << n) - 1)`) produces today; the proposed combine makes it lsl x; bic x.

usage: mvnscan.py ROOT... [--hot hot.txt] [-n TOP]
Scans *.s files; attributes sites to functions (.type @function ... .Lfunc_end).
"""
import os, re, sys, collections

R_FUNC = re.compile(r"^\s*\.type\s+([^,]+),\s*@function|^[0-9a-f]+ <(.+)>:$")
R_END = re.compile(r"^\.Lfunc_end")
R_LSL = re.compile(r"^\s*lsl\s+(w\d+),\s*(w\d+),\s*(w\d+)")
R_MVN = re.compile(r"^\s*mvn\s+(w\d+),\s*(w\d+)\s*$")
R_AND = re.compile(r"^\s*and\s+(x\d+),\s*(x\d+),\s*(x\d+)\s*$")
R_WRITE = re.compile(r"^\s*(\w+)\s+([wx]\d+)")
WINDOW = 8

def scan_file(path, per_fn, per_file):
    fn = None
    recent = []  # (idx, line)
    try:
        lines = open(path, errors="replace").read().split("\n")
    except OSError:
        return
    lines = [re.sub(r"^\s*[0-9a-f]+:\s*", "    ", l) for l in lines]
    for i, line in enumerate(lines):
        m = R_FUNC.match(line)
        if m:
            fn = m.group(1) or m.group(2); continue
        if R_END.match(line):
            fn = None; continue
        m = R_MVN.match(line)
        if m and m.group(1) == m.group(2):
            reg = m.group(1); n = reg[1:]
            # a register-shift lsl into the same w register shortly before
            back = [l for l in lines[max(0, i - WINDOW):i]]
            lsl = None
            for l in reversed(back):
                lm = R_LSL.match(l)
                if lm and lm.group(1) == reg:
                    lsl = lm; break
                wm = R_WRITE.match(l)
                if wm and wm.group(2)[1:] == n and wm.group(1) not in ("cmp", "tst", "b", "str", "strb", "strh"):
                    break  # register redefined in between
            if not lsl:
                continue
            # a 64-bit and using x<n> shortly after, before x<n>/w<n> is redefined
            fwd = lines[i + 1:i + 1 + WINDOW]
            hit = False
            for l in fwd:
                am = R_AND.match(l)
                if am and ("x" + n) in (am.group(2), am.group(3)):
                    hit = True; break
                wm = R_WRITE.match(l)
                if wm and wm.group(2)[1:] == n and wm.group(1) not in ("cmp", "tst", "b", "str", "strb", "strh"):
                    break
            if hit:
                per_fn[(path, fn or "?")] += 1
                per_file[path] += 1

def main():
    args = sys.argv[1:]
    top = 25; hot = None; roots = []
    while args:
        a = args.pop(0)
        if a == "-n": top = int(args.pop(0))
        elif a == "--hot": hot = args.pop(0)
        else: roots.append(a)
    hotset = set()
    if hot:
        for l in open(hot):
            hotset.add(l.split()[0])
    for root in roots:
        per_fn = collections.Counter(); per_file = collections.Counter()
        nfiles = 0
        for dp, _, fs in os.walk(root):
            for f in fs:
                if f.endswith(".s") or f.endswith(".dis"):
                    nfiles += 1
                    scan_file(os.path.join(dp, f), per_fn, per_file)
        total = sum(per_fn.values())
        print(f"== {root}: {total} sites in {len(per_file)} of {nfiles} TUs, {len(per_fn)} functions")
        for (path, fn), c in per_fn.most_common(top):
            mark = " HOT" if fn in hotset else ""
            print(f"  {c:4d}  {fn[:70]:<70} {os.path.relpath(path, root)[-60:]}{mark}")

if __name__ == "__main__":
    main()
