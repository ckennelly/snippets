# sanundo.sh BIN NAME: run undo.lua under ASan/LSan on a copy of syn-1000
set -u
BIN=$1; NAME=$2; R=~/results/san/undo-$NAME; rm -rf $R; mkdir -p $R
W=$(mktemp -d); cp ~/libs/syn-1000/library.db ~/libs/syn-1000/data.db $W/
printf 'ui/show_welcome_screen=FALSE\nrun_crawler_on_start=FALSE\nui_last/view=lighttable\nplugins/lighttable/layout=1\nplugins/lighttable/base_layout=1\nui_last/window_w=2560\nui_last/window_h=1440\n' > $W/darktablerc
DISPLAY=:99 xdotool mousemove 5 5
DISPLAY=:99 DTX_OUT=$R/progress.txt \
  ASAN_OPTIONS="detect_leaks=1:halt_on_error=0:log_path=$R/asan" UBSAN_OPTIONS="print_stacktrace=1:log_path=$R/asan" \
  timeout 900 $BIN --configdir $W --library $W/library.db --cachedir ~/libs/syn-1000/cache \
  --luacmd 'dofile("'$(dirname $(readlink -f $0))/undo.lua'")' > $R/dt.log 2>&1
echo "$NAME rc=$? $(grep -c ^PASS $R/progress.txt) pass, $(grep ^fails $R/progress.txt), $(tail -1 $R/progress.txt); asan errors $(cat $R/asan.* 2>/dev/null | grep -c 'ERROR: AddressSanitizer')"
grep ^FAIL $R/progress.txt
rm -rf $W
