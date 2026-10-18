# santags.sh BIN NAME: darktable-cli exports of a raw whose XMP carries
# hierarchical tags, under LeakSanitizer. Default metadata flags (tags in the
# exported XMP, the dt_tag_get_list_export() path), then the private tag
# probe: the parents "sanx" and "sanx|beta" marked private, exported with and
# without DT_META_PRIVATE_TAG, attached and not. Records the exported keywords.
set -u
BIN=$1; NAME=$2; R=~/results/san/tags-$NAME; rm -rf $R; mkdir -p $R
CLI=$(dirname $BIN)/darktable-cli
W=$(mktemp -d); mkdir -p $W/img $W/cfg
src=~/libs/syn-1000/roll/img000000.CR3
mkxmp() { # mkxmp TAG... : sidecar with these hierarchical tags
  cp $src.xmp $W/img/img.CR3.xmp
  args=(); for t in "$@"; do args+=(-XMP-lr:HierarchicalSubject+="$t" -XMP-dc:Subject+="${t##*|}"); done
  exiftool -q -overwrite_original -XMP-lr:HierarchicalSubject= -XMP-dc:Subject= "${args[@]}" $W/img/img.CR3.xmp
}
run() { # run LABEL FLAGS
  printf 'plugins/lighttable/export/metadata_flags=%s\n' $2 > $W/cfg/darktablerc
  rm -f $W/out.jpg
  ASAN_OPTIONS="detect_leaks=1:halt_on_error=0:log_path=$R/asan-$1" UBSAN_OPTIONS="print_stacktrace=1:log_path=$R/asan-$1" \
    timeout 600 $CLI $W/img/img.CR3 $W/img/img.CR3.xmp $W/out.jpg --width 128 --height 128 --core --configdir $W/cfg --disable-opencl > $R/cli-$1.log 2>&1
  local rc=$?
  kw=$(exiftool -s3 -sep , -XMP-dc:Subject $W/out.jpg 2>/dev/null | tr ',' '\n' | sort | tr '\n' ' ')
  echo "$1 rc=$rc keywords: $kw" | tee -a $R/keywords.txt
}
cp $src $W/img/img.CR3
mkxmp "sanx|alpha" "sanx|beta|deep" "sanx|beta|wide" "solo" "sanx" "sanx|beta"
run default 2f
sqlite3 $W/cfg/data.db "UPDATE tags SET flags = COALESCE(flags, 0) | 2 WHERE name IN ('sanx', 'sanx|beta'); SELECT name, COALESCE(flags, 0) FROM tags WHERE name LIKE 'sanx%' OR name = 'solo';" | tr '\n' ' ' | sed 's/^/tags: /' | tee -a $R/keywords.txt; echo
run attached-private-on 1002f
run attached-private-off 2f
mkxmp "sanx|alpha" "sanx|beta|deep" "sanx|beta|wide" "solo"
run parents-private-on 1002f
run parents-private-off 2f
echo "$NAME list_export reports: $(cat $R/asan-default.* 2>/dev/null | grep -c '_tag_get_attached_export')"
rm -rf $W
