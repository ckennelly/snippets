-- extra.lua: drive color labels, duplicates, tagging and export on the
-- first images of the collection, then quit, so that LeakSanitizer reports
-- what these paths leak. Writes progress to DTX_OUT.
local dt = require "darktable"
local out = io.open(os.getenv("DTX_OUT"), "w")
local function log(s) out:write(s .. "\n"); out:flush() end
dt.control.sleep(20000)
local img = dt.collection[1]
dt.gui.selection({ img })
dt.control.sleep(1000)
for i = 1, 10 do
  dt.gui.action("views/thumbtable/color label", "red", "toggle", 1.0)
  dt.control.sleep(300)
end
log("colorlabels " .. tostring(img.red))
-- the thumbtable duplicate action is not valid from a Lua call; the Lua
-- API takes the same path, including the undo record
for i = 1, 3 do
  dt.database.duplicate(img)
end
log("images " .. #dt.database)
local t1 = dt.tags.create("sanx|alpha")
local t2 = dt.tags.create("sanx|beta")
local t3 = dt.tags.create("sanx|gamma")
for i = 1, 3 do
  dt.tags.attach(t1, dt.collection[i]); dt.tags.attach(t2, dt.collection[i]); dt.tags.attach(t3, dt.collection[i])
end
log("tagged")
local fmt = dt.new_format("jpeg")
fmt.max_width = 256; fmt.max_height = 256
for i = 1, 3 do
  fmt:write_image(dt.collection[i], os.getenv("DTX_EXPORT") .. "/x" .. i .. ".jpg")
end
log("exported")
log("done")
out:close()
dt.gui.action("global/quit", 1.0)
