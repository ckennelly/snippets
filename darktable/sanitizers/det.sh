# det.sh: are 0103 and 0168 deterministic run to run on one build?
R=~/results/integ/det; rm -rf $R; mkdir -p $R
cd ~/dt-tests
for run in base1 base2 int8a; do
  b=${run%[0-9a-z]}; case $run in base*) b=base;; int8*) b=int8;; esac
  for t in 0103-almost-all 0168-lut3d-srgb-pyramid; do
    rm -f $t/output.png
    DARKTABLE_CLI=~/dt-ab/$b/bin/darktable-cli ./run --disable-opencl $t > $R/$run-$t.log 2>&1
    cp $t/output.png $R/$run-$t.png
  done
done
for t in 0103-almost-all 0168-lut3d-srgb-pyramid; do
  for p in "base1 base2" "base1 int8a" "int8a ../int8-out/${t}_output"; do
    set -- $p; a=$R/$1-$t.png; [ $2 = "../int8-out/${t}_output" ] && c=~/results/integ/int8-out/${t}_output.png || c=$R/$2-$t.png
    echo "$t $1 vs $2: AE=$(compare -metric AE $a $c null: 2>&1 | cut -d' ' -f1)"
  done
done
