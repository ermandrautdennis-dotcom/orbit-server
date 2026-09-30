"""Builds the Lua loader snippet handed to users.

The loader collects the executor's HWID, POSTs it with the key to /api/script,
and runs whatever the server returns. Nothing about the actual payload lives
on the client — only the loader does.
"""
from __future__ import annotations

from app import config

_TEMPLATE = """--[[ Orbit loader — paste into your executor ]]--
local KEY  = "{key}"
local TIER = "{tier}"
local URL  = "{base}/api/script"

local HttpService = game:GetService("HttpService")

-- HWID: most executors expose gethwid(); fall back to a stable client id.
local function get_hwid()
    local ok, id = pcall(function()
        if gethwid then return gethwid() end
        if syn and syn.crypt then return gethwid and gethwid() end
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    return ok and id or "unknown"
end

-- request(): syn.request / http_request / request depending on executor.
local http = (syn and syn.request) or http_request or request
if not http then
    return warn("[Orbit] no HTTP function found in this executor")
end

local res = http({{
    Url = URL,
    Method = "POST",
    Headers = {{ ["Content-Type"] = "application/json" }},
    Body = HttpService:JSONEncode({{ key = KEY, hwid = get_hwid(), tier = TIER }}),
}})

if res.StatusCode == 200 then
    local data = HttpService:JSONDecode(res.Body)
    local fn = loadstring(data.script)
    if fn then fn() else warn("[Orbit] failed to compile script") end
else
    local msg = res.Body
    pcall(function() msg = HttpService:JSONDecode(res.Body).detail end)
    warn("[Orbit] auth failed: " .. tostring(msg))
end
"""


def build_loader(key: str, tier: str) -> str:
    return _TEMPLATE.format(key=key, tier=tier, base=config.BASE_URL)
