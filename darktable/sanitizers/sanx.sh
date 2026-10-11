# sanx.sh BIN NAME: run extra.lua under ASan/LSan on a copy of syn-1000
set -u
BIN=$1; NAME=$2; R=~/results/san/sanx-$NAME; rm -rf $R; mkdir -p $R/export
W=$(mktemp -d); cp ~/libs/syn-1000/library.db ~/libs/syn-1000/data.db $W/
printf 'ui/show_welcome_screen=FALSE\nrun_crawler_on_start=FALSE\nui_last/view=lighttable\nplugins/lighttable/layout=1\nplugins/lighttable/base_layout=1\nui_last/window_w=2560\nui_last/window_h=1440\n' > $W/darktablerc
DISPLAY=:99 xdotool mousemove 5 5
DISPLAY=:99 DTX_OUT=$R/progress.txt DTX_EXPORT=$R/export \
  ASAN_OPTIONS="detect_leaks=1:halt_on_error=0:log_path=$R/asan" UBSAN_OPTIONS="print_stacktrace=1:log_path=$R/asan" \
  timeout 900 $BIN --configdir $W --library $W/library.db --cachedir ~/libs/syn-1000/cache \
  --luacmd 'dofile("'$(dirname $(readlink -f $0))/extra.lua'")' > $R/dt.log 2>&1
echo "$NAME rc=$? $(tr '\n' ' ' < $R/progress.txt) exports=$(ls $R/export | wc -l)"
rm -rf $W
# export through darktable-cli, whose default metadata flags include tags
W=$(mktemp -d)
ASAN_OPTIONS="detect_leaks=1:halt_on_error=0:log_path=$R/cli" UBSAN_OPTIONS="print_stacktrace=1:log_path=$R/cli"   timeout 600 $(dirname $BIN)/darktable-cli ~/libs/syn-1000/roll/img000000.CR3 ~/libs/syn-1000/roll/img000000.CR3.xmp $R/export/cli.jpg   --width 256 --height 256 --core --configdir $W --disable-opencl > $R/cli.log 2>&1
echo "$NAME cli rc=$? $(ls $R/export/cli*.jpg 2>/dev/null | wc -l) exported"
rm -rf $W
