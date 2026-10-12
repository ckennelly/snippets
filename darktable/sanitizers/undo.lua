-- undo.lua: rate, color-label and duplicate three images, then undo and
-- redo through the lighttable actions (the ctrl+z/ctrl+y path), so that the
-- undo entries are replayed and then freed both when a new action drops the
-- redo list and at exit. Checks the image state after every step and writes
-- PASS/FAIL lines to DTX_OUT.
local dt = require "darktable"
local out = io.open(os.getenv("DTX_OUT"), "w")
local fails = 0
local function log(s) out:write(s .. "\n"); out:flush() end
local function check(name, got, want)
  if got == want then log("PASS " .. name .. " " .. tostring(got))
  else fails = fails + 1; log("FAIL " .. name .. " got " .. tostring(got) .. " want " .. tostring(want)) end
end
-- undo merges the steps recorded within 0.5 s, so keep them further apart
local function act(...) dt.gui.action(...); dt.control.sleep(1500) end
local function undo() act("views/lighttable/undo", 1.0) end
local function redo() act("views/lighttable/redo", 1.0) end
local names = { [0] = "zero", "one", "two", "three", "four", "five" }
local function rate(n) act("views/thumbtable/rating", names[n], "select", 1.0) end
local function red() act("views/thumbtable/color label", "red", "toggle", 1.0) end

dt.control.sleep(20000)
local imgs = { dt.collection[1], dt.collection[2], dt.collection[3] }
dt.gui.selection(imgs)
dt.control.sleep(1000)
local function ratings() return imgs[1].rating .. imgs[2].rating .. imgs[3].rating end
local function reds() return tostring(imgs[1].red) .. tostring(imgs[2].red) .. tostring(imgs[3].red) end

-- ratings
rate(0); local r0 = ratings(); check("rating start", r0, "000")
rate(1); rate(2); rate(3); rate(4)
check("rating set", ratings(), "444")
undo(); check("rating undo", ratings(), "333")
undo(); check("rating undo", ratings(), "222")
redo(); check("rating redo", ratings(), "333")
undo(); undo(); check("rating undo x2", ratings(), "111")
-- a new action drops the redo list: the rating 2, 3 and 4 steps
rate(5); check("rating new", ratings(), "555")
redo(); check("rating redo after drop is a no-op", ratings(), "555")
undo(); check("rating undo", ratings(), "111")
undo(); check("rating undo to start", ratings(), r0)
redo(); check("rating redo", ratings(), "111")

-- color labels
local c0 = reds()
red(); red(); red()
local c1 = reds()
check("label toggled", c1 ~= c0, true)
undo(); check("label undo", reds(), c0)
undo(); check("label undo", reds(), c1)
redo(); check("label redo", reds(), c0)
-- drops the third toggle from the redo list
red(); check("label new", reds(), c1)
undo(); check("label undo", reds(), c0)

-- duplicates
local n0 = #dt.database
dt.database.duplicate(imgs[1]); dt.control.sleep(1500)
dt.database.duplicate(imgs[1]); dt.control.sleep(1500)
check("duplicate", #dt.database, n0 + 2)
undo(); check("duplicate undo", #dt.database, n0 + 1)
redo(); check("duplicate redo", #dt.database, n0 + 2)
undo(); undo(); check("duplicate undo x2", #dt.database, n0)
redo(); check("duplicate redo", #dt.database, n0 + 1)
-- drops the second duplicate from the redo list
rate(2); check("rating after duplicate", ratings(), "222")
undo(); check("rating undo", ratings(), "111")
undo(); check("duplicate undo", #dt.database, n0)

log("fails " .. fails)
log("done")
out:close()
dt.gui.action("global/quit", 1.0)
