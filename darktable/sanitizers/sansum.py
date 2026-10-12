# sansum.py: dedupe ASan/UBSan/LSan reports by kind + first darktable frame
import gzip,re,sys,collections
for f in sys.argv[1:]:
    t=(gzip.open if f.endswith(".gz") else open)(f,"rt",errors="replace").read()
    c=collections.Counter(); ex={}
    # UBSan runtime errors
    for m in re.finditer(r"^(\S+?):(\d+):\d+: runtime error: (.*)$",t,re.M):
        k=("ubsan",m.group(1).split("/darktable/")[-1]+":"+m.group(2),re.sub(r"0x[0-9a-f]+","X",m.group(3))[:100])
        c[k]+=1
    # ASan errors
    for m in re.finditer(r"ERROR: AddressSanitizer: (\S+)(.*?)(?=\n\n|\Z)",t,re.S):
        fr=re.findall(r"in (\S+) (\S*darktable/src/\S+)",m.group(2))
        c[("asan",m.group(1),fr[0][0]+" "+fr[0][1].split("/src/")[-1] if fr else "?")]+=1
    # LSan leaks: group by first darktable frame
    leaks=re.findall(r"(Direct|Indirect) leak of (\d+) byte\(s\) in (\d+) object\(s\) allocated from:\n(.*?)(?=\n\n)",t,re.S)
    lk=collections.defaultdict(lambda:[0,0])
    for kind,b,n,stack in leaks:
        fr=re.findall(r"in (\S+) \S*darktable/src/(\S+)",stack)
        key=(kind,fr[0][0]+" "+fr[0][1] if fr else "no-dt-frame: "+";".join(re.findall(r"in (\S+)",stack)[:3]))
        lk[key][0]+=int(b); lk[key][1]+=int(n)
    print("=====",f, "summary:", re.findall(r"SUMMARY: .*",t)[-3:])
    for k,v in c.most_common(40): print(f"{v:7d}  {k}")
    print("-- leaks (darktable frame):")
    for k,v in sorted(lk.items(),key=lambda kv:-kv[1][0])[:40]:
        if not k[1].startswith("no-dt-frame"): print(f"{v[0]:9d} B {v[1]:6d} obj  {k}")
    nd=sum(v[0] for k,v in lk.items() if k[1].startswith("no-dt-frame"))
    print(f"   non-darktable-frame leaks total: {nd} B")
