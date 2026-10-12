# evidence.py: for each fix, the first matching report from the base run and the count of
# matching reports before (base) and after (build with the fix)
# usage: evidence.py [RAW_DIR [OUT]]  (default: results/raw, results/EVIDENCE.md)
import gzip, re, glob, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
R = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "results", "raw")
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "results", "EVIDENCE.md")
def read(path):
    return (gzip.open if path.endswith(".gz") else open)(path, "rt", errors="replace").read()
def blocks(path):
    t = read(path)
    b = re.findall(r"((?:Direct|Indirect) leak of \d+ byte\(s\) in \d+ object\(s\) allocated from:\n.*?)(?=\n\n)", t, re.S)
    b += re.findall(r"(\S+: runtime error: .*?\n(?:.*\n)*?)(?=\n|\S+: runtime error)", t)
    return b
def one(p): return sorted(glob.glob(os.path.join(R, p + "*")))[0]
FIX = [  # (fix, pattern, base report, fixed report)
 ("fix/lsan-leaks thumbnail filename", "thumbnail.c:2418", "asan_ef98688fc/ubsan-filemanager.*", "asan_fix_lsan-leaks/ubsan-filemanager.*"),
 ("fix/lsan-leaks ratings undo", "ratings.c:225", "asan_ef98688fc/ubsan-filemanager.*", "asan_fix_lsan-leaks/ubsan-filemanager.*"),
 ("fix/lsan-leaks range block txt", "range.c:1901", "asan_ef98688fc/ubsan-filemanager.*", "asan_fix_lsan-leaks/ubsan-filemanager.*"),
 ("fix/lsan-leaks dt_tag_get_list", "tags.c:792", "asan_ef98688fc/ubsan-filemanager.*", "asan_fix_lsan-leaks/ubsan-filemanager.*"),
 ("fix/lsan-leaks colorlabels undo", "colorlabels.c:223", "undo-base/asan.*", "undo-tip/asan.*"),
 ("fix/lsan-leaks duplicate undo", "image.c:1556", "undo-base/asan.*", "undo-tip/asan.*"),
 ("fix/sqlite-stmt-leaks act_on statements", ("act_on.c", "sqlite3VdbeCreate"), "asan_ef98688fc/ubsan-hover.*", "asan_san_all/ubsan-hover.*"),
 ("fix/sqlite-stmt-leaks _image_get_set_name_id SELECT", ("_image_get_set_name_id", "sqlite3VdbeCreate"), "import-base/asan.*", "import-stmtfix/asan.*"),
 ("fix/introspection-int8-default", "imageop.c:273", "asan_ef98688fc/dt-filemanager.log", "asan_san_fixes/dt-filemanager.log"),
]
out = []
for name, pat, base, fixed in FIX:
    m = lambda b: all(p in b for p in pat) if isinstance(pat, tuple) else pat in b
    bb = [b for b in blocks(one(base)) if m(b)]
    fb = [b for b in blocks(one(fixed)) if m(b)]
    nbytes = sum(int(m.group(1)) for b in bb for m in [re.search(r"of (\d+) byte", b)] if m)
    out.append(f"## {name}\n\nreports matching `{" + ".join(pat) if isinstance(pat, tuple) else pat}`: base {len(bb)}"
               + (f" ({nbytes} B)" if nbytes else "") + f", with the fix {len(fb)}\n"
               f"base: `{os.path.relpath(one(base), R)}`, fixed: `{os.path.relpath(one(fixed), R)}`\n\n```\n"
               + (bb[0].strip() if bb else "(none)") + "\n```\n")
open(OUT, "w").write("\n".join(out))
print("\n".join(l for l in "\n".join(out).splitlines() if l.startswith(("##", "reports"))))
