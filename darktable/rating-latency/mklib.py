#!/usr/bin/env python3
"""Build a benchmark library of N images from a small set of raw files.

  mklib.py --bin BUILD/bin/darktable --raws DIR --n 50000 --out LIBDIR

Every raw in DIR is hard-linked into LIBDIR/roll as img000000.ext,
img000001.ext, ... cycling through the raws. darktable imports one link per
raw (the seed), then the seed rows of images, tagged_images and meta_data are
cloned in SQL up to N. Importing 50k files through darktable takes about 40
minutes; this takes seconds and gives the same rows except for the image id.
LIBDIR then holds library.db, data.db, roll/ and cache/ (thumbnails)."""
import argparse, os, shutil, sqlite3, subprocess, sys, tempfile, time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from run import xvfb


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--bin", required=True)
    ap.add_argument("--raws", required=True)
    ap.add_argument("--n", type=int, required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--display", default=":99")
    a = ap.parse_args()

    raws = sorted(f for f in os.listdir(a.raws) if os.path.isfile(os.path.join(a.raws, f)))
    k = len(raws)
    if a.n < k:
        sys.exit(f"--n must be at least the number of raws ({k})")
    out = os.path.abspath(a.out)
    roll = os.path.join(out, "roll")
    if os.path.exists(out):
        sys.exit(f"{out} exists")
    os.makedirs(roll)
    names = [f"img{i:06d}{os.path.splitext(raws[i % k])[1]}" for i in range(a.n)]
    for i in range(k):
        os.link(os.path.join(a.raws, raws[i]), os.path.join(roll, names[i]))

    # import the seed through darktable
    xvfb(a.display)
    cfg = tempfile.mkdtemp(prefix="dtmklib-")
    done = os.path.join(cfg, "done")
    lua = (f'local dt = require "darktable"; dt.database.import("{roll}"); '
           f'local f = io.open("{done}", "w"); f:write(#dt.database); f:close()')
    with open(os.path.join(cfg, "darktablerc"), "w") as f:
        f.write("ui/show_welcome_screen=FALSE\nrun_crawler_on_start=FALSE\n")
    p = subprocess.Popen([a.bin, "--configdir", cfg, "--library", os.path.join(cfg, "library.db"),
                          "--cachedir", os.path.join(out, "cache"), "--luacmd", lua],
                         env=dict(os.environ, DISPLAY=a.display),
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    for _ in range(600):
        if os.path.exists(done) and open(done).read():
            break
        time.sleep(1)
    time.sleep(5)  # let the sidecar and thumbnail jobs settle before the kill
    os.killpg(p.pid, 9)
    p.wait()

    db = sqlite3.connect(os.path.join(cfg, "library.db"))
    seed = {fn: i for i, fn in db.execute("SELECT id, filename FROM images")}
    if len(seed) != k:
        sys.exit(f"seed import gave {len(seed)} images, expected {k}")
    cols = [r[1] for r in db.execute("PRAGMA table_info(images)")]
    copy = [c for c in cols if c not in ("id", "group_id", "filename", "position")]
    ins = (f"INSERT INTO images (id, group_id, filename, position, {', '.join(copy)}) "
           f"SELECT :new, :new, :name, :new << 32, {', '.join(copy)} FROM images WHERE id = :src")
    first = db.execute("SELECT MAX(id) FROM images").fetchone()[0] + 1
    with db:
        for i in range(k, a.n):
            new, src = first + i - k, seed[names[i % k]]
            arg = dict(new=new, name=names[i], src=src)
            db.execute(ins, arg)
            db.execute("INSERT INTO tagged_images (imgid, tagid, position) "
                       "SELECT :new, tagid, position FROM tagged_images WHERE imgid = :src", arg)
            db.execute("INSERT INTO meta_data (id, key, value) "
                       "SELECT :new, key, value FROM meta_data WHERE id = :src", arg)
    db.execute("ANALYZE")
    db.close()
    for i in range(k, a.n):
        os.link(os.path.join(a.raws, raws[i % k]), os.path.join(roll, names[i]))
    for f in ("library.db", "data.db"):
        shutil.copy(os.path.join(cfg, f), out)
    shutil.rmtree(cfg)
    print(f"{out}: {a.n} images from {k} raws")


if __name__ == "__main__":
    main()
