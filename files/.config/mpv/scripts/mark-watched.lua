local utils = require("mp.utils")

local watched_dir = os.getenv("HOME") .. "/.local/state/lf/watched"
local current_hash = nil

local function compute_hash()
    local path = mp.get_property("path")
    if not path then return nil end

    local r1 = utils.subprocess({
        args = { "realpath", "--", path },
        cancellable = false,
    })
    local real = (r1.status == 0)
        and r1.stdout:gsub("%s+$", "")
        or  path

    local r2 = utils.subprocess({
        args = { "md5sum" },
        stdin_data = real,
        cancellable = false,
    })
    if r2.status ~= 0 then return nil end
    local hash = r2.stdout:match("^(%x+)")
    if not hash or hash == "" then return nil end
    return hash:upper()
end

mp.register_event("file-loaded", function()
    current_hash = compute_hash()
    if current_hash then
        os.remove(watched_dir .. "/" .. current_hash)
    end
end)

mp.register_event("end-file", function(event)
    if event.reason == "eof" and current_hash then
        os.execute("mkdir -p '" .. watched_dir .. "'")
        local f = io.open(watched_dir .. "/" .. current_hash, "w")
        if f then
            f:write("")
            f:close()
        end
    end
    current_hash = nil
end)
