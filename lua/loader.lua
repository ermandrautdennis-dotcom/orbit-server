--[[ loader.lua — Lua 5.1 / Luau, client-side authentication bootstrap.

    Shipped to the client, therefore assumed to be fully readable by anyone who
    runs it. It contains no secret of ours: the only credential it carries is the
    user's own script key, which they paste in themselves and which can be
    rotated from the panel at any time.

    Everything that decides whether the protected source is handed over happens
    on the server:
      * script key -> license resolution, status, expiry, owner blacklist
      * tier authorisation (a public license cannot request the private hub)
      * global and per-script online switches
      * grant issuance, single-use consumption, IP binding and expiry
      * rate limiting

    Protocol:
      1. GET  /api/status                 -> is anything online at all
      2. POST /api/script/authenticate    -> { grant, expires_in, script.version }
      3. POST /api/script/fetch           -> the Lua source, as text
      4. compile and run

    Usage (exactly what the Discord panel hands the user):
        script_key = "osk_..."
        script_tier = "public"            -- or "private"
        loadstring(game:HttpGet("https://your-domain/api/script/loader"))()
--]]

local API_BASE      = "__API_BASE_URL__"
local LOADER_VERSION = "1.0.0"
local REQUEST_TIMEOUT = 15

-- ── Environment shims ───────────────────────────────────────────────────────
-- Executors expose HTTP under different names. Resolve once, fail clearly.
local http_request = (syn and syn.request)
    or (http and http.request)
    or http_request
    or (fluxus and fluxus.request)
    or request

local HttpService = (typeof(game) ~= "nil") and game:GetService("HttpService") or nil

local function json_encode(t)
    if HttpService then return HttpService:JSONEncode(t) end
    error("orbit: no JSON encoder available")
end

local function json_decode(s)
    if HttpService then
        local ok, result = pcall(function() return HttpService:JSONDecode(s) end)
        if ok then return result end
    end
    return nil
end

-- ── Output ──────────────────────────────────────────────────────────────────
local function log(msg)
    print("[orbit] " .. tostring(msg))
end

local function fail(msg)
    -- One generic surface for the user. The server already knows the real reason
    -- and has logged it; echoing server internals here would help nobody but an
    -- attacker probing for which of their keys is which.
    log(msg)
    error("[orbit] " .. tostring(msg), 0)
end

-- ── Transport ───────────────────────────────────────────────────────────────
local function post(path, body)
    if not http_request then
        fail("Your executor does not expose an HTTP request function.")
    end
    local ok, response = pcall(http_request, {
        Url = API_BASE .. path,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["Accept"] = "application/json, text/plain",
            ["X-Loader-Version"] = LOADER_VERSION,
        },
        Body = json_encode(body),
        Timeout = REQUEST_TIMEOUT,
    })
    if not ok then
        fail("Could not reach the authentication server.")
    end
    local status = response.StatusCode or response.Status or 0
    return status, response.Body or ""
end

local function get(path)
    local ok, body = pcall(function()
        return game:HttpGet(API_BASE .. path)
    end)
    if not ok then return nil end
    return body
end

-- ── Input ───────────────────────────────────────────────────────────────────
-- The user sets these as globals above the loadstring call. getfenv exists in
-- Lua 5.1 and most Luau executors but not all, so resolve defensively rather
-- than indexing whatever it happens to return.
local function read_global(name)
    local ok, env = pcall(function()
        if type(getfenv) == "function" then return getfenv(0) end
        return nil
    end)
    if ok and type(env) == "table" and env[name] ~= nil then return env[name] end
    return _G[name]
end

local key = read_global("script_key")
local tier = read_global("script_tier") or "public"

if type(key) ~= "string" or #key < 16 then
    fail('No script key set. Put script_key = "osk_..." above the loadstring call.')
end
if tier ~= "public" and tier ~= "private" then
    tier = "public"
end

-- ── Step 1: global status ───────────────────────────────────────────────────
do
    local raw = get("/api/status")
    local parsed = raw and json_decode(raw)
    if parsed and parsed.script_status ~= "online" then
        fail("Script is currently offline.")
    end
end

-- ── Step 2: authenticate, receive a short-lived grant ───────────────────────
log("authenticating…")
local status, body = post("/api/script/authenticate", {
    script_key = key,
    tier = tier,
    loader_version = LOADER_VERSION,
})

if status == 503 then fail("Script is currently offline.") end
if status == 429 then fail("Too many attempts. Wait a minute and try again.") end
if status == 401 or status == 403 then fail("Authentication failed.") end
if status ~= 200 then fail("Authentication failed.") end

local auth = json_decode(body)
if not auth or not auth.grant then fail("Authentication failed.") end

local remote_version = auth.script and auth.script.version or "?"
log(("authenticated — %s v%s"):format(tier, tostring(remote_version)))

-- ── Step 3: redeem the grant for the source ─────────────────────────────────
-- The grant is single-use, IP-bound and expires in seconds, so there is nothing
-- worth caching here; fetch immediately.
local fetch_status, source = post("/api/script/fetch", { grant = auth.grant })

if fetch_status == 503 then fail("Script is currently offline.") end
if fetch_status == 429 then fail("Too many requests. Slow down.") end
if fetch_status ~= 200 then fail("Access denied.") end
if type(source) ~= "string" or #source == 0 then fail("Access denied.") end

-- ── Step 4: compile and run ─────────────────────────────────────────────────
local chunk, compile_err = loadstring(source, "=orbit:" .. tier)
if not chunk then
    fail("Script failed to compile: " .. tostring(compile_err))
end

log("loaded")
return chunk()
