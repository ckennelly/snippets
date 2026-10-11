# integ.sh: full integration suite (CPU path) for base and the int8 fix; keep outputs to compare
set -u
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3-venv imagemagick > /dev/null 2>&1
R=~/results/integ; mkdir -p $R
cd ~/dt-tests
for b in base int8; do
  [ -f $R/$b.done ] && continue
  git clean -q -fdx -e .venv 0* 2>/dev/null
  DARKTABLE_CLI=~/dt-ab/$b/bin/darktable-cli timeout 10800 ./run --disable-opencl > $R/$b.log 2>&1
  echo "$b rc=$?"
  mkdir -p $R/$b-out
  for d in 0*/; do for f in $d*.png; do case $f in */expected.png) ;; *) [ -f "$f" ] && cp "$f" $R/$b-out/$(dirname $f)_$(basename $f);; esac; done; done
  tail -5 $R/$b.log
  touch $R/$b.done
done
# byte comparison of every rendered output
n=0; d=0
for f in $R/base-out/*.png; do g=$R/int8-out/$(basename $f); n=$((n+1)); cmp -s $f $g || { d=$((d+1)); echo "DIFF $(basename $f)"; }; done
echo "compared $n outputs, $d differ"
echo INTEG_DONE
