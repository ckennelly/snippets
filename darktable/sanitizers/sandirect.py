# sandirect.py: direct leaks only, keyed by the first 4 frames (any library), with sizes
import re,sys,collections
for f in sys.argv[1:]:
    t=open(f,errors="replace").read()
    lk=collections.defaultdict(lambda:[0,0,""])
    for b,n,stack in re.findall(r"Direct leak of (\d+) byte\(s\) in (\d+) object\(s\) allocated from:\n(.*?)(?=\n\n)",t,re.S):
        frames=re.findall(r"#\d+ 0x[0-9a-f]+ in (\S+) (\S+)",stack)
        frames=[(fn,loc.split("/src/")[-1] if "darktable/src" in loc else loc.split("/")[-1].split("+")[0]) for fn,loc in frames]
        frames=[x for x in frames if not x[0].startswith(("malloc","calloc","realloc","g_malloc","g_malloc0","g_realloc","g_strdup","g_slice","operator"))]
        dt=[x for x in frames if ".c:" in x[1] or ".cc:" in x[1]]
        key=" <- ".join(f"{a} {b}" for a,b in (dt[:3] if dt else frames[:3]))
        lk[key][0]+=int(b); lk[key][1]+=int(n)
    print("=====",f)
    for k,v in sorted(lk.items(),key=lambda kv:-kv[1][0])[:45]: print(f"{v[0]:8d} B {v[1]:6d} obj  {k}")
