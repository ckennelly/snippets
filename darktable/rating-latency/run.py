#!/usr/bin/env python3
"""One benchmark run: start darktable under Xvfb on a fresh copy of a library,
let bench.lua apply KEYS ratings, and print/save the per-action CPU times.

  run.py --bin BUILD/bin/darktable --lib LIBDIR --layout culling --out run.json

LIBDIR is what mklib.py makes: library.db, data.db, and cache/ (thumbnails,
shared between runs). The databases are copied to a scratch config directory
for every run so every build starts from the same state."""
import argparse, json, os, shutil, signal, statistics, subprocess, sys, tempfile, time

HERE = os.path.dirname(os.path.abspath(__file__))
LAYOUTS = {"filemanager": 1, "culling": 2}


def xvfb(display):
    if subprocess.run(["xdpyinfo", "-display", display], capture_output=True).returncode == 0:
        return
    subprocess.Popen(["Xvfb", display, "-screen", "0", "2560x1440x24", "-nolisten", "tcp", "-noreset"],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    for _ in range(50):
        if subprocess.run(["xdpyinfo", "-display", display], capture_output=True).returncode == 0:
            return
        time.sleep(0.1)
    sys.exit("Xvfb did not start")


def run(a):
    xvfb(a.display)
    # keep the pointer off the thumbnails: the rating acts on a hovered image
    # in preference to the selection
    subprocess.run(["xdotool", "mousemove", "5", "5"], env=dict(os.environ, DISPLAY=a.display), check=True)
    work = tempfile.mkdtemp(prefix="dtbench-")
    cfg = os.path.join(work, "cfg")
    os.makedirs(cfg)
    for db in ("library.db", "data.db"):
        shutil.copy(os.path.join(a.lib, db), cfg)
    conf = {
        "ui/show_welcome_screen": "FALSE",
        "run_crawler_on_start": "FALSE",
        "ui_last/view": "lighttable",
        "ui_last/window_x": 0, "ui_last/window_y": 0,
        "ui_last/window_w": 2560, "ui_last/window_h": 1440,
        "plugins/lighttable/layout": LAYOUTS[a.layout],
        "plugins/lighttable/base_layout": LAYOUTS[a.layout],
        "plugins/lighttable/culling_num_images": 1,
        "plugins/lighttable/filtering/sort0": a.sort,
        "plugins/lighttable/filtering/sortorder0": 0,
    }
    with open(os.path.join(cfg, "darktablerc"), "w") as f:
        for k, v in sorted(conf.items()):
            f.write(f"{k}={v}\n")
    res = os.path.join(work, "result.txt")
    env = dict(os.environ, DISPLAY=a.display, DTB_OUT=res, DTB_KEYS=str(a.keys),
               DTB_GAP_MS=str(a.gap_ms), DTB_SETTLE_MS=str(a.settle_ms))
    if a.quit:
        env["DTB_QUIT"] = "1"
    cmd = [a.bin, "--configdir", cfg, "--library", os.path.join(cfg, "library.db"),
           "--cachedir", os.path.join(a.lib, "cache"),
           "--luacmd", f'dofile("{os.path.join(HERE, "bench.lua")}")']
    cpus = ["taskset", "-c", a.cpus] if a.cpus else []
    log = open(os.path.join(work, "darktable.log"), "w")
    p = subprocess.Popen(cpus + cmd, env=env, stdout=log, stderr=subprocess.STDOUT,
                         start_new_session=True)
    deadline = time.time() + (a.settle_ms + 10000 + 2 * a.keys * a.gap_ms) / 1e3 + 300
    lines = []
    while time.time() < deadline and p.poll() is None:
        if os.path.exists(res):
            lines = open(res).read().splitlines()
            if lines and lines[-1] == "done":
                break
        time.sleep(1)
    if a.quit:
        try:
            p.wait(timeout=300)
        except subprocess.TimeoutExpired:
            pass
    try:
        os.killpg(p.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    p.wait()
    log.close()
    if a.log:
        shutil.copy(os.path.join(work, "darktable.log"), a.log)
    if not lines or lines[-1] != "done":
        sys.exit(f"no result; see {work}/darktable.log")

    idle = dict(kv.split("=") for kv in lines[0].split()[1:])
    keys = [dict(kv.split("=") for kv in l.split()[2:]) for l in lines[1:-2]]
    check = dict(kv.split("=") for kv in lines[-2].split()[1:])
    if check["rating"] != check["expected"]:
        sys.exit(f"rating actions did not apply ({lines[-2]}); see {work}/darktable.log")
    n = len(keys)
    gui = [int(k["gui_ns"]) / 1e6 for k in keys]
    proc = [int(k["proc_us"]) / 1e3 for k in keys]
    out = dict(bin=a.bin, lib=a.lib, layout=a.layout, sort=a.sort, keys=n, gap_ms=a.gap_ms,
               label=a.label,
               # background CPU over one gap, for scale
               idle_gui_ms_per_key=int(idle["gui_ns"]) / 1e6 * a.gap_ms / int(idle["ms"]),
               idle_proc_ms_per_key=int(idle["proc_us"]) / 1e3 * a.gap_ms / int(idle["ms"]),
               gui_ms=gui, proc_ms=proc,
               gui_ms_p50=statistics.median(gui), proc_ms_p50=statistics.median(proc))
    if a.out:
        # atomic, so a run killed by a preemption leaves no partial result
        # for ab.py to mistake for a finished one
        with open(a.out + ".tmp", "w") as f:
            json.dump(out, f, indent=1)
        os.replace(a.out + ".tmp", a.out)
    print(f"{a.label or os.path.basename(a.bin)} {a.layout} n={n}: "
          f"gui p50 {out['gui_ms_p50']:.2f} ms/key (idle {out['idle_gui_ms_per_key']:.2f}), "
          f"process p50 {out['proc_ms_p50']:.2f} ms/key (idle {out['idle_proc_ms_per_key']:.2f})")
    shutil.rmtree(work)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--bin", required=True)
    ap.add_argument("--lib", required=True)
    ap.add_argument("--layout", choices=LAYOUTS, default="filemanager")
    ap.add_argument("--sort", type=int, default=0, help="0 filename, 6 rating")
    ap.add_argument("--keys", type=int, default=100)
    ap.add_argument("--gap-ms", type=int, default=500)
    ap.add_argument("--settle-ms", type=int, default=15000)
    ap.add_argument("--cpus", default="", help="taskset cpu list, e.g. 2-9")
    ap.add_argument("--display", default=":99")
    ap.add_argument("--label", default="")
    ap.add_argument("--out")
    ap.add_argument("--quit", action="store_true",
                    help="quit darktable normally after the run (for sanitizer exit reports)")
    ap.add_argument("--log", help="save darktable's output here")
    run(ap.parse_args())
