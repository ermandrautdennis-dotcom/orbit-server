--[[ Orbit loader (reference copy)

    The Discord bot hands out a filled-in version of this automatically:
      - /key <key>            → premium loader with your key baked in
      - panel "Public" button → public loader

    You normally don't edit this by hand. Replace KEY / URL below only if you
    want a static loader. TIER must match a file in scripts/ (public/premium).
]]--

local KEY  = "PASTE-YOUR-KEY"
local TIER = "premium"
local URL  = "https://your-app.up.railway.app/api/script"

local HttpService = game:GetService("HttpService")

local function get_hwid()
    local ok, id = pcall(function()
        if gethwid then return gethwid() end
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    return ok and id or "unknown"
end

local http = (syn and syn.request) or http_request or request
if not http then
    return warn("[Orbit] no HTTP function found in this executor")
end

local res = http({
    Url = URL,
    Method = "POST",
    Headers = { ["Content-Type"] = "application/json" },
    Body = HttpService:JSONEncode({ key = KEY, hwid = get_hwid(), tier = TIER }),
})

if res.StatusCode == 200 then
    local data = HttpService:JSONDecode(res.Body)
    local fn = loadstring(data.script)
    if fn then fn() else warn("[Orbit] failed to compile script") end
else
    local msg = res.Body
    pcall(function() msg = HttpService:JSONDecode(res.Body).detail end)
    warn("[Orbit] auth failed: " .. tostring(msg))
end
