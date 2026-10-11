-- Drives the lighttable rating action through darktable.gui.action (the same
-- dt_action_process() path a keyboard shortcut takes) and records, per action,
-- the CPU time of the GUI thread and of the whole process.
--
-- darktable --luacmd 'dofile("bench.lua")' with
--   DTB_OUT      results file (one line per action, then "done")
--   DTB_KEYS     number of rating actions (default 100)
--   DTB_GAP_MS   time between actions; must cover the redraw (default 500)
--   DTB_SETTLE_MS  wait before the first action (default 15000)
--   DTB_IDLE_MS  idle window measured before the first action (default 10000)
local dt = require "darktable"

local keys = tonumber(os.getenv("DTB_KEYS") or "100")
local gap = tonumber(os.getenv("DTB_GAP_MS") or "500")
local settle = tonumber(os.getenv("DTB_SETTLE_MS") or "15000")
local idle = tonumber(os.getenv("DTB_IDLE_MS") or "10000")
local out = assert(io.open(assert(os.getenv("DTB_OUT"), "DTB_OUT unset"), "w"))

local function line(path)
  local f = assert(io.open(path))
  local l = f:read("*l")
  f:close()
  return l
end

-- the GUI thread is the main thread, so its tid is the pid
local pid = line("/proc/self/stat"):match("^(%d+)")
local sched = "/proc/" .. pid .. "/task/" .. pid .. "/schedstat"
-- first schedstat field: ns on cpu
local function gui_ns() return tonumber(line(sched):match("^(%d+)")) end

dt.control.sleep(settle)

-- act on one image: the first of the collection
dt.gui.selection({ dt.collection[1] })
dt.control.sleep(1000)

-- an idle window, for the background floor
local g0, p0 = gui_ns(), os.clock()
dt.control.sleep(idle)
out:write(string.format("idle gui_ns=%d proc_us=%d ms=%d\n",
                        gui_ns() - g0, math.floor((os.clock() - p0) * 1e6), idle))

-- alternate two ratings so that every action is a real change
local stars = { "two", "four" }
for i = 1, keys do
  local g, p = gui_ns(), os.clock()
  -- returns NaN for a write: only reads report a value
  dt.gui.action("views/thumbtable/rating", stars[i % 2 + 1], "select", 1.0)
  dt.control.sleep(gap)
  out:write(string.format("key %d gui_ns=%d proc_us=%d\n",
                          i, gui_ns() - g, math.floor((os.clock() - p) * 1e6)))
end
-- check that the actions reached the image
out:write(string.format("check rating=%d expected=%d\n", dt.collection[1].rating, keys % 2 == 0 and 2 or 4))
out:write("done\n")
out:close()
