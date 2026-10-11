-- import.lua: import DTX_DIR (new maker, model and lens names), wait for
-- the import to settle, then quit so that LeakSanitizer reports
local dt = require "darktable"
local out = io.open(os.getenv("DTX_OUT"), "w")
dt.control.sleep(5000)
dt.database.import(os.getenv("DTX_DIR"))
dt.control.sleep(15000)
out:write("images " .. #dt.database .. "\ndone\n")
out:close()
dt.gui.action("global/quit", 1.0)
