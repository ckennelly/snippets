-- tagexport.lua: attach a few hierarchical tags, then press the tagging
-- module's "export..." button (its file chooser is accepted by sanexport.sh
-- through xdotool) so that dt_tag_export() writes the tag list, then quit.
-- "aaa tag" is the first tag by name, but sorts after "aaa|sub" by path
-- (dt_sort_tag() compares with '|' as '\1'), so sorting moves the head.
-- Writes progress to DTX_OUT.
local dt = require "darktable"
local out = io.open(os.getenv("DTX_OUT"), "w")
local function log(s) out:write(s .. "\n"); out:flush() end
dt.control.sleep(20000)
for _, name in ipairs({ "aaa tag", "aaa|sub", "sanx|alpha", "sanx|beta|deep", "sanx|beta|wide", "solo" }) do
  local t = dt.tags.create(name)
  dt.tags.attach(t, dt.collection[1]); dt.tags.attach(t, dt.collection[2])
end
log("tagged")
dt.gui.action("lib/tagging/export...", 1.0)
log("export action returned")
dt.control.sleep(5000)
log("done")
out:close()
dt.gui.action("global/quit", 1.0)
