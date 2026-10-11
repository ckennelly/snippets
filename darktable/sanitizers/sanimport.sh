# sanimport.sh BIN NAME: import a JPEG whose maker, model and lens are new to
# the library, under LeakSanitizer, so _image_get_set_name_id() takes its
# INSERT path for each of them
set -u
BIN=$1; NAME=$2; R=~/results/san/import-$NAME; rm -rf $R; mkdir -p $R
W=$(mktemp -d); mkdir -p $W/img
raw=$(ls ~/corpus/raw/*.CR2 | head -1)
$(dirname $BIN)/darktable-cli "$raw" $W/src.jpg --width 256 --height 256 --core --configdir $W/cli --disable-opencl > /dev/null 2>&1
exiftool -q -Make="Sanx Optics" -Model="S1" -LensModel="Sanx 50mm" -o $W/img/new.jpg $W/src.jpg
printf 'ui/show_welcome_screen=FALSE\nrun_crawler_on_start=FALSE\n' > $W/darktablerc
DISPLAY=:99 DTX_OUT=$R/progress.txt DTX_DIR=$W/img \
  ASAN_OPTIONS="detect_leaks=1:halt_on_error=0:log_path=$R/asan" UBSAN_OPTIONS="print_stacktrace=1:log_path=$R/asan" \
  timeout 600 $BIN --configdir $W --library $W/library.db --cachedir $W/cache \
  --luacmd "dofile(\"$(dirname $(readlink -f $0))/import.lua\")" > $R/dt.log 2>&1
echo "$NAME rc=$? $(tr '\n' ' ' < $R/progress.txt 2>/dev/null) name_id=$(cat $R/asan.* 2>/dev/null | grep -c _image_get_set_name_id)"
rm -rf $W
