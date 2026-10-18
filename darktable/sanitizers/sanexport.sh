# sanexport.sh BIN NAME: tagexport.lua under ASan/LSan on a copy of syn-1000,
# accepting the tag export file chooser with xdotool
set -u
BIN=$1; NAME=$2; R=~/results/san/tagexport-$NAME; rm -rf $R; mkdir -p $R/out
W=$(mktemp -d); cp ~/libs/syn-1000/library.db ~/libs/syn-1000/data.db $W/
printf 'ui/show_welcome_screen=FALSE\nrun_crawler_on_start=FALSE\nui_last/view=lighttable\nplugins/lighttable/layout=1\nplugins/lighttable/base_layout=1\nui_last/window_w=2560\nui_last/window_h=1440\nplugins/lighttable/tagging/last_import_export_location=%s\n' $R/out > $W/darktablerc
DISPLAY=:99 xdotool mousemove 5 5
( for i in $(seq 1 60); do
    wid=$(DISPLAY=:99 xdotool search --name "select file to export to" 2>/dev/null | head -1)
    if [ -n "$wid" ]; then sleep 2; DISPLAY=:99 xdotool windowfocus --sync $wid; DISPLAY=:99 xdotool key Return; echo "accepted $wid" >> $R/chooser.txt; break; fi
    sleep 2
  done ) &
acc=$!
DISPLAY=:99 DTX_OUT=$R/progress.txt \
  ASAN_OPTIONS="detect_leaks=1:halt_on_error=0:log_path=$R/asan" UBSAN_OPTIONS="print_stacktrace=1:log_path=$R/asan" \
  timeout 600 $BIN --configdir $W --library $W/library.db --cachedir ~/libs/syn-1000/cache \
  --luacmd 'dofile("'$(dirname $(readlink -f $0))/tagexport.lua'")' > $R/dt.log 2>&1
echo "$NAME rc=$? $(tr '\n' ' ' < $R/progress.txt) $(cat $R/chooser.txt 2>/dev/null) files=$(ls $R/out) lines=$(cat $R/out/* 2>/dev/null | wc -l) dt_tag_export reports=$(cat $R/asan.* 2>/dev/null | grep -c 'dt_tag_export')"
kill $acc 2>/dev/null; wait $acc 2>/dev/null
rm -rf $W
