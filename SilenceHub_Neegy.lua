-- ════════════════════════════════════════════════════════════════
--  SILENCE HUB — PRE-GAME LOADER  (PATCHED v11)
--  Runs BEFORE game.Loaded — black overlay, FFlags, world cleanup.
-- ════════════════════════════════════════════════════════════════
do
    local _SH_LOADER_CFG = {
        SHOW_SCREEN    = true,
        APPLY_FFLAGS   = true,
        VISUAL_CLEANUP = false,
        NUKE_TEXTURES  = false,
        DISPLAY_TIME   = 5,
    }

    if _G.SH_LoaderEnabled == false then
        _SH_LOADER_CFG.SHOW_SCREEN = false
        _SH_LOADER_CFG.APPLY_FFLAGS = false
        _SH_LOADER_CFG.VISUAL_CLEANUP = false
        _SH_LOADER_CFG.NUKE_TEXTURES = false
    end

    _G._SH_LoaderCfg = _SH_LOADER_CFG

    local _TweenService    = game:GetService("TweenService")
    local _RunService      = game:GetService("RunService")
    local _ContentProvider = game:GetService("ContentProvider")
    local _Lighting        = game:GetService("Lighting")
    local _Players         = game:GetService("Players")

    local _lp = _Players.LocalPlayer
    while not _lp do task.wait(); _lp = _Players.LocalPlayer end

    local function _mountGui(g)
        if syn and syn.protect_gui then pcall(function() syn.protect_gui(g) end) end
        local ok, hui = pcall(function() return gethui and gethui() end)
        if ok and hui then g.Parent = hui; return end
        if not pcall(function() g.Parent = game:GetService("CoreGui") end) then
            g.Parent = _lp:WaitForChild("PlayerGui", 5)
        end
    end

    local _C = {
        BgBase    = Color3.fromRGB(4,   4,   6),
        BgPanel   = Color3.fromRGB(15,  18,  28),
        BgCard    = Color3.fromRGB(20,  25,  38),
        Gold      = Color3.fromRGB(255, 215,  60),
        GoldLight = Color3.fromRGB(255, 235, 100),
        GoldMid   = Color3.fromRGB(230, 170,  20),
        GoldDark  = Color3.fromRGB(140,  95,   0),
        TextDim   = Color3.fromRGB(140, 140, 140),
    }

    local _blackSG, _blackFrame
    if _SH_LOADER_CFG.SHOW_SCREEN then
        _blackSG = Instance.new("ScreenGui")
        _blackSG.Name           = "SHLoaderOverlay"
        _blackSG.ResetOnSpawn   = false
        _blackSG.IgnoreGuiInset = true
        _blackSG.DisplayOrder   = 999998

        _blackFrame = Instance.new("Frame")
        _blackFrame.Size             = UDim2.new(1,0,1,0)
        _blackFrame.BackgroundColor3 = _C.BgBase
        _blackFrame.BorderSizePixel  = 0
        _blackFrame.Parent           = _blackSG

        local _statusLbl = Instance.new("TextLabel")
        _statusLbl.Size                  = UDim2.new(1,0,0,20)
        _statusLbl.Position              = UDim2.new(0,0,1,-44)
        _statusLbl.BackgroundTransparency = 1
        _statusLbl.Text                  = "silence hub — loading…"
        _statusLbl.TextColor3            = _C.GoldMid
        _statusLbl.Font                  = Enum.Font.GothamBold
        _statusLbl.TextSize              = 11
        _statusLbl.Parent                = _blackFrame

        local _sg = Instance.new("UIGradient", _statusLbl)
        _sg.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   _C.GoldDark),
            ColorSequenceKeypoint.new(0.3, _C.GoldMid),
            ColorSequenceKeypoint.new(0.5, _C.GoldLight),
            ColorSequenceKeypoint.new(0.7, _C.GoldMid),
            ColorSequenceKeypoint.new(1,   _C.GoldDark),
        })
        task.spawn(function()
            local t = 0
            while _statusLbl and _statusLbl.Parent do
                t += task.wait(0.016)
                _sg.Offset = Vector2.new(math.sin(t*0.65)*0.55 + math.sin(t*1.3+1.2)*0.12, 0)
            end
        end)

        _mountGui(_blackSG)
    end

    -- FFlag injection
    if _SH_LOADER_CFG.APPLY_FFLAGS then
        task.spawn(function()
            local _setter
            for _, name in ipairs({"setfflag","setfastflag","set_fflag","setFFlag","fflag"}) do
                local fn = rawget(getfenv and getfenv() or {}, name) or (getgenv and getgenv()[name])
                if type(fn) == "function" then _setter = fn; break end
            end
            if _setter then
                local _ff = {
                    ["DFIntTaskSchedulerTargetFps"]               = "9999",
                    ["FFlagTaskSchedulerLimitTargetFpsToDevice"]  = "False",
                    ["FIntTaskSchedulerAutoThreadLimit"]           = "8",
                    ["FFlagEnableTextureStreaming"]                = "True",
                    ["DFIntMaxConcurrentDownloads"]                = "64",
                    ["FIntContentProviderConcurrentDownloadCount"] = "64",
                    ["FFlagLuauCodegen"]                           = "True",
                    ["FFlagLuauCodegenFull"]                       = "True",
                    ["FFlagDisablePostProcess"]                    = "True",
                    ["FFlagDisablePostFx"]                         = "True",
                    ["FFlagDisableTelemetryOnJoin"]                = "True",
                }
                for f, v in pairs(_ff) do pcall(function() _setter(f, v) end) end
            end
        end)
    end

    -- World visual cleanup
    if _SH_LOADER_CFG.VISUAL_CLEANUP or _SH_LOADER_CFG.NUKE_TEXTURES then
        pcall(function()
            local r = settings().Rendering
            r.QualityLevel        = Enum.QualityLevel.Level01
            r.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
        end)
        pcall(function() _Lighting.GlobalShadows = false; _Lighting.FogEnd = 100000; _Lighting.FogStart = 99999 end)

        local function _cleanObj(obj)
            if _SH_LOADER_CFG.NUKE_TEXTURES then
                pcall(function()
                    if obj:IsA("MeshPart") then obj.TextureID = ""; obj.Material = Enum.Material.SmoothPlastic
                    elseif obj:IsA("SpecialMesh") then obj.TextureId = ""
                    elseif obj:IsA("BasePart") then obj.Material = Enum.Material.SmoothPlastic; obj.CastShadow = false
                    end
                end)
            end
            if _SH_LOADER_CFG.VISUAL_CLEANUP then
                local cl = obj.ClassName
                if cl=="ParticleEmitter" or cl=="Fire" or cl=="Smoke" or cl=="Sparkles"
                    or cl=="Trail" or cl=="Beam" or cl=="Highlight"
                    or cl=="PointLight" or cl=="SpotLight" or cl=="SurfaceLight"
                    or cl=="BloomEffect" or cl=="BlurEffect" or cl=="DepthOfFieldEffect"
                    or cl=="SunRaysEffect" or cl=="ColorCorrectionEffect" then
                    pcall(function() obj.Enabled = false end)
                elseif cl=="Atmosphere" then pcall(function() obj.Density = 0 end)
                elseif cl=="Clouds"     then pcall(function() obj.Cover = 0; obj.Density = 0 end)
                elseif cl=="Decal" or cl=="Texture" then pcall(function() obj.Transparency = 1 end)
                end
            end
        end

        task.spawn(function()
            for _, obj in ipairs(workspace:GetDescendants()) do _cleanObj(obj) end
            for _, obj in ipairs(_Lighting:GetDescendants())  do _cleanObj(obj) end
        end)
        workspace.DescendantAdded:Connect(_cleanObj)
        _Lighting.DescendantAdded:Connect(_cleanObj)
    end

    -- Wait for game loaded, then fade out overlay
    task.spawn(function()
        local _t0 = os.clock()
        if not game:IsLoaded() then game.Loaded:Wait() end
        local _loadMs = math.floor((os.clock() - _t0) * 1000)

        if _blackFrame then
            _TweenService:Create(_blackFrame, TweenInfo.new(0.4), {BackgroundTransparency=1}):Play()
            task.delay(0.4, function() if _blackSG then _blackSG:Destroy() end end)
        end

        if _SH_LOADER_CFG.SHOW_SCREEN then
            task.spawn(function()
                task.wait(0.45)
                local _sg2 = Instance.new("ScreenGui")
                _sg2.Name="SHLoaderCard"; _sg2.ResetOnSpawn=false; _sg2.DisplayOrder=999
                local _card = Instance.new("Frame")
                _card.Size=UDim2.fromOffset(220,58); _card.Position=UDim2.new(0.5,-110,0,16)
                _card.BackgroundColor3=_C.BgBase; _card.BorderSizePixel=0; _card.Parent=_sg2
                Instance.new("UICorner",_card).CornerRadius=UDim.new(0,7)
                local _sk=Instance.new("UIStroke",_card); _sk.Color=_C.BgCard; _sk.Thickness=1; _sk.Transparency=0.3

                local _bar=Instance.new("Frame")
                _bar.Size=UDim2.new(1,0,0,2); _bar.BackgroundColor3=_C.Gold
                _bar.BorderSizePixel=0; _bar.Parent=_card
                Instance.new("UICorner",_bar).CornerRadius=UDim.new(0,7)
                local _bg=Instance.new("UIGradient",_bar)
                _bg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,_C.GoldDark),ColorSequenceKeypoint.new(0.5,_C.GoldLight),ColorSequenceKeypoint.new(1,_C.GoldDark)})

                local _title=Instance.new("TextLabel")
                _title.Size=UDim2.new(1,-32,0,18); _title.Position=UDim2.fromOffset(10,6)
                _title.BackgroundTransparency=1; _title.Text="silence hub"
                _title.Font=Enum.Font.GothamBlack; _title.TextSize=11; _title.TextColor3=_C.GoldMid
                _title.TextXAlignment=Enum.TextXAlignment.Left; _title.Parent=_card
                local _tg=Instance.new("UIGradient",_title)
                _tg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,_C.GoldDark),ColorSequenceKeypoint.new(0.3,_C.GoldMid),ColorSequenceKeypoint.new(0.5,_C.GoldLight),ColorSequenceKeypoint.new(0.7,_C.GoldMid),ColorSequenceKeypoint.new(1,_C.GoldDark)})
                task.spawn(function() local t=0 while _title and _title.Parent do t+=task.wait(0.016) _tg.Offset=Vector2.new(math.sin(t*0.65)*0.55+math.sin(t*1.3+1.2)*0.12,0) end end)

                local _close=Instance.new("TextButton")
                _close.Size=UDim2.fromOffset(18,18); _close.Position=UDim2.new(1,-22,0,6)
                _close.BackgroundColor3=_C.BgCard; _close.BorderSizePixel=0
                _close.Text="✕"; _close.TextColor3=_C.TextDim; _close.TextSize=10
                _close.Font=Enum.Font.GothamBold; _close.Parent=_card
                Instance.new("UICorner",_close).CornerRadius=UDim.new(0,3)

                local _div=Instance.new("Frame")
                _div.Size=UDim2.new(1,-20,0,1); _div.Position=UDim2.fromOffset(10,28)
                _div.BackgroundColor3=_C.BgPanel; _div.BorderSizePixel=0; _div.Parent=_card

                local _info=Instance.new("TextLabel")
                _info.Size=UDim2.new(1,-20,0,20); _info.Position=UDim2.fromOffset(10,33)
                _info.BackgroundTransparency=1
                _info.Text=string.format("⏱  ready in %dms", _loadMs)
                _info.TextColor3=_C.GoldMid; _info.Font=Enum.Font.GothamBold
                _info.TextSize=12; _info.TextXAlignment=Enum.TextXAlignment.Left
                _info.Parent=_card

                local function _dismiss()
                    if not _sg2 or not _sg2.Parent then return end
                    local fi=TweenInfo.new(0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
                    for _,c in ipairs(_sg2:GetDescendants()) do
                        if c:IsA("Frame") then _TweenService:Create(c,fi,{BackgroundTransparency=1}):Play()
                        elseif c:IsA("TextLabel") or c:IsA("TextButton") then _TweenService:Create(c,fi,{TextTransparency=1}):Play() end
                    end
                    task.delay(0.45, function() if _sg2 then _sg2:Destroy() end end)
                end
                _close.MouseButton1Click:Connect(_dismiss)
                _mountGui(_sg2)
                task.delay(_SH_LOADER_CFG.DISPLAY_TIME, _dismiss)
            end)
        end
    end)
end

-- ════════════════════════════════════════════════════════════════
--  GAME LOADED GATE
-- ════════════════════════════════════════════════════════════════
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- ════════════════════════════════════════════════════════════════
--  HOP GUARD — kill previous instance before re-running
-- ════════════════════════════════════════════════════════════════
do
    if type(_G.SH_Shutdown) == "function" then
        pcall(_G.SH_Shutdown)
        task.wait(0.15)
    end

    _G.__SH_Conns = _G.__SH_Conns or {}
    _G.SH_RegConn = function(c)
        if c and type(c.Disconnect) == "function" then
            table.insert(_G.__SH_Conns, c)
        end
        return c
    end

    _G.SH_Shutdown = function()
        _G.__SXE_RadarOff = true
        if _G.SXE_CentralScanner then
            pcall(task.cancel, _G.SXE_CentralScanner)
            _G.SXE_CentralScanner = nil
        end
        if type(_G.CarpetBoost_Toggle) == "function" then
            pcall(function()
                if CarpetState and CarpetState.enabled then
                    if CarpetState.conn then CarpetState.conn:Disconnect(); CarpetState.conn = nil end
                end
            end)
        end
        if type(_G._SH_StopBoxESP) == "function" then pcall(_G._SH_StopBoxESP) end
        for _, c in ipairs(_G.__SH_Conns or {}) do
            pcall(function() c:Disconnect() end)
        end
        _G.__SH_Conns = {}
        pcall(function()
            if _G.__SH_DrawingObjs then
                for _, d in ipairs(_G.__SH_DrawingObjs) do
                    pcall(function() d:Remove() end)
                end
                _G.__SH_DrawingObjs = {}
            end
        end)
    end

    pcall(function()
        local LP = game:GetService("Players").LocalPlayer
        LP.OnTeleport:Connect(function(state)
            if state == Enum.TeleportState.Started then
                pcall(_G.SH_Shutdown)
            end
        end)
    end)
end

-- ════════════════════════════════════════════════════════════════
--  STABILITY + ANTI-DETECTION GLOBALS (merged)
-- ════════════════════════════════════════════════════════════════
-- Silence globals
_G.JAF_StealUseFPP   = false
_G.MynxxGrappleQuiet = true
_G.MynxxNoAnim       = false
_G.MynxxScanCache    = true

-- Neegy globals
_G.TacoNeutralizeIdentity = false
_G.TacoAntiFlash          = true
_G.TacoInvisAuto          = false
_G.TacoAutoKickOnSteal    = false
_G.TacoRailStealSync      = true

-- ════════════════════════════════════════════════════════════════
--  BAC NEUTRALIZERS (setthreadidentity only)
-- ════════════════════════════════════════════════════════════════
if _G.TacoNeutralizeIdentity == true then
    local _noop = function() return nil end
    local ge = (getgenv and getgenv()) or _G
    for _, k in ipairs({"setthreadidentity","set_thread_identity","setidentity"}) do
        pcall(function() ge[k] = _noop end)
        pcall(function() _G[k]  = _noop end)
    end
end

-- ════════════════════════════════════════════════════════════════
--  ANTI-FLASH (Neegy — strip accessories from all characters)
-- ════════════════════════════════════════════════════════════════
if not _G.__TacoAntiFlash then
    _G.__TacoAntiFlash = true
    local Players = game:GetService("Players")
    local FX = { ParticleEmitter = true, Beam = true, Trail = true, Fire = true,
        Smoke = true, Sparkles = true, Explosion = true, PointLight = true,
        SpotLight = true, SurfaceLight = true }
    local function kill(item)
        if pcall(function() item:Destroy() end) then return end
        pcall(function()
            for _, d in ipairs(item:GetDescendants()) do
                if d:IsA("BasePart") then
                    d.Transparency = 1
                    d.CanCollide = false
                    d.CanQuery = false
                    d.CastShadow = false
                    d.LocalTransparencyModifier = 1
                elseif FX[d.ClassName] then
                    d.Enabled = false
                elseif d:IsA("Sound") then
                    d.Volume = 0
                    d:Stop()
                end
            end
        end)
    end
    local function strip(char)
        if not char or _G.TacoAntiFlash == false then return end
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Accessory") then kill(item) end
        end
    end
    local hooked = setmetatable({}, { __mode = "k" })
    local function hookChar(char)
        if not char or hooked[char] then return end
        hooked[char] = true
        strip(char)
        char.ChildAdded:Connect(function(c)
            if c:IsA("Accessory") and _G.TacoAntiFlash ~= false then
                task.defer(kill, c)
            end
        end)
    end
    local function hookPlayer(p)
        if p.Character then task.spawn(hookChar, p.Character) end
        p.CharacterAdded:Connect(hookChar)
    end
    for _, p in ipairs(Players:GetPlayers()) do pcall(hookPlayer, p) end
    Players.PlayerAdded:Connect(hookPlayer)
    workspace.DescendantAdded:Connect(function(d)
        if _G.TacoAntiFlash == false then return end
        if d.ClassName == "Accessory" then
            local par = d.Parent
            if par and par:FindFirstChildOfClass("Humanoid") then task.defer(kill, d) end
        end
    end)
    task.spawn(function()
        task.wait(tonumber(_G.TacoAntiFlashBootWait) or 3)
        while true do
            if _G.TacoAntiFlash ~= false then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Character then strip(p.Character) end
                end
                for _, m in ipairs(workspace:GetChildren()) do
                    if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then strip(m) end
                end
            end
            task.wait(6)
        end
    end)
end

-- Uncap FPS
pcall(function()
    if type(setfpscap) == "function" then setfpscap(999) end
end)

-- Silence print/warn spam
local print = function() end
local warn  = function() end

-- ════════════════════════════════════════════════════════════════
--  _waitForCharacter helper
-- ════════════════════════════════════════════════════════════════
local function _waitForCharacter(timeout)
    timeout = timeout or 30
    local _lp = game:GetService("Players").LocalPlayer
    local _deadline = os.clock() + timeout
    while os.clock() < _deadline do
        local c = _lp.Character
        if c and c:FindFirstChild("HumanoidRootPart") then return c end
        task.wait(0.05)
    end
    return nil
end

-- ════════════════════════════════════════════════════════════════
--  PLAYER / CHARACTER READY
-- ════════════════════════════════════════════════════════════════
local Players = game:GetService("Players")
local LP = Players.LocalPlayer or Players.PlayerAdded:Wait()

if not LP.Character or not LP.Character.Parent then
    LP.CharacterAdded:Wait()
end

local PG = LP:WaitForChild("PlayerGui", 30)

-- ════════════════════════════════════════════════════════════════
--  STAGGERED STARTUP
-- ════════════════════════════════════════════════════════════════
_waitForCharacter(30)
task.wait(0.5 + math.random(0, 150)/1000)

task.spawn(function()
    local _deadline = os.clock() + 25
    while type(_G.MynxxStartSideTP) ~= "function" do
        if os.clock() > _deadline then break end
        task.wait(0.1)
    end
    if type(_G.MynxxStartSideTP) == "function" then
        task.wait(0.2)
        pcall(_G.MynxxStartSideTP)
    end
end)

task.wait(math.random(50, 250) / 1000)
-- ════════════════════════════════════════════════════════════════
--  END SECTION 1 — BOOT
-- ════════════════════════════════════════════════════════════════
-- ============================================================================
-- SECTION 2: NET CORE ENGINES
-- Three anti-detection subsystems ported from neegy (BAC-3825 undetected).
--   Engine A: Net-Get       – hookfunction-based remote resolver
--   Engine B: secure_call   – run arbitrary fn inside game closure context
--   Engine C: Channel Registry – Synchronizer module scanner (multi-path)
-- ============================================================================

-- ============================================================================
-- ENGINE A: NET-GET (BAC-3825 undetected remote resolver via hookfunction)
-- ============================================================================
do
local RS = game:GetService("ReplicatedStorage")
local RUN = game:GetService("RunService")
local _netFolder = RS:WaitForChild("Packages"):WaitForChild("Net")
local _net
local function _getNet()
    if _net then return _net end
    local ok, m = pcall(require, _netFolder)
    if ok and type(m) == "table" then _net = m end
    return _net
end

local _getconns  = getconnections or get_signal_cons
local _hookfn    = hookfunction or replaceclosure or detourfunction
local _islc      = islclosure or is_l_closure
local _isexec    = isexecutorclosure or is_synapse_function or checkclosure
local _canHook   = type(_getconns) == "function" and type(_hookfn) == "function"
                   and type(_islc) == "function" and type(_isexec) == "function"
                   and type(debug) == "table" and type(debug.info) == "function"

local _queue, _hooked = {}, false

local function _hostFn()
    for _, sname in ipairs({ "Heartbeat", "PostSimulation", "PreSimulation", "RenderStepped", "PreRender", "Stepped" }) do
        local oks, sig = pcall(function() return RUN[sname] end)
        if oks and typeof(sig) == "RBXScriptSignal" then
            local okc, conns = pcall(_getconns, sig)
            if okc and type(conns) == "table" then
                for _, c in ipairs(conns) do
                    local okf, f = pcall(function() return c.Function end)
                    if okf and type(f) == "function" and _islc(f) and not _isexec(f) then
                        local src = select(2, pcall(debug.info, f, "s"))
                        if type(src) == "string" and src:find("^ReplicatedStorage%.") and not src:find("ReplicatedFirst") then
                            return f
                        end
                    end
                end
            end
        end
    end
end

_G._shStart = _G._shStart or os.clock()
local function _shUIReady()
    local minWait  = tonumber(_G.SH_HookMinWait) or 0.5
    local maxWait  = tonumber(_G.SH_HookMaxWait) or 3
    local elapsed  = os.clock() - (_G._shStart or os.clock())
    if elapsed < minWait then task.wait(minWait - elapsed) end
    local deadline = (_G._shStart or os.clock()) + maxWait
    local plr      = game:GetService("Players").LocalPlayer
    local cg       = game:GetService("CoreGui")
    while os.clock() < deadline do
        local ok, hit = pcall(function()
            local pg = plr and plr:FindFirstChildOfClass("PlayerGui")
            local scan = function(root)
                if not root then return false end
                for _, g in ipairs(root:GetChildren()) do
                    if g:IsA("ScreenGui") and g.Name ~= "" then
                        local n = g.Name:lower()
                        if n:find("brain") or n:find("topia") or n:find("hub") then return true end
                    end
                end
                return false
            end
            return scan(pg) or scan(cg)
        end)
        if ok and hit then break end
        task.wait(0.1)
    end
end

local function _install()
    if _hooked then return true end
    if not _canHook then return false end
    _shUIReady()
    if not _getNet() then return false end
    local h = _hostFn()
    if not h then return false end
    _G.__SH_NetHost = h
    local orig
    local w = function(...)
        local job = table.remove(_queue, 1)
        if job then
            local ok, r = pcall(_net[job.kind], _net, job.name)
            job.result = (ok and typeof(r) == "Instance") and r or nil
            job.done = true
        end
        return orig(...)
    end
    local oke, env = pcall(getfenv, h)
    if oke and type(env) == "table" then pcall(setfenv, w, env) end
    local okh, res = pcall(_hookfn, h, w)
    if not okh or type(res) ~= "function" then return false end
    orig = res
    _hooked = true
    return true
end
_G.SH_NetInstall = _install
_G.SH_NetHooked = function() return _hooked end
_G._shUIReady = _shUIReady

local _cache = {}
local function _get(name, kind)
    kind = (kind == "RemoteFunction" and "RemoteFunction")
        or (kind == "UnreliableRemoteEvent" and "UnreliableRemoteEvent")
        or "RemoteEvent"
    if type(name) ~= "string" or name == "" then return nil end
    local logical = name:match("^R[EF]/(.+)$") or name:match("^URE/(.+)$") or name
    local ck = kind .. "|" .. logical
    local hit = _cache[ck]
    if hit and hit.Parent then return hit end
    _cache[ck] = nil
    if not _getNet() then return nil end
    if not _install() then return nil end
    local job = { kind = kind, name = logical }
    _queue[#_queue + 1] = job
    local deadline = os.clock() + (tonumber(_G.SH_NetTimeout) or 5)
    pcall(function()
        while not job.done and os.clock() < deadline do RUN.Heartbeat:Wait() end
    end)
    if job.result and job.result.Parent then
        _cache[ck] = job.result
        return job.result
    end
    if not job.done then
        for i = #_queue, 1, -1 do
            if _queue[i] == job then table.remove(_queue, i) end
        end
        _hooked = false
    end
    return nil
end
_G.SH_Net = {
    RemoteEvent = function(_, name) return _get(name, "RemoteEvent") end,
    RemoteFunction = function(_, name) return _get(name, "RemoteFunction") end,
    UnreliableRemoteEvent = function(_, name) return _get(name, "UnreliableRemoteEvent") end,
}
_G.SH_GetRemote = _get
_G.Resolve = _get
_G.__secureGetRemote = function(method, name) return _get(name, method) end
do
    local _dummy = Instance.new("RemoteEvent")
    local _rawFire = (clonefunction and clonefunction(_dummy.FireServer)) or _dummy.FireServer
    _G.RawFire = function(name, ...)
        local r = _get(name)
        if not r then return false end
        _rawFire(r, ...)
        return true
    end
end
-- Pre-warm the hook so the first remote lookup isn't the one paying for it.
task.spawn(function()
    for _ = 1, 60 do
        if _install() then break end
        task.wait(0.25)
    end
end)
end

-- ============================================================================
-- ENGINE B: SECURE_CALL (run arbitrary fn inside game closure context)
-- ============================================================================
do
local secure_call = _G.secure_call
if type(secure_call) ~= "function" then
    local RUNSVC = (type(cloneref) == "function" and cloneref(game:GetService("RunService"))) or game:GetService("RunService")
    local state = { ready = false, inside = false }
    local conn, original

    local _getconns = getconnections or get_signal_cons
    local _hookfn   = hookfunction or replaceclosure or detourfunction
    local _islc     = islclosure or is_l_closure
    local _isexec   = isexecutorclosure or is_synapse_function or checkclosure
    local _canHook  = type(_getconns) == "function" and type(_hookfn) == "function"
                      and type(_islc) == "function" and type(_isexec) == "function"
                      and type(loadstring) == "function" and type(setfenv) == "function"
                      and type(debug) == "table" and type(debug.info) == "function"

    local WRAP_SRC = table.concat({
        "local state, pack, unpack = ...",
        "return function(...)",
        "    local job = state.job",
        "    if job and not job.done then",
        "        job.done = true",
        "        state.inside = true",
        "        job.result = pack(pcall(job.fn, unpack(job.args, 1, job.args.n)))",
        "        state.inside = false",
        "    end",
        "    return state.original(...)",
        "end",
    }, string.char(10))

    local function host()
        for _, sname in ipairs({ "Heartbeat", "RenderStepped", "PostSimulation" }) do
            local oks, sig = pcall(function() return RUNSVC[sname] end)
            if oks and typeof(sig) == "RBXScriptSignal" then
                local ok, conns = pcall(_getconns, sig)
                if ok and type(conns) == "table" then
                    for _, c in ipairs(conns) do
                        local okf, f = pcall(function() return c.Function end)
                        if okf and type(f) == "function" and _islc(f) and not _isexec(f) then
                            local s = select(2, pcall(debug.info, f, "s"))
                            if type(s) == "string" and s:find("^ReplicatedStorage%.") and not s:find("ReplicatedFirst") then
                                return f, c, s
                            end
                        end
                    end
                end
            end
        end
    end

    local function install()
        if state.ready then return true end
        if not _canHook then return false end
        if type(_G._shUIReady) == "function" then pcall(_G._shUIReady) end
        local h, c, src = host()
        if not h then return false end
        local chunk = loadstring(WRAP_SRC, "=" .. src)
        if type(chunk) ~= "function" then return false end
        local ok, env = pcall(getfenv, h)
        if ok and type(env) == "table" then pcall(setfenv, chunk, env) end
        local okw, wrapper = pcall(chunk, state, table.pack, table.unpack)
        if not okw or type(wrapper) ~= "function" then return false end
        local okh, orig = pcall(_hookfn, h, wrapper)
        if not okh or type(orig) ~= "function" then return false end
        original = orig
        state.original = original
        conn = c
        state.ready = true
        return true
    end

    secure_call = function(fn, ...)
        if type(fn) ~= "function" then return nil end
        if state.inside then return fn(...) end
        if not install() then return nil end
        state.job = { fn = fn, args = table.pack(...), done = false }
        pcall(function() conn:Fire(0) end)
        local job = state.job
        state.job = nil
        if not job or not job.done or not job.result then return nil end
        if not job.result[1] then error(job.result[2], 2) end
        return table.unpack(job.result, 2, job.result.n)
    end
    _G.secure_call = secure_call
    _G.SH_SyncHooked = function() return state.ready end
end
end

-- ============================================================================
-- ENGINE C: CHANNEL REGISTRY (Synchronizer module scanner, multi-path discovery)
-- ============================================================================
do
local RS = game:GetService("ReplicatedStorage")
local secure_call = _G.secure_call

local _xchan
local _lastTry, _attempts = 0, 0
local _deepScans, _lastDeep = 0, 0
local MAX_ATTEMPTS, RETRY_GAP = 40, 0.5
local BOOT_T0, BOOT_BURST, BOOT_GAP = os.clock(), 3.0, 0.10
local MAX_DEEP, DEEP_GAP = 3, 1.5
local RS_SYNC = RS
local _mask_sc
local function _getMask()
    if _mask_sc and _mask_sc.Parent then return _mask_sc end
    local c = RS_SYNC:FindFirstChild("Controllers")
    _mask_sc = c and c:FindFirstChild("PlotController")
    return _mask_sc
end

local _syncMod_sc, _nextTry_sc = nil, 0
local function _getSyncMod()
    if _syncMod_sc then return _syncMod_sc end
    local p = RS_SYNC:FindFirstChild("Packages")
    local m = p and p:FindFirstChild("Synchronizer")
    if not m then return nil end
    local ok, mod = pcall(require, m)
    if ok and type(mod) == "table" then _syncMod_sc = mod end
    return _syncMod_sc
end

local function _channelCount(t)
    if type(t) ~= "table" then return 0 end
    local ok, hits = pcall(function()
        local h, n = 0, 0
        for _, v in next, t do
            n = n + 1
            if type(v) == "table" and type(rawget(v, "CacheTable")) == "table" then
                h = h + 1
            end
            if n >= 50 then break end
        end
        return h
    end)
    return (ok and hits) or 0
end

local function _probe(mod)
    local gu = (debug and debug.getupvalue) or getupvalue
    if type(gu) ~= "function" then return nil, 0, nil end
    local best, bestN, where = nil, 0, nil
    local function consider(t, tag)
        local n = _channelCount(t)
        if n > bestN then best, bestN, where = t, n, tag end
    end
    local cands = {
        { mod.Get, 10, 4, "Get/10/4" },
        { mod.GetAllChannels, 10, 1, "GetAll/10/1" },
        { mod.Wait, 10, 1, "Wait/10/1" },
    }
    for _, c in ipairs(cands) do
        if type(c[1]) == "function" then
            local o, u = pcall(gu, c[1], c[2])
            if o and type(u) == "table" then
                consider(rawget(u, c[3]), c[4])
                if bestN > 0 then return best, bestN, where end
            end
        end
    end
    for _, fn in ipairs({ mod.Get, mod.GetAllChannels, mod.Wait, mod.WaitAndCall, mod.GetTableFromChannel }) do
        if type(fn) == "function" then
            for i = 8, 12 do
                local o, u = pcall(gu, fn, i)
                if o and type(u) == "table" then
                    consider(u, "up" .. i)
                    for j = 1, 4 do consider(rawget(u, j), "up" .. i .. "/" .. j) end
                    if bestN > 0 then return best, bestN, where end
                end
            end
        end
    end
    local ok, up = pcall(gu, mod.Get, 9)
    if ok and type(up) == "table" then
        consider(rawget(up, 3), "Get/9/3")
        if bestN > 0 then return best, bestN, where end
        consider(up, "Get/9")
        if bestN > 0 then return best, bestN, where end
    end
    return best, bestN, where
end

local function _deepScan(mod)
    local gu = (debug and debug.getupvalue) or getupvalue
    if type(gu) ~= "function" then return nil, 0, nil end
    local best, bestN, where = nil, 0, nil
    local function consider(t, tag)
        local n = _channelCount(t)
        if n > bestN then best, bestN, where = t, n, tag end
    end
    for fname, fn in next, mod do
        if type(fn) == "function" then
            for i = 1, 24 do
                local o, u = pcall(gu, fn, i)
                if not o then break end
                if type(u) == "table" then
                    consider(u, tostring(fname) .. "/" .. i)
                    for j = 1, 4 do
                        consider(rawget(u, j), tostring(fname) .. "/" .. i .. "/" .. j)
                    end
                end
            end
        end
    end
    return best, bestN, where
end

local _gcFound, _gcFoundN, _gcState = nil, 0, "idle"
local function _gcScanOnce()
    if type(getgc) ~= "function" then return end
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return end
    local live, nLive = {}, 0
    for _, p in ipairs(plots:GetChildren()) do live[p.Name] = true; nLive = nLive + 1 end
    if nLive == 0 then return end
    local best, bestN = nil, 0
    pcall(function()
        local gc = getgc(true)
        for i = 1, #gc do
            local t = gc[i]
            if type(t) == "table" then
                pcall(function()
                    local pk = 0
                    for k in next, t do
                        if type(k) == "string" and live[k] then pk = pk + 1; if pk >= 2 then break end end
                    end
                    if pk < 2 then return end
                    local hits, seen = 0, 0
                    for k, v in next, t do
                        seen = seen + 1
                        if type(k) == "string" and live[k]
                            and type(v) == "table" and type(rawget(v, "CacheTable")) == "table" then
                            hits = hits + 1
                        end
                        if seen >= 64 then break end
                    end
                    if hits > bestN and hits >= 2 then best, bestN = t, hits end
                end)
                if bestN >= nLive then break end
            end
        end
    end)
    if best and bestN > 0 then _gcFound, _gcFoundN = best, bestN end
end

local _gcLastScan = 0
local function _gcChans()
    if _gcFound then return _gcFound, _gcFoundN, "getgc/plot-key+CacheTable" end
    if os.clock() - _gcLastScan < (tonumber(_G.SH_SyncScanGap) or 0.2) then return nil, 0, nil end
    _gcLastScan = os.clock()
    _gcScanOnce()
    if _gcFound then return _gcFound, _gcFoundN, "getgc/plot-key+CacheTable" end
    return nil, 0, nil
end

local function _apiChans(mod)
    if type(mod) ~= "table" then return nil, 0, nil end
    local fn = rawget(mod, "GetAllChannels")
    if type(fn) ~= "function" then return nil, 0, nil end
    local function _accept(reg, tag)
        if type(reg) ~= "table" then return nil, 0, nil end
        local n = _channelCount(reg)
        if n > 0 then return reg, n, tag end
        return nil, 0, nil
    end
    local mask = _getMask()
    if _G.SH_AllowSecureSyncCall and mask and type(secure_call) == "function" then
        for _, form in ipairs({ "self", "plain" }) do
            local ok, reg = pcall(function()
                if form == "self" then return secure_call(fn, mask, mod) end
                return secure_call(fn, mask)
            end)
            if ok then
                local r, n, t = _accept(reg, "GetAllChannels/secure_call(" .. form .. ")")
                if r then return r, n, t end
            end
        end
    end
    if _G.SH_AllowRawSyncCall then
        for _, form in ipairs({ "self", "plain" }) do
            local ok, reg = pcall(function()
                if form == "self" then return fn(mod) end
                return fn()
            end)
            if ok then
                local r, n, t = _accept(reg, "GetAllChannels/RAW(" .. form .. ")")
                if r then return r, n, t end
            end
        end
    end
    return nil, 0, nil
end

if _G.SH_AllowSecureSyncCall == nil then _G.SH_AllowSecureSyncCall = true end
local _xchan2, _nextTry2, _attempts2 = nil, 0, 0
local _xchan2Until = 0

-- Persistent plot->channel accumulator (never-regress).
if _G.SH_ChanAccumulate == nil then _G.SH_ChanAccumulate = true end
local _chanAcc, _chanAccN = {}, 0

local function _liveChanCount(t)
    if type(t) ~= "table" then return 0 end
    local ok, hits = pcall(function()
        local plots = workspace:FindFirstChild("Plots")
        local h = 0
        for k, v in next, t do
            if type(k) == "string" and type(v) == "table"
                and type(rawget(v, "CacheTable")) == "table"
                and (not plots or plots:FindFirstChild(k)) then
                h = h + 1
            end
        end
        return h
    end)
    return (ok and hits) or 0
end

local function _accIngest(reg)
    if _G.SH_ChanAccumulate == false then return end
    if type(reg) ~= "table" then return end
    pcall(function()
        local plots = workspace:FindFirstChild("Plots")
        for k, v in next, reg do
            if type(k) == "string" and type(v) == "table"
                and type(rawget(v, "CacheTable")) == "table"
                and (not plots or plots:FindFirstChild(k)) then
                if _chanAcc[k] == nil then _chanAccN = _chanAccN + 1 end
                _chanAcc[k] = v
            end
        end
        if plots then
            for k in next, _chanAcc do
                if not plots:FindFirstChild(k) then
                    _chanAcc[k] = nil; _chanAccN = _chanAccN - 1
                end
            end
        end
    end)
    _G.SH_ChanAccN = _chanAccN
end

-- Anchored channel registry (metatable identity sweep).
local _identityChans
do
    local _cls, _reg, _regN = nil, nil, 0
    local _nextSweep, _clsNextTry, _clsTries = 0, 0, 0

    local function _classHandle()
        if _cls then return _cls end
        if os.clock() < _clsNextTry then return nil end
        _clsNextTry = os.clock() + 0.25
        _clsTries = _clsTries + 1
        if _clsTries > 200 then return nil end
        local ok, c = pcall(function()
            local pkgs = RS:FindFirstChild("Packages")
            local sync = pkgs and pkgs:FindFirstChild("Synchronizer")
            local chan = sync and sync:FindFirstChild("Channel")
            if not chan then return nil end
            return require(chan)
        end)
        if ok and type(c) == "table" then _cls = c end
        return _cls
    end

    local function _coverage()
        local plots = workspace:FindFirstChild("Plots")
        if not plots then return 0, 0 end
        local total, hit = 0, 0
        for _, p in ipairs(plots:GetChildren()) do
            total = total + 1
            local c = _reg and _reg[p.Name]
            if type(c) == "table" and type(rawget(c, "CacheTable")) == "table" then
                hit = hit + 1
            end
        end
        return hit, total
    end

    local function _sweepHeap()
        local cls = _classHandle()
        if not cls or type(getgc) ~= "function" then
            _G.SH_IdentityDiag = cls and "getgc unavailable" or "Channel class unresolved"
            return false
        end
        local plots = workspace:FindFirstChild("Plots")
        local reg, n = {}, 0
        local swept = pcall(function()
            local heap = getgc(true)
            for i = 1, #heap do
                local v = heap[i]
                if type(v) == "table" and getmetatable(v) == cls then
                    local idx = rawget(v, "Index")
                    if type(idx) == "string" and (not plots or plots:FindFirstChild(idx)) then
                        if reg[idx] == nil then n = n + 1 end
                        reg[idx] = v
                    end
                end
            end
        end)
        if not swept then
            _G.SH_IdentityDiag = "heap sweep errored"
            return false
        end
        if n > 0 then
            _reg, _regN = reg, n
            _G.SH_IdentityDiag = string.format("metatable identity - %d channels", n)
            return true
        end
        _G.SH_IdentityDiag = "identity sweep - 0 channels"
        return false
    end

    _identityChans = function()
        if _G.SH_IdentityChans == false then return nil, 0, nil end
        local hit, total = _coverage()
        if total > 0 and hit >= total then return _reg, _regN, "identity" end
        local now = os.clock()
        if now >= _nextSweep then
            _nextSweep = now + (tonumber(_G.SH_IdentitySweepGap) or 0.35)
            _sweepHeap()
            hit, total = _coverage()
        end
        _G.SH_IdentityCover = hit
        if _reg and _regN > 0 then return _reg, _regN, "identity" end
        return nil, 0, nil
    end
    _G.SH_IdentitySweep = function() _sweepHeap() return _regN end
end

local function _chans()
    if _xchan2 then
        local now = os.clock()
        if now < _xchan2Until then return _xchan2 end
        if _channelCount(_xchan2) > 0 then _xchan2Until = now + 2 return _xchan2 end
    end
    if os.clock() < _nextTry2 then return _xchan2 end
    _attempts2 = _attempts2 + 1
    local best, n, where
    if _G.SH_AllowSecureSyncCall and _attempts2 <= 400 then
        local mod = _getSyncMod()
        if mod then best, n, where = _apiChans(mod) end
    end
    if type(_identityChans) == "function" then
        local _ib, _in, _iw = _identityChans()
        if _ib and _in > 0 and _in >= (n or 0) then best, n, where = _ib, _in, _iw end
    end
    if not best or n == 0 then best, n, where = _gcChans() end
    if (not best or n == 0) and _attempts2 <= 400
        and (_G.SH_AllowUpvalueProbe or _G.SH_AllowSecureSyncCall or _G.SH_AllowRawSyncCall) then
        local mod = _getSyncMod()
        if mod then
            if _G.SH_AllowUpvalueProbe then
                best, n, where = _probe(mod)
                if (not best or n == 0) and os.clock() - _lastDeep > 1 then
                    _lastDeep = os.clock()
                    _deepScans = _deepScans + 1
                    best, n, where = _deepScan(mod)
                end
            end
            if not best or n == 0 then best, n, where = _apiChans(mod) end
        end
    end
    if best and n > 0 then
        if _G.SH_ChanAccumulate ~= false then
            local newN = _liveChanCount(best)
            local oldN = (_xchan2 and _liveChanCount(_xchan2)) or 0
            if newN >= oldN or oldN == 0 then _xchan2 = best end
            _accIngest(best)
            _accIngest(_xchan2)
        else
            _xchan2 = best
        end
        _G.SH_SyncDiag = string.format("rawget/CacheTable scoring via %s - %d channels", tostring(where), n)
        return _xchan2
    end
    _nextTry2 = os.clock() + 0.1
    return _xchan2
end

_G.__secureChans = _chans
_G.SH_SyncAll = function() return _chans() end
_G.SH_SyncGet = function(idx)
    local t = _chans()
    if idx == nil then return nil end
    if t then
        local ok, cd = pcall(rawget, t, idx)
        if ok and type(cd) == "table" then return cd end
        local ok2, cd2 = pcall(function() return t[idx] end)
        if ok2 and type(cd2) == "table" then return cd2 end
    end
    if _G.SH_ChanAccumulate ~= false then
        local a = _chanAcc[idx]
        if type(a) == "table" then return a end
    end
    return nil
end

_G.sProp = function(ch, key)
    if type(ch) ~= "table" or key == nil then return nil end
    local ct = rawget(ch, "CacheTable")
    if type(ct) ~= "table" then
        local okC, c2 = pcall(function() return ch.CacheTable end)
        if okC and type(c2) == "table" then ct = c2 end
    end
    if type(ct) ~= "table" then return nil end
    local v = rawget(ct, key)
    if v ~= nil then return v end
    local okV, v2 = pcall(function() return ct[key] end)
    if okV then return v2 end
    return nil
end

_G._shRawCT = function(plotName)
    local c = _G.SH_SyncGet(plotName)
    if not c then return nil end
    return rawget(c, "CacheTable")
end

local _AD, _MD, _TD
local function _data()
    if _AD then return true end
    local ok = pcall(function()
        local d = game:GetService("ReplicatedStorage"):WaitForChild("Datas")
        _AD = require(d:WaitForChild("Animals"))
        _MD = require(d:WaitForChild("Mutations"))
        _TD = require(d:WaitForChild("Traits"))
    end)
    return ok and _AD ~= nil
end

_G._shGen = function(index, mutation, traits)
    if not _data() then return 0 end
    local info = _AD[index]
    if not info or not info.Generation then return 0 end
    local mult = 1
    if mutation and mutation ~= "None" and mutation ~= "" then
        local m = _MD[mutation]
        if m and m.Modifier then mult = mult + m.Modifier end
    end
    if type(traits) == "table" then
        for _, tr in ipairs(traits) do
            local t = _TD[tr]
            if t and t.MultiplierModifier then mult = mult + t.MultiplierModifier end
        end
    end
    return info.Generation * mult
end

_G._shAnimShim = setmetatable({
    GetGeneration = function(_, index, mutation, traits) return _G._shGen(index, mutation, traits) end
}, {
    __index = function(_, k)
        local ok, real = pcall(function() return require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Animals")) end)
        if ok and type(real) == "table" then return rawget(real, k) end
        return nil
    end
})

_G.SH_GetPlotChannel = function(plotName) return _G.SH_SyncGet(plotName) end
_G.SH_GetAllPlots = function() return _G.SH_SyncAll() or {} end
_G.SH_GetPlotAnimalList = function(plotName)
    local ct = _G._shRawCT(plotName)
    local al = ct and ct.AnimalList
    return type(al) == "table" and al or nil
end

-- Aliases for cross-section compatibility
_G.SH_SyncAll    = _G.SH_SyncAll
_G.SH_SyncGet    = _G.SH_SyncGet
_G.SH_RawCT     = _G._shRawCT
_G.SH_Gen        = _G._shGen
_G.SH_AnimShim   = _G._shAnimShim
_G.stealthGet    = function(n) return _G.SH_SyncGet(n) end
_G.SyncInt       = { _cache = {}, _data = nil }

-- Pre-warm: wait for sync table then stabilize accumulator
task.spawn(function()
    for _ = 1, 300 do
        if _G.SH_SyncAll() then break end
        task.wait(0.02)
    end
    local _pw_prev, _pw_same = -1, 0
    for _ = 1, 150 do
        if type(_G.SH_ScanAllPets) == "function" then
            pcall(_G.SH_ScanAllPets)
        else
            _G.SH_SyncAll()
        end
        local _pw_nc = tonumber(_G.SH_ScanNoChan) or -1
        if _pw_nc == 0 then break end
        if _pw_nc == _pw_prev then
            _pw_same = _pw_same + 1
            if _pw_same >= 3 then break end
        else
            _pw_same = 0
        end
        _pw_prev = _pw_nc
        task.wait(0.05)
    end
end)

_G.SH_GetSyncData = _G.SH_GetSyncData or function(plot)
    local plotName = type(plot) == "string" and plot or (plot and plot.Name)
    if not plotName then return nil end
    local Pkgs = game:GetService("ReplicatedStorage"):FindFirstChild("Packages")
    local Sync = Pkgs and Pkgs:FindFirstChild("Synchronizer")
    if not Sync then return nil end
    local okMod, mod = pcall(require, Sync)
    if not okMod or type(mod) ~= "table" then return nil end
    local okT, data = pcall(function() return _G.SH_RawCT(plotName) end)
    if okT and type(data) == "table" then return data end
    local okC, ch = pcall(function() return _G.SH_SyncGet(plotName) end)
    if okC and ch then
        local synth = { __channel = ch }
        pcall(function() local ct = rawget(ch, "CacheTable"); if type(ct) == "table" then synth.AnimalList = ct.AnimalList; synth.Owner = ct.Owner end end)
        return synth
    end
    return nil
end

-- Remote name update (hash-based resolution for post-patch remote renames)
local _REMOTE_HASH = _G.SH_RemoteHash or {
    ["UseItem"] = "068a62948a73ec6c61f9f22ada765e9fc2add9b70cb9e2da5732837444a3f862",
}
local _REMOTE_SUFFIX = { ["QuantumCloner/OnTeleport"] = "OnTeleport" }
local function _resolveByNetName(name)
    local pkgs = game:GetService("ReplicatedStorage"):FindFirstChild("Packages")
    local folder = pkgs and pkgs:FindFirstChild("Net")
    if not folder then return nil end
    local hash = _REMOTE_HASH[name]
    local suf = _REMOTE_SUFFIX[name]
    for _, d in ipairs(folder:GetDescendants()) do
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
            local dn = tostring(d.Name)
            if dn == name or (hash and dn == hash) then return d end
            if suf and (dn == suf or dn:sub(-#suf) == suf) then return d end
        end
    end
    if hash then
        local hit = folder:FindFirstChild(hash, true)
        if hit and (hit:IsA("RemoteEvent") or hit:IsA("RemoteFunction")) then return hit end
    end
    return nil
end
_G.SH_ResolveNetName = _resolveByNetName
_G.SH_SetRemoteHash = function(n, h) _REMOTE_HASH[tostring(n)] = tostring(h) end

-- Self-service remote dump
task.spawn(function()
    task.wait(tonumber(_G.SH_RemoteDumpDelay) or 5)
    pcall(function()
        local pkgs = game:GetService("ReplicatedStorage"):FindFirstChild("Packages")
        local folder = pkgs and pkgs:FindFirstChild("Net")
        if not folder then return end
        local names = {}
        for _, d in ipairs(folder:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
                names[#names + 1] = d.ClassName .. "  " .. tostring(d.Name)
            end
        end
        table.sort(names)
        if writefile then
            pcall(writefile, "SH_Remotes.txt",
                "Net remotes (" .. #names .. "):\n" .. table.concat(names, "\n"))
        end
    end)
end)

-- Modules loader + getRemote alias
local Synchronizer, AnimalsData, AnimalsShared, NumberUtils
local function loadModules()
    if AnimalsData then return true end
    pcall(function()
        local Datas = RS:FindFirstChild("Datas") or RS:WaitForChild("Datas", 5)
        if Datas then
            local a = Datas:FindFirstChild("Animals") or Datas:WaitForChild("Animals", 5)
            if a then AnimalsData = require(a) end
        end
    end)
    AnimalsShared = _G._shAnimShim
    if not NumberUtils then
        pcall(function()
            local Utils = RS:FindFirstChild("Utils")
            local n = Utils and Utils:FindFirstChild("NumberUtils")
            if n then NumberUtils = require(n) end
        end)
    end
    return AnimalsData ~= nil
end

local function getRemote(method, name)
    return _G.__secureGetRemote(method, name)
end
_G.SH_GetRemote = getRemote
end
-- ══ RAILTP ENGINE (velocity cruise) ══
do

local RailTP = {}

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local Workspace      = game:GetService("Workspace")
local LP             = Players.LocalPlayer

--============================================================================
-- CONFIG (plain KV file, not JSON)
--============================================================================
local CFG_PATH = "railtp.cfg"

local defaults = {
    cruise        = 480,
    approach      = 80,
    brakeRadius   = 60,
    arriveRadius  = 5.5,
    settleTime    = 0.22,
    hover         = 0,
    tickHz        = 60,
    maxAirTime    = 25,
}

local S = {}
for k,v in pairs(defaults) do S[k] = v end

local function _loadCfg()
    if type(readfile) ~= "function" or type(isfile) ~= "function" then return end
    if not isfile(CFG_PATH) then return end
    local raw = readfile(CFG_PATH)
    for line in tostring(raw):gmatch("[^\r\n]+") do
        local k, v = line:match("^([%w_]+)%s*=%s*(.+)$")
        if k and v and defaults[k] ~= nil then
            local n = tonumber(v)
            if n then S[k] = n end
        end
    end
end

local function _saveCfg()
    if type(writefile) ~= "function" then return end
    local buf = {}
    for k,v in pairs(S) do buf[#buf+1] = k .. "=" .. tostring(v) end
    pcall(writefile, CFG_PATH, table.concat(buf, "\n"))
end

_loadCfg()

--============================================================================
-- CHARACTER PLUMBING
--============================================================================
local char, hum, hrp
local att, mover, aligner

local function _charReady()
    char = LP.Character or LP.CharacterAdded:Wait()
    hum  = char:WaitForChild("Humanoid", 5)
    hrp  = char:WaitForChild("HumanoidRootPart", 5)
    return hum and hrp
end

local function _teardownMover()
    if att then pcall(function() att:Destroy() end); att = nil end
    if mover then pcall(function() mover:Destroy() end); mover = nil end
    if aligner then pcall(function() aligner:Destroy() end); aligner = nil end
end

local function _buildMover()
    _teardownMover()
    if not (hrp and hrp.Parent) then return false end
    att = Instance.new("Attachment")
    att.Name = "_rtp_anchor"
    att.Parent = hrp

    mover = Instance.new("LinearVelocity")
    mover.Name = "_rtp_drive"
    mover.Attachment0 = att
    mover.RelativeTo = Enum.ActuatorRelativeTo.World
    mover.ForceLimitMode = Enum.ForceLimitMode.PerAxis
    mover.MaxAxesForce = Vector3.new(2.5e5, 2.5e5, 2.5e5)
    mover.VectorVelocity = Vector3.zero
    mover.Enabled = false
    mover.Parent = hrp

    aligner = Instance.new("AlignOrientation")
    aligner.Name = "_rtp_face"
    aligner.Attachment0 = att
    aligner.Mode = Enum.OrientationAlignmentMode.OneAttachment
    aligner.Responsiveness = 40
    aligner.MaxTorque = 1e5
    aligner.Enabled = false
    aligner.Parent = hrp
    return true
end

--============================================================================
-- STATE
--============================================================================
local state = "idle"
local settleStartTs = 0
local target = nil
local arriveCbs = {}
local startTs = 0
local lastTickTs = 0
local activeConn

local function _pushArriveCb(fn) arriveCbs[#arriveCbs+1] = fn end
local function _flushArrive()
    local list = arriveCbs; arriveCbs = {}
    for _,fn in ipairs(list) do task.spawn(fn) end
end

--============================================================================
-- SCANNER
--============================================================================
local function _plotList()
    local out = {}
    for _,inst in ipairs(Workspace:GetChildren()) do
        if inst:IsA("Model") or inst:IsA("Folder") then
            local pods = inst:FindFirstChild("AnimalPodiums", true)
            if pods then out[#out+1] = {root = inst, pods = pods} end
        end
    end
    return out
end

local function _readOverheadName(podium)
    local main = podium:FindFirstChild("Main") or podium:FindFirstChild("Base")
    if not main then return nil end
    for _,d in ipairs(main:GetDescendants()) do
        if d:IsA("TextLabel") and d.Text and #d.Text > 0 then
            local t = d.Text
            if not t:find("%$") and not t:find("/s") and #t < 40 then
                return t
            end
        end
    end
    return nil
end

local function _podiumCFrame(podium)
    local base = podium:FindFirstChild("Base") or podium
    if base:IsA("BasePart") then return base.CFrame end
    local ok, cf = pcall(function() return podium:GetPivot() end)
    if ok then return cf end
    return nil
end

function RailTP.rescanPets()
    local out = {}
    for _,plot in ipairs(_plotList()) do
        for _,podium in ipairs(plot.pods:GetChildren()) do
            local cf   = _podiumCFrame(podium)
            local name = _readOverheadName(podium)
            if cf and name then
                out[#out+1] = {
                    plot = plot.root.Name,
                    slot = podium.Name,
                    name = name,
                    cf   = cf,
                }
            end
        end
    end
    return out
end

--============================================================================
-- CRUISE LOOP
--============================================================================
local function _stopLoop()
    if activeConn then pcall(function() activeConn:Disconnect() end); activeConn = nil end
    if mover then mover.VectorVelocity = Vector3.zero; mover.Enabled = false end
    if aligner then aligner.Enabled = false end
end

local _savedCollide = {}
local function _phaseOn()
    if not char then return end
    _savedCollide = {}
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BasePart") and d.CanCollide then
            _savedCollide[d] = true
            pcall(function() d.CanCollide = false end)
        end
    end
end
local function _phaseOff()
    for p, _ in pairs(_savedCollide) do
        if p and p.Parent then pcall(function() p.CanCollide = true end) end
    end
    _savedCollide = {}
end

local function _arriveNow()
    state = "arrived"
    _stopLoop()
    _phaseOff()
    if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Freefall) end) end
    _flushArrive()
    state = "idle"
    target = nil
end

local function _startLoop()
    _stopLoop()
    if not _buildMover() then return end
    if _G.TacoRailPhase ~= false then _phaseOn() end
    mover.Enabled = true
    aligner.Enabled = true
    startTs = os.clock()
    lastTickTs = startTs
    state = "cruising"

    settleStartTs = 0
    activeConn = RunService.Heartbeat:Connect(function()
        if not (hrp and hrp.Parent and target) then _arriveNow() return end
        if os.clock() - startTs > S.maxAirTime then _arriveNow() return end

        -- anti-die: keep character alive during cruise
        if _G.TacoRailAntiDie ~= false then
            local char = hrp.Parent
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                if hum.Health < hum.MaxHealth then
                    pcall(function() hum.Health = hum.MaxHealth end)
                end
                pcall(function() hum.BreakJointsOnDeath = false end)
                pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end)
                pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false) end)
                pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) end)
                pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false) end)
            end
            local voidY = tonumber(_G.TacoRailVoidFloor) or -400
            if hrp.Position.Y < voidY then
                pcall(function()
                    hrp.CFrame = CFrame.new(hrp.Position.X, target.Y + math.max(S.hover, 8), hrp.Position.Z)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                end)
            end
        end

        local aim   = target + Vector3.new(0, S.hover, 0)
        local here  = hrp.Position
        local delta = aim - here
        local dist  = delta.Magnitude

        -- settle phase: hold upright at target before firing arrive
        if state == "settling" then
            local settleDur = tonumber(_G.TacoSettleTime) or S.settleTime
            local pull = delta
            local pmag = pull.Magnitude
            if pmag > 0.05 then pull = pull / pmag * math.min(pmag * 6, 40) end
            mover.VectorVelocity = pull
            aligner.CFrame = CFrame.lookAt(here, Vector3.new(aim.X, here.Y, aim.Z))
            if os.clock() - settleStartTs >= settleDur then _arriveNow() end
            return
        end

        if dist <= S.arriveRadius then
            state = "settling"
            settleStartTs = os.clock()
            return
        end

        local speed
        if dist <= S.brakeRadius then
            state = "braking"
            local t = dist / S.brakeRadius
            speed = math.max(S.approach * (t * t), 25)
        else
            state = "cruising"
            speed = S.cruise
        end

        local dir = (dist > 0.001) and (delta / dist) or Vector3.zero
        mover.VectorVelocity = dir * speed
        aligner.CFrame = CFrame.lookAt(here, Vector3.new(aim.X, here.Y, aim.Z))
    end)
end

--============================================================================
-- PUBLIC API
--============================================================================
function RailTP.setCruise(v)        S.cruise = tonumber(v) or S.cruise; _saveCfg() end
function RailTP.setArrivalRadius(v) S.arriveRadius = tonumber(v) or S.arriveRadius; _saveCfg() end
function RailTP.setHover(v)         S.hover = tonumber(v) or S.hover; _saveCfg() end

function RailTP.state()    return state end
function RailTP.isActive() return state ~= "idle" and state ~= "arrived" end

function RailTP.onArrive(fn) if type(fn) == "function" then _pushArriveCb(fn) end end

function RailTP.release()
    _stopLoop()
    _phaseOff()
    _teardownMover()
    state = "idle"
    target = nil
end

function RailTP.cruiseTo(dest)
    if typeof(dest) == "CFrame" then dest = dest.Position end
    if typeof(dest) ~= "Vector3" then return false, "bad target" end
    if not _charReady() then return false, "no character" end
    target = dest
    state = "arming"
    _startLoop()
    return true
end

function RailTP.cruisePet(petName, plotName)
    local hits = RailTP.rescanPets()
    local want = tostring(petName or ""):lower()
    local best, bestScore
    for _,h in ipairs(hits) do
        if not plotName or h.plot == plotName then
            local n = h.name:lower()
            local score
            if n == want then score = 3
            elseif n:find(want, 1, true) then score = 2
            elseif want:find(n, 1, true) then score = 1
            end
            if score and (not bestScore or score > bestScore) then
                best, bestScore = h, score
            end
        end
    end
    if not best then return false, "no match" end
    return RailTP.cruiseTo(best.cf.Position)
end

-- character respawn hookup
task.spawn(function()
    while not LP do LP = Players.LocalPlayer; if not LP then task.wait(0.1) end end
    pcall(function()
        LP.CharacterAdded:Connect(function()
            task.wait(0.15)
            _charReady()
            if RailTP.isActive() and target then
                _startLoop()
            end
        end)
    end)
    _charReady()
end)

RailTP.getTarget = function() return target end

_G.RailTP = RailTP

end
-- ============================================================================
-- SECTION 4 — GRAPPLE, SCANNER & ESP ENGINES
-- ============================================================================
-- Engines:
--   1. Remote Name Update (hash table + resolver)
--   2. Grapple System (equip, fire, carpet engage)
--   3. Pet Position & World MPS (podium text reader with TTL cache)
--   4. Pet Ranking (_rankPets with priority/nearest/highest modes)
--   5. scanAllPets (workspace.Plots iterator + channel reader)
--   6. XRay ESP (BoxHandleAdornment with XRayShaded)
--   7. Pathfind ESP Line (beam between waypoints)
--   8. Scanner Warm + Cached scan
-- ============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

-- ============================================================================
-- ENGINE 1: Remote Name Update (hash table + resolver)
-- ============================================================================
do
    _G.SH_GetRemote = getRemote

    local _REMOTE_HASH = _G.SH_RemoteHash or {
        ["UseItem"] = "068a62948a73ec6c61f9f22ada765e9fc2add9b70cb9e2da5732837444a3f862",
    }
    local _REMOTE_SUFFIX = { ["QuantumCloner/OnTeleport"] = "OnTeleport" }

    local function _resolveByNetName(name)
        local pkgs = RS:FindFirstChild("Packages")
        local folder = pkgs and pkgs:FindFirstChild("Net")
        if not folder then return nil end
        local hash = _REMOTE_HASH[name]
        local suf = _REMOTE_SUFFIX[name]
        for _, d in ipairs(folder:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
                local dn = tostring(d.Name)
                if dn == name or (hash and dn == hash) then return d end
                if suf and (dn == suf or dn:sub(-#suf) == suf) then return d end
            end
        end
        if hash then
            local hit = folder:FindFirstChild(hash, true)
            if hit and (hit:IsA("RemoteEvent") or hit:IsA("RemoteFunction")) then return hit end
        end
        return nil
    end
    _G.SH_ResolveNetName = _resolveByNetName

    _G.SH_SetRemoteHash = function(n, h) _REMOTE_HASH[tostring(n)] = tostring(h) end

    -- Dump current Net remote names to file on boot
    task.spawn(function()
        task.wait(tonumber(_G.SH_RemoteDumpDelay) or 5)
        pcall(function()
            local pkgs = RS:FindFirstChild("Packages")
            local folder = pkgs and pkgs:FindFirstChild("Net")
            if not folder then return end
            local names = {}
            for _, d in ipairs(folder:GetDescendants()) do
                if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent") then
                    names[#names + 1] = d.ClassName .. "  " .. tostring(d.Name)
                end
            end
            table.sort(names)
            if writefile then
                pcall(writefile, "SH_Remotes.txt",
                    "Net remotes (" .. #names .. "):\n" .. table.concat(names, "\n"))
            end
            if _G.SH_Log then pcall(_G.SH_Log, "NET_REMOTES", { count = #names }) end
        end)
    end)
end

-- ============================================================================
-- ENGINE 2: Grapple System (equip, fire, carpet engage)
-- ============================================================================
do
    local GRAPPLE_ARG = 0.8
    local CARPET_SPEED = 280
    local CARPET_NAMES = { "Flying Carpet", "Waverider", "Santa's Sleigh", "Witch's Broom", "Cupid's Wings" }
    local GRAPPLE_NAMES = { "Grapple Hook", "Grappling Hook", "Grapple", "Hook", "Web Slinger", "Grapple Gun", "GrappleHook" }

    local _grappleUseItem, _grappleItemUse
    task.spawn(function() _grappleUseItem = getRemote("RemoteEvent", "UseItem") or _G.SH_ResolveNetName("UseItem") end)
    task.spawn(function() _grappleItemUse = getRemote("RemoteEvent", "75c9466d-e4c0-4b02-b26a-c3615fcc1e42") end)

    local _grappleRemoteGet
    do
        local _netFolder, _ordCache, _ordNextTry = nil, nil, 0

        local function _net()
            if _netFolder and _netFolder.Parent then return _netFolder end
            local pkgs = RS:FindFirstChild("Packages")
            _netFolder = pkgs and pkgs:FindFirstChild("Net")
            return _netFolder
        end

        local function _learnIndex(remote)
            if not remote then return end
            local folder = _net()
            if not folder or remote.Parent ~= folder then return end
            local kids = folder:GetChildren()
            for i = 1, #kids do
                if kids[i] == remote then _G.SH_NetUseItemIndex = i return end
            end
        end

        local function _ordinalRemote()
            if _ordCache and _ordCache.Parent then return _ordCache end
            if os.clock() < _ordNextTry then return nil end
            _ordNextTry = os.clock() + 0.5
            local folder = _net()
            if not folder then return nil end
            local kid = folder:GetChildren()[tonumber(_G.SH_NetUseItemIndex) or 6]
            if kid and kid:IsA("RemoteEvent") then _ordCache = kid return kid end
            return nil
        end
        _G.SH_NetOrdinalRemote = _ordinalRemote

        _grappleRemoteGet = function()
            local r = (_grappleUseItem and _grappleUseItem.Parent and _grappleUseItem)
                or (_grappleItemUse and _grappleItemUse.Parent and _grappleItemUse)
                or getRemote("RemoteEvent", "UseItem")
                or _G.SH_ResolveNetName("UseItem")
            if r then _learnIndex(r) return r end
            return _ordinalRemote()
        end
    end
    _G.SH_GrappleRemote = _grappleRemoteGet

    local function _grappleReady()
        local char = LP.Character
        if not char or not char:IsDescendantOf(workspace) then return false end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp or not hrp.Parent then return false end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return false end
        local voidY = tonumber(_G.SH_VoidY) or -50
        if hrp.Position.Y < voidY then return false end
        if hrp.AssemblyLinearVelocity.Y < -(tonumber(_G.SH_GrappleFallVel) or 150) then return false end
        return true
    end
    _G.SH_GrappleReady = _grappleReady

    local function _fireGrapple()
        if not _grappleReady() then return false end
        local fired = false
        if _grappleUseItem and _grappleUseItem.Parent then
            local ok = pcall(function() _grappleUseItem:FireServer(GRAPPLE_ARG) end)
            fired = fired or ok
        end
        if _grappleItemUse and _grappleItemUse.Parent then
            local ok = pcall(function() _grappleItemUse:FireServer(GRAPPLE_ARG) end)
            fired = fired or ok
        end
        if not fired then
            local r = _grappleRemoteGet()
            if r then
                local ok = pcall(function() r:FireServer(GRAPPLE_ARG) end)
                fired = fired or ok
            end
        end
        return fired
    end
    _G.SH_FireGrappleBoth = _fireGrapple

    local function findTool(name)
        local char = LP.Character
        local bp = LP:FindFirstChild("Backpack")
        return (char and char:FindFirstChild(name)) or (bp and bp:FindFirstChild(name))
    end

    local function findGrapple()
        for _, n in ipairs(GRAPPLE_NAMES) do
            local t = findTool(n)
            if t and t:IsA("Tool") then return t, n end
        end
        return nil
    end

    local function fireGrapple()
        local char = LP.Character
        if not char then return false end
        if not char:FindFirstChild("Grapple Hook") then
            local bp = LP:FindFirstChild("Backpack")
            local tool = bp and bp:FindFirstChild("Grapple Hook")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if tool and hum then pcall(function() hum:EquipTool(tool) end) end
        end
        if not char:FindFirstChild("Grapple Hook") then return false end
        local ok = _fireGrapple()
        local tries = 0
        while not ok and tries < 2 do
            tries = tries + 1
            task.wait(0.05)
            if not (LP.Character and LP.Character:FindFirstChild("Grapple Hook")) then break end
            ok = _fireGrapple()
        end
        return ok
    end
    _G.SH_FireGrapple = fireGrapple

    -- Carpet equip & engage
    local _lastCarpetName = nil
    local function equipCarpet()
        local char = LP.Character
        if not char then return nil end
        if _lastCarpetName then
            local t = char:FindFirstChild(_lastCarpetName)
            if t and t.Parent == char then return _lastCarpetName end
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return nil end
        for _, n in ipairs(CARPET_NAMES) do
            local t = findTool(n)
            if t and t:IsA("Tool") then
                if t.Parent ~= char then pcall(function() hum:EquipTool(t) end) end
                _lastCarpetName = n
                return n
            end
        end
        return nil
    end

    local function setCarpetTool(name)
        if type(name) ~= "string" or name == "" then return end
        _G.SH_CarpetTool = name
        for i = #CARPET_NAMES, 1, -1 do
            if CARPET_NAMES[i] == name then table.remove(CARPET_NAMES, i) end
        end
        table.insert(CARPET_NAMES, 1, name)
    end
    _G.SH_SetCarpetTool = setCarpetTool
    if type(_G.SH_CarpetTool) == "string" and _G.SH_CarpetTool ~= "" then
        setCarpetTool(_G.SH_CarpetTool)
    end

    local _carpetEngaging = false
    local function carpetEngage(force)
        if not force then
            local c = LP.Character
            if c then
                for _, n in ipairs(CARPET_NAMES) do
                    local t = c:FindFirstChild(n)
                    if t and t:IsA("Tool") then
                        _G.NeegyRailState = "rail@" .. tostring(n)
                        return n
                    end
                end
            end
        end
        if _carpetEngaging then
            local _tw = os.clock()
            repeat RunService.Heartbeat:Wait() until (not _carpetEngaging) or os.clock() - _tw > 6
            local c = LP.Character
            if c then
                for _, n in ipairs(CARPET_NAMES) do
                    local t = c:FindFirstChild(n)
                    if t and t:IsA("Tool") then return n end
                end
            end
        end
        _carpetEngaging = true
        -- Instant grapple fire before tool equip round-trip
        if _G.SH_InstantGrapple ~= false then pcall(_fireGrapple) end
        local _t0 = os.clock()
        while not findTool("Grapple Hook") and os.clock() - _t0 < 5 do
            RunService.Heartbeat:Wait()
        end
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum then _carpetEngaging = false; return nil end

        if not char:FindFirstChild("Grapple Hook") then
            local g = findTool("Grapple Hook")
            if g then pcall(function() hum:EquipTool(g) end) end
        end
        local _te = os.clock()
        while not (LP.Character and LP.Character:FindFirstChild("Grapple Hook")) and os.clock() - _te < 1.5 do
            local c = LP.Character
            local h2 = c and c:FindFirstChildOfClass("Humanoid")
            local g = findTool("Grapple Hook")
            if g and h2 then pcall(function() h2:EquipTool(g) end) end
            RunService.Heartbeat:Wait()
        end
        if LP.Character and LP.Character:FindFirstChild("Grapple Hook") then
            local _gok = _fireGrapple()
            local _gTries = 0
            while not _gok and _gTries < 2 do
                _gTries = _gTries + 1
                task.wait(0.05)
                if not (LP.Character and LP.Character:FindFirstChild("Grapple Hook")) then break end
                _gok = _fireGrapple()
            end
        end
        task.wait(0.05)
        local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:UnequipTools() end) end
        task.wait(0.05)
        local cn
        local _tc = os.clock()
        repeat
            cn = equipCarpet()
            local c = LP.Character
            if cn and c and c:FindFirstChild(cn) then break end
            RunService.Heartbeat:Wait()
        until os.clock() - _tc > 0.5
        _G.NeegyRailState = "rail@" .. tostring(cn)
        _carpetEngaging = false
        return cn
    end

    _G.SH_EquipCarpet = equipCarpet
    _G.SH_CarpetEngaging = function() return _carpetEngaging end

    -- Keep carpet on respawn
    if _G.SH_KeepCarpet == nil then _G.SH_KeepCarpet = true end
    LP.CharacterAdded:Connect(function(c)
        _G._SH_NeedsSpawnGuard = true
        _G._SH_SpawnPos = nil
        _G._SH_SpawnAt = os.clock()
        task.spawn(function()
            local hrp = c:WaitForChild("HumanoidRootPart", 10)
            if hrp then _G._SH_SpawnPos = hrp.Position end
        end)
    end)
    if _G._SH_SpawnAt == nil then _G._SH_SpawnAt = os.clock() end

    -- Disarm spawn guard on drift or timeout
    task.spawn(function()
        while true do
            task.wait(0.15)
            if _G._SH_NeedsSpawnGuard and _G._SH_SpawnPos then
                local c = LP.Character
                local hrp = c and c:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local drift = (hrp.Position - _G._SH_SpawnPos).Magnitude
                    if drift > (tonumber(_G.SH_SpawnGuardDriftDisarm) or 50) then
                        _G._SH_NeedsSpawnGuard = false
                    end
                end
            end
            if _G._SH_NeedsSpawnGuard and _G._SH_SpawnAt then
                if os.clock() - _G._SH_SpawnAt > (tonumber(_G.SH_SpawnGuardTimeDisarm) or 3) then
                    _G._SH_NeedsSpawnGuard = false
                end
            end
        end
    end)

    LP.CharacterAdded:Connect(function(c)
        if _G.SH_KeepCarpet == false then return end
        task.spawn(function()
            c:WaitForChild("Humanoid", 10)
            task.wait(tonumber(_G.SH_CarpetRespawnDelay) or 0.6)
            if _G.SH_KeepCarpet == false then return end
            if _carpetEngaging or LP.Character ~= c then return end
            if LP:GetAttribute("Stealing") == true then return end
            for _, n in ipairs(CARPET_NAMES) do
                if c:FindFirstChild(n) then return end
            end
            pcall(equipCarpet)
        end)
    end)

    -- Fire grapple on spawn
    if _G.SH_GrappleOnSpawn == nil then _G.SH_GrappleOnSpawn = true end

    local function _fireGrappleAggressive()
        local c = LP.Character
        if not c then return false end
        local fired = false
        if _grappleUseItem and _grappleUseItem.Parent then
            fired = pcall(function() _grappleUseItem:FireServer(GRAPPLE_ARG) end) or fired
        end
        if _grappleItemUse and _grappleItemUse.Parent then
            fired = pcall(function() _grappleItemUse:FireServer(GRAPPLE_ARG) end) or fired
        end
        local r = _grappleRemoteGet()
        if r and r.Parent then
            fired = pcall(function() r:FireServer(GRAPPLE_ARG) end) or fired
        end
        for _, name in ipairs({"Grapple Hook","Grappling Hook","Grapple","Hook","GrappleHook","Web Slinger","Grapple Gun"}) do
            local t = c:FindFirstChild(name)
            if t and t:IsA("Tool") then
                pcall(function() t:Activate() end)
                fired = true
            end
        end
        return fired
    end
    _G.SH_FireGrappleAggressive = _fireGrappleAggressive

    local function _grappleOnSpawn(char)
        if _G.SH_GrappleOnSpawn == false or not char then return end
        task.spawn(function()
            local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)
            if not hum or LP.Character ~= char then return end
            local d = tonumber(_G.SH_GrappleOnSpawnDelay) or 0
            if d > 0 then task.wait(d) end
            local t0 = os.clock()
            local cap = tonumber(_G.SH_GrappleOnSpawnWait) or 8
            while os.clock() - t0 < cap do
                if _G.SH_GrappleOnSpawn == false or LP.Character ~= char then return end
                if LP:GetAttribute("Stealing") == true then return end
                local _ready = false
                if type(_G.SH_ToolsReady) == "function" then
                    local ok, r = pcall(_G.SH_ToolsReady)
                    _ready = ok and r == true
                end
                if not _ready and findTool("Grapple Hook") then _ready = true end
                if _ready then break end
                RunService.Heartbeat:Wait()
            end
            if LP.Character ~= char then return end
            if LP:GetAttribute("Stealing") == true then return end
            if _G.SH_GrappleWaitReady == true then
                local _rt = os.clock()
                while os.clock() - _rt < (tonumber(_G.SH_GrappleReadyWait) or 6) do
                    if _G.SH_GrappleOnSpawn == false or LP.Character ~= char then return end
                    if type(_G.SH_GrappleReady) ~= "function" or _G.SH_GrappleReady() then break end
                    RunService.Heartbeat:Wait()
                end
            end
            local _ok = fireGrapple()
            local _tries = 0
            while not _ok and _tries < 6 do
                _tries = _tries + 1
                RunService.Heartbeat:Wait()
                if _G.SH_GrappleOnSpawn == false or LP.Character ~= char then return end
                _ok = fireGrapple()
            end
            if _ok and _G.SH_GrappleOnSpawnHold ~= false then
                local _hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                if _hrp then pcall(function()
                    _hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    _hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end) end
            end
        end)
    end
    _G.SH_GrappleOnSpawnNow = function() _grappleOnSpawn(LP.Character) end
    if LP.Character then _grappleOnSpawn(LP.Character) end
    LP.CharacterAdded:Connect(_grappleOnSpawn)
end

-- ============================================================================
-- ENGINE 3: Pet Position & World MPS (podium text reader with TTL cache)
-- ============================================================================
do
    local _MPS_SUFFIX = { K = 1e3, M = 1e6, B = 1e9, T = 1e12, Q = 1e15 }
    local _wmpsCache, _wmpsAt = {}, {}
    local _petModelCache = setmetatable({}, { __mode = "v" })
    local _petPosCache = {}

    local function _worldMPS(plot, slot)
        local podiums = plot and plot:FindFirstChild("AnimalPodiums")
        local podium = podiums and podiums:FindFirstChild(tostring(slot))
        if not podium then return nil end
        local _ck = plot.Name .. "\0" .. tostring(slot)
        local _now = os.clock()
        if _wmpsAt[_ck] and (_now - _wmpsAt[_ck]) < (tonumber(_G.SH_WorldMPSTTL) or 1) then
            return _wmpsCache[_ck]
        end
        local best = nil
        for _, d in ipairs(podium:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                local txt = d.Text
                if type(txt) == "string" and txt ~= "" then
                    local num, suf = txt:match("%$%s*([%d%.]+)%s*([KMBTQ]?)%s*/s")
                    if num then
                        local v = tonumber(num)
                        if v then
                            v = v * (_MPS_SUFFIX[suf] or 1)
                            if not best or v > best then best = v end
                        end
                    end
                end
            end
        end
        _wmpsCache[_ck], _wmpsAt[_ck] = best, _now
        return best
    end
    _G._SH_WorldMPS = _worldMPS

    local function _getPetPositionUncached(plot, slot, strict)
        local podiums = plot:FindFirstChild("AnimalPodiums")
        if not podiums then return nil end
        local podium = podiums:FindFirstChild(tostring(slot))
        if not podium then return nil end
        local key = plot.Name .. "\0" .. tostring(slot)
        local cached = _petModelCache[key]
        if cached and cached.Parent and cached:IsDescendantOf(podium) then
            local ok, cf = pcall(function() return cached:GetBoundingBox() end)
            if ok then return cf.Position end
        end
        _petModelCache[key] = nil
        for _, desc in ipairs(podium:GetDescendants()) do
            if desc:IsA("Model") and desc.Name ~= "Claim" and desc.Name ~= "Base" and desc.Name ~= "Decorations" then
                if desc:FindFirstChildWhichIsA("MeshPart", true) then
                    local ok, cf = pcall(function() return desc:GetBoundingBox() end)
                    if ok then
                        _petModelCache[key] = desc
                        return cf.Position
                    end
                end
            end
        end
        if strict then return nil end
        local ok, cf = pcall(function() return podium:GetPivot() end)
        if ok then return cf.Position end
        return podium.Position
    end

    local function getPetPosition(plot, slot, strict)
        if not plot then return nil end
        local key = plot.Name .. "\0" .. tostring(slot) .. "\0" .. (strict and "1" or "0")
        local pc = _petPosCache[key]
        local now = os.clock()
        if pc and (now - pc.t) < (tonumber(_G.SH_PetPosTTL) or 2.5) then
            return pc.pos
        end
        local pos = _getPetPositionUncached(plot, slot, strict)
        _petPosCache[key] = { pos = pos, t = now }
        return pos
    end
    _G.SH_InvalidatePetPos = function() _petPosCache = {} end
    _G._SH_GetPetPosition = getPetPosition
    _G._SH_WorldMPSFn = _worldMPS
end

-- ============================================================================
-- ENGINE 4: Pet Ranking (_rankPets with priority/nearest/highest modes)
-- ============================================================================
do
    local PET_PRIORITY_TIERS, TIER_LOOKUP = {}, {}
    do
        local PET_TIER_SPEC = {
            { 0, "Headless Horseman" },
            { 0, "Signore Carapace" },
            { 0, "John Pork" },
            { 0, "Strawberry Elephant" },
            { 5e9, "Arcadragon" },
            { 10e9, "Elefanto Frigo" },
            { 5e9, "Meowl" },
            { 5e9, "Skibidi Toilet" },
            { 0, "Love Love Bear" },
            { 0, "Antonio" },
            { 0, "Pancake and Syrup" },
            { 0, "Griffin" },
            { 5e9, "Globa Steppa","La Supreme Combinasion","Fishino Clownino","Dragon Gingerini","Tirilikalika Tirilikalako" },
            { 10e9, "Ginger Gerat","Pet" },
            { 3e9, "Hydra Bunny","Digi Narwhal","Kalika Bros" },
            { 3e9, "Hydra Dragon Cannelloni","Dragon Cannelloni","Bunny and Eggy" },
            { 3e9, "Ketupat Bros","Rosey and Teddy","La Casa Boo","Fragola la la" },
            { 1e9, "Fragola La La La","Cerberus","Guest 666","Los Hackers" },
            { 750e6, "Garama and Madunung","Spooky and Pumpky","Reinito Sleighito","Burguro And Fryuro","Cooki and Milki","Fragrama and Chocrama","La Food Combinasion","Los Amigos","Foxini Lanternini","Capitano Moby","Fortunu and Cashuru","Los Sekolahs","Celestial Pegasus" },
            { 1e9, "La Secret Combinasion","Sammyni Fattini","Cloverat Clapat","Popcuru and Fizzuru" },
        }
        for tier, row in ipairs(PET_TIER_SPEC) do
            local names = table.move(row, 2, #row, 1, {})
            PET_PRIORITY_TIERS[tier] = { pets = names, threshold = row[1] }
            for _, petName in ipairs(names) do TIER_LOOKUP[petName] = tier end
        end
    end

    local function _normName(s)
        return tostring(s):lower():gsub("[^%w]", "")
    end

    local _priCacheVer, _priCache = -1, {}
    local function _priLookup()
        local ver = _G.SH_PriVersion or 0
        local plist = _G.SHARED_PRIORITY_ITEMS
        local n = (type(plist) == "table") and #plist or 0
        if _priCacheVer ~= ver or (n > 0 and next(_priCache) == nil) then
            table.clear(_priCache)
            if type(plist) == "table" then
                for i = #plist, 1, -1 do _priCache[_normName(plist[i])] = i end
            end
            _priCacheVer = ver
        end
        return _priCache
    end
    _G.SH_PriLookup = _priLookup

    local function _rankPets(pets)
        if type(pets) ~= "table" then return {} end
        local _priLk = _priLookup()
        for _, p in ipairs(pets) do
            p._pri = _priLk[_normName(p.name)] or (p.index and _priLk[_normName(p.index)]) or nil
        end
        local function _tie(a, b)
            local pa, pb = tostring(a.plot), tostring(b.plot)
            if pa ~= pb then return pa < pb end
            return (tonumber(a.slot) or 0) < (tonumber(b.slot) or 0)
        end
        local mode = _G.SH_StealMode
        if mode == "highest" then
            table.sort(pets, function(a, b)
                local ma, mb = (a.mps or 0), (b.mps or 0)
                if ma ~= mb then return ma > mb end
                return _tie(a, b)
            end)
            return pets
        end
        if mode == "nearest" then
            local _hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            local _myPos = _hrp and _hrp.Position
            if _myPos then
                table.sort(pets, function(a, b)
                    local da = a.position and (a.position - _myPos).Magnitude or math.huge
                    local db = b.position and (b.position - _myPos).Magnitude or math.huge
                    if da ~= db then return da < db end
                    return _tie(a, b)
                end)
            end
            return pets
        end
        if _G.SH_PriorityStrict == true then
            local only = {}
            for _, p in ipairs(pets) do
                if p._pri ~= nil then only[#only + 1] = p end
            end
            table.sort(only, function(a, b)
                local ia, ib = a._pri, b._pri
                if ia ~= ib then return ia < ib end
                local ma, mb = tonumber(a.mps) or 0, tonumber(b.mps) or 0
                if ma ~= mb then return ma > mb end
                return _tie(a, b)
            end)
            return only
        end
        table.sort(pets, function(a, b)
            local ia, ib = a._pri, b._pri
            if (ia ~= nil) ~= (ib ~= nil) then return ia ~= nil end
            if ia and ib and ia ~= ib then return ia < ib end
            local ma, mb = tonumber(a.mps) or 0, tonumber(b.mps) or 0
            if ma ~= mb then return ma > mb end
            return _tie(a, b)
        end)
        return pets
    end
    _G.SH_RankPets = _rankPets
    _G._SH_NormName = _normName
end

-- ============================================================================
-- ENGINE 5: scanAllPets (workspace.Plots iterator + channel reader)
-- ============================================================================
do
    local _genCache = {}

    local function getPlotChannel(plotName)
        local channel
        pcall(function() channel = _G.SH_SyncGet(plotName) end)
        return channel
    end

    local function channelGet(channel, key)
        if not channel then return nil end
        local v
        pcall(function()
            local ct = rawget(channel, "CacheTable")
            if type(ct) == "table" then v = ct[key] end
        end)
        if v ~= nil then return v end
        pcall(function()
            local d = rawget(channel, "Data")
            if type(d) == "table" then v = d[key] end
        end)
        if v ~= nil then return v end
        pcall(function() v = rawget(channel, key) end)
        return v
    end

    local function isMyPlot(channel)
        if not channel then return false end
        local owner = channelGet(channel, "Owner")
        if not owner then return false end
        local result = false
        pcall(function()
            if typeof(owner) == "Instance" and owner:IsA("Player") then
                result = owner.UserId == LP.UserId
            elseif type(owner) == "table" and owner.UserId then
                result = owner.UserId == LP.UserId
            elseif typeof(owner) == "Instance" then
                result = owner == LP
            elseif type(owner) == "string" then
                result = owner:lower() == LP.Name:lower()
                    or owner:lower() == (LP.DisplayName or LP.Name):lower()
            end
        end)
        return result
    end

    local function ownerInGame(channel)
        if not channel then return false end
        local owner = channelGet(channel, "Owner")
        if not owner then return false end
        local inGame = false
        pcall(function()
            if typeof(owner) == "Instance" and owner:IsA("Player") then
                inGame = Players:FindFirstChild(owner.Name) ~= nil
            elseif type(owner) == "number" then
                inGame = Players:GetPlayerByUserId(owner) ~= nil
            elseif type(owner) == "table" and owner.Name then
                inGame = Players:FindFirstChild(tostring(owner.Name)) ~= nil
            elseif typeof(owner) == "Instance" and owner.Name then
                inGame = Players:FindFirstChild(owner.Name) ~= nil
            elseif type(owner) == "string" then
                if Players:FindFirstChild(owner) then
                    inGame = true
                else
                    local lo = owner:lower()
                    for _, pl in ipairs(Players:GetPlayers()) do
                        if pl.Name:lower() == lo or (pl.DisplayName or ""):lower() == lo then inGame = true break end
                    end
                end
            end
        end)
        return inGame
    end

    local function scanAllPets()
        local pets = {}
        if not loadModules() then return pets end
        local Plots = workspace:FindFirstChild("Plots")
        if not Plots then return pets end
        local _plotTotal, _plotNoChan = 0, 0
        for _, plot in ipairs(Plots:GetChildren()) do
            local channel = getPlotChannel(plot.Name)
            _plotTotal = _plotTotal + 1
            if not channel then _plotNoChan = _plotNoChan + 1; continue end
            if isMyPlot(channel) then continue end
            if _G.SH_RequireOwner == true and not ownerInGame(channel) then continue end
            local animalList = channelGet(channel, "AnimalList")
            if not animalList then continue end
            for slot, animalData in pairs(animalList) do
                if type(animalData) ~= "table" then continue end
                local animalName = animalData.Index
                if not animalName then continue end
                local animalInfo = AnimalsData and AnimalsData[animalName]
                if not animalInfo and _G.SH_RequireKnown == true then continue end
                if _SH_IsFusing and _SH_IsFusing(animalData) then continue end
                local mutation = animalData.Mutation or "None"
                local genValue
                local _gk = plot.Name .. "\0" .. tostring(slot)
                local _gc = _genCache[_gk]
                if _gc and _gc.n == animalName and _gc.m == animalData.Mutation and _gc.t == animalData.Traits then
                    genValue = _gc.g
                else
                    genValue = 0
                    pcall(function()
                        genValue = AnimalsShared:GetGeneration(animalName, animalData.Mutation, animalData.Traits, nil)
                    end)
                    if genValue and genValue > 0 then
                        _genCache[_gk] = { n = animalName, m = animalData.Mutation, t = animalData.Traits, g = genValue }
                    end
                end
                if (not genValue or genValue <= 0) and _G.SH_WorldMPS ~= false then
                    local wm = _G._SH_WorldMPS and _G._SH_WorldMPS(plot, slot)
                    if wm and wm > 0 then genValue = wm end
                end
                local displayName = (animalInfo and animalInfo.DisplayName) or animalName
                local pos = _G._SH_GetPetPosition and _G._SH_GetPetPosition(plot, slot, (_G.SH_RequireOwner == false) or (_G.SH_RequireModel == true))
                if pos then
                    if genValue >= (tonumber(_G.SH_MinMPS) or 0) then
                        table.insert(pets, {
                            name = displayName,
                            index = animalName,
                            mps = genValue,
                            mutation = mutation,
                            position = pos,
                            plot = plot.Name,
                            slot = tostring(slot),
                        })
                    end
                end
            end
        end
        _G.SH_ScanNoChan = _plotNoChan
        _G.SH_ScanTotal  = _plotTotal
        _G.SH_ScanUsed   = _plotTotal - _plotNoChan
        return _G.SH_RankPets(pets)
    end
    _G.SH_ScanAllPets = scanAllPets
end

-- ============================================================================
-- ENGINE 6: XRay ESP (BoxHandleAdornment with XRayShaded)
-- ============================================================================
do
    if _G.SH_Xray == nil then _G.SH_Xray = true end
    local _xf
    local _boxes = {}

    local function _ensure()
        if _xf and _xf.Parent then return end
        _xf = Instance.new("Folder"); _xf.Name = "SH_XrayESP"; _xf.Parent = workspace
    end

    local function _clearAll()
        if _xf then pcall(function() _xf:Destroy() end) end
        _xf = nil; table.clear(_boxes)
    end

    task.spawn(function()
        task.wait(tonumber(_G.SH_XrayBootWait) or 8)
        while true do
            task.wait(tonumber(_G.SH_XrayGap) or 0.75)
            if _G.SH_Xray == false then
                if _xf then _clearAll() end
            elseif _G.SH_TPActive and _G.SH_XrayPauseOnTP ~= false then
                -- Skip scan while TP is flying
            else
                local ok, pets = pcall(_G.SH_ScanAllPets)
                if ok and type(pets) == "table" then
                    _ensure()
                    local seen = {}
                    for _, p in ipairs(pets) do
                        if p and p.position then
                            local uid = tostring(p.plot) .. "_" .. tostring(p.slot)
                            seen[uid] = true
                            local b = _boxes[uid]
                            if not (b and b.anchor and b.anchor.Parent) then
                                local anchor = Instance.new("Part")
                                anchor.Anchored = true; anchor.CanCollide = false
                                anchor.CanQuery = false; anchor.CanTouch = false
                                anchor.Transparency = 1; anchor.Size = Vector3.one
                                anchor.Parent = _xf
                                local a = Instance.new("BoxHandleAdornment")
                                a.Adornee = anchor; a.AlwaysOnTop = true; a.ZIndex = 0
                                pcall(function() a.Shading = Enum.AdornShading.XRayShaded end)
                                local _sz = tonumber(_G.SH_XraySize) or 4.5
                                a.Size = Vector3.new(_sz, _sz, _sz)
                                a.Transparency = tonumber(_G.SH_XrayTransp) or 0.5
                                a.Parent = anchor
                                b = { anchor = anchor, adorn = a }; _boxes[uid] = b
                            end
                            pcall(function() b.anchor.CFrame = CFrame.new(p.position) end)
                            pcall(function() b.adorn.Color3 = _G.SH_XrayColor or Color3.fromRGB(255, 255, 255) end)
                        end
                    end
                    for uid, b in pairs(_boxes) do
                        if not seen[uid] then
                            pcall(function() b.anchor:Destroy() end); _boxes[uid] = nil
                        end
                    end
                end
            end
        end
    end)
end

-- ============================================================================
-- ENGINE 7: Pathfind ESP Line (beam between waypoints)
-- ============================================================================
do
    if _G.SH_ESPLineOn == nil then _G.SH_ESPLineOn = false end
    local COL_LINE = Color3.fromRGB(244, 227, 161)

    local _segments = {}
    local _dots     = {}
    local _cycleID  = 0

    local function _makeAnchor(name)
        local p = Instance.new("Part")
        p.Name = name; p.Size = Vector3.new(0.05,0.05,0.05)
        p.Anchored = true; p.CanCollide = false
        p.Transparency = 1; p.CastShadow = false
        p.Parent = workspace; return p
    end

    local function _clearAll()
        for _, seg in ipairs(_segments) do
            pcall(function() seg.beam:Destroy()    end)
            pcall(function() seg.att0:Destroy()    end)
            pcall(function() seg.att1:Destroy()    end)
            pcall(function() seg.anchorA:Destroy() end)
            pcall(function() seg.anchorB:Destroy() end)
        end
        _segments = {}
        for _, d in ipairs(_dots) do pcall(function() d:Destroy() end) end
        _dots = {}
    end

    local function _makeDot(pos, sz)
        local d = Instance.new("Part")
        d.Name = "SH_ESPDot"; d.Shape = Enum.PartType.Ball
        d.Size = Vector3.new(sz,sz,sz)
        d.Anchored = true; d.CanCollide = false; d.CastShadow = false
        d.Material = Enum.Material.Neon; d.Color = COL_LINE; d.Transparency = 0
        d.CFrame = CFrame.new(pos); d.Parent = workspace; return d
    end

    local function _makeSegment(i, posA, posB)
        local ancA = _makeAnchor("SH_ESPA"..i)
        local ancB = _makeAnchor("SH_ESPB"..i)
        pcall(function() ancA.CFrame = CFrame.new(posA) end)
        pcall(function() ancB.CFrame = CFrame.new(posB) end)
        local att0 = Instance.new("Attachment")
        att0.Position = Vector3.new(0,0,0); att0.Parent = ancA
        local att1 = Instance.new("Attachment")
        att1.Position = Vector3.new(0,0,0); att1.Parent = ancB
        local beam = Instance.new("Beam")
        beam.Name = "SH_ESPBeam"
        beam.Attachment0 = att0; beam.Attachment1 = att1
        beam.FaceCamera = true; beam.LightEmission = 1; beam.LightInfluence = 0
        beam.Color = ColorSequence.new(COL_LINE)
        beam.Transparency = NumberSequence.new(0)
        beam.Width0 = 0.75; beam.Width1 = 0.75
        beam.TextureMode = Enum.TextureMode.Wrap; beam.TextureSpeed = 0
        beam.Segments = 6; beam.Parent = workspace
        _segments[#_segments+1] = {anchorA=ancA,anchorB=ancB,att0=att0,att1=att1,beam=beam}
    end

    local function _drawRoute(waypoints)
        _clearAll()
        local N = waypoints and #waypoints or 0
        if N < 2 then return end
        for i = 1, N do
            local sz = (i == 1 or i == N) and 0.55 or 0.35
            _dots[#_dots+1] = _makeDot(waypoints[i], sz)
        end
        for i = 1, N - 1 do
            _makeSegment(i, waypoints[i], waypoints[i+1])
        end
    end

    local function _showBeams()
        for _, seg in ipairs(_segments) do
            pcall(function() seg.beam.Transparency = NumberSequence.new(0) end)
        end
    end

    _G._SH_TPBeamDraw = function(waypoints, cycleId)
        if _G.SH_ESPLineOn == false then return end
        _cycleID = cycleId
        pcall(_drawRoute, waypoints)
    end

    _G._SH_TPBeamHide = function(cycleId)
        if cycleId and cycleId ~= _cycleID then return end
        _cycleID = 0
        _clearAll()
    end

    _G._SH_TPBeamCycleID = 0

    RunService.Heartbeat:Connect(function()
        if _G.SH_ESPLineOn == false then
            if _cycleID ~= 0 then _clearAll(); _cycleID = 0 end
            return
        end
        if _cycleID == 0 or #_segments == 0 then return end
        _showBeams()
    end)
end

-- ============================================================================
-- ENGINE 8: Scanner Warm + Cached scan
-- ============================================================================
do
    local _scanShared, _scanSharedAt = nil, 0
    local _stableTopUid = nil

    local function scanAllPetsCached(maxAge)
        local now = os.clock()
        if _scanShared and (now - _scanSharedAt) <= (tonumber(maxAge) or 0.15) then
            return _scanShared
        end
        local ok, p = pcall(_G.SH_ScanAllPets)
        if ok and type(p) == "table" then
            _scanShared, _scanSharedAt = p, now
            return p
        end
        return nil
    end
    _G.SH_ScanCached = scanAllPetsCached

    local function neegyRailScan()
        local full = _G.SH_ScanAllPets()
        if type(full) ~= "table" then full = {} end
        if _G.SH_ScanTiered then
            local ok, tiered = pcall(_G.SH_ScanTiered)
            if ok and type(tiered) == "table" and #tiered > 0 then
                local seen = {}
                for _, p in ipairs(full) do
                    if p and p.plot and p.slot ~= nil then
                        seen[tostring(p.plot) .. "_" .. tostring(p.slot)] = true
                    end
                end
                for _, p in ipairs(tiered) do
                    if p and p.plot and p.slot ~= nil then
                        local uid = tostring(p.plot) .. "_" .. tostring(p.slot)
                        if not seen[uid] then
                            seen[uid] = true
                            full[#full + 1] = p
                        end
                    end
                end
                full = _G.SH_RankPets(full)
            end
        end
        -- Top-stability anti-flicker
        if _G.SH_TopStable ~= false and type(full) == "table" and #full > 0 then
            local _nt
            for _, p in ipairs(full) do if not p.conveyor then _nt = p break end end
            if _nt then
                local _ntUid = tostring(_nt.plot) .. "_" .. tostring(_nt.slot)
                if _stableTopUid and _ntUid ~= _stableTopUid then
                    local _rem
                    for _, p in ipairs(full) do
                        if not p.conveyor and (tostring(p.plot) .. "_" .. tostring(p.slot)) == _stableTopUid then
                            _rem = p; break
                        end
                    end
                    if _rem then
                        local _ip, _in = _rem._pri, _nt._pri
                        local _better
                        if _in ~= nil and _ip == nil then
                            _better = true
                        elseif _in ~= nil and _ip ~= nil then
                            _better = _in < _ip
                        elseif _in == nil and _ip ~= nil then
                            _better = false
                        else
                            local _m = tonumber(_G.SH_TopHysteresis) or 0.15
                            _better = (tonumber(_nt.mps) or 0) > (tonumber(_rem.mps) or 0) * (1 + _m)
                        end
                        if not _better then
                            for _i, _p in ipairs(full) do
                                if _p == _rem then
                                    if _i ~= 1 then
                                        table.remove(full, _i)
                                        table.insert(full, 1, _rem)
                                    end
                                    break
                                end
                            end
                            _ntUid = _stableTopUid
                        end
                    end
                end
                _stableTopUid = _ntUid
            end
        end
        return full
    end
    _G.SH_ScanForTP = neegyRailScan

    -- Scanner warm: background poll until caches are hot
    task.spawn(function()
        if _G.SH_ScanWarm == false then return end
        pcall(loadModules)
        local t0 = os.clock()
        while os.clock() - t0 < (tonumber(_G.SH_ScanWarmWait) or 25) do
            local ok, pets = pcall(neegyRailScan)
            if ok and pets and #pets > 0 then
                if _G.SH_Log then pcall(_G.SH_Log, "SCAN_WARM", { pets = #pets, t = math.floor((os.clock() - t0) * 1000) }) end
                break
            end
            task.wait(tonumber(_G.SH_ScanWarmGap) or 0.02)
        end
    end)

    local function _petUid(p)
        if not p then return nil end
        return tostring(p.plot) .. "_" .. tostring(p.slot)
    end
    _G._SH_PetUid = _petUid
end
-- ============================================================
-- SECTION 5: CONFIG SYSTEM v2 + UI FRAMEWORK (Silence Hub)
-- ============================================================
-- This section contains:
--   - Services & globals
--   - SH_DEFAULTS + SH_SCHEMA (with neegy keys)
--   - Config system v2 (load/save/validate/migrate/proxy)
--   - Toggle restore
--   - GUI creation (ScreenGui, main frame, gold LED animation)
--   - Drag, top bar, nav bar, content frame
--   - Tab system (with Neegy tab)
--   - UI helpers: mkSection, mkToggle, mkSlider, mkButton, mkKeybind
-- ============================================================

task.wait(math.random(50, 250) / 1000)
task.spawn(function()

local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local Stats=game:GetService("Stats")
local HttpService=game:GetService("HttpService")
local LP=Players.LocalPlayer
local PG=LP:WaitForChild("PlayerGui")

-- DEFAULTS
_G.TPVelocity=58.0; _G.MynxxClimb=58.0; _G.MynxxCloseSpeed=42.0 -- PATCHED v4: reduced to avoid server velocity detection
_G.MynxxBrainrotSpeed=48.0; _G.SKY_CLONE_WAIT=0.35; _G.TPCloneDelay=0.35 -- PATCHED v4: reduced speeds
_G.MynxxAutoTP=true; _G.MynxxStealMode="priority"
_G.MynxxSettleMaxMs=400; _G.MynxxStallSec=1.2; _G.MynxxTPStop=false -- PATCHED v4: longer settle = fewer retries
local KEYBINDS={manualTP=Enum.KeyCode.T,toggleUI=Enum.KeyCode.LeftControl,instaReset=Enum.KeyCode.X,rejoinJob=Enum.KeyCode.K,rejoinPs=Enum.KeyCode.J,kick=Enum.KeyCode.P}

-- ============================================================
-- INSTA RESET ENGINE
-- ============================================================
do
    local _CAM_BIND_IR = "SH_IR_" .. tostring(math.random(1e5,9e5))
    local _resetting   = false
    local FLING_POWER  = 50000
    local FLING_TIME   = 0.4
    local USE_VOID     = true
    local VOID_TIME    = 0.6
    local TIMEOUT      = 6

    local RS  = game:GetService("RunService")
    local UIS_ir = game:GetService("UserInputService")

    local function _hideLocally(obj)
        if obj:IsA("BasePart") or obj:IsA("Decal") then
            obj.LocalTransparencyModifier = 1
        end
    end

    local function _instaReset()
        if _resetting then return end
        local lp   = game:GetService("Players").LocalPlayer
        local char = lp.Character
        if not char or not char.Parent then return end
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end
        local hrp  = hum.RootPart or char:FindFirstChild("HumanoidRootPart")
        _resetting = true

        task.spawn(function()
            local cam      = workspace.CurrentCamera
            local frozen   = cam.CFrame
            local old_type = cam.CameraType
            pcall(function()
                cam.CameraType = Enum.CameraType.Scriptable
                RS:BindToRenderStep(_CAM_BIND_IR, Enum.RenderPriority.Camera.Value + 1, function()
                    cam.CFrame = frozen
                end)
            end)

            local added
            pcall(function()
                for _, obj in ipairs(char:GetDescendants()) do pcall(_hideLocally, obj) end
                added = char.DescendantAdded:Connect(function(obj) pcall(_hideLocally, obj) end)
            end)

            local new_char
            local respawned = lp.CharacterAdded:Connect(function(c) new_char = c end)

            local function unlock()
                pcall(function() hum.PlatformStand = false end)
                pcall(function() hum.Sit           = false end)
                pcall(function() hum.AutoRotate    = true  end)
            end
            unlock()

            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("BasePart") then
                    pcall(function() obj.Anchored    = false end)
                    pcall(function() obj.CanCollide  = false end)
                elseif obj.Name == "SeatWeld" then
                    pcall(function() obj:Destroy() end)
                end
            end

            local started = os.clock()
            local function alive_hrp()
                if hrp and hrp.Parent then return hrp end
                hrp = hum.RootPart or char:FindFirstChild("HumanoidRootPart")
                return (hrp and hrp.Parent) and hrp or nil
            end

            local fling_until = os.clock() + FLING_TIME
            while not new_char and os.clock() < fling_until and hum.Parent do
                unlock()
                pcall(function() hum.HipHeight = 1e30 end)
                local root = alive_hrp()
                if root then
                    pcall(function() root.Anchored = false end)
                    pcall(function() root.AssemblyLinearVelocity = Vector3.new(0, FLING_POWER, 0) end)
                    pcall(function() root.Velocity               = Vector3.new(0, FLING_POWER, 0) end)
                end
                RS.Heartbeat:Wait()
            end

            if USE_VOID and not new_char then
                local floor = -500
                pcall(function() floor = workspace.FallenPartsDestroyHeight end)
                local void_until = os.clock() + VOID_TIME
                while not new_char and os.clock() < void_until do
                    local root = alive_hrp()
                    if not root then break end
                    pcall(function() root.CFrame = CFrame.new(0, floor - 500, 0) end)
                    pcall(function() root.AssemblyLinearVelocity = Vector3.new(0, -FLING_POWER, 0) end)
                    RS.Heartbeat:Wait()
                end
            end

            while not new_char and os.clock() - started < TIMEOUT do
                if hum.Parent then
                    pcall(function() hum.Health = 0 end)
                    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Dead) end)
                end
                if char.Parent then pcall(function() char:BreakJoints() end) end
                task.wait(0.1)
            end

            pcall(function() respawned:Disconnect() end)
            if added then pcall(function() added:Disconnect() end) end
            pcall(function() RS:UnbindFromRenderStep(_CAM_BIND_IR) end)
            pcall(function()
                cam.CameraType = old_type == Enum.CameraType.Scriptable
                    and Enum.CameraType.Custom or old_type
                if new_char then
                    local new_hum = new_char:FindFirstChildOfClass("Humanoid")
                        or new_char:WaitForChild("Humanoid", 5)
                    if new_hum then cam.CameraSubject = new_hum end
                end
            end)
            _resetting = false
        end)
    end

    -- Expose globally for panel and keybind listeners
    _G.SH_InstaReset = _instaReset
end

-- ============================================================
-- SILENCE HUB — CONFIG SYSTEM v2 (PRODUCTION)
-- ============================================================

local CONFIG_FILE = "SilenceHub_Config.json"

-- Canonical defaults — single source of truth
local SH_DEFAULTS = {
    -- TP numerics
    tpVelocity    = 58.0, -- PATCHED v4
    climbSpeed    = 157.14,
    closeSpeed    = 68.72,
    brainrotSpeed = 64.04,
    cloneDelay    = 0.2,
    settleMaxMs   = 250,
    stallSec      = 0.6,
    carpetSpeedVal= 140,
    -- TP strings / booleans
    autoTp        = true,
    stealMode     = "priority",
    manualTPKey   = "T",
    espMinRate    = "4M",
    -- Toggles
    brainrotESP   = false,
    lineToBase    = false,
    baseOwnerESP  = false,
    baseTimerESP  = false,
    boxESP        = false,
    stealRadius   = 95,
    autoGrabHz    = 83,
    autoGrab      = false,
    infJump       = false,
    xray          = false,
    antiRagdoll   = false,
    autoKick      = false,
    invisPanel    = false,
    agPanel       = false,
    actionPanel   = false,
    playerESP     = false,
    loaderScreen  = true,
    fpsBoost      = false,
    fpsGateEnabled = false,
    fpsGateMin     = 30,
    antiFlasher   = false,
    openOnStart   = true,
    carpetSpeed   = false,
    stealPanel    = false,
    adminPanel    = false,
    autoBuy       = false,
    autoBuyKey    = "B",
    kickToPS      = false,
    kickPsCode    = "",
    uiLocked      = false,
    walkSpeedOn   = false,
    walkSpeedVal  = 16,
    uiPositions   = {},
    -- Taco TP
    neegyCruise    = 500,
    tacoClimb      = 200,
    tacoCloseSpeed = 400,
    landingDelay   = 0.15,
    tacoStealHold  = 1.3,
    tacoCommitRange= 30,
    tacoStealMode  = "priority",
    activeTPEngine = 1,
    -- Neegy features
    railCruise       = 480,
    railApproach     = 80,
    railBrakeRadius  = 60,
    railArriveRadius = 5.5,
    railHover        = 0,
    faceAway         = false,
    faceAwayOwner    = false,
    baseXray         = true,
    baseXrayAlpha    = 0.9,
    hideCollect      = true,
    flightNoclip     = true,
    antiDie          = false,
    espLine          = false,
    petXray          = true,
    stealHold        = 1.3,
    stealCommitRange = 28,
    priorityStrict   = false,
}

-- Type schema — used by validator
local SH_SCHEMA = {
    tpVelocity    = "number",
    climbSpeed    = "number",
    closeSpeed    = "number",
    brainrotSpeed = "number",
    cloneDelay    = "number",
    settleMaxMs   = "number",
    stallSec      = "number",
    carpetSpeedVal= "number",
    autoTp        = "boolean",
    stealMode     = "string",
    manualTPKey   = "string",
    espMinRate    = "string",
    brainrotESP   = "boolean",
    lineToBase    = "boolean",
    baseOwnerESP  = "boolean",
    baseTimerESP  = "boolean",
    autoGrab      = "boolean",
    infJump       = "boolean",
    xray          = "boolean",
    antiRagdoll   = "boolean",
    autoKick      = "boolean",
    invisPanel    = "boolean",
    carpetSpeed   = "boolean",
    stealPanel    = "boolean",
    adminPanel    = "boolean",
    autoBuy       = "boolean",
    autoBuyKey    = "string",
    kickToPS      = "boolean",
    kickPsCode    = "string",
    uiLocked      = "boolean",
    walkSpeedOn   = "boolean",
    walkSpeedVal  = "number",
    uiPositions   = "table",
    fpsGateEnabled = "boolean",
    fpsGateMin     = "number",
    neegyCruise    = "number",
    tacoClimb      = "number",
    tacoCloseSpeed = "number",
    landingDelay   = "number",
    tacoStealHold  = "number",
    tacoCommitRange= "number",
    tacoStealMode  = "string",
    activeTPEngine = "number",
    -- Neegy features
    railCruise       = "number",
    railApproach     = "number",
    railBrakeRadius  = "number",
    railArriveRadius = "number",
    railHover        = "number",
    faceAway         = "boolean",
    faceAwayOwner    = "boolean",
    baseXray         = "boolean",
    baseXrayAlpha    = "number",
    hideCollect      = "boolean",
    flightNoclip     = "boolean",
    antiDie          = "boolean",
    espLine          = "boolean",
    petXray          = "boolean",
    stealHold        = "number",
    stealCommitRange = "number",
    priorityStrict   = "boolean",
}

-- File system availability — probed with retry on startup
local SH_FS_OK = false

local function _probeFS()
    for attempt = 1, 3 do
        local ok = pcall(function()
            if type(readfile)  ~= "function" then error("no readfile")  end
            if type(writefile) ~= "function" then error("no writefile") end
            if type(isfile)    ~= "function" then error("no isfile")    end
        end)
        if ok then
            SH_FS_OK = true
            print("[CONFIG] File system: OK (attempt " .. attempt .. ")")
            return true
        end
        if attempt < 3 then task.wait(0.5) end
    end
    print("[CONFIG] File system: unavailable — running on defaults only")
    return false
end

-- Deep-copy defaults into a fresh table
local function _cloneDefaults()
    local t = {}
    for k, v in pairs(SH_DEFAULTS) do
        t[k] = (type(v) == "table") and {} or v
    end
    return t
end

-- Validate a single value against schema; return default on failure
local function _validateKey(key, value)
    local expected = SH_SCHEMA[key]
    if not expected then return value end  -- unknown key: pass through
    if type(value) ~= expected then
        print("[CONFIG] Error: key '" .. key .. "' expected " .. expected .. ", got " .. type(value) .. " — reset to default")
        return SH_DEFAULTS[key]
    end
    return value
end

-- Migrate legacy config format (keys with _ prefix and "Auto Grab" toggle key)
-- to the new flat key format (autoGrab, tpVelocity, etc.)
local LEGACY_KEY_MAP = {
    _tpVelocity    = "tpVelocity",
    _climbSpeed    = "climbSpeed",
    _closeSpeed    = "closeSpeed",
    _brainrotSpeed = "brainrotSpeed",
    _cloneDelay    = "cloneDelay",
    _autoTp        = "autoTp",
    _stealMode     = "stealMode",
    _espMinRate    = "espMinRate",
    _lineToBase    = "lineToBase",
    _carpetSpeedVal= "carpetSpeedVal",
    _manualTPKey   = "manualTPKey",
    _settleMaxMs   = "settleMaxMs",
    _stallSec      = "stallSec",
}
-- Toggle names used as keys in the old JSON format
local LEGACY_TOGGLE_MAP = {
    ["Brainrot ESP"]          = "brainrotESP",
    ["Line To Base"]          = "lineToBase",
    ["Base Owner ESP"]        = "baseOwnerESP",
    ["Base Timer ESP"]        = "baseTimerESP",
    ["Auto Grab"]             = "autoGrab",
    ["Inf Jump"]              = "infJump",
    ["XRay"]                  = "xray",
    ["Anti Ragdoll"]          = "antiRagdoll",
    ["Auto Kick on Steal"]    = "autoKick",
    ["Invisible Steal Panel"] = "invisPanel",
}

local function _migrateRaw(raw)
    if type(raw) ~= "table" then return raw end
    local changed = false
    for oldKey, newKey in pairs(LEGACY_KEY_MAP) do
        if raw[oldKey] ~= nil and raw[newKey] == nil then
            raw[newKey] = raw[oldKey]
            raw[oldKey] = nil
            changed = true
        end
    end
    for oldKey, newKey in pairs(LEGACY_TOGGLE_MAP) do
        if raw[oldKey] ~= nil and raw[newKey] == nil then
            raw[newKey] = raw[oldKey]
            raw[oldKey] = nil
            changed = true
        end
    end
    if changed then
        print("[CONFIG] Migrated legacy config format to v2 keys")
    end
    return raw
end

-- Validate entire loaded table; fill missing keys from defaults; reset corrupt values
local function _validateConfig(raw)
    if type(raw) ~= "table" then
        print("[CONFIG] Error: config is not a table — using defaults")
        return _cloneDefaults()
    end
    -- Migrate old-format keys before validation
    raw = _migrateRaw(raw)
    local out = _cloneDefaults()
    for k, _ in pairs(SH_DEFAULTS) do
        if raw[k] ~= nil then
            if k == "uiPositions" then
                -- preserve as-is if it's a table, else keep default {}
                out[k] = (type(raw[k]) == "table") and raw[k] or {}
            else
                out[k] = _validateKey(k, raw[k])
            end
        end
        -- missing keys already filled by _cloneDefaults()
    end
    return out
end

-- Apply a validated config table to all _G globals
local function _applyToGlobals(cfg)
    _G.TPVelocity         = cfg.tpVelocity
    _G.MynxxClimb         = cfg.climbSpeed
    _G.MynxxCloseSpeed    = cfg.closeSpeed
    _G.MynxxBrainrotSpeed = cfg.brainrotSpeed
    _G.SKY_CLONE_WAIT     = cfg.cloneDelay
    _G.TPCloneDelay       = cfg.cloneDelay
    _G.MynxxAutoTP        = cfg.autoTp
    _G.MynxxStealMode     = cfg.stealMode
    _G.MynxxSettleMaxMs   = cfg.settleMaxMs
    _G.MynxxStallSec      = cfg.stallSec
    _G.SH_ESPMinRate      = cfg.espMinRate
    _G.SH_LineToBase      = cfg.lineToBase
    _G.SH_CarpetSpeedOn   = cfg.carpetSpeed
    _G.SH_CarpetSpeedVal  = cfg.carpetSpeedVal
    _G.SH_FPSGateEnabled   = cfg.fpsGateEnabled == true
    _G.SH_FPSGateMin       = math.max(1, math.floor(cfg.fpsGateMin or 30))
    if cfg.manualTPKey then
        local ok2, kc = pcall(function() return Enum.KeyCode[cfg.manualTPKey] end)
        if ok2 and kc then KEYBINDS.manualTP = kc end
    end
    if cfg.uiLocked ~= nil then _G.SH_UIsLocked = cfg.uiLocked end
    -- Walkspeed in Invis Panel Engine setzen
    if cfg.walkSpeedOn ~= nil then _G.InvisWalkSpeedEnabled = cfg.walkSpeedOn end
    if cfg.walkSpeedVal then _G.InvisWalkSpeed = cfg.walkSpeedVal end
    if cfg.openOnStart ~= nil and _G.SH_Config then
        _G.SH_Config.openOnStart = cfg.openOnStart
    end
    if cfg.cloneKey then
        local ok3, kc3 = pcall(function() return Enum.KeyCode[cfg.cloneKey] end)
        if ok3 and kc3 then
            task.spawn(function()
                local t=0
                while not _G.SH_setCloneKey and t<10 do task.wait(0.3);t=t+0.3 end
                if _G.SH_setCloneKey then pcall(_G.SH_setCloneKey,kc3) end
            end)
        end
    end
    -- Neegy globals
    if cfg.railCruise       ~= nil then _G.RailCruise         = cfg.railCruise       end
    if cfg.railApproach     ~= nil then _G.RailApproach       = cfg.railApproach     end
    if cfg.railBrakeRadius  ~= nil then _G.RailBrakeRadius    = cfg.railBrakeRadius  end
    if cfg.railArriveRadius ~= nil then _G.RailArriveRadius   = cfg.railArriveRadius end
    if cfg.railHover        ~= nil then _G.RailHover          = cfg.railHover        end
    if cfg.faceAway         ~= nil then _G.FaceAway           = cfg.faceAway         end
    if cfg.faceAwayOwner    ~= nil then _G.FaceAwayOwner      = cfg.faceAwayOwner    end
    if cfg.baseXray         ~= nil then _G.BaseXray           = cfg.baseXray         end
    if cfg.baseXrayAlpha    ~= nil then _G.BaseXrayAlpha      = cfg.baseXrayAlpha    end
    if cfg.hideCollect      ~= nil then _G.HideCollect        = cfg.hideCollect      end
    if cfg.flightNoclip     ~= nil then _G.FlightNoclip       = cfg.flightNoclip     end
    if cfg.antiDie          ~= nil then _G.AntiDie            = cfg.antiDie          end
    if cfg.espLine          ~= nil then _G.ESPLine            = cfg.espLine          end
    if cfg.petXray          ~= nil then _G.PetXray            = cfg.petXray          end
    if cfg.stealHold        ~= nil then _G.StealHold          = cfg.stealHold        end
    if cfg.stealCommitRange ~= nil then _G.StealCommitRange   = cfg.stealCommitRange end
    if cfg.priorityStrict   ~= nil then _G.PriorityStrict     = cfg.priorityStrict   end
end

-- Internal raw table (not directly exposed — writes go through metatable proxy)
local _SH_ConfigRaw = _cloneDefaults()

-- Snapshot dirty flag — true when _SH_ConfigRaw has unsaved changes
local _SH_ConfigDirty = false

-- loadConfig — reads file, validates, applies, returns success bool
local function loadConfig()
    if not SH_FS_OK then
        print("[CONFIG] Loaded (defaults — no file system)")
        _applyToGlobals(_SH_ConfigRaw)
        return false
    end
    local fileExists = pcall(function()
        if not isfile(CONFIG_FILE) then error("missing") end
    end)
    if not fileExists then
        -- First run: write defaults to disk
        local ok = pcall(function()
            writefile(CONFIG_FILE, HttpService:JSONEncode(_SH_ConfigRaw))
        end)
        if ok then
            print("[CONFIG] Loaded (first run — defaults written to disk)")
        else
            print("[CONFIG] Error: could not write default config to disk")
        end
        _applyToGlobals(_SH_ConfigRaw)
        return false
    end
    -- Read & decode
    local raw, readErr
    local readOk = pcall(function()
        raw = readfile(CONFIG_FILE)
    end)
    if not readOk or type(raw) ~= "string" or #raw == 0 then
        print("[CONFIG] Error: could not read config file — using defaults")
        _applyToGlobals(_SH_ConfigRaw)
        return false
    end
    local decoded, decodeErr
    local decodeOk = pcall(function()
        decoded = HttpService:JSONDecode(raw)
    end)
    if not decodeOk then
        print("[CONFIG] Error: malformed JSON in config — using defaults")
        _applyToGlobals(_SH_ConfigRaw)
        return false
    end
    -- Validate + fill missing keys
    local validated = _validateConfig(decoded)
    -- Write back to _SH_ConfigRaw
    for k, v in pairs(validated) do _SH_ConfigRaw[k] = v end
    _applyToGlobals(_SH_ConfigRaw)
    print("[CONFIG] Loaded")
    return true
end

-- saveConfig — flushes current _SH_ConfigRaw to disk (task.spawn safe)
local function saveConfig()
    if not SH_FS_OK then return end
    -- Snapshot current _G values into raw table before writing
    _SH_ConfigRaw.tpVelocity    = (type(_G.TPVelocity)         == "number")  and _G.TPVelocity         or _SH_ConfigRaw.tpVelocity
    _SH_ConfigRaw.climbSpeed    = (type(_G.MynxxClimb)         == "number")  and _G.MynxxClimb         or _SH_ConfigRaw.climbSpeed
    _SH_ConfigRaw.closeSpeed    = (type(_G.MynxxCloseSpeed)    == "number")  and _G.MynxxCloseSpeed    or _SH_ConfigRaw.closeSpeed
    _SH_ConfigRaw.brainrotSpeed = (type(_G.MynxxBrainrotSpeed) == "number")  and _G.MynxxBrainrotSpeed or _SH_ConfigRaw.brainrotSpeed
    _SH_ConfigRaw.cloneDelay    = (type(_G.SKY_CLONE_WAIT)     == "number")  and _G.SKY_CLONE_WAIT     or _SH_ConfigRaw.cloneDelay
    _SH_ConfigRaw.settleMaxMs   = (type(_G.MynxxSettleMaxMs)   == "number")  and _G.MynxxSettleMaxMs   or _SH_ConfigRaw.settleMaxMs
    _SH_ConfigRaw.stallSec      = (type(_G.MynxxStallSec)      == "number")  and _G.MynxxStallSec      or _SH_ConfigRaw.stallSec
    _SH_ConfigRaw.carpetSpeedVal= (type(_G.SH_CarpetSpeedVal)  == "number")  and _G.SH_CarpetSpeedVal  or _SH_ConfigRaw.carpetSpeedVal
    _SH_ConfigRaw.fpsGateEnabled = (_G.SH_FPSGateEnabled == true)
    _SH_ConfigRaw.fpsGateMin     = (type(_G.SH_FPSGateMin) == "number") and math.max(1, math.floor(_G.SH_FPSGateMin)) or _SH_ConfigRaw.fpsGateMin
    _SH_ConfigRaw.autoTp        = (type(_G.MynxxAutoTP)        == "boolean") and _G.MynxxAutoTP        or _SH_ConfigRaw.autoTp
    _SH_ConfigRaw.stealMode     = (type(_G.MynxxStealMode)     == "string")  and _G.MynxxStealMode     or _SH_ConfigRaw.stealMode
    _SH_ConfigRaw.espMinRate    = (type(_G.SH_ESPMinRate)      == "string")  and _G.SH_ESPMinRate      or _SH_ConfigRaw.espMinRate
    _SH_ConfigRaw.lineToBase    = (_G.SH_LineToBase    == true)
    _SH_ConfigRaw.adminPanel    = (_G.SH_Config and _G.SH_Config.adminPanel == true) or false
    _SH_ConfigRaw.carpetSpeed   = (_G.SH_CarpetSpeedOn == true)
    _SH_ConfigRaw.carpetTool    = (type(_G.MynxxCarpetTool) == "string" and _G.MynxxCarpetTool ~= "") and _G.MynxxCarpetTool or _SH_ConfigRaw.carpetTool
    if _SH_ConfigRaw.openOnStart == nil then _SH_ConfigRaw.openOnStart = true end -- behalte was gesetzt wurde
    _SH_ConfigRaw.autoGrab      = (_G.SH_Config and _G.SH_Config.autoGrab == true) or (_SH_ConfigRaw.autoGrab == true) or false
    if KEYBINDS and KEYBINDS.manualTP then
        _SH_ConfigRaw.manualTPKey = KEYBINDS.manualTP.Name
    end
    -- Taco TP settings
    _SH_ConfigRaw.neegyCruise    = (type(_G.NeegyCruise)           =="number") and _G.NeegyCruise           or _SH_ConfigRaw.neegyCruise
    _SH_ConfigRaw.tacoClimb      = (type(_G.TacoClimb)             =="number") and _G.TacoClimb             or _SH_ConfigRaw.tacoClimb
    _SH_ConfigRaw.tacoCloseSpeed = (type(_G.TacoCloseSpeed)        =="number") and _G.TacoCloseSpeed        or _SH_ConfigRaw.tacoCloseSpeed
    _SH_ConfigRaw.landingDelay   = (type(_G.LandingDelay)          =="number") and _G.LandingDelay          or _SH_ConfigRaw.landingDelay
    _SH_ConfigRaw.tacoStealHold  = (type(_G.TacoStealHoldDuration) =="number") and _G.TacoStealHoldDuration or _SH_ConfigRaw.tacoStealHold
    _SH_ConfigRaw.tacoCommitRange= (type(_G.TacoStealCommitRange)  =="number") and _G.TacoStealCommitRange  or _SH_ConfigRaw.tacoCommitRange
    _SH_ConfigRaw.tacoStealMode  = (type(_G.TacoStealMode)         =="string") and _G.TacoStealMode         or _SH_ConfigRaw.tacoStealMode
    if type(_G._SH_activeTPEngine)=="number" then _SH_ConfigRaw.activeTPEngine=_G._SH_activeTPEngine end
    -- Neegy settings sync
    _SH_ConfigRaw.railCruise       = (type(_G.RailCruise)       =="number")  and _G.RailCruise       or _SH_ConfigRaw.railCruise
    _SH_ConfigRaw.railApproach     = (type(_G.RailApproach)     =="number")  and _G.RailApproach     or _SH_ConfigRaw.railApproach
    _SH_ConfigRaw.railBrakeRadius  = (type(_G.RailBrakeRadius)  =="number")  and _G.RailBrakeRadius  or _SH_ConfigRaw.railBrakeRadius
    _SH_ConfigRaw.railArriveRadius = (type(_G.RailArriveRadius) =="number")  and _G.RailArriveRadius or _SH_ConfigRaw.railArriveRadius
    _SH_ConfigRaw.railHover        = (type(_G.RailHover)        =="number")  and _G.RailHover        or _SH_ConfigRaw.railHover
    _SH_ConfigRaw.faceAway         = (_G.FaceAway         == true)
    _SH_ConfigRaw.faceAwayOwner    = (_G.FaceAwayOwner    == true)
    _SH_ConfigRaw.baseXray         = (_G.BaseXray         == true)
    _SH_ConfigRaw.baseXrayAlpha    = (type(_G.BaseXrayAlpha)    =="number")  and _G.BaseXrayAlpha    or _SH_ConfigRaw.baseXrayAlpha
    _SH_ConfigRaw.hideCollect      = (_G.HideCollect      == true)
    _SH_ConfigRaw.flightNoclip     = (_G.FlightNoclip     == true)
    _SH_ConfigRaw.antiDie          = (_G.AntiDie          == true)
    _SH_ConfigRaw.espLine          = (_G.ESPLine          == true)
    _SH_ConfigRaw.petXray          = (_G.PetXray          == true)
    _SH_ConfigRaw.stealHold        = (type(_G.StealHold)        =="number")  and _G.StealHold        or _SH_ConfigRaw.stealHold
    _SH_ConfigRaw.stealCommitRange = (type(_G.StealCommitRange) =="number")  and _G.StealCommitRange or _SH_ConfigRaw.stealCommitRange
    _SH_ConfigRaw.priorityStrict   = (_G.PriorityStrict   == true)
    -- WalkSpeed sync
    pcall(function()
        local ws = _G.WalkSpeedState
        if ws then
            _SH_ConfigRaw.walkSpeedOn  = ws.enabled or false
            _SH_ConfigRaw.walkSpeedVal = ws.speed   or 16
        end
    end)
    local ok = pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(_SH_ConfigRaw))
    end)
    if ok then
        _SH_ConfigDirty = false
        print("[CONFIG] Saved")
    else
        print("[CONFIG] Error: writefile failed")
    end
end

-- Metatable proxy — SH_Config[key] = value auto-persists via __newindex
local SH_Config = setmetatable({}, {
    __index = function(_, key)
        return _SH_ConfigRaw[key]
    end,
    __newindex = function(_, key, value)
        -- Validate type before storing
        local validated = _validateKey(key, value)
        _SH_ConfigRaw[key] = validated
        _SH_ConfigDirty = true
        -- Async write — never blocks the caller
        task.spawn(saveConfig)
    end,
    __pairs = function(_)
        return pairs(_SH_ConfigRaw)
    end,
})
_G.SH_Config = SH_Config

-- Boot sequence: synchron laden damit _SH_ConfigRaw befüllt ist
-- bevor die GUI openOnStart liest
_probeFS()
loadConfig()

-- Periodic auto-save every 5s (catches _G mutations that bypass the proxy)
-- v12: checks _G.__SH_Dead so the old loop exits on re-inject after hop
local _SH_AutoSaveId = (_G.__SH_AutoSaveId or 0) + 1
_G.__SH_AutoSaveId = _SH_AutoSaveId
task.spawn(function()
    while _G.__SH_AutoSaveId == _SH_AutoSaveId do
        task.wait(5)
        if _G.__SH_AutoSaveId ~= _SH_AutoSaveId then break end
        pcall(saveConfig)
    end
end)

-- Expose save/load globally so UI code can call them directly
_G.SH_SaveConfig = saveConfig
_G.SH_LoadConfig = loadConfig

-- Compat shim: legacy UI code calls saveSettings() — route it through the proxy flush
local function saveSettings()
    pcall(saveConfig)
end

-- ============================================================
-- TOGGLE RESTORE — waits for GUI ready, then re-applies saved states
-- ============================================================
task.spawn(function()
    local t = 0
    while not _G.SH_GUI_Ready and t < 30 do
        task.wait(0.1); t = t + 0.1
    end
    if not _G.SH_GUI_Ready then
        print("[CONFIG] Error: GUI timeout — toggle restore skipped")
        return
    end

    -- Re-read from disk to get the freshest state (GUI may have taken >0.5s to load)
    local cfg = _SH_ConfigRaw

    if SH_FS_OK and pcall(function()
        if isfile(CONFIG_FILE) then
            local fresh = HttpService:JSONDecode(readfile(CONFIG_FILE))
            cfg = _validateConfig(fresh)
        end
    end) then end  -- silent — cfg already set above on success

    local function setToggleVisual(name, on)
        local ts = _G.TOGGLE_STATES or {}
        if ts[name] then pcall(ts[name].set, on) end
    end

    local function waitAndActivate(name, checkFn, activateFn, timeoutSec)
        timeoutSec = timeoutSec or 15
        setToggleVisual(name, true)
        task.spawn(function()
            local elapsed = 0
            while not checkFn() and elapsed < timeoutSec do
                task.wait(0.3); elapsed = elapsed + 0.3
            end
            if checkFn() then
                local ok2 = pcall(activateFn)
                if ok2 then
                    print("[CONFIG] Restored: " .. name)
                else
                    setToggleVisual(name, false)
                    print("[CONFIG] Error: engine failed for " .. name)
                end
            else
                setToggleVisual(name, false)
                print("[CONFIG] Error: timeout waiting for " .. name)
            end
        end)
    end

    if cfg.brainrotESP == true then
        waitAndActivate("Brainrot ESP",
            function() return _G._SH_StartESP ~= nil end,
            function() _G._SH_StartESP() end)
    end

    if cfg.lineToBase == true then
        _G.SH_LineToBase = true
        local ts = _G.TOGGLE_STATES
        if ts and ts["Line To Base"] then ts["Line To Base"].set(true) end
    end

    if cfg.baseOwnerESP == true then
        waitAndActivate("Base Owner ESP",
            function() return _G._SH_StartBaseOwnerESP ~= nil end,
            function() _G._SH_StartBaseOwnerESP() end)
    end

    if cfg.baseTimerESP == true then
        waitAndActivate("Base Timer ESP",
            function() return _G._SH_StartBaseTimerESP ~= nil end,
            function() _G._SH_StartBaseTimerESP() end)
    end

    if cfg.boxESP == true then
        waitAndActivate("Box ESP",
            function() return _G._SH_StartBoxESP ~= nil end,
            function() _G._SH_StartBoxESP() end)
    end

    if cfg.autoGrab == true then
        waitAndActivate("Auto Grab",
            function() return _G.SabcomAutoSteal ~= nil end,
            function() _G.SabcomAutoSteal(true) end,
            60)
    end

    if cfg.infJump == true then
        local ts = _G.TOGGLE_STATES
        if ts and ts["Inf Jump"] then ts["Inf Jump"].set(true) end
    end

    if cfg.xray == true then
        waitAndActivate("XRay",
            function() return _G.SH_toggleXRay ~= nil end,
            function() _G.SH_toggleXRay(true) end)
    end

    if cfg.antiRagdoll == true then
        waitAndActivate("Anti Ragdoll",
            function() return _G.SH_startAntiRagdoll ~= nil end,
            function() _G.SH_startAntiRagdoll() end)
    end

    if cfg.autoKick == true then
        waitAndActivate("Auto Kick on Steal",
            function() return _G.SH_toggleAutoKick ~= nil end,
            function() _G.SH_toggleAutoKick(true) end)
    end

    if cfg.invisPanel == true then
        waitAndActivate("Invisible Steal Panel",
            function() return _G.SH_ShowInvisPanel ~= nil end,
            function() _G.SH_ShowInvisPanel(true) end)
    end

    if cfg.stealPanel == true then
        local ts=_G.TOGGLE_STATES
        if ts and ts["Steal Panel"] then ts["Steal Panel"].set(true) end
        task.spawn(function()
            local t=0
            while not _G.SH_ShowStealPanel and t<15 do task.wait(0.3);t=t+0.3 end
            if _G.SH_ShowStealPanel then pcall(_G.SH_ShowStealPanel,true) end
        end)
    end
    if cfg.adminPanel == true then
        waitAndActivate("Admin Panel",function() return _G.SH_toggleAdminPanel~=nil end,function() _G.SH_toggleAdminPanel(true) end)
    end
    if cfg.autoBuy == true then
        waitAndActivate("Auto Buy",function() return _G.SH_toggleAutoBuy~=nil end,function() _G.SH_toggleAutoBuy(true) end)
    end
    if cfg.walkSpeedOn == true then
        task.spawn(function()
            local t=0
            while not _G.setWalkSpeedEnabled and t<15 do task.wait(0.3);t=t+0.3 end
            if _G.setWalkSpeedEnabled then
                if cfg.walkSpeedVal then pcall(_G.setWalkSpeedValue or function() end, cfg.walkSpeedVal) end
                pcall(_G.setWalkSpeedEnabled, true)
            end
        end)
    end
    if cfg.kickToPS == true then
        waitAndActivate("Kick to PS",function() return _G.SH_toggleKickToPS~=nil end,function() _G.SH_toggleKickToPS(true) end)
    end
    -- restore loader screen setting (cfg.loaderScreen defaults true if unset)
    if cfg.loaderScreen == false then
        pcall(function()
            if _G._SH_LoaderCfg then _G._SH_LoaderCfg.SHOW_SCREEN = false end
        end)
    end

    if cfg.fpsBoost == true then
        waitAndActivate("FPS Boost",
            function() return _G.SH_toggleFPSBoost ~= nil end,
            function() _G.SH_toggleFPSBoost(true) end)
    end

    if cfg.antiFlasher == true then
        waitAndActivate("Anti Flasher",
            function() return _G.SH_toggleAntiFlasher ~= nil end,
            function() _G.SH_toggleAntiFlasher(true) end)
    end

    if cfg.playerESP == true then
        waitAndActivate("Player ESP",
            function() return _G.SH_togglePlayerESP ~= nil end,
            function() _G.SH_togglePlayerESP(true) end)
    end

    if cfg.actionPanel == true then
        local ts = _G.TOGGLE_STATES
        if ts and ts["Action Panel"] then ts["Action Panel"].set(true) end
        if _G.SH_ActionsPanel then _G.SH_ActionsPanel.Visible = true end
    end

    if cfg.agPanel == true then
        local ts = _G.TOGGLE_STATES
        if ts and ts["Auto Grab Panel"] then ts["Auto Grab Panel"].set(true) end
        task.spawn(function()
            local t=0
            while not _G.SH_ShowAutoGrabPanel and t<15 do task.wait(0.3);t=t+0.3 end
            if _G.SH_ShowAutoGrabPanel then pcall(_G.SH_ShowAutoGrabPanel, true) end
        end)
    end

    if cfg.carpetSpeed == true then
        _G.SH_CarpetSpeedOn = true
        local ts = _G.TOGGLE_STATES
        if ts and ts["Carpet Speed"] then ts["Carpet Speed"].set(true) end
    end

    -- Taco TP restore
    if type(cfg.neegyCruise)     =="number" then _G.NeegyCruise           =cfg.neegyCruise     end
    if type(cfg.tacoClimb)       =="number" then _G.TacoClimb             =cfg.tacoClimb       end
    if type(cfg.tacoCloseSpeed)  =="number" then _G.TacoCloseSpeed        =cfg.tacoCloseSpeed  end
    if type(cfg.landingDelay)    =="number" then _G.LandingDelay          =cfg.landingDelay    end
    if type(cfg.tacoStealHold)   =="number" then _G.TacoStealHoldDuration =cfg.tacoStealHold   end
    if type(cfg.tacoCommitRange) =="number" then _G.TacoStealCommitRange  =cfg.tacoCommitRange end
    if type(cfg.tacoStealMode)   =="string" then _G.TacoStealMode         =cfg.tacoStealMode   end
    _G._SH_activeTPEngine = (cfg.activeTPEngine==2) and 2 or 1
    if _G._SH_refreshTPTab then pcall(_G._SH_refreshTPTab) end

    -- Neegy restore
    if type(cfg.railCruise)       =="number"  then _G.RailCruise       =cfg.railCruise       end
    if type(cfg.railApproach)     =="number"  then _G.RailApproach     =cfg.railApproach     end
    if type(cfg.railBrakeRadius)  =="number"  then _G.RailBrakeRadius  =cfg.railBrakeRadius  end
    if type(cfg.railArriveRadius) =="number"  then _G.RailArriveRadius =cfg.railArriveRadius end
    if type(cfg.railHover)        =="number"  then _G.RailHover        =cfg.railHover        end
    if cfg.faceAway       == true then _G.FaceAway       = true end
    if cfg.faceAwayOwner  == true then _G.FaceAwayOwner  = true end
    if cfg.baseXray       == true then _G.BaseXray       = true end
    if type(cfg.baseXrayAlpha)    =="number"  then _G.BaseXrayAlpha    =cfg.baseXrayAlpha    end
    if cfg.hideCollect    == true then _G.HideCollect    = true end
    if cfg.flightNoclip   == true then _G.FlightNoclip   = true end
    if cfg.antiDie        == true then _G.AntiDie        = true end
    if cfg.espLine        == true then _G.ESPLine        = true end
    if cfg.petXray        == true then _G.PetXray        = true end
    if type(cfg.stealHold)        =="number"  then _G.StealHold        =cfg.stealHold        end
    if type(cfg.stealCommitRange) =="number"  then _G.StealCommitRange =cfg.stealCommitRange end
    if cfg.priorityStrict == true then _G.PriorityStrict = true end

    print("[CONFIG] Loaded")
end)


local function tw(o,i,p) TweenService:Create(o,i,p):Play() end
local TF=TweenInfo.new(0.18,Enum.EasingStyle.Sine,Enum.EasingDirection.Out)
local TFM=TweenInfo.new(0.28,Enum.EasingStyle.Quint,Enum.EasingDirection.Out)
local TFB=TweenInfo.new(0.35,Enum.EasingStyle.Back,Enum.EasingDirection.Out)

-- SCREEN GUI
local _SGNAME="SH"..tostring(math.random(1e6,9e6))
local old=PG:FindFirstChild(_SGNAME); if old then old:Destroy() end
local sg=Instance.new("ScreenGui"); sg.Name=_SGNAME; sg.ResetOnSpawn=false
sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; sg.DisplayOrder=999999; sg.IgnoreGuiInset=true; sg.Parent=PG

-- REOPEN BTN
local reopenBtn=Instance.new("TextButton",sg)
reopenBtn.Size=UDim2.fromOffset(50,50); reopenBtn.Position=UDim2.new(0,10,0.5,-25)
reopenBtn.BackgroundColor3=Color3.fromRGB(15,18,28); reopenBtn.BackgroundTransparency=0.15
reopenBtn.Text="SH"; reopenBtn.Font=Enum.Font.GothamBold; reopenBtn.TextSize=18
reopenBtn.TextColor3=Color3.fromRGB(0,170,255); reopenBtn.AutoButtonColor=false; reopenBtn.Visible=false
local rc=Instance.new("UICorner",reopenBtn); rc.CornerRadius=UDim.new(0,12)
local rs=Instance.new("UIStroke",reopenBtn); rs.Thickness=2; rs.Color=Color3.fromRGB(0,150,255)

-- MAIN FRAME
local main=Instance.new("Frame",sg); main.Name="Main"
main.Size=UDim2.fromOffset(660,440); main.Position=UDim2.new(0.5,-330,0.5,-220)
main.BackgroundColor3=Color3.fromRGB(4,4,6); main.BackgroundTransparency=0
main.BorderSizePixel=0; main.ClipsDescendants=true
local mc=Instance.new("UICorner",main); mc.CornerRadius=UDim.new(0,12)
local ledS=Instance.new("UIStroke",main); ledS.Thickness=1.5; ledS.Color=Color3.fromRGB(180,130,0); ledS.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
local glow=Instance.new("Frame",main); glow.Size=UDim2.fromScale(1,1); glow.BackgroundColor3=Color3.fromRGB(180,120,0)
glow.BackgroundTransparency=0.97; glow.BorderSizePixel=0; glow.ZIndex=0
Instance.new("UICorner",glow).CornerRadius=UDim.new(0,12)
local uiScale=Instance.new("UIScale",main)

-- Gold wave LED animation on main panel
task.spawn(function()
    local t=0 while main and main.Parent do t=t+RunService.Heartbeat:Wait()
        local p1=(math.sin(t*1.3)+1)/2; local p2=(math.sin(t*2.1+0.5)+1)/2
        local r=math.floor(160+p1*80); local g=math.floor(100+p2*80)
        ledS.Color=Color3.fromRGB(r,g,0)
        ledS.Thickness=1.2+p1*0.8; ledS.Transparency=p2*0.25
        glow.BackgroundTransparency=0.95+p2*0.04
        rs.Color=Color3.fromRGB(math.floor(140+p1*60),math.floor(90+p1*60),0)
    end
end)

-- Globale UI Position Helfer
_G._SH_saveUIPos = function(name, frame)
    if not _SH_ConfigRaw then return end
    if not _SH_ConfigRaw.uiPositions then _SH_ConfigRaw.uiPositions = {} end
    _SH_ConfigRaw.uiPositions[name] = {
        xs=frame.Position.X.Scale, xo=frame.Position.X.Offset,
        ys=frame.Position.Y.Scale, yo=frame.Position.Y.Offset
    }
    pcall(saveConfig)
end
_G._SH_loadUIPos = function(name, frame)
    if not _SH_ConfigRaw or not _SH_ConfigRaw.uiPositions then return end
    local d = _SH_ConfigRaw.uiPositions[name]
    if d then frame.Position = UDim2.new(d.xs or 0, d.xo or 0, d.ys or 0, d.yo or 0) end
end

-- DRAG
do
    local drag,dragS,startP,dragI=false,nil,nil,nil
    main.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            drag=true;dragS=i.Position;startP=main.Position
            i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then drag=false end end)
        end
    end)
    main.InputChanged:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseMovement then dragI=i end end)
    UIS.InputChanged:Connect(function(i)
        if i==dragI and drag then local d=i.Position-dragS
            main.Position=UDim2.new(startP.X.Scale,startP.X.Offset+d.X,startP.Y.Scale,startP.Y.Offset+d.Y) end
    end)
end
UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then if _G._SH_saveUIPos then pcall(_G._SH_saveUIPos,"MainPanel",main) end end end)
if _G._SH_loadUIPos then pcall(_G._SH_loadUIPos,"MainPanel",main) end

-- TOP BAR
local topBar=Instance.new("Frame",main); topBar.Size=UDim2.new(1,0,0,42)
topBar.BackgroundColor3=Color3.fromRGB(8,8,10); topBar.BackgroundTransparency=0; topBar.BorderSizePixel=0
Instance.new("UICorner",topBar).CornerRadius=UDim.new(0,12)
local logo=Instance.new("Frame",topBar); logo.Size=UDim2.fromOffset(32,32); logo.Position=UDim2.new(0,8,0.5,-16)
logo.BackgroundColor3=Color3.fromRGB(130,90,0); logo.BackgroundTransparency=0.2; logo.BorderSizePixel=0
Instance.new("UICorner",logo).CornerRadius=UDim.new(0,8)
Instance.new("UIStroke",logo).Color=Color3.fromRGB(255,200,60)
local lL=Instance.new("TextLabel",logo); lL.Size=UDim2.fromScale(1,1); lL.BackgroundTransparency=1
lL.Text="SH"; lL.Font=Enum.Font.GothamBlack; lL.TextSize=14; lL.TextColor3=Color3.fromRGB(255,230,80)
local titleL=Instance.new("TextLabel",topBar); titleL.Size=UDim2.fromOffset(140,0); titleL.Position=UDim2.fromOffset(48,0)
titleL.BackgroundTransparency=1; titleL.Text="Silence Hub"; titleL.Font=Enum.Font.GothamBlack; titleL.TextSize=17
titleL.TextColor3=Color3.fromRGB(255,220,60); titleL.TextXAlignment=Enum.TextXAlignment.Left
-- animated gold on title
local titleGrad=Instance.new("UIGradient",titleL)
task.spawn(function()
    local t=0
    while titleL and titleL.Parent do
        t=t+task.wait(0.016)
        titleGrad.Offset=Vector2.new(math.sin(t*1.2)*0.7+math.sin(t*2.5)*0.15,0)
        titleGrad.Rotation=math.sin(t*0.8)*10
        titleGrad.Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0,Color3.fromRGB(120,80,0)),
            ColorSequenceKeypoint.new(0.4+math.sin(t*1.5)*0.1,Color3.fromRGB(255,235,100)),
            ColorSequenceKeypoint.new(1,Color3.fromRGB(140,95,0)),
        })
    end
end)
local badge=Instance.new("Frame",topBar); badge.Size=UDim2.fromOffset(230,22); badge.Position=UDim2.new(0,168,0.5,-11)
badge.BackgroundColor3=Color3.fromRGB(80,55,0); badge.BackgroundTransparency=0.6; badge.BorderSizePixel=0
Instance.new("UICorner",badge).CornerRadius=UDim.new(0,20)
local badgeS=Instance.new("UIStroke",badge); badgeS.Color=Color3.fromRGB(200,150,0); badgeS.Thickness=1; badgeS.Transparency=0.3
local badgeL=Instance.new("TextLabel",badge); badgeL.Size=UDim2.new(1,-16,1,0); badgeL.Position=UDim2.fromOffset(8,0)
badgeL.BackgroundTransparency=1; badgeL.Text="@sqz8  ·  @fehlenentscheidung"; badgeL.Font=Enum.Font.GothamMedium
badgeL.TextSize=11; badgeL.TextColor3=Color3.fromRGB(255,210,60); badgeL.TextXAlignment=Enum.TextXAlignment.Left
-- gold wave on badge
local badgeGrad=Instance.new("UIGradient",badgeL)
task.spawn(function() local t=0 while badge and badge.Parent do t=t+task.wait(0.016)
    local w=math.sin(t*1.3)*0.6+math.sin(t*2.7)*0.15
    badgeGrad.Offset=Vector2.new(w,0); badgeGrad.Rotation=math.sin(t*0.7)*6
    badgeGrad.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(120,80,0)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(255,230,80)),ColorSequenceKeypoint.new(1,Color3.fromRGB(120,80,0))})
    badgeS.Transparency=0.2+math.sin(t*2)*0.15
end end)
local closeBtn=Instance.new("TextButton",topBar); closeBtn.Size=UDim2.fromOffset(28,28); closeBtn.Position=UDim2.new(1,-36,0.5,-14)
closeBtn.BackgroundTransparency=1; closeBtn.Text="x"; closeBtn.Font=Enum.Font.GothamBold; closeBtn.TextSize=20
closeBtn.TextColor3=Color3.fromRGB(75,95,135); closeBtn.AutoButtonColor=false; closeBtn.BorderSizePixel=0
Instance.new("UICorner",closeBtn).CornerRadius=UDim.new(0,7)
closeBtn.MouseEnter:Connect(function() tw(closeBtn,TF,{TextColor3=Color3.fromRGB(255,70,70)}) end)
closeBtn.MouseLeave:Connect(function() tw(closeBtn,TF,{TextColor3=Color3.fromRGB(75,95,135)}) end)

-- NAV BAR
local navBar=Instance.new("Frame",main); navBar.Size=UDim2.new(0,140,1,-52); navBar.Position=UDim2.fromOffset(10,46)
navBar.BackgroundColor3=Color3.fromRGB(8,8,10); navBar.BackgroundTransparency=0; navBar.BorderSizePixel=0
Instance.new("UICorner",navBar).CornerRadius=UDim.new(0,8)
local navStroke=Instance.new("UIStroke",navBar); navStroke.Color=Color3.fromRGB(120,85,0); navStroke.Thickness=1; navStroke.Transparency=0.5
local navL=Instance.new("UIListLayout",navBar); navL.Padding=UDim.new(0,5); navL.SortOrder=Enum.SortOrder.LayoutOrder
local navP=Instance.new("UIPadding",navBar); navP.PaddingTop=UDim.new(0,8); navP.PaddingLeft=UDim.new(0,6); navP.PaddingRight=UDim.new(0,6)

-- CONTENT
local content=Instance.new("Frame",main); content.Name="Content"
content.Size=UDim2.new(1,-162,1,-52); content.Position=UDim2.fromOffset(158,46)
content.BackgroundTransparency=1; content.BorderSizePixel=0

-- TABS (extended with Neegy)
local TABS={"Keybinds","TP","ESP","UI","Misc","Performance","Neegy"}
local TCOLORS={Keybinds=Color3.fromRGB(0,180,255),TP=Color3.fromRGB(0,220,120),ESP=Color3.fromRGB(255,100,200),UI=Color3.fromRGB(150,90,255),Misc=Color3.fromRGB(255,160,40),Performance=Color3.fromRGB(255,80,80),Neegy=Color3.fromRGB(200,168,75)}
local tabFrames={}; local tabBtns={}; local curTab=""

local function switchTab(name)
    if curTab==name then return end; curTab=name
    for k,f in pairs(tabFrames) do f.Visible=(k==name) end
    for k,b in pairs(tabBtns) do
        local col=TCOLORS[k] or Color3.fromRGB(0,170,255)
        if k==name then tw(b,TFM,{BackgroundColor3=Color3.fromRGB(90,60,0),BackgroundTransparency=0.1,TextColor3=Color3.fromRGB(255,220,60)})
        else tw(b,TF,{BackgroundColor3=Color3.fromRGB(12,12,14),BackgroundTransparency=0,TextColor3=Color3.fromRGB(130,135,145)}) end
    end
end

for i,name in ipairs(TABS) do
    local col=TCOLORS[name]
    local btn=Instance.new("TextButton",navBar); btn.Size=UDim2.new(1,0,0,36)
    local isFirst=(i==1)
    btn.BackgroundColor3=isFirst and Color3.fromRGB(90,60,0) or Color3.fromRGB(12,12,14)
    btn.BackgroundTransparency=isFirst and 0.1 or 0
    btn.TextColor3=isFirst and Color3.fromRGB(255,220,60) or Color3.fromRGB(140,145,155); btn.Text=name
    btn.Font=Enum.Font.GothamBold; btn.TextSize=12; btn.LayoutOrder=i; btn.AutoButtonColor=false
    btn.TextXAlignment=Enum.TextXAlignment.Left; btn.BorderSizePixel=0
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,6)
    Instance.new("UIPadding",btn).PaddingLeft=UDim.new(0,12)
    local ind=Instance.new("Frame",btn); ind.Size=UDim2.fromOffset(3,20); ind.Position=UDim2.new(0,0,0.5,-10)
    ind.BackgroundColor3=col; ind.BackgroundTransparency=i==1 and 0 or 1; ind.BorderSizePixel=0
    Instance.new("UICorner",ind).CornerRadius=UDim.new(0,2)
    btn.MouseEnter:Connect(function() if curTab~=name then tw(btn,TF,{BackgroundColor3=Color3.fromRGB(40,28,0),BackgroundTransparency=0,TextColor3=Color3.fromRGB(220,185,60)}) end end)
    btn.MouseLeave:Connect(function() if curTab~=name then tw(btn,TF,{BackgroundColor3=Color3.fromRGB(12,12,14),BackgroundTransparency=0,TextColor3=Color3.fromRGB(130,135,145)}) end end)
    btn.MouseButton1Click:Connect(function()
        for _,b2 in pairs(tabBtns) do local i2=b2:FindFirstChildOfClass("Frame"); if i2 then tw(i2,TF,{BackgroundTransparency=b2==btn and 0 or 1}) end end
        switchTab(name)
    end)
    tabBtns[name]=btn
    local sf=Instance.new("ScrollingFrame",content); sf.Name=name; sf.Size=UDim2.fromScale(1,1)
    sf.BackgroundTransparency=1; sf.BorderSizePixel=0; sf.ScrollBarThickness=4; sf.ScrollBarImageColor3=col
    sf.ScrollBarImageColor3=Color3.fromRGB(180,130,0)
    sf.CanvasSize=UDim2.new(0,0,0,0); sf.AutomaticCanvasSize=Enum.AutomaticSize.Y; sf.Visible=(i==1)
    local sfL=Instance.new("UIListLayout",sf); sfL.Padding=UDim.new(0,8); sfL.SortOrder=Enum.SortOrder.LayoutOrder; sfL.HorizontalAlignment=Enum.HorizontalAlignment.Center
    local sfP=Instance.new("UIPadding",sf); sfP.PaddingTop=UDim.new(0,12); sfP.PaddingBottom=UDim.new(0,12); sfP.PaddingLeft=UDim.new(0,12); sfP.PaddingRight=UDim.new(0,12)
    tabFrames[name]=sf
end
curTab="Keybinds"

-- UI HELPERS
local function mkSection(parent,label,color)
    color=color or Color3.fromRGB(0,180,255)
    local f=Instance.new("Frame",parent); f.Size=UDim2.new(1,0,0,24); f.BackgroundTransparency=1; f.BorderSizePixel=0
    local ln=Instance.new("Frame",f); ln.Size=UDim2.new(1,0,0,1); ln.Position=UDim2.new(0,0,1,-1); ln.BackgroundColor3=color; ln.BackgroundTransparency=0.55; ln.BorderSizePixel=0
    local lb=Instance.new("TextLabel",f); lb.Size=UDim2.new(1,0,1,-2); lb.BackgroundTransparency=1; lb.Text=label; lb.Font=Enum.Font.GothamBlack; lb.TextSize=11; lb.TextColor3=color; lb.TextXAlignment=Enum.TextXAlignment.Left
end

-- Zentrale Toggle State Registry
_G.TOGGLE_STATES = {}
local TOGGLE_STATES = _G.TOGGLE_STATES
local function registerToggle(name, setFn, getFn)
    TOGGLE_STATES[name] = {set=setFn, get=getFn}
end

local function mkToggle(parent,label,default,onChange,color)
    color=color or Color3.fromRGB(0,200,100); local val=default
    local row=Instance.new("Frame",parent); row.Size=UDim2.new(1,0,0,42); row.BackgroundColor3=Color3.fromRGB(20,25,38); row.BackgroundTransparency=0.3; row.BorderSizePixel=0
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,8)
    local rS=Instance.new("UIStroke",row); rS.Color=Color3.fromRGB(30,38,58); rS.Thickness=1; rS.Transparency=0.7
    local rP=Instance.new("UIPadding",row); rP.PaddingLeft=UDim.new(0,12); rP.PaddingRight=UDim.new(0,10)
    local lb=Instance.new("TextLabel",row); lb.Size=UDim2.new(1,-56,1,0); lb.BackgroundTransparency=1; lb.Text=label; lb.Font=Enum.Font.GothamMedium; lb.TextSize=13; lb.TextColor3=Color3.fromRGB(200,210,230); lb.TextXAlignment=Enum.TextXAlignment.Left
    local tr=Instance.new("TextButton",row); tr.Size=UDim2.fromOffset(42,24); tr.Position=UDim2.new(1,-42,0.5,-12); tr.BackgroundColor3=val and color or Color3.fromRGB(40,50,72); tr.Text=""; tr.AutoButtonColor=false; tr.BorderSizePixel=0
    Instance.new("UICorner",tr).CornerRadius=UDim.new(0,12)
    local th=Instance.new("Frame",tr); th.Size=UDim2.fromOffset(18,18); th.Position=val and UDim2.fromOffset(21,3) or UDim2.fromOffset(3,3); th.BackgroundColor3=Color3.fromRGB(255,255,255); th.BorderSizePixel=0
    Instance.new("UICorner",th).CornerRadius=UDim.new(0,9)
    local function set(on) val=on; tw(tr,TFM,{BackgroundColor3=on and color or Color3.fromRGB(40,50,72)}); tw(th,TFM,{Position=on and UDim2.fromOffset(21,3) or UDim2.fromOffset(3,3)}); if onChange then pcall(onChange,on) end end
    tr.MouseButton1Click:Connect(function() set(not val) end)
    return row,set,function() return val end
end

local function mkSlider(parent,label,min,max,default,onChange,step,color)
    color=color or Color3.fromRGB(0,170,255); step=step or 1; local val=default
    local row=Instance.new("Frame",parent); row.Size=UDim2.new(1,0,0,56); row.BackgroundColor3=Color3.fromRGB(20,25,38); row.BackgroundTransparency=0.3; row.BorderSizePixel=0
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,8)
    local rS=Instance.new("UIStroke",row); rS.Color=Color3.fromRGB(30,38,58); rS.Thickness=1; rS.Transparency=0.7
    local rP=Instance.new("UIPadding",row); rP.PaddingLeft=UDim.new(0,12); rP.PaddingRight=UDim.new(0,12); rP.PaddingTop=UDim.new(0,8)
    local tr=Instance.new("Frame",row); tr.Size=UDim2.new(1,0,0,18); tr.BackgroundTransparency=1
    local lb=Instance.new("TextLabel",tr); lb.Size=UDim2.new(0.65,0,1,0); lb.BackgroundTransparency=1; lb.Text=label; lb.Font=Enum.Font.GothamMedium; lb.TextSize=11; lb.TextColor3=Color3.fromRGB(185,200,220); lb.TextXAlignment=Enum.TextXAlignment.Left
    local vl=Instance.new("TextLabel",tr); vl.Size=UDim2.new(0.35,0,1,0); vl.Position=UDim2.new(0.65,0,0,0); vl.BackgroundTransparency=1; vl.Font=Enum.Font.GothamBold; vl.TextSize=11; vl.TextColor3=color; vl.TextXAlignment=Enum.TextXAlignment.Right
    vl.Text=step<1 and string.format("%.2f",val) or tostring(math.floor(val))
    local bg=Instance.new("Frame",row); bg.Size=UDim2.new(1,0,0,8); bg.Position=UDim2.fromOffset(0,32); bg.BackgroundColor3=Color3.fromRGB(28,35,54); bg.BorderSizePixel=0
    Instance.new("UICorner",bg).CornerRadius=UDim.new(0,4)
    local fi=Instance.new("Frame",bg); fi.Size=UDim2.new((val-min)/math.max(max-min,1),0,1,0); fi.BackgroundColor3=color; fi.BorderSizePixel=0
    Instance.new("UICorner",fi).CornerRadius=UDim.new(0,4)
    local td=Instance.new("Frame",bg); td.Size=UDim2.fromOffset(14,14); td.AnchorPoint=Vector2.new(0.5,0.5); td.Position=UDim2.new((val-min)/math.max(max-min,1),0,0.5,0); td.BackgroundColor3=Color3.fromRGB(255,255,255); td.BorderSizePixel=0
    Instance.new("UICorner",td).CornerRadius=UDim.new(0,7)
    local tdS=Instance.new("UIStroke",td); tdS.Color=color; tdS.Thickness=2; tdS.Transparency=0.4
    local function setVal(v) v=math.floor(v/step+0.5)*step; v=math.clamp(v,min,max); val=v; local r=(v-min)/math.max(max-min,1); tw(fi,TF,{Size=UDim2.new(r,0,1,0)}); tw(td,TF,{Position=UDim2.new(r,0,0.5,0)}); vl.Text=step<1 and string.format("%.2f",v) or tostring(math.floor(v)); if onChange then pcall(onChange,v) end end
    local dragging=false
    local function fromX(x) local r=math.clamp((x-bg.AbsolutePosition.X)/bg.AbsoluteSize.X,0,1); setVal(min+r*(max-min)) end
    bg.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true;fromX(i.Position.X) end end)
    bg.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
    UIS.InputChanged:Connect(function(i) if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then fromX(i.Position.X) end end)
end

local function mkButton(parent,label,onClick,color)
    color=color or Color3.fromRGB(0,150,255)
    local btn=Instance.new("TextButton",parent); btn.Size=UDim2.new(1,0,0,38); btn.BackgroundColor3=color; btn.BackgroundTransparency=0.2
    btn.Text=label; btn.Font=Enum.Font.GothamBold; btn.TextSize=13; btn.TextColor3=Color3.fromRGB(255,255,255); btn.AutoButtonColor=false; btn.BorderSizePixel=0
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,8)
    local bS=Instance.new("UIStroke",btn); bS.Color=color; bS.Thickness=1.5; bS.Transparency=0.5
    btn.MouseEnter:Connect(function() tw(btn,TF,{BackgroundTransparency=0.05}) end)
    btn.MouseLeave:Connect(function() tw(btn,TF,{BackgroundTransparency=0.2}) end)
    btn.MouseButton1Click:Connect(function() tw(btn,TF,{BackgroundTransparency=0.45}); task.delay(0.12,function() tw(btn,TF,{BackgroundTransparency=0.2}) end); if onClick then pcall(onClick) end end)
    return btn
end

local function mkKeybind(parent,label,defaultKey,onChanged)
    local cur=defaultKey; local listening=false
    local row=Instance.new("Frame",parent); row.Size=UDim2.new(1,0,0,42); row.BackgroundColor3=Color3.fromRGB(20,25,38); row.BackgroundTransparency=0.3; row.BorderSizePixel=0
    Instance.new("UICorner",row).CornerRadius=UDim.new(0,8)
    local rS=Instance.new("UIStroke",row); rS.Color=Color3.fromRGB(30,38,58); rS.Thickness=1; rS.Transparency=0.7
    local rP=Instance.new("UIPadding",row); rP.PaddingLeft=UDim.new(0,12); rP.PaddingRight=UDim.new(0,10)
    local lb=Instance.new("TextLabel",row); lb.Size=UDim2.new(0.55,0,1,0); lb.BackgroundTransparency=1; lb.Text=label; lb.Font=Enum.Font.GothamMedium; lb.TextSize=13; lb.TextColor3=Color3.fromRGB(200,210,230); lb.TextXAlignment=Enum.TextXAlignment.Left
    local kb=Instance.new("TextButton",row); kb.Size=UDim2.new(0.42,0,0,28); kb.Position=UDim2.new(0.58,0,0.5,-14); kb.BackgroundColor3=Color3.fromRGB(28,36,54); kb.BackgroundTransparency=0.2; kb.Text=cur and cur.Name or "NONE"; kb.Font=Enum.Font.GothamBold; kb.TextSize=11; kb.TextColor3=Color3.fromRGB(0,180,255); kb.AutoButtonColor=false; kb.BorderSizePixel=0
    Instance.new("UICorner",kb).CornerRadius=UDim.new(0,7)
    local kbS=Instance.new("UIStroke",kb); kbS.Color=Color3.fromRGB(0,180,255); kbS.Thickness=1.5; kbS.Transparency=0.5
    kb.MouseButton1Click:Connect(function() if listening then return end; listening=true; kb.Text="..."; tw(kb,TF,{TextColor3=Color3.fromRGB(255,180,0)}); tw(kbS,TF,{Color=Color3.fromRGB(255,180,0)}) end)
    UIS.InputBegan:Connect(function(inp,gp) if not listening then return end; if inp.UserInputType~=Enum.UserInputType.Keyboard then return end; listening=false; cur=inp.KeyCode; kb.Text=cur.Name; tw(kb,TF,{TextColor3=Color3.fromRGB(0,180,255)}); tw(kbS,TF,{Color=Color3.fromRGB(0,180,255)}); if onChanged then pcall(onChanged,cur) end end)
end

-- ============================================================
-- END SECTION 5
-- ============================================================
-- ============================================================
-- SECTION 6: TAB CONTENTS (Keybinds, TP, ESP, UI, Misc, Neegy)
-- ============================================================

-- KEYBINDS
do local f=tabFrames["Keybinds"];local C=TCOLORS.Keybinds
    mkSection(f,"Keybinds",C)
    local info=Instance.new("TextLabel",f);info.Size=UDim2.new(1,0,0,26);info.BackgroundTransparency=1;info.Text="Click a button, then press the key";info.Font=Enum.Font.Gotham;info.TextSize=11;info.TextColor3=Color3.fromRGB(100,120,160);info.TextXAlignment=Enum.TextXAlignment.Left
    mkKeybind(f,"Manual TP",KEYBINDS.manualTP,function(k) KEYBINDS.manualTP=k;saveSettings() end)
    mkKeybind(f,"UI Toggle",KEYBINDS.toggleUI,function(k) KEYBINDS.toggleUI=k end)

    mkSection(f,"Carpet Speed",Color3.fromRGB(0,200,180))
    local csOn=false
    local csKeyConn=UIS.InputBegan:Connect(function(inp,gp)
        if gp then return end
        if inp.KeyCode==Enum.KeyCode.Q then
            csOn=not csOn
            if _G.SH_setCarpetSpeed then pcall(_G.SH_setCarpetSpeed,csOn) end
            if _G.SH_Config then _G.SH_Config.carpetSpeed=csOn end
            saveSettings()
        end
    end)
    local csRow=Instance.new("Frame",f);csRow.Size=UDim2.new(1,0,0,38)
    csRow.BackgroundColor3=Color3.fromRGB(20,25,38);csRow.BackgroundTransparency=0.3;csRow.BorderSizePixel=0
    Instance.new("UICorner",csRow).CornerRadius=UDim.new(0,8)
    local csPad=Instance.new("UIPadding",csRow);csPad.PaddingLeft=UDim.new(0,12);csPad.PaddingRight=UDim.new(0,10)
    local csLbl=Instance.new("TextLabel",csRow);csLbl.Size=UDim2.new(0.6,0,1,0);csLbl.BackgroundTransparency=1
    csLbl.Text="Carpet Speed (Q)";csLbl.Font=Enum.Font.GothamMedium;csLbl.TextSize=13
    csLbl.TextColor3=Color3.fromRGB(200,210,230);csLbl.TextXAlignment=Enum.TextXAlignment.Left
    local csKeyLbl=Instance.new("TextLabel",csRow);csKeyLbl.Size=UDim2.new(0.37,0,0,26);csKeyLbl.Position=UDim2.new(0.63,0,0.5,-13)
    csKeyLbl.BackgroundColor3=Color3.fromRGB(28,36,54);csKeyLbl.BackgroundTransparency=0.2;csKeyLbl.Text="Q"
    csKeyLbl.Font=Enum.Font.GothamBold;csKeyLbl.TextSize=12;csKeyLbl.TextColor3=Color3.fromRGB(0,200,180)
    Instance.new("UICorner",csKeyLbl).CornerRadius=UDim.new(0,7)

    mkSlider(f,"Carpet Speed (100-200)",100,200,_G.SH_Config and _G.SH_Config.carpetSpeedVal or 140,function(v)
        if _G.SH_setCarpetSpeedValue then pcall(_G.SH_setCarpetSpeedValue,v) end
        _G.SH_CarpetSpeedVal=v
        if _G.SH_Config then _G.SH_Config.carpetSpeedVal=v end
        saveSettings()
    end,1,Color3.fromRGB(0,200,180))

    mkSection(f,"Action Keybinds",Color3.fromRGB(56,140,255))
    mkKeybind(f,"Insta Reset",  KEYBINDS.instaReset, function(k) KEYBINDS.instaReset=k end)
    mkKeybind(f,"Rejoin Job Id",KEYBINDS.rejoinJob,  function(k) KEYBINDS.rejoinJob=k  end)
    mkKeybind(f,"Rejoin PS",    KEYBINDS.rejoinPs,   function(k) KEYBINDS.rejoinPs=k   end)
    mkKeybind(f,"Kick",         KEYBINDS.kick,        function(k) KEYBINDS.kick=k       end)

    mkSection(f,"Instant Clone",Color3.fromRGB(255,200,0))
    local _cloneKey = Enum.KeyCode.F
    mkKeybind(f,"Instant Clone",_cloneKey,function(k)
        _cloneKey=k
        if _G.SH_setCloneKey then pcall(_G.SH_setCloneKey,k) end
        if _G.SH_Config then _G.SH_Config.cloneKey=k.Name end
        if _SH_ConfigRaw then _SH_ConfigRaw.cloneKey=k.Name end
        saveSettings()
    end)
    local _ci=Instance.new("TextLabel",f);_ci.Size=UDim2.new(1,0,0,20);_ci.BackgroundTransparency=1
    _ci.Text="Press key to instant clone (needs Quantum Cloner)";_ci.Font=Enum.Font.Gotham
    _ci.TextSize=10;_ci.TextColor3=Color3.fromRGB(100,120,160);_ci.TextXAlignment=Enum.TextXAlignment.Left
    mkSection(f,"Auto Buy",Color3.fromRGB(0,150,255))
    local _abk=Enum.KeyCode.B
    mkKeybind(f,"Auto Buy",_abk,function(k)
        _abk=k
        if _G.SH_setAutoBuyKey then pcall(_G.SH_setAutoBuyKey,k) end
        if _SH_ConfigRaw then _SH_ConfigRaw.autoBuyKey=k.Name end
        saveSettings()
    end)
end

-- TP TAB
do local f=tabFrames["TP"];local C=COL_TP
    mkSection(f,"Auto TP",C)
    mkToggle(f,"Auto TP on Load",_G.MynxxAutoTP,function(on) _G.MynxxAutoTP=on;saveSettings() end,C)
    local mCard=Instance.new("Frame",f);mCard.Size=UDim2.new(1,0,0,44);mCard.BackgroundColor3=Color3.fromRGB(16,22,34);mCard.BackgroundTransparency=0.1;mCard.BorderSizePixel=0
    Instance.new("UICorner",mCard).CornerRadius=UDim.new(0,12)
    local mS=Instance.new("UIStroke",mCard);mS.Color=Color3.fromRGB(28,38,58);mS.Thickness=1;mS.Transparency=0.6
    local mInner=Instance.new("Frame",mCard);mInner.Size=UDim2.new(1,-16,0,28);mInner.Position=UDim2.new(0,8,0.5,-14);mInner.BackgroundTransparency=1
    local mL=Instance.new("UIListLayout",mInner);mL.FillDirection=Enum.FillDirection.Horizontal;mL.Padding=UDim.new(0,6);mL.VerticalAlignment=Enum.VerticalAlignment.Center
    local MODES={"priority","nearest","highest"};local MLBLS={"PRIORITY","NEAREST","HIGHEST"};local mBtns={}
    local function refreshM() for i,b in ipairs(mBtns) do local on=(_G.MynxxStealMode==MODES[i]);tw(b,TFM,{BackgroundColor3=on and C or Color3.fromRGB(24,32,50),BackgroundTransparency=on and 0.05 or 0.5,TextColor3=on and Color3.fromRGB(10,20,15) or Color3.fromRGB(120,135,165)}) end end
    for i,lbl in ipairs(MLBLS) do
        local on=(_G.MynxxStealMode==MODES[i])
        local b=Instance.new("TextButton",mInner);b.Size=UDim2.new(0,0,1,0);b.AutomaticSize=Enum.AutomaticSize.X;b.BackgroundColor3=on and C or Color3.fromRGB(24,32,50);b.BackgroundTransparency=on and 0.05 or 0.5;b.Text=lbl;b.Font=Enum.Font.GothamBlack;b.TextSize=11;b.TextColor3=on and Color3.fromRGB(10,20,15) or Color3.fromRGB(120,135,165);b.AutoButtonColor=false;b.BorderSizePixel=0
        Instance.new("UICorner",b).CornerRadius=UDim.new(0,8)
        local bp=Instance.new("UIPadding",b);bp.PaddingLeft=UDim.new(0,14);bp.PaddingRight=UDim.new(0,14)
        b.MouseButton1Click:Connect(function()
            _G.MynxxStealMode=MODES[i]
            -- Auch AutoGrab Engine informieren
            if _G.setStealMode then pcall(_G.setStealMode, MODES[i]:sub(1,1):upper()..MODES[i]:sub(2)) end
            refreshM();saveSettings()
        end)
        mBtns[i]=b
    end
    mkSection(f,"Settings",C)
    local sBtn=Instance.new("TextButton",f);sBtn.Size=UDim2.new(1,0,0,40);sBtn.BackgroundColor3=Color3.fromRGB(16,22,34);sBtn.BackgroundTransparency=0.1;sBtn.Text="";sBtn.AutoButtonColor=false;sBtn.BorderSizePixel=0
    Instance.new("UICorner",sBtn).CornerRadius=UDim.new(0,12)
    local sBtnS=Instance.new("UIStroke",sBtn);sBtnS.Color=Color3.fromRGB(28,38,58);sBtnS.Thickness=1;sBtnS.Transparency=0.55
    local sBtnL=Instance.new("TextLabel",sBtn);sBtnL.Size=UDim2.new(1,-50,1,0);sBtnL.Position=UDim2.fromOffset(16,0);sBtnL.BackgroundTransparency=1;sBtnL.Text="TP Settings";sBtnL.Font=Enum.Font.GothamBold;sBtnL.TextSize=13;sBtnL.TextColor3=Color3.fromRGB(200,215,235);sBtnL.TextXAlignment=Enum.TextXAlignment.Left
    local sBtnA=Instance.new("TextLabel",sBtn);sBtnA.Size=UDim2.fromOffset(20,20);sBtnA.Position=UDim2.new(1,-28,0.5,-10);sBtnA.BackgroundTransparency=1;sBtnA.Text=">";sBtnA.Font=Enum.Font.GothamBold;sBtnA.TextSize=16;sBtnA.TextColor3=Color3.fromRGB(60,80,115)
    sBtn.MouseEnter:Connect(function() tw(sBtn,TF,{BackgroundTransparency=0});tw(sBtnS,TF,{Color=C,Transparency=0.3});tw(sBtnA,TF,{TextColor3=C}) end)
    sBtn.MouseLeave:Connect(function() tw(sBtn,TF,{BackgroundTransparency=0.1});tw(sBtnS,TF,{Color=Color3.fromRGB(28,38,58),Transparency=0.55});tw(sBtnA,TF,{TextColor3=Color3.fromRGB(60,80,115)}) end)
    sBtn.MouseButton1Click:Connect(function() if popOpen then closePopup() else openPopup() end end)
end

-- ESP TAB
do local f=tabFrames["ESP"];local C=TCOLORS["ESP"]

    mkSection(f,"Brainrot ESP",C)
    local brainrotESPOn=false
    do local _,_s,_g=mkToggle(f,"Brainrot ESP",false,function(on)
        brainrotESPOn=on
        if on then if _G._SH_StartESP then pcall(_G._SH_StartESP) end
        else if _G._SH_StopESP then pcall(_G._SH_StopESP) end end
        saveSettings()
    end,C)

    local rateValues={"100K","500K","1M","2M","4M","6M","8M","10M","20M","50M","100M","1B"}
    local rateIdx=5
    do local cur=_G.SH_ESPMinRate or "4M"
        for i,v in ipairs(rateValues) do if v==cur then rateIdx=i;break end end
    end
    local rateRow=Instance.new("Frame",f);rateRow.Size=UDim2.new(1,0,0,56)
    rateRow.BackgroundColor3=Color3.fromRGB(20,25,38);rateRow.BackgroundTransparency=0.3;rateRow.BorderSizePixel=0
    Instance.new("UICorner",rateRow).CornerRadius=UDim.new(0,8)
    local rS2=Instance.new("UIStroke",rateRow);rS2.Color=Color3.fromRGB(30,38,58);rS2.Thickness=1;rS2.Transparency=0.7
    local rP2=Instance.new("UIPadding",rateRow);rP2.PaddingLeft=UDim.new(0,12);rP2.PaddingRight=UDim.new(0,12);rP2.PaddingTop=UDim.new(0,8)
    local rTop=Instance.new("Frame",rateRow);rTop.Size=UDim2.new(1,0,0,18);rTop.BackgroundTransparency=1
    local rLbl=Instance.new("TextLabel",rTop);rLbl.Size=UDim2.new(0.6,0,1,0);rLbl.BackgroundTransparency=1
    rLbl.Text="Min Rate";rLbl.Font=Enum.Font.GothamMedium;rLbl.TextSize=11;rLbl.TextColor3=Color3.fromRGB(185,200,220);rLbl.TextXAlignment=Enum.TextXAlignment.Left
    local rVal=Instance.new("TextLabel",rTop);rVal.Size=UDim2.new(0.4,0,1,0);rVal.Position=UDim2.new(0.6,0,0,0)
    rVal.BackgroundTransparency=1;rVal.Text=rateValues[rateIdx];rVal.Font=Enum.Font.GothamBold;rVal.TextSize=11;rVal.TextColor3=C;rVal.TextXAlignment=Enum.TextXAlignment.Right
    local rBg=Instance.new("Frame",rateRow);rBg.Size=UDim2.new(1,0,0,8);rBg.Position=UDim2.fromOffset(0,32)
    rBg.BackgroundColor3=Color3.fromRGB(28,35,54);rBg.BorderSizePixel=0
    Instance.new("UICorner",rBg).CornerRadius=UDim.new(0,4)
    local rFi=Instance.new("Frame",rBg);rFi.Size=UDim2.new(rateIdx/#rateValues,0,1,0);rFi.BackgroundColor3=C;rFi.BorderSizePixel=0
    Instance.new("UICorner",rFi).CornerRadius=UDim.new(0,4)
    local rTd=Instance.new("Frame",rBg);rTd.Size=UDim2.fromOffset(14,14);rTd.AnchorPoint=Vector2.new(0.5,0.5)
    rTd.Position=UDim2.new(rateIdx/#rateValues,0,0.5,0);rTd.BackgroundColor3=Color3.fromRGB(255,255,255);rTd.BorderSizePixel=0
    Instance.new("UICorner",rTd).CornerRadius=UDim.new(0,7)
    local rTdS=Instance.new("UIStroke",rTd);rTdS.Color=C;rTdS.Thickness=2;rTdS.Transparency=0.4
    local TF2=TweenInfo.new(0.15,Enum.EasingStyle.Sine,Enum.EasingDirection.Out)
    local function setRate(idx)
        idx=math.clamp(math.floor(idx+0.5),1,#rateValues);rateIdx=idx
        local rel=idx/#rateValues
        TweenService:Create(rFi,TF2,{Size=UDim2.new(rel,0,1,0)}):Play()
        TweenService:Create(rTd,TF2,{Position=UDim2.new(rel,0,0.5,0)}):Play()
        rVal.Text=rateValues[idx];_G.SH_ESPMinRate=rateValues[idx]
        _G.SH_Config.espMinRate=rateValues[idx] -- proxy triggers auto-save via __newindex
    end
    local rDragging=false
    local function fromX2(x) local r=math.clamp((x-rBg.AbsolutePosition.X)/rBg.AbsoluteSize.X,0,1);setRate(1+r*(#rateValues-1)) end
    rBg.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then rDragging=true;fromX2(i.Position.X) end end)
    rBg.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then rDragging=false end end)
    UIS.InputChanged:Connect(function(i) if rDragging and i.UserInputType==Enum.UserInputType.MouseMovement then fromX2(i.Position.X) end end)

    mkSection(f,"Line To Base",Color3.fromRGB(0,200,255))
    do local _,_s,_g=mkToggle(f,"Line To Base",false,function(on)
        _G.SH_LineToBase=on
        if on then
            if _G.createPlotBeam then pcall(_G.createPlotBeam)
            else task.spawn(function()
                local t=0
                while not _G.createPlotBeam and t<10 do task.wait(0.3);t=t+0.3 end
                if _G.createPlotBeam then pcall(_G.createPlotBeam) end
            end) end
        else
            if _G.resetPlotBeam then pcall(_G.resetPlotBeam) end
        end
        if _G.SH_Config then _G.SH_Config.lineToBase=on end
        saveSettings()
    end,Color3.fromRGB(0,200,255))

    mkSection(f,"Base Owner ESP",Color3.fromRGB(255,100,100))
    local baseOwnerOn=false
    do local _,_s,_g=mkToggle(f,"Base Owner ESP",false,function(on)
        baseOwnerOn=on
        if on then if _G._SH_StartBaseOwnerESP then pcall(_G._SH_StartBaseOwnerESP) end
        else if _G._SH_StopBaseOwnerESP then pcall(_G._SH_StopBaseOwnerESP) end end
        saveSettings()
        if _G.SH_Config then _G.SH_Config.brainrotESP = on end
        saveSettings()
    end,Color3.fromRGB(255,100,100))
    registerToggle("Base Owner ESP", _s, _g)
end

    registerToggle("Line To Base", _s, _g)
end

    registerToggle("Brainrot ESP", _s, _g)
end


    mkSection(f,"Player ESP",Color3.fromRGB(100,200,255))
    do local _,_s,_g=mkToggle(f,"Player ESP",false,function(on)
        task.spawn(function()
            local t=0
            while not _G.SH_togglePlayerESP and t<10 do task.wait(0.3);t=t+0.3 end
            if _G.SH_togglePlayerESP then pcall(_G.SH_togglePlayerESP,on) end
        end)
        if _G.SH_Config then _G.SH_Config.playerESP = on end
        saveSettings()
    end,Color3.fromRGB(100,200,255))
    registerToggle("Player ESP",_s,_g)
end

    mkSection(f,"Base Timer ESP",Color3.fromRGB(255,220,0))
    local baseTimerOn=false
    do local _,_s,_g=mkToggle(f,"Base Timer ESP",false,function(on)
        baseTimerOn=on
        if on then if _G._SH_StartBaseTimerESP then pcall(_G._SH_StartBaseTimerESP) end
        else if _G._SH_StopBaseTimerESP then pcall(_G._SH_StopBaseTimerESP) end end
        saveSettings()
        if _G.SH_Config then _G.SH_Config.baseTimerESP = on end
        saveSettings()
    end,Color3.fromRGB(255,220,0))
    registerToggle("Base Timer ESP", _s, _g)
end

    -- ── Box ESP ───────────────────────────────────────────────────
    mkSection(f,"Box ESP",Color3.fromRGB(255,80,180))
    do local _,_s,_g=mkToggle(f,"Box ESP",false,function(on)
        task.spawn(function()
            local t=0
            while not _G._SH_StartBoxESP and t<10 do task.wait(0.3);t=t+0.3 end
            if on then
                if _G._SH_StartBoxESP then pcall(_G._SH_StartBoxESP) end
            else
                if _G._SH_StopBoxESP then pcall(_G._SH_StopBoxESP) end
            end
        end)
        if _G.SH_Config then _G.SH_Config.boxESP = on end
        saveSettings()
    end,Color3.fromRGB(255,80,180))
    registerToggle("Box ESP",_s,_g)
end


end

-- UI TAB
do local f=tabFrames["UI"];local C=TCOLORS["UI"]
    mkSection(f,"Open UI on Start",Color3.fromRGB(0,180,255))
    do local _,_s,_g=mkToggle(f,"Open UI on Start",
        (_SH_ConfigRaw and _SH_ConfigRaw.openOnStart ~= false) or true,
        function(on)
            if _SH_ConfigRaw then _SH_ConfigRaw.openOnStart = on end
            if _G.SH_Config  then _G.SH_Config.openOnStart  = on end
            saveSettings()
        end,Color3.fromRGB(0,180,255))
    registerToggle("Open UI on Start",_s,_g)
end

    mkSection(f,"Invisible Steal Panel",Color3.fromRGB(150,90,255))
    do local _,_s,_g=mkToggle(f,"Invisible Steal Panel",false,function(on)
        task.spawn(function()
            local t=0
            while not _G.SH_ShowInvisPanel and t<15 do task.wait(0.3);t=t+0.3 end
            if _G.SH_ShowInvisPanel then pcall(_G.SH_ShowInvisPanel,on) end
        end)
        saveSettings()
        if _G.SH_Config then _G.SH_Config.invisPanel = on end
        saveSettings()
    end,Color3.fromRGB(150,90,255))
    registerToggle("Invisible Steal Panel", _s, _g)
end

    mkSection(f,"Action Panel",Color3.fromRGB(56,140,255))
    do local _,_s,_g=mkToggle(f,"Action Panel",false,function(on)
        if _G.SH_ActionsPanel then
            _G.SH_ActionsPanel.Visible = on
        end
        if _G.SH_Config then _G.SH_Config.actionPanel = on end
        saveSettings()
    end,Color3.fromRGB(56,140,255))
    registerToggle("Action Panel",_s,_g)
end

    mkSection(f,"Steal Panel",Color3.fromRGB(80,160,255))
    do local _,_s,_g=mkToggle(f,"Steal Panel",false,function(on)
        task.spawn(function()
            local t=0
            while not _G.SH_ShowStealPanel and t<15 do task.wait(0.3);t=t+0.3 end
            if _G.SH_ShowStealPanel then pcall(_G.SH_ShowStealPanel,on) end
        end)
        if _G.SH_Config then _G.SH_Config.stealPanel=on end
        saveSettings()
    end,Color3.fromRGB(80,160,255))
    registerToggle("Steal Panel",_s,_g)
end

    mkSection(f,"Admin Panel",Color3.fromRGB(50,170,255))
    do local _,_s,_g=mkToggle(f,"Admin Panel",false,function(on)
        task.spawn(function()
            local t=0
            while not _G.SH_toggleAdminPanel and t<15 do task.wait(0.3);t=t+0.3 end
            if _G.SH_toggleAdminPanel then pcall(_G.SH_toggleAdminPanel,on) end
        end)
        if _G.SH_Config then _G.SH_Config.adminPanel=on end
        saveSettings()
    end,Color3.fromRGB(50,170,255))
    registerToggle("Admin Panel",_s,_g)
end

    do
        local _lr=Instance.new("Frame",f)
        _lr.Size=UDim2.new(1,-16,0,36);_lr.BackgroundTransparency=1
        local _ll=Instance.new("TextLabel",_lr)
        _ll.Size=UDim2.new(0.65,0,1,0);_ll.BackgroundTransparency=1
        _ll.Text="Lock All UIs";_ll.Font=Enum.Font.GothamBold;_ll.TextSize=13
        _ll.TextColor3=Color3.fromRGB(220,220,255);_ll.TextXAlignment=Enum.TextXAlignment.Left
        local _lb=Instance.new("TextButton",_lr)
        _lb.Size=UDim2.new(0,50,0,28);_lb.Position=UDim2.new(1,-50,0.5,-14)
        _lb.BackgroundColor3=Color3.fromRGB(30,30,50);_lb.BackgroundTransparency=0.3
        _lb.AutoButtonColor=false;_lb.Font=Enum.Font.GothamBold;_lb.TextSize=20
        Instance.new("UICorner",_lb).CornerRadius=UDim.new(0,8)
        _G.SH_UIsLocked=(_SH_ConfigRaw and _SH_ConfigRaw.uiLocked==true) or false
        local function _ul()
            _lb.Text=_G.SH_UIsLocked and "\xF0\x9F\x94\x92" or "\xF0\x9F\x94\x93"
            _lb.TextColor3=_G.SH_UIsLocked and Color3.fromRGB(255,80,80) or Color3.fromRGB(80,255,120)
            pcall(function()
                local pg=game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
                local sg=pg and pg:FindFirstChild("SH_StealPanel")
                local mf=sg and sg:FindFirstChild("MainFrame")
                if mf then mf.Draggable=not _G.SH_UIsLocked end
            end)
        end
        _ul()
        _lb.MouseButton1Click:Connect(function()
            _G.SH_UIsLocked=not _G.SH_UIsLocked;_ul()
            if _SH_ConfigRaw then _SH_ConfigRaw.uiLocked=_G.SH_UIsLocked end
            if _G.SH_Config then _G.SH_Config.uiLocked=_G.SH_UIsLocked end
            saveSettings()
        end)
    end
end

-- MISC TAB
do local f=tabFrames["Misc"];local C=TCOLORS.Misc
    mkSection(f,"Auto Grab",Color3.fromRGB(255,160,40))
    do local _,_s,_g=mkToggle(f,"Auto Grab",false,function(on)
        if _G.SabcomAutoSteal then
            pcall(_G.SabcomAutoSteal, on)
        else
            local _onCapture = on
            task.spawn(function()
                local deadline = tick() + 60
                while tick() < deadline do
                    if _G.SabcomAutoSteal then pcall(_G.SabcomAutoSteal, _onCapture); break end
                    task.wait(0.25)
                end
            end)
        end
        if _G.SH_Config then _G.SH_Config.autoGrab = on end
        if _SH_ConfigRaw ~= nil then _SH_ConfigRaw.autoGrab = on end
        pcall(function() if _G.SH_SaveConfig then _G.SH_SaveConfig() end end)
        saveSettings()
    end,Color3.fromRGB(255,160,40))
    registerToggle("Auto Grab", _s, _g)
end

    -- ── Steal Radius slider ───────────────────────────────────────
    mkSection(f,"Steal Radius",Color3.fromRGB(255,160,40))
    mkSlider(f,"Steal Radius (studs)",10,300,
        (_G.SH_Config and _G.SH_Config.stealRadius) or 95,
        function(v)
            if _G.SH_Config then _G.SH_Config.stealRadius = v end
            -- write into the live autograb Config table via bridge global
            if _G.JAF_SetStealRadius then pcall(_G.JAF_SetStealRadius, v)
            else
                -- direct write if bridge not defined yet
                pcall(function()
                    if Config then Config.StealRadius = v end
                end)
            end
            saveSettings()
        end,
        1, Color3.fromRGB(255,160,40))

    -- ── Autograb Speed slider (resolve interval) ──────────────────
    mkSection(f,"Autograb Speed",Color3.fromRGB(255,200,40))
    do
        -- _asResolveDt controls how often autograb checks for a steal target
        -- lower = faster. We expose it as ticks/sec so it reads intuitively.
        -- 0.006s = ~166 tps (max), 0.05s = 20 tps (slower)
        local function _dtToHz(dt) return math.floor(1/dt + 0.5) end
        local function _hzToDt(hz) return 1/math.max(hz, 10) end
        mkSlider(f,"Check Rate (tps)",10,200,
            _dtToHz(_G._asResolveDt or 0.012),
            function(v)
                local dt = _hzToDt(v)
                _G._asResolveDt = dt
                -- write into live variable via global bridge
                if _G.JAF_SetAutoGrabDt then pcall(_G.JAF_SetAutoGrabDt, dt) end
                if _G.SH_Config then _G.SH_Config.autoGrabHz = v end
                saveSettings()
            end,
            5, Color3.fromRGB(255,200,40))
    end

    mkSection(f,"Inf Jump",Color3.fromRGB(100,220,255))
    local infJumpOn=false;local isHoldingJump=false
    local ijC1,ijC2,ijC3=nil,nil,nil
    do local _,_s,_g=mkToggle(f,"Inf Jump",false,function(on)
        infJumpOn=on
        if on then
            ijC1=UIS.InputBegan:Connect(function(i,gp) if gp then return end;if i.KeyCode==Enum.KeyCode.Space or i.KeyCode==Enum.KeyCode.ButtonA then isHoldingJump=true end end)
            ijC2=UIS.InputEnded:Connect(function(i) if i.KeyCode==Enum.KeyCode.Space or i.KeyCode==Enum.KeyCode.ButtonA then isHoldingJump=false end end)
            ijC3=RunService.Heartbeat:Connect(function()
                if not isHoldingJump then return end
                local char=LP.Character;if not char then return end
                local hum=char:FindFirstChildOfClass("Humanoid");local root=char:FindFirstChild("HumanoidRootPart")
                if hum and root and root.AssemblyLinearVelocity.Y<(hum.JumpPower*0.8) then
                    root.AssemblyLinearVelocity=Vector3.new(root.AssemblyLinearVelocity.X,hum.JumpPower,root.AssemblyLinearVelocity.Z)
                end
            end)
            UIS.JumpRequest:Connect(function()
                if not infJumpOn then return end
                local char=LP.Character;if not char then return end
                local hum=char:FindFirstChildOfClass("Humanoid");local root=char:FindFirstChild("HumanoidRootPart")
                if hum and root then root.AssemblyLinearVelocity=Vector3.new(root.AssemblyLinearVelocity.X,hum.JumpPower,root.AssemblyLinearVelocity.Z) end
            end)
        else
            isHoldingJump=false
            if ijC1 then ijC1:Disconnect();ijC1=nil end
            if ijC2 then ijC2:Disconnect();ijC2=nil end
            if ijC3 then ijC3:Disconnect();ijC3=nil end
        end
        if _G.SH_Config then _G.SH_Config.infJump = on end
        saveSettings()
    end,Color3.fromRGB(100,220,255))
    registerToggle("Inf Jump", _s, _g)
end


    mkSection(f,"XRay",Color3.fromRGB(0,230,180))
    do local _,_s,_g=mkToggle(f,"XRay",false,function(on)
        task.spawn(function()
            local t=0
            while not _G.SH_toggleXRay and t<10 do task.wait(0.3);t=t+0.3 end
            if _G.SH_toggleXRay then pcall(_G.SH_toggleXRay,on) end
        end)
        saveSettings()
        if _G.SH_Config then _G.SH_Config.xray = on end
        saveSettings()
    end,Color3.fromRGB(0,230,180))
    registerToggle("XRay", _s, _g)
end


    mkSection(f,"Anti Ragdoll",Color3.fromRGB(255,140,0))
    do local _,_s,_g=mkToggle(f,"Anti Ragdoll",false,function(on)
        task.spawn(function()
            local t=0
            while not _G.SH_startAntiRagdoll and t<10 do task.wait(0.3);t=t+0.3 end
            if on then if _G.SH_startAntiRagdoll then pcall(_G.SH_startAntiRagdoll) end
            else if _G.SH_stopAntiRagdoll then pcall(_G.SH_stopAntiRagdoll) end end
        end)
        saveSettings()
        if _G.SH_Config then _G.SH_Config.antiRagdoll = on end
        saveSettings()
    end,Color3.fromRGB(255,140,0))
    registerToggle("Anti Ragdoll", _s, _g)
end


    mkSection(f,"Auto Kick on Steal",Color3.fromRGB(255,60,60))
    do local _,_s,_g=mkToggle(f,"Auto Kick on Steal",false,function(on)
        task.spawn(function()
            local t=0
            while not _G.SH_toggleAutoKick and t<10 do task.wait(0.3);t=t+0.3 end
            if _G.SH_toggleAutoKick then pcall(_G.SH_toggleAutoKick,on) end
        end)
        saveSettings()
        if _G.SH_Config then _G.SH_Config.autoKick = on end
        saveSettings()
    end,Color3.fromRGB(255,60,60))
    registerToggle("Auto Kick on Steal", _s, _g)
end


    mkSection(f,"Settings",C)
    -- Save Config Button mit Animation
local saveBtnFrame = Instance.new("Frame",f)
saveBtnFrame.Size = UDim2.new(1,0,0,38)
saveBtnFrame.BackgroundTransparency = 1
saveBtnFrame.BorderSizePixel = 0

local saveBtn = Instance.new("TextButton",saveBtnFrame)
saveBtn.Size = UDim2.fromScale(1,1)
saveBtn.BackgroundColor3 = C
saveBtn.BackgroundTransparency = 0.2
saveBtn.Text = "Save Config"
saveBtn.Font = Enum.Font.GothamBold
saveBtn.TextSize = 13
saveBtn.TextColor3 = Color3.fromRGB(255,255,255)
saveBtn.AutoButtonColor = false
saveBtn.BorderSizePixel = 0
Instance.new("UICorner",saveBtn).CornerRadius = UDim.new(0,8)

saveBtn.MouseButton1Click:Connect(function()
    local TS = _G.TOGGLE_STATES or {}

    -- Map GUI label strings → camelCase SH_Config keys (matches the load system)
    local toggleMapping = {
        ["Brainrot ESP"]          = "brainrotESP",
        ["Line To Base"]          = "lineToBase",
        ["Base Owner ESP"]        = "baseOwnerESP",
        ["Base Timer ESP"]        = "baseTimerESP",
        ["Auto Grab"]             = "autoGrab",
        ["Inf Jump"]              = "infJump",
        ["XRay"]                  = "xray",
        ["Anti Ragdoll"]          = "antiRagdoll",
        ["Auto Kick on Steal"]    = "autoKick",
        ["Invisible Steal Panel"] = "invisPanel",
        ["Carpet Speed"]          = "carpetSpeed",
    }

    -- Push all toggle states through the proxy (triggers auto-save via __newindex)
    for label, configKey in pairs(toggleMapping) do
        if TS[label] then
            _G.SH_Config[configKey] = TS[label].get()
        end
    end

    -- Push numeric/string values through the proxy
    _G.SH_Config.tpVelocity    = _G.TPVelocity
    _G.SH_Config.climbSpeed    = _G.MynxxClimb
    _G.SH_Config.closeSpeed    = _G.MynxxCloseSpeed
    _G.SH_Config.brainrotSpeed = _G.MynxxBrainrotSpeed
    _G.SH_Config.cloneDelay    = _G.SKY_CLONE_WAIT
    _G.SH_Config.settleMaxMs   = _G.MynxxSettleMaxMs
    _G.SH_Config.stallSec      = _G.MynxxStallSec
    _G.SH_Config.carpetSpeedVal= _G.SH_CarpetSpeedVal or 140
    _G.SH_Config.autoTp        = _G.MynxxAutoTP
    _G.SH_Config.stealMode     = _G.MynxxStealMode
    _G.SH_Config.espMinRate    = _G.SH_ESPMinRate
    if KEYBINDS and KEYBINDS.manualTP then
        _G.SH_Config.manualTPKey = KEYBINDS.manualTP.Name
    end

    -- Force an immediate flush to disk
    local ok = pcall(_G.SH_SaveConfig)

    if ok then
        saveBtn.Text = "Saved!"
        saveBtn.BackgroundColor3 = Color3.fromRGB(0,200,80)
        TweenService:Create(saveBtn,TweenInfo.new(0.15),{BackgroundTransparency=0}):Play()
        task.delay(1.5, function()
            saveBtn.Text = "Save Config"
            TweenService:Create(saveBtn,TweenInfo.new(0.3),{BackgroundColor3=C,BackgroundTransparency=0.2}):Play()
        end)
        print("[SH] Config gespeichert!")
    else
        saveBtn.Text = "Error!"
        saveBtn.BackgroundColor3 = Color3.fromRGB(220,60,60)
        task.delay(1.5, function()
            saveBtn.Text = "Save Config"
            TweenService:Create(saveBtn,TweenInfo.new(0.3),{BackgroundColor3=C,BackgroundTransparency=0.2}):Play()
        end)
    end
end)
    mkSection(f,"Kick to PS after Steal",Color3.fromRGB(255,70,70))
    do local _,_s,_g=mkToggle(f,"Kick to PS",false,function(on)
        task.spawn(function()
            local t=0
            while not _G.SH_toggleKickToPS and t<10 do task.wait(0.3);t=t+0.3 end
            if _G.SH_toggleKickToPS then pcall(_G.SH_toggleKickToPS,on) end
        end)
        if _G.SH_Config then _G.SH_Config.kickToPS=on end
        saveSettings()
    end,Color3.fromRGB(255,70,70))
    registerToggle("Kick to PS",_s,_g)
end
    do
        local _l=Instance.new("TextLabel",f)
        _l.Size=UDim2.new(1,-16,0,18);_l.BackgroundTransparency=1
        _l.Text="Private Server Code:";_l.Font=Enum.Font.Gotham;_l.TextSize=11
        _l.TextColor3=Color3.fromRGB(160,180,220);_l.TextXAlignment=Enum.TextXAlignment.Left
        local _b=Instance.new("TextBox",f)
        _b.Size=UDim2.new(1,-16,0,28);_b.BackgroundColor3=Color3.fromRGB(20,24,38)
        _b.BackgroundTransparency=0.3;_b.BorderSizePixel=0;_b.Font=Enum.Font.Gotham
        _b.TextSize=11;_b.TextColor3=Color3.fromRGB(220,230,255)
        _b.PlaceholderText="PS Code...";_b.PlaceholderColor3=Color3.fromRGB(80,90,120)
        _b.Text=(_SH_ConfigRaw and _SH_ConfigRaw.kickPsCode or "");_b.ClearTextOnFocus=false
        Instance.new("UICorner",_b).CornerRadius=UDim.new(0,6)
        _b.FocusLost:Connect(function()
            local c=_b.Text:gsub("%s+","");_b.Text=c
            if _G.SH_setKickToPSCode then pcall(_G.SH_setKickToPSCode,c) end
            if _SH_ConfigRaw then _SH_ConfigRaw.kickPsCode=c end
            if _G.SH_Config then _G.SH_Config.kickPsCode=c end
            saveSettings()
        end)
    end
end

-- NEEGY TAB
do local f=tabFrames["Neegy"];local C=Color3.fromRGB(200,168,75)
    mkSection(f,"RailTP Cruise",C)
    mkSlider(f,"Cruise Speed",100,1000,_G.SH_Config and _G.SH_Config.railCruise or 480,function(v)
        if _G.RailTP then pcall(_G.RailTP.setCruise,v) end
        if _G.SH_Config then _G.SH_Config.railCruise=v end
        saveSettings()
    end,10,C)

    mkSection(f,"Flight",C)
    do local _,_s,_g=mkToggle(f,"Flight Noclip",true,function(on)
        _G.SH_FlightNoclip=on
        if _G.SH_Config then _G.SH_Config.flightNoclip=on end
        saveSettings()
    end,C)
    registerToggle("Flight Noclip",_s,_g)
    end

    do local _,_s,_g=mkToggle(f,"Anti-Die",false,function(on)
        if on then if _G.SH_AntiDieOn then pcall(_G.SH_AntiDieOn) end
        else if _G.SH_AntiDieOff then pcall(_G.SH_AntiDieOff) end end
        if _G.SH_Config then _G.SH_Config.antiDie=on end
        saveSettings()
    end,Color3.fromRGB(255,100,100))
    registerToggle("Anti-Die",_s,_g)
    end

    mkSection(f,"Face Away",Color3.fromRGB(180,140,60))
    do local _,_s,_g=mkToggle(f,"Face Away Nearest",false,function(on)
        _G.SH_FaceAwayNearest=on
        if _G.SH_Config then _G.SH_Config.faceAway=on end
        saveSettings()
    end,Color3.fromRGB(180,140,60))
    registerToggle("Face Away",_s,_g)
    end

    do local _,_s,_g=mkToggle(f,"Face Away Owner",false,function(on)
        _G.SH_FaceAwayOwner=on
        if _G.SH_Config then _G.SH_Config.faceAwayOwner=on end
        saveSettings()
    end,Color3.fromRGB(180,140,60))
    registerToggle("Face Away Owner",_s,_g)
    end

    mkSection(f,"Base",Color3.fromRGB(160,120,40))
    do local _,_s,_g=mkToggle(f,"Base XRay",true,function(on)
        if on then if _G.SH_BaseXrayEnable then pcall(_G.SH_BaseXrayEnable) end
        else if _G.SH_BaseXrayDisable then pcall(_G.SH_BaseXrayDisable) end end
        if _G.SH_Config then _G.SH_Config.baseXray=on end
        saveSettings()
    end,Color3.fromRGB(160,120,40))
    registerToggle("Base XRay",_s,_g)
    end

    mkSlider(f,"Base XRay Alpha",0.1,1.0,0.9,function(v)
        _G.SH_BaseXrayAlpha=v
        if _G.SH_Config then _G.SH_Config.baseXrayAlpha=v end
        saveSettings()
    end,0.05,Color3.fromRGB(160,120,40))

    do local _,_s,_g=mkToggle(f,"Hide Collect Labels",true,function(on)
        _G.SH_HideCollect=on
        if _G.SH_Config then _G.SH_Config.hideCollect=on end
        saveSettings()
    end,Color3.fromRGB(160,120,40))
    registerToggle("Hide Collect",_s,_g)
    end

    mkSection(f,"ESP",Color3.fromRGB(200,168,75))
    do local _,_s,_g=mkToggle(f,"Pet XRay",true,function(on)
        _G.SH_PetXray=on
        if _G.SH_Config then _G.SH_Config.petXray=on end
        saveSettings()
    end,Color3.fromRGB(200,168,75))
    registerToggle("Pet XRay",_s,_g)
    end

    do local _,_s,_g=mkToggle(f,"ESP Path Line",false,function(on)
        _G.SH_ESPLineOn=on
        if not on and _G.SH_TPBeamHide then pcall(_G.SH_TPBeamHide) end
        if _G.SH_Config then _G.SH_Config.espLine=on end
        saveSettings()
    end,Color3.fromRGB(200,168,75))
    registerToggle("ESP Line",_s,_g)
    end

    mkSection(f,"Steal",Color3.fromRGB(255,180,60))
    mkSlider(f,"Steal Hold (s)",0.3,3.0,1.3,function(v)
        _G.SH_StealHoldDuration=v
        if _G.SH_Config then _G.SH_Config.stealHold=v end
        saveSettings()
    end,0.1,Color3.fromRGB(255,180,60))

    mkSlider(f,"Commit Range",10,60,28,function(v)
        _G.SH_StealCommitRange=v
        if _G.SH_Config then _G.SH_Config.stealCommitRange=v end
        saveSettings()
    end,1,Color3.fromRGB(255,180,60))

    do local _,_s,_g=mkToggle(f,"Priority Strict",false,function(on)
        _G.SH_PriorityStrict=on
        if _G.SH_Config then _G.SH_Config.priorityStrict=on end
        saveSettings()
    end,Color3.fromRGB(255,180,60))
    registerToggle("Priority Strict",_s,_g)
    end
end
-- ============================================================
-- SECTION 7: ENGINES BATCH 1
-- Actions Panel, HUD Bar + Dropdown Settings, Anti-Flasher,
-- Invis Steal Engine, WalkSpeed CFrame Bypass, Carpet Boost
-- ============================================================

--------------------------------------------------------------------------------
-- 7-A  ACTIONS PANEL (gold-themed, tabbed: Actions + Server Hop)
--------------------------------------------------------------------------------
do
    local ACT_ACCENT     = Color3.fromRGB(180,130,0)
    local ACT_ACCENT_LT  = Color3.fromRGB(255,210,60)
    local ACT_BG         = Color3.fromRGB(4,4,6)
    local ACT_PANEL      = Color3.fromRGB(10,10,14)
    local ACT_ROW        = Color3.fromRGB(14,14,18)
    local ACT_ROW_HOV    = Color3.fromRGB(22,18,8)
    local ACT_TEXT       = Color3.fromRGB(220,215,200)
    local ACT_DIM        = Color3.fromRGB(140,125,90)
    local ACT_STROKE     = Color3.fromRGB(130,90,0)
    local ACT_TF         = TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
    local ACT_TFM        = TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    -- Panel ScreenGui
    local actSG = Instance.new("ScreenGui")
    actSG.Name        = "SH_ActionsPanelSG"
    actSG.ResetOnSpawn= false
    actSG.IgnoreGuiInset = true
    actSG.DisplayOrder= 998
    actSG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() actSG.Parent = game:GetService("CoreGui") end)
    if not actSG.Parent then actSG.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") end

    -- Panel Frame
    local actPanel = Instance.new("Frame")
    actPanel.Name             = "ActionsPanel"
    actPanel.Size             = UDim2.new(0, 210, 0, 272)
    actPanel.Position         = UDim2.new(0, 20, 1, -292)
    actPanel.BackgroundColor3 = ACT_BG
    actPanel.BackgroundTransparency = 0
    actPanel.BorderSizePixel  = 0
    actPanel.ClipsDescendants = true
    actPanel.Visible          = false
    actPanel.Parent           = actSG
    Instance.new("UICorner", actPanel).CornerRadius = UDim.new(0, 14)
    local actStroke = Instance.new("UIStroke", actPanel)
    actStroke.Color       = ACT_ACCENT
    actStroke.Thickness   = 1.5
    actStroke.Transparency= 0.2
    actStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    -- animated gold shimmer on Action Panel
    task.spawn(function()
        local t=0
        while actPanel and actPanel.Parent do
            t=t+task.wait(0.016)
            actStroke.Transparency=0.15+math.sin(t*1.1)*0.08+math.sin(t*2.0+0.8)*0.04
            actStroke.Color=Color3.fromRGB(
                math.floor(160+math.sin(t*0.8)*22),
                math.floor(115+math.sin(t*1.6)*14),
                0)
        end
    end)

    -- Expose globally so the Misc toggle can reach it
    _G.SH_ActionsPanel = actPanel
    do
        local _ad,_as,_ap=false,nil,nil
        local _U=game:GetService("UserInputService")
        actPanel.InputBegan:Connect(function(i)
            if _G.SH_UIsLocked then return end
            if i.UserInputType==Enum.UserInputType.MouseButton1 then
                _ad=true;_as=i.Position;_ap=actPanel.Position
            end
        end)
        _U.InputEnded:Connect(function(i)
            if i.UserInputType==Enum.UserInputType.MouseButton1 then _ad=false; if _G._SH_saveUIPos then pcall(_G._SH_saveUIPos,"ActionsPanel",actPanel) end end
        end)
        _U.InputChanged:Connect(function(i)
            if _G.SH_UIsLocked then _ad=false;return end
            if _ad and i.UserInputType==Enum.UserInputType.MouseMovement then
                local d=i.Position-_as
                actPanel.Position=UDim2.new(_ap.X.Scale,_ap.X.Offset+d.X,_ap.Y.Scale,_ap.Y.Offset+d.Y)
            end
        end)
    end
    if _G._SH_loadUIPos then pcall(_G._SH_loadUIPos,"ActionsPanel",actPanel) end

    -- Glass sheen
    local sheen = Instance.new("Frame", actPanel)
    sheen.Size = UDim2.new(1, 0, 0, 56)
    sheen.BackgroundColor3 = Color3.fromRGB(255,255,255)
    sheen.BackgroundTransparency = 1
    sheen.BorderSizePixel = 0
    sheen.ZIndex = 2
    Instance.new("UICorner", sheen).CornerRadius = UDim.new(0, 14)
    local sheenGrad = Instance.new("UIGradient", sheen)
    sheenGrad.Rotation = 90
    sheenGrad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.87),
        NumberSequenceKeypoint.new(1, 1),
    })

    -- Accent bar (top gradient line)
    local accentBar = Instance.new("Frame", actPanel)
    accentBar.Size             = UDim2.new(1, 0, 0, 2)
    accentBar.BackgroundColor3 = ACT_ACCENT
    accentBar.BorderSizePixel  = 0
    local accentGrad = Instance.new("UIGradient", accentBar)
    accentGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, ACT_ACCENT),
        ColorSequenceKeypoint.new(1, ACT_ACCENT_LT),
    })

    -- Header
    local actHeader = Instance.new("Frame", actPanel)
    actHeader.Size               = UDim2.new(1, 0, 0, 42)
    actHeader.BackgroundTransparency = 1

    local actTitle = Instance.new("TextLabel", actHeader)
    actTitle.Size                = UDim2.new(1, -48, 0, 17)
    actTitle.Position            = UDim2.new(0, 14, 0, 7)
    actTitle.BackgroundTransparency = 1
    actTitle.Text                = "ACTION PANEL"
    actTitle.TextColor3          = Color3.fromRGB(255,220,60)
    actTitle.Font                = Enum.Font.GothamBlack
    actTitle.TextSize            = 12
    actTitle.TextXAlignment      = Enum.TextXAlignment.Left
    do
        local _ag=Instance.new("UIGradient",actTitle)
        _ag.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(140,95,0)),ColorSequenceKeypoint.new(0.3,Color3.fromRGB(230,170,20)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(255,235,100)),ColorSequenceKeypoint.new(0.7,Color3.fromRGB(230,170,20)),ColorSequenceKeypoint.new(1,Color3.fromRGB(140,95,0))})
        task.spawn(function() local t=0 while actTitle and actTitle.Parent do t=t+task.wait(0.016) _ag.Offset=Vector2.new(math.sin(t*0.75)*0.55+math.sin(t*1.4+1)*0.12,0) end end)
    end

    local actSub = Instance.new("TextLabel", actHeader)
    actSub.Size                  = UDim2.new(1, -48, 0, 13)
    actSub.Position              = UDim2.new(0, 14, 0, 24)
    actSub.BackgroundTransparency= 1
    actSub.Text                  = "Silence Hub Private"
    actSub.TextColor3            = ACT_DIM
    actSub.Font                  = Enum.Font.GothamMedium
    actSub.TextSize              = 10
    actSub.TextXAlignment        = Enum.TextXAlignment.Left

    -- Close button
    local actClose = Instance.new("TextButton", actHeader)
    actClose.Size                = UDim2.fromOffset(24, 24)
    actClose.Position            = UDim2.new(1, -30, 0, 9)
    actClose.BackgroundColor3    = Color3.fromRGB(180, 50, 65)
    actClose.BackgroundTransparency = 0.2
    actClose.Text                = "×"
    actClose.TextColor3          = Color3.fromRGB(255,255,255)
    actClose.Font                = Enum.Font.GothamBold
    actClose.TextSize            = 16
    actClose.AutoButtonColor     = false
    actClose.BorderSizePixel     = 0
    Instance.new("UICorner", actClose).CornerRadius = UDim.new(0, 6)
    actClose.MouseEnter:Connect(function()
        TweenService:Create(actClose, ACT_TF, {BackgroundTransparency=0}):Play()
    end)
    actClose.MouseLeave:Connect(function()
        TweenService:Create(actClose, ACT_TF, {BackgroundTransparency=0.2}):Play()
    end)
    actClose.MouseButton1Click:Connect(function()
        actPanel.Visible = false
        local ts = _G.TOGGLE_STATES
        if ts and ts["Action Panel"] then pcall(ts["Action Panel"].set, false) end
    end)

    -- Draggable header
    do
        local _drag, _dS, _dP = false, nil, nil
        actHeader.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or
               i.UserInputType == Enum.UserInputType.Touch then
                _drag = true; _dS = i.Position; _dP = actPanel.Position
            end
        end)
        game:GetService("UserInputService").InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or
               i.UserInputType == Enum.UserInputType.Touch then
                _drag = false
            end
        end)
        game:GetService("UserInputService").InputChanged:Connect(function(i)
            if _drag and (i.UserInputType == Enum.UserInputType.MouseMovement or
                          i.UserInputType == Enum.UserInputType.Touch) then
                local d = i.Position - _dS
                actPanel.Position = UDim2.new(
                    _dP.X.Scale, _dP.X.Offset + d.X,
                    _dP.Y.Scale, _dP.Y.Offset + d.Y
                )
            end
        end)
    end

    -- Header divider
    local actDiv = Instance.new("Frame", actPanel)
    actDiv.Size             = UDim2.new(1, -24, 0, 1)
    actDiv.Position         = UDim2.new(0, 12, 0, 42)
    actDiv.BackgroundColor3 = ACT_ACCENT
    actDiv.BackgroundTransparency = 0.65
    actDiv.BorderSizePixel  = 0

    -- Button factory for the panel
    local function actBtn(parent, label, yOff, callback)
        local row = Instance.new("Frame", parent)
        row.Size              = UDim2.new(1, 0, 0, 40)
        row.BackgroundColor3  = ACT_PANEL
        row.BackgroundTransparency = 0.28
        row.BorderSizePixel   = 0
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 9)
        local rowS = Instance.new("UIStroke", row)
        rowS.Color       = ACT_STROKE
        rowS.Thickness   = 1
        rowS.Transparency= 0.72
        rowS.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

        local btn = Instance.new("TextButton", row)
        btn.Size              = UDim2.fromScale(1, 1)
        btn.BackgroundTransparency = 1
        btn.Text              = label
        btn.TextColor3        = ACT_TEXT
        btn.Font              = Enum.Font.GothamMedium
        btn.TextSize          = 13
        btn.AutoButtonColor   = false
        btn.BorderSizePixel   = 0

        -- Left accent dot
        local dot = Instance.new("Frame", btn)
        dot.Size              = UDim2.fromOffset(4, 4)
        dot.Position          = UDim2.new(0, 12, 0.5, -2)
        dot.BackgroundColor3  = ACT_ACCENT
        dot.BorderSizePixel   = 0
        dot.BackgroundTransparency = 0.3
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

        btn.MouseEnter:Connect(function()
            TweenService:Create(row, ACT_TF, {BackgroundColor3=ACT_ROW_HOV, BackgroundTransparency=0.12}):Play()
            TweenService:Create(rowS, ACT_TF, {Transparency=0.35}):Play()
            TweenService:Create(dot, ACT_TF, {BackgroundTransparency=0}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(row, ACT_TF, {BackgroundColor3=ACT_PANEL, BackgroundTransparency=0.28}):Play()
            TweenService:Create(rowS, ACT_TF, {Transparency=0.72}):Play()
            TweenService:Create(dot, ACT_TF, {BackgroundTransparency=0.3}):Play()
        end)
        btn.MouseButton1Click:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.08), {BackgroundTransparency=0}):Play()
            task.delay(0.12, function()
                TweenService:Create(row, ACT_TF, {BackgroundTransparency=0.28}):Play()
            end)
            pcall(callback)
        end)
        return row
    end

    -- ── ACTION PANEL TAB BAR ───────────────────────────────────────────
    actPanel.Size = UDim2.new(0, 210, 0, 305)

    local ACT_TAB_H = 26
    local actTabBar = Instance.new("Frame", actPanel)
    actTabBar.Size             = UDim2.new(1, -24, 0, ACT_TAB_H)
    actTabBar.Position         = UDim2.new(0, 12, 0, 48)
    actTabBar.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
    actTabBar.BorderSizePixel  = 0
    Instance.new("UICorner", actTabBar).CornerRadius = UDim.new(0, 6)

    local ACT_TABS = {"Actions", "Server Hop"}
    local actTabFrames = {}
    local actTabBtns   = {}
    local actActiveTab = "Actions"

    local actTabW = math.floor(186 / #ACT_TABS)
    for ti, tname in ipairs(ACT_TABS) do
        local tbtn = Instance.new("TextButton", actTabBar)
        tbtn.Size             = UDim2.fromOffset(actTabW, ACT_TAB_H - 4)
        tbtn.Position         = UDim2.fromOffset((ti-1)*actTabW + 2, 2)
        tbtn.BackgroundColor3 = (ti==1) and ACT_ACCENT or Color3.fromRGB(0,0,0)
        tbtn.BackgroundTransparency = (ti==1) and 0 or 1
        tbtn.BorderSizePixel  = 0
        tbtn.Text             = tname
        tbtn.Font             = Enum.Font.GothamBold
        tbtn.TextSize         = 10
        tbtn.TextColor3       = (ti==1) and Color3.fromRGB(255,255,255) or Color3.fromRGB(110,90,40)
        tbtn.AutoButtonColor  = false
        tbtn.ZIndex           = 6
        Instance.new("UICorner", tbtn).CornerRadius = UDim.new(0, 5)
        actTabBtns[tname] = tbtn

        local cf = Instance.new("Frame", actPanel)
        cf.Size               = UDim2.new(1, -24, 1, -(48 + ACT_TAB_H + 6))
        cf.Position           = UDim2.new(0, 12, 0, 48 + ACT_TAB_H + 4)
        cf.BackgroundTransparency = 1
        cf.BorderSizePixel    = 0
        cf.Visible            = (ti == 1)
        cf.ZIndex             = 5
        actTabFrames[tname]   = cf
    end

    local function showActTab(name)
        actActiveTab = name
        for tname, cf in pairs(actTabFrames) do cf.Visible = (tname == name) end
        for tname, btn in pairs(actTabBtns) do
            if tname == name then
                btn.BackgroundColor3 = ACT_ACCENT
                btn.BackgroundTransparency = 0
                btn.TextColor3 = Color3.fromRGB(255,255,255)
            else
                btn.BackgroundColor3 = Color3.fromRGB(0,0,0)
                btn.BackgroundTransparency = 1
                btn.TextColor3 = Color3.fromRGB(110,90,40)
            end
        end
    end
    for tname, btn in pairs(actTabBtns) do
        btn.MouseButton1Click:Connect(function() showActTab(tname) end)
    end

    -- ── ACTIONS TAB (existing buttons) ────────────────────────────────
    local actList = Instance.new("Frame", actTabFrames["Actions"])
    actList.Size              = UDim2.new(1, 0, 1, 0)
    actList.BackgroundTransparency = 1
    local actLayout = Instance.new("UIListLayout", actList)
    actLayout.Padding         = UDim.new(0, 7)
    actLayout.SortOrder       = Enum.SortOrder.LayoutOrder
    actLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    -- Helper: leave/kick logic
    local function doLeave()
        pcall(function() game:GetService("GuiService"):LeaveGame() end)
        pcall(function() game:Shutdown() end)
    end
    local function doRejoinJob()
        local PS = game:GetService("Players")
        if #PS:GetPlayers() <= 1 then
            game:GetService("TeleportService"):Teleport(game.PlaceId, PS.LocalPlayer)
        else
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, PS.LocalPlayer)
        end
    end
    local function doRejoinPs()
        local PS = game:GetService("Players")
        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, PS.LocalPlayer)
    end
    local function doKick()
        local fired = false
        pcall(function()
            for _, gui in ipairs(game:GetService("CoreGui"):GetDescendants()) do
                if gui:IsA("TextButton")
                    and (gui.Text=="Leave" or gui.Text=="Verlassen" or gui.Name=="ConfirmButton")
                then
                    gui:activate(); fired = true; break
                end
            end
        end)
        if not fired then doLeave() end
    end
    local function doInstaReset()
        if _G.SH_InstaReset then pcall(_G.SH_InstaReset) end
    end

    actBtn(actList, "⟳  Insta Reset",   0, doInstaReset)
    actBtn(actList, "↻  Rejoin Job Id",  0, doRejoinJob)
    actBtn(actList, "↺  Rejoin PS",      0, doRejoinPs)
    actBtn(actList, "✕  Kick",           0, doKick)

    -- ── SERVER HOP TAB ────────────────────────────────────────────────
    do
        local shFrame = actTabFrames["Server Hop"]

        local shStatus = Instance.new("TextLabel", shFrame)
        shStatus.Size             = UDim2.new(1, 0, 0, 28)
        shStatus.Position         = UDim2.fromOffset(0, 0)
        shStatus.BackgroundTransparency = 1
        shStatus.Text             = "Ready"
        shStatus.Font             = Enum.Font.GothamMedium
        shStatus.TextSize         = 11
        shStatus.TextColor3       = Color3.fromRGB(140,210,140)
        shStatus.TextXAlignment   = Enum.TextXAlignment.Center
        shStatus.ZIndex           = 6

        local shInfo = Instance.new("TextLabel", shFrame)
        shInfo.Size               = UDim2.new(1, 0, 0, 24)
        shInfo.Position           = UDim2.fromOffset(0, 28)
        shInfo.BackgroundTransparency = 1
        shInfo.Text               = ""
        shInfo.Font               = Enum.Font.Gotham
        shInfo.TextSize           = 9
        shInfo.TextColor3         = Color3.fromRGB(160,140,100)
        shInfo.TextXAlignment     = Enum.TextXAlignment.Center
        shInfo.TextWrapped        = true
        shInfo.ZIndex             = 6

        -- HOP button
        local hopRow = Instance.new("Frame", shFrame)
        hopRow.Size               = UDim2.new(1, 0, 0, 44)
        hopRow.Position           = UDim2.fromOffset(0, 56)
        hopRow.BackgroundColor3   = Color3.fromRGB(14, 100, 40)
        hopRow.BackgroundTransparency = 0.15
        hopRow.BorderSizePixel    = 0
        Instance.new("UICorner", hopRow).CornerRadius = UDim.new(0, 9)
        local hopStroke = Instance.new("UIStroke", hopRow)
        hopStroke.Color           = Color3.fromRGB(60, 220, 100)
        hopStroke.Thickness       = 1
        hopStroke.Transparency    = 0.55

        local hopBtn = Instance.new("TextButton", hopRow)
        hopBtn.Size               = UDim2.fromScale(1,1)
        hopBtn.BackgroundTransparency = 1
        hopBtn.Text               = "⚡  HOP SERVER"
        hopBtn.Font               = Enum.Font.GothamBold
        hopBtn.TextSize           = 13
        hopBtn.TextColor3         = Color3.fromRGB(100, 255, 140)
        hopBtn.AutoButtonColor    = false
        hopBtn.BorderSizePixel    = 0
        hopBtn.ZIndex             = 7

        local hopDot = Instance.new("Frame", hopBtn)
        hopDot.Size               = UDim2.fromOffset(4,4)
        hopDot.Position           = UDim2.new(0,12,0.5,-2)
        hopDot.BackgroundColor3   = Color3.fromRGB(60,255,120)
        hopDot.BorderSizePixel    = 0
        hopDot.BackgroundTransparency = 0.3
        Instance.new("UICorner", hopDot).CornerRadius = UDim.new(1,0)

        hopBtn.MouseEnter:Connect(function()
            TweenService:Create(hopRow, ACT_TF, {BackgroundColor3=Color3.fromRGB(20,140,55), BackgroundTransparency=0.05}):Play()
            TweenService:Create(hopStroke, ACT_TF, {Transparency=0.2}):Play()
        end)
        hopBtn.MouseLeave:Connect(function()
            TweenService:Create(hopRow, ACT_TF, {BackgroundColor3=Color3.fromRGB(14,100,40), BackgroundTransparency=0.15}):Play()
            TweenService:Create(hopStroke, ACT_TF, {Transparency=0.55}):Play()
        end)

        -- fetch + teleport logic
        local _shHopping = false
        local _SH_FETCHER_URL = "https://swagyfinder-production.up.railway.app/get_server"

        local function doServerHop()
            if _shHopping then return end
            _shHopping = true
            hopBtn.Text = "⏳  Fetching..."
            hopBtn.TextColor3 = Color3.fromRGB(255,210,80)
            shStatus.Text = "Contacting fetcher..."
            shStatus.TextColor3 = Color3.fromRGB(255,210,80)
            shInfo.Text = ""

            task.spawn(function()
                local ok, result = pcall(function()
                    local HttpService = game:GetService("HttpService")
                    local _reqFn = (type(syn) == "table" and syn.request)
                        or (type(http) == "table" and http.request)
                        or (type(request) == "function" and request)
                        or (type(http_request) == "function" and http_request)
                    local resp
                    if _reqFn then
                        local res = _reqFn({ Url = _SH_FETCHER_URL, Method = "GET" })
                        resp = res and (res.Body or res.body or res.Content or "")
                    else
                        resp = HttpService:GetAsync(_SH_FETCHER_URL, true)
                    end
                    return HttpService:JSONDecode(resp)
                end)

                if not ok or type(result) ~= "table" then
                    shStatus.Text = "Fetch failed"
                    shStatus.TextColor3 = Color3.fromRGB(255,80,80)
                    shInfo.Text = tostring(result):sub(1,60)
                    hopBtn.Text = "⚡  HOP SERVER"
                    hopBtn.TextColor3 = Color3.fromRGB(100,255,140)
                    _shHopping = false
                    return
                end

                local jobId = result.jobId or result.job_id or result.JobId or result.id
                if not jobId or jobId == "" then
                    shStatus.Text = "No job ID in response"
                    shStatus.TextColor3 = Color3.fromRGB(255,80,80)
                    shInfo.Text = "Check fetcher endpoint"
                    hopBtn.Text = "⚡  HOP SERVER"
                    hopBtn.TextColor3 = Color3.fromRGB(100,255,140)
                    _shHopping = false
                    return
                end

                shStatus.Text = "Hopping..."
                shStatus.TextColor3 = Color3.fromRGB(100,255,140)
                shInfo.Text = jobId:sub(1,28).."..."

                task.wait(0.3)
                pcall(function()
                    local PS  = game:GetService("Players")
                    local TS  = game:GetService("TeleportService")
                    TS:TeleportToPlaceInstance(game.PlaceId, jobId, PS.LocalPlayer)
                end)

                task.wait(3)
                shStatus.Text = "Hop sent — waiting"
                hopBtn.Text = "⚡  HOP SERVER"
                hopBtn.TextColor3 = Color3.fromRGB(100,255,140)
                _shHopping = false
            end)
        end

        hopBtn.MouseButton1Click:Connect(function()
            TweenService:Create(hopRow, TweenInfo.new(0.08), {BackgroundTransparency=0}):Play()
            task.delay(0.12, function()
                TweenService:Create(hopRow, ACT_TF, {BackgroundTransparency=0.15}):Play()
            end)
            doServerHop()
        end)

        _G.SH_ServerHop = doServerHop
    end

    -- Keybind listeners (wired to KEYBINDS table)
    game:GetService("UserInputService").InputBegan:Connect(function(inp, gp)
        if gp then return end
        if game:GetService("UserInputService"):GetFocusedTextBox() then return end
        local k = inp.KeyCode
        if k == KEYBINDS.instaReset  then doInstaReset() end
        if k == KEYBINDS.rejoinJob   then doRejoinJob()  end
        if k == KEYBINDS.rejoinPs    then doRejoinPs()   end
        if k == KEYBINDS.kick        then doKick()        end
    end)

end -- Actions Panel END


--------------------------------------------------------------------------------
-- 7-B  HUD BAR + DROPDOWN SETTINGS
--------------------------------------------------------------------------------
do
-- ── TOP HUD BAR (moved to top + dropdown settings) ──────────────────
local hud=Instance.new("Frame",sg)
hud.Size=UDim2.fromOffset(640,44)
hud.AnchorPoint=Vector2.new(0.5,0)
hud.Position=UDim2.new(0.5,0,0,6)
hud.BackgroundColor3=Color3.fromRGB(4,4,6)
hud.BackgroundTransparency=0
hud.BorderSizePixel=0
hud.ClipsDescendants=false
Instance.new("UICorner",hud).CornerRadius=UDim.new(0,8)
local hudS=Instance.new("UIStroke",hud);hudS.Color=Color3.fromRGB(160,120,0);hudS.Thickness=1.2;hudS.Transparency=0.2
local hudG=Instance.new("UIGradient");hudG.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(100,70,0)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(255,210,60)),ColorSequenceKeypoint.new(1,Color3.fromRGB(100,70,0))});hudG.Rotation=0;hudG.Parent=hudS
-- wave shimmer on HUD gold border
task.spawn(function()
    local t=0
    while hud and hud.Parent do
        t=t+task.wait(0.016)
        hudG.Offset=Vector2.new(math.sin(t*1.1)*0.7+math.sin(t*2.3)*0.2,0)
        hudG.Rotation=math.sin(t*0.6)*12
        hudS.Transparency=0.1+math.sin(t*1.8)*0.12
        hudS.Thickness=1.5+math.sin(t*2.0)*0.5
    end
end)

-- brand label
local brandL=Instance.new("TextLabel",hud)
brandL.Size=UDim2.new(1,-140,1,0);brandL.Position=UDim2.fromOffset(16,0)
brandL.BackgroundTransparency=1
brandL.Text="Silence Hub  |  @sqz8  |  @fehlenentscheidung"
brandL.Font=Enum.Font.GothamBlack;brandL.TextSize=15
brandL.TextColor3=Color3.fromRGB(255,210,60);brandL.TextXAlignment=Enum.TextXAlignment.Left
local brandGrad=Instance.new("UIGradient",brandL)
brandGrad.Rotation=0
task.spawn(function()
    local t=0
    while brandL and brandL.Parent do
        t=t+task.wait(0.016)
        local wave = math.sin(t*1.4)*0.55
        local wave2= math.sin(t*2.1+1)*0.12
        brandGrad.Offset=Vector2.new(wave+wave2,0)
        brandGrad.Rotation=math.sin(t*0.9)*8
        brandGrad.Color=ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Color3.fromRGB(120,80,0)),
            ColorSequenceKeypoint.new(0.2+math.sin(t*1.1)*0.1, Color3.fromRGB(220,160,0)),
            ColorSequenceKeypoint.new(0.45+math.sin(t*1.7)*0.08,Color3.fromRGB(255,240,130)),
            ColorSequenceKeypoint.new(0.7+math.sin(t*1.3)*0.08, Color3.fromRGB(230,170,10)),
            ColorSequenceKeypoint.new(1,   Color3.fromRGB(120,80,0)),
        })
    end
end)

-- stats label (fps/ping)
local statsL=Instance.new("TextLabel",hud)
statsL.Size=UDim2.new(0,150,1,0);statsL.Position=UDim2.new(1,-194,0,0)
statsL.BackgroundTransparency=1;statsL.RichText=true
statsL.TextXAlignment=Enum.TextXAlignment.Right
statsL.Font=Enum.Font.GothamBold;statsL.TextSize=11;statsL.Text="FPS: -- | Ping: --ms"

-- dropdown arrow button
local arrowBtn=Instance.new("TextButton",hud)
arrowBtn.Size=UDim2.fromOffset(34,34);arrowBtn.Position=UDim2.new(1,-40,0,0)
arrowBtn.BackgroundTransparency=1;arrowBtn.Text="⌄"
arrowBtn.Font=Enum.Font.GothamBold;arrowBtn.TextSize=16
arrowBtn.TextColor3=Color3.fromRGB(140,170,220);arrowBtn.ZIndex=5

-- ── TABBED DROPDOWN SETTINGS PANEL ─────────────────────────────────
local DROP_TABS = {"ESP","TP","Misc","UI","Perf","PRI"}
local DROP_TAB_CONTENT = {
    ESP  = {"Brainrot ESP","Line To Base","Base Owner ESP","Player ESP","Base Timer ESP"},
    TP   = {},
    Misc = {"Auto Grab","Inf Jump","XRay","Anti Ragdoll","Auto Kick on Steal","Kick to PS"},
    UI   = {"Open UI on Start","Invisible Steal Panel","Action Panel","Steal Panel","Admin Panel"},
    Perf = {"Loader Screen","FPS Boost","Anti Flasher"},
    PRI  = {},
}

local ROW_H   = 32
local TAB_H   = 28
local PAD     = 6
local COLS    = Color3.fromRGB(6,6,9)
local COL_TAB = Color3.fromRGB(10,10,14)
local COL_SEL = Color3.fromRGB(180,130,0)
local COL_TXT = Color3.fromRGB(210,210,220)
local TweenService2 = game:GetService("TweenService")
local TF2 = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local maxRows = 0
for _, rows in pairs(DROP_TAB_CONTENT) do
    if #rows > maxRows then maxRows = #rows end
end
local dropH = TAB_H + PAD + maxRows * ROW_H + PAD + 4

local dropPanel = Instance.new("Frame", sg)
dropPanel.Size   = UDim2.new(0,580,0,dropH)
dropPanel.AnchorPoint = Vector2.new(0.5,0)
dropPanel.Position = UDim2.new(0.5,0,0,50)
dropPanel.BackgroundColor3 = Color3.fromRGB(6,6,9)
dropPanel.BackgroundTransparency = 0
dropPanel.BorderSizePixel = 0
dropPanel.ClipsDescendants = true
dropPanel.Visible = false
dropPanel.ZIndex  = 20
Instance.new("UICorner",dropPanel).CornerRadius = UDim.new(0,0)
local dpStroke = Instance.new("UIStroke",dropPanel)
dpStroke.Color = Color3.fromRGB(160,120,0); dpStroke.Thickness=1; dpStroke.Transparency=0.3

-- Tab bar
local tabBar = Instance.new("Frame", dropPanel)
tabBar.Size = UDim2.new(1,0,0,TAB_H)
tabBar.Position = UDim2.fromOffset(0,0)
tabBar.BackgroundColor3 = Color3.fromRGB(10,10,14)
tabBar.BorderSizePixel = 0
Instance.new("UICorner",tabBar).CornerRadius = UDim.new(0,0)

-- Content area
local contentArea = Instance.new("Frame", dropPanel)
contentArea.Size = UDim2.new(1,0,1,-TAB_H)
contentArea.Position = UDim2.fromOffset(0,TAB_H)
contentArea.BackgroundTransparency = 1
contentArea.BorderSizePixel = 0
contentArea.ClipsDescendants = true

local tabFrameMap = {}
local tabBtnMap   = {}
local activeTabName = DROP_TABS[1]

-- Label -> config key map for auto-saving dropdown toggles
local DROP_TOGGLE_MAP = {
    ["Brainrot ESP"]          = "brainrotESP",
    ["Line To Base"]          = "lineToBase",
    ["Base Owner ESP"]        = "baseOwnerESP",
    ["Base Timer ESP"]        = "baseTimerESP",
    ["Player ESP"]            = "playerESP",
    ["Auto Grab"]             = "autoGrab",
    ["Inf Jump"]              = "infJump",
    ["XRay"]                  = "xray",
    ["Anti Ragdoll"]          = "antiRagdoll",
    ["Auto Kick on Steal"]    = "autoKick",
    ["Kick to PS"]            = "kickToPS",
    ["Invisible Steal Panel"] = "invisPanel",
    ["Steal Panel"]           = "stealPanel",
    ["Admin Panel"]           = "adminPanel",
    ["Action Panel"]          = "actionPanel",
    ["Open UI on Start"]      = "openOnStart",
    ["Loader Screen"]         = "loaderScreen",
    ["FPS Boost"]             = "fpsBoost",
    ["Anti Flasher"]          = "antiFlasher",
}
local function _saveDropToggle(label, state)
    local ckey = DROP_TOGGLE_MAP[label]
    if ckey then
        _SH_ConfigRaw[ckey] = state
        if _G.SH_Config then
            pcall(function() _G.SH_Config[ckey] = state end)
        end
    end
    pcall(saveConfig)
end

local function buildMiniToggle(parent, yOff, label, getVal, setVal)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1,-16,0,ROW_H-2)
    row.Position = UDim2.fromOffset(8, yOff)
    row.BackgroundColor3 = Color3.fromRGB(12,12,16)
    row.BackgroundTransparency = 0
    row.BorderSizePixel = 0
    Instance.new("UICorner",row).CornerRadius = UDim.new(0,4)

    local lbl = Instance.new("TextLabel",row)
    lbl.Size = UDim2.new(1,-60,1,0)
    lbl.Position = UDim2.fromOffset(10,0)
    lbl.BackgroundTransparency=1; lbl.Text=label
    lbl.Font=Enum.Font.GothamMedium; lbl.TextSize=11
    lbl.TextColor3=COL_TXT; lbl.TextXAlignment=Enum.TextXAlignment.Left

    local initV = pcall(getVal) and getVal() or false
    local tog = Instance.new("TextButton",row)
    tog.Size = UDim2.fromOffset(40,18)
    tog.AnchorPoint = Vector2.new(1,0.5)
    tog.Position = UDim2.new(1,-8,0.5,0)
    tog.BackgroundColor3 = initV and Color3.fromRGB(160,115,0) or Color3.fromRGB(20,14,4)
    tog.BorderSizePixel=0; tog.Text=""
    Instance.new("UICorner",tog).CornerRadius = UDim.new(1,0)
    local nob = Instance.new("Frame",tog)
    nob.Size = UDim2.fromOffset(14,14)
    nob.AnchorPoint = Vector2.new(0,0.5)
    nob.Position = initV and UDim2.new(1,-16,0.5,0) or UDim2.fromOffset(2,9)
    nob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    nob.BorderSizePixel = 0
    Instance.new("UICorner",nob).CornerRadius = UDim.new(1,0)

    local state = initV
    tog.MouseButton1Click:Connect(function()
        state = not state
        tog.BackgroundColor3 = state and Color3.fromRGB(160,115,0) or Color3.fromRGB(20,14,4)
        nob.Position = state and UDim2.new(1,-16,0.5,0) or UDim2.fromOffset(2,9)
        pcall(setVal, state)
        if _G.TOGGLE_STATES and _G.TOGGLE_STATES[label] then
            pcall(_G.TOGGLE_STATES[label].set, state)
        end
        _saveDropToggle(label, state)
    end)
end

local dpOpen = false
local TP_DROP_H = 330
local function showTab(name)
    activeTabName = name
    for tname, fr in pairs(tabFrameMap) do
        fr.Visible = (tname == name)
    end
    for tname, btn in pairs(tabBtnMap) do
        if tname == name then
            btn.BackgroundColor3 = COL_SEL
            btn.TextColor3 = Color3.fromRGB(255,255,255)
        else
            btn.BackgroundColor3 = Color3.fromRGB(0,0,0)
            btn.BackgroundTransparency = 1
            btn.TextColor3 = Color3.fromRGB(105,90,50)
        end
    end
    if dpOpen and dropPanel.Visible then
        local tH = ((name=="TP") or (name=="PRI")) and TP_DROP_H or dropH
        TweenService2:Create(dropPanel, TF2, {Size=UDim2.new(0,580,0,tH)}):Play()
    end
end

local tabW = math.floor(580 / #DROP_TABS)
for i, tname in ipairs(DROP_TABS) do
    local tbtn = Instance.new("TextButton", tabBar)
    tbtn.Size = UDim2.fromOffset(tabW, TAB_H)
    tbtn.Position = UDim2.fromOffset((i-1)*tabW, 0)
    tbtn.BackgroundTransparency = 1
    tbtn.Text = tname
    tbtn.Font = Enum.Font.GothamBold; tbtn.TextSize = 11
    tbtn.TextColor3 = Color3.fromRGB(105,90,50)
    tbtn.BorderSizePixel = 0
    tbtn.ZIndex = 22
    if i==1 then Instance.new("UICorner",tbtn).CornerRadius=UDim.new(0,8) end
    tabBtnMap[tname] = tbtn

    local cf = Instance.new("Frame", contentArea)
    cf.Size = UDim2.new(1,0,1,0)
    cf.BackgroundTransparency = 1
    cf.BorderSizePixel = 0
    cf.Visible = false
    cf.ZIndex = 21
    tabFrameMap[tname] = cf

    local rows = DROP_TAB_CONTENT[tname]
    for ri, rowLabel in ipairs(rows) do
        local yOff = PAD + (ri-1)*ROW_H
            buildMiniToggle(cf, yOff, rowLabel,
                function()
                    local ck = DROP_TOGGLE_MAP[rowLabel]
                    if ck and _SH_ConfigRaw then
                        return _SH_ConfigRaw[ck] == true
                    end
                    if _G.TOGGLE_STATES and _G.TOGGLE_STATES[rowLabel] then
                        return _G.TOGGLE_STATES[rowLabel].get()
                    end
                    return false
                end,
                function(v)
                    if _G.TOGGLE_STATES and _G.TOGGLE_STATES[rowLabel] then
                        pcall(_G.TOGGLE_STATES[rowLabel].set, v)
                    end
                end)
    end

    tbtn.MouseButton1Click:Connect(function() showTab(tname) end)
end

showTab(DROP_TABS[1])

-- ── Custom TP Tab Builder ─────────────────────────────────────────────────────
do
    local cf = tabFrameMap["TP"]

    local outer = Instance.new("Frame", cf)
    outer.Size = UDim2.new(1,0,1,0)
    outer.BackgroundTransparency = 1; outer.BorderSizePixel = 0; outer.ZIndex = 22

    local yHeader = PAD

    local selHdr = Instance.new("TextLabel", outer)
    selHdr.Size=UDim2.new(1,-16,0,18); selHdr.Position=UDim2.fromOffset(8,yHeader)
    selHdr.BackgroundTransparency=1; selHdr.Text="TP ENGINE"
    selHdr.Font=Enum.Font.GothamBold; selHdr.TextSize=10
    selHdr.TextColor3=Color3.fromRGB(200,145,0); selHdr.TextXAlignment=Enum.TextXAlignment.Left
    selHdr.ZIndex=23
    yHeader = yHeader + 22

    local function makeRadio(parent, x, y, lbl, active)
        local btn=Instance.new("TextButton",parent)
        btn.Size=UDim2.fromOffset(108,26); btn.Position=UDim2.fromOffset(x,y)
        btn.BackgroundColor3=active and COL_SEL or Color3.fromRGB(16,12,4)
        btn.BorderSizePixel=0; btn.Text=lbl; btn.Font=Enum.Font.GothamBold; btn.TextSize=11
        btn.TextColor3=active and Color3.fromRGB(255,255,255) or Color3.fromRGB(110,90,40)
        btn.ZIndex=24; Instance.new("UICorner",btn).CornerRadius=UDim.new(0,6)
        return btn
    end

    local _activeTP = (_SH_ConfigRaw and _SH_ConfigRaw.activeTPEngine == 2) and 2 or 1
    _G._SH_activeTPEngine = _activeTP

    local tp1Btn = makeRadio(outer, 8,   yHeader, "TP 1  (Base)", _activeTP==1)
    local tp2Btn = makeRadio(outer, 122, yHeader, "TP 2  (Taco)", _activeTP==2)
    yHeader = yHeader + 34

    local div=Instance.new("Frame",outer); div.Size=UDim2.new(1,-16,0,1)
    div.Position=UDim2.fromOffset(8,yHeader); div.BackgroundColor3=Color3.fromRGB(80,55,0)
    div.BorderSizePixel=0; div.ZIndex=23
    yHeader = yHeader + 6

    local panelY  = yHeader
    local panelSz = UDim2.new(1,0,1,-panelY)

    local function makeNumRow(parent, y, lbl, getF, setF)
        local row=Instance.new("Frame",parent)
        row.Size=UDim2.new(1,-12,0,28); row.Position=UDim2.fromOffset(6,y)
        row.BackgroundColor3=Color3.fromRGB(14,11,3); row.BackgroundTransparency=0.5
        row.BorderSizePixel=0; row.ZIndex=24
        Instance.new("UICorner",row).CornerRadius=UDim.new(0,6)
        local l=Instance.new("TextLabel",row)
        l.Size=UDim2.new(1,-106,1,0); l.Position=UDim2.fromOffset(10,0)
        l.BackgroundTransparency=1; l.Text=lbl
        l.Font=Enum.Font.GothamMedium; l.TextSize=11
        l.TextColor3=COL_TXT; l.TextXAlignment=Enum.TextXAlignment.Left; l.ZIndex=25
        local box=Instance.new("TextBox",row)
        box.Size=UDim2.fromOffset(92,20); box.AnchorPoint=Vector2.new(1,0.5)
        box.Position=UDim2.new(1,-7,0.5,0)
        box.BackgroundColor3=Color3.fromRGB(8,6,2); box.BorderSizePixel=0
        local ok,cur=pcall(getF); box.Text=tostring(ok and cur or 0)
        box.Font=Enum.Font.GothamMedium; box.TextSize=11
        box.TextColor3=Color3.fromRGB(210,185,130); box.TextXAlignment=Enum.TextXAlignment.Center
        box.PlaceholderText="value"; box.ZIndex=25
        Instance.new("UICorner",box).CornerRadius=UDim.new(0,5)
        local bs=Instance.new("UIStroke",box); bs.Color=Color3.fromRGB(100,70,0); bs.Thickness=1
        box.FocusLost:Connect(function()
            local v=tonumber(box.Text)
            if v then pcall(setF,v); box.Text=tostring(v); task.spawn(saveConfig)
            else box.Text=tostring(getF() or "") end
        end)
    end

    local function makeCycleRow(parent, y, lbl, opts, getF, setF)
        local row=Instance.new("Frame",parent)
        row.Size=UDim2.new(1,-12,0,28); row.Position=UDim2.fromOffset(6,y)
        row.BackgroundColor3=Color3.fromRGB(14,11,3); row.BackgroundTransparency=0.5
        row.BorderSizePixel=0; row.ZIndex=24
        Instance.new("UICorner",row).CornerRadius=UDim.new(0,6)
        local l=Instance.new("TextLabel",row)
        l.Size=UDim2.new(1,-116,1,0); l.Position=UDim2.fromOffset(10,0)
        l.BackgroundTransparency=1; l.Text=lbl
        l.Font=Enum.Font.GothamMedium; l.TextSize=11
        l.TextColor3=COL_TXT; l.TextXAlignment=Enum.TextXAlignment.Left; l.ZIndex=25
        local cur=getF() or opts[1]
        local idx=1; for i,v in ipairs(opts) do if v==cur then idx=i break end end
        local sel=Instance.new("TextButton",row)
        sel.Size=UDim2.fromOffset(108,20); sel.AnchorPoint=Vector2.new(1,0.5)
        sel.Position=UDim2.new(1,-7,0.5,0)
        sel.BackgroundColor3=Color3.fromRGB(8,6,2); sel.BorderSizePixel=0
        sel.Text=cur.." ▾"; sel.Font=Enum.Font.GothamMedium; sel.TextSize=11
        sel.TextColor3=Color3.fromRGB(210,185,130); sel.ZIndex=25
        Instance.new("UICorner",sel).CornerRadius=UDim.new(0,5)
        Instance.new("UIStroke",sel).Color=Color3.fromRGB(100,70,0)
        sel.MouseButton1Click:Connect(function()
            idx=idx%#opts+1; pcall(setF,opts[idx]); sel.Text=opts[idx].." ▾"
            task.spawn(saveConfig)
        end)
    end

    local function makeSectionHdr(parent, y, txt)
        local h=Instance.new("TextLabel",parent)
        h.Size=UDim2.new(1,-12,0,16); h.Position=UDim2.fromOffset(6,y)
        h.BackgroundTransparency=1; h.Text=txt
        h.Font=Enum.Font.GothamBold; h.TextSize=10
        h.TextColor3=Color3.fromRGB(200,145,0); h.TextXAlignment=Enum.TextXAlignment.Left
        h.ZIndex=25
    end

    -- ── TP 1 Settings Panel (Base/Mynxx) ──────────────────────────────────────
    local tp1Panel=Instance.new("ScrollingFrame",outer)
    tp1Panel.Size=panelSz; tp1Panel.Position=UDim2.fromOffset(0,panelY)
    tp1Panel.BackgroundTransparency=1; tp1Panel.BorderSizePixel=0
    tp1Panel.ScrollBarThickness=4; tp1Panel.ScrollBarImageColor3=Color3.fromRGB(160,115,0)
    tp1Panel.AutomaticCanvasSize=Enum.AutomaticSize.Y; tp1Panel.CanvasSize=UDim2.new(0,0,0,0)
    tp1Panel.Visible=(_activeTP==1); tp1Panel.ZIndex=23

    do
        local y=PAD
        makeSectionHdr(tp1Panel,y,"BASE TP SETTINGS"); y=y+20
        makeNumRow(tp1Panel,y,"TP Velocity",
            function() return _G.TPVelocity or 157 end,
            function(v) _G.TPVelocity=v end); y=y+32
        makeNumRow(tp1Panel,y,"Climb Speed",
            function() return _G.MynxxClimb or 157 end,
            function(v) _G.MynxxClimb=v end); y=y+32
        makeNumRow(tp1Panel,y,"Close Speed",
            function() return _G.MynxxCloseSpeed or 68 end,
            function(v) _G.MynxxCloseSpeed=v end); y=y+32
        makeNumRow(tp1Panel,y,"Brainrot Speed",
            function() return _G.MynxxBrainrotSpeed or 64 end,
            function(v) _G.MynxxBrainrotSpeed=v end); y=y+32
        makeNumRow(tp1Panel,y,"Clone Delay",
            function() return _G.TPCloneDelay or _G.SKY_CLONE_WAIT or 0.2 end,
            function(v) _G.SKY_CLONE_WAIT=v; _G.TPCloneDelay=v end); y=y+32
        makeCycleRow(tp1Panel,y,"Steal Mode",
            {"priority","nearest","highest"},
            function() return _G.MynxxStealMode or "priority" end,
            function(v) _G.MynxxStealMode=v end); y=y+38

        makeSectionHdr(tp1Panel,y,"STABLE FPS GATE"); y=y+20
        buildMiniToggle(tp1Panel,y,"Enable FPS Gate",
            function() return _G.SH_FPSGateEnabled==true end,
            function(v)
                _G.SH_FPSGateEnabled=v
                _G.SH_Config.fpsGateEnabled=v
                task.spawn(saveConfig)
            end); y=y+28
        makeNumRow(tp1Panel,y,"Min FPS",
            function() return _G.SH_FPSGateMin or 30 end,
            function(v)
                _G.SH_FPSGateMin=math.max(1,math.floor(v))
                _G.SH_Config.fpsGateMin=_G.SH_FPSGateMin
                task.spawn(saveConfig)
            end); y=y+32

        makeSectionHdr(tp1Panel,y,"FLYING GEAR"); y=y+20
        makeCycleRow(tp1Panel,y,"Active Tool",
            {"Flying Carpet","Witch Broom","Waverider","Cupid's Wings","Santa's Sleigh"},
            function()
                return _G.MynxxCarpetTool or "Flying Carpet"
            end,
            function(v)
                _G.MynxxCarpetTool = v
                if _G.MynxxSetCarpetTool then _G.MynxxSetCarpetTool(v) end
                if _SH_ConfigRaw then _SH_ConfigRaw.carpetTool = v end
                task.spawn(saveConfig)
            end); y=y+38
    end

    -- ── TP 2 Settings Panel (Taco) ─────────────────────────────────────────────
    local tp2Panel=Instance.new("ScrollingFrame",outer)
    tp2Panel.Size=panelSz; tp2Panel.Position=UDim2.fromOffset(0,panelY)
    tp2Panel.BackgroundTransparency=1; tp2Panel.BorderSizePixel=0
    tp2Panel.ScrollBarThickness=4; tp2Panel.ScrollBarImageColor3=Color3.fromRGB(160,115,0)
    tp2Panel.AutomaticCanvasSize=Enum.AutomaticSize.Y; tp2Panel.CanvasSize=UDim2.new(0,0,0,0)
    tp2Panel.Visible=(_activeTP==2); tp2Panel.ZIndex=23

    do
        local y=PAD
        makeSectionHdr(tp2Panel,y,"TACO TP SETTINGS"); y=y+20
        makeNumRow(tp2Panel,y,"Cruise Speed",
            function() return _G.NeegyCruise or _SH_ConfigRaw.neegyCruise or 500 end,
            function(v) _G.NeegyCruise=v end); y=y+32
        makeNumRow(tp2Panel,y,"Climb Speed",
            function() return _G.TacoClimb or _SH_ConfigRaw.tacoClimb or 200 end,
            function(v) _G.TacoClimb=v end); y=y+32
        makeNumRow(tp2Panel,y,"Close Speed",
            function() return _G.TacoCloseSpeed or _SH_ConfigRaw.tacoCloseSpeed or 400 end,
            function(v) _G.TacoCloseSpeed=v end); y=y+32
        makeNumRow(tp2Panel,y,"Landing Delay",
            function() return _G.LandingDelay or _SH_ConfigRaw.landingDelay or 0.15 end,
            function(v) _G.LandingDelay=v end); y=y+32
        makeNumRow(tp2Panel,y,"Hold Duration",
            function() return _G.TacoStealHoldDuration or _SH_ConfigRaw.tacoStealHold or 1.3 end,
            function(v) _G.TacoStealHoldDuration=v end); y=y+32
        makeNumRow(tp2Panel,y,"Commit Range",
            function() return _G.TacoStealCommitRange or _SH_ConfigRaw.tacoCommitRange or 30 end,
            function(v) _G.TacoStealCommitRange=v end); y=y+32
        makeCycleRow(tp2Panel,y,"Steal Mode",
            {"priority","nearest","highest"},
            function() return _G.TacoStealMode or _SH_ConfigRaw.tacoStealMode or "priority" end,
            function(v) _G.TacoStealMode=v end); y=y+38

        makeSectionHdr(tp2Panel,y,"STABLE FPS GATE"); y=y+20
        buildMiniToggle(tp2Panel,y,"Enable FPS Gate",
            function() return _G.SH_FPSGateEnabled==true end,
            function(v)
                _G.SH_FPSGateEnabled=v
                _G.SH_Config.fpsGateEnabled=v
                task.spawn(saveConfig)
            end); y=y+28
        makeNumRow(tp2Panel,y,"Min FPS",
            function() return _G.SH_FPSGateMin or 30 end,
            function(v)
                _G.SH_FPSGateMin=math.max(1,math.floor(v))
                _G.SH_Config.fpsGateMin=_G.SH_FPSGateMin
                task.spawn(saveConfig)
            end); y=y+32

        makeSectionHdr(tp2Panel,y,"FLYING GEAR"); y=y+20
        makeCycleRow(tp2Panel,y,"Active Tool",
            {"Flying Carpet","Witch Broom","Waverider","Cupid's Wings","Santa's Sleigh"},
            function()
                return _G.MynxxCarpetTool or "Flying Carpet"
            end,
            function(v)
                _G.MynxxCarpetTool = v
                if _G.MynxxSetCarpetTool then _G.MynxxSetCarpetTool(v) end
                if _SH_ConfigRaw then _SH_ConfigRaw.carpetTool = v end
                task.spawn(saveConfig)
            end); y=y+38
    end

    -- ── Engine switch logic ────────────────────────────────────────────────────
    local function setTPEngine(n)
        _activeTP=n; _G._SH_activeTPEngine=n
        if n==1 then
            tp1Btn.BackgroundColor3=COL_SEL;              tp1Btn.TextColor3=Color3.fromRGB(255,255,255)
            tp2Btn.BackgroundColor3=Color3.fromRGB(16,12,4); tp2Btn.TextColor3=Color3.fromRGB(110,90,40)
            _G.MynxxAutoTP=true;  _G.TacoAutoTP=false
            tp1Panel.Visible=true; tp2Panel.Visible=false
        else
            tp2Btn.BackgroundColor3=COL_SEL;              tp2Btn.TextColor3=Color3.fromRGB(255,255,255)
            tp1Btn.BackgroundColor3=Color3.fromRGB(16,12,4); tp1Btn.TextColor3=Color3.fromRGB(110,90,40)
            _G.MynxxAutoTP=false; _G.TacoAutoTP=true
            tp2Panel.Visible=true; tp1Panel.Visible=false
        end
        task.spawn(saveConfig)
    end

    _G._SH_refreshTPTab = function()
        local eng = (_G._SH_activeTPEngine == 2) and 2 or 1
        setTPEngine(eng)
    end

    tp1Btn.MouseButton1Click:Connect(function() setTPEngine(1) end)
    tp2Btn.MouseButton1Click:Connect(function() setTPEngine(2) end)

end
-- ── End TP Tab Builder ────────────────────────────────────────────────────────

-- ── Priority List Tab Builder (PRI) ──────────────────────────────────────────
do
    local cf = tabFrameMap["PRI"]

    local scroll = Instance.new("ScrollingFrame", cf)
    scroll.Size = UDim2.new(1,0,1,0)
    scroll.CanvasSize = UDim2.new(0,0,0,0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ScrollBarThickness = 4
    scroll.ScrollBarImageColor3 = Color3.fromRGB(160,115,0)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ZIndex = 22

    local yOff = PAD

    local priHdr = Instance.new("TextLabel", scroll)
    priHdr.Size=UDim2.new(1,-16,0,18); priHdr.Position=UDim2.fromOffset(8, yOff)
    priHdr.BackgroundTransparency=1; priHdr.Text="LIST  PRIORITY"
    priHdr.Font=Enum.Font.GothamBold; priHdr.TextSize=10
    priHdr.TextColor3=Color3.fromRGB(200,145,0); priHdr.TextXAlignment=Enum.TextXAlignment.Left
    priHdr.ZIndex=23
    yOff=yOff+22

    local priScroll=Instance.new("ScrollingFrame",scroll)
    priScroll.Size=UDim2.new(1,-16,0,310); priScroll.Position=UDim2.fromOffset(8,yOff)
    priScroll.BackgroundColor3=Color3.fromRGB(9,11,18); priScroll.BorderSizePixel=0
    priScroll.ScrollBarThickness=3; priScroll.ScrollBarImageColor3=Color3.fromRGB(160,115,0)
    priScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
    priScroll.CanvasSize=UDim2.new(0,0,0,0); priScroll.ZIndex=23
    Instance.new("UICorner",priScroll).CornerRadius=UDim.new(0,6)
    local ps2=Instance.new("UIStroke",priScroll); ps2.Color=Color3.fromRGB(100,70,0); ps2.Transparency=0.3
    yOff=yOff+318

    local addRow=Instance.new("Frame",scroll)
    addRow.Size=UDim2.new(1,-16,0,28); addRow.Position=UDim2.fromOffset(8,yOff)
    addRow.BackgroundTransparency=1; addRow.BorderSizePixel=0; addRow.ZIndex=23

    local addBox=Instance.new("TextBox",addRow)
    addBox.Size=UDim2.new(1,-62,1,0)
    addBox.BackgroundColor3=Color3.fromRGB(8,6,2); addBox.BorderSizePixel=0
    addBox.Text=""; addBox.PlaceholderText="Pet name to add..."
    addBox.Font=Enum.Font.GothamMedium; addBox.TextSize=11
    addBox.TextColor3=Color3.fromRGB(210,185,130); addBox.ZIndex=24
    Instance.new("UICorner",addBox).CornerRadius=UDim.new(0,5)
    Instance.new("UIStroke",addBox).Color=Color3.fromRGB(100,70,0)

    local addBtn=Instance.new("TextButton",addRow)
    addBtn.Size=UDim2.fromOffset(56,28); addBtn.AnchorPoint=Vector2.new(1,0)
    addBtn.Position=UDim2.new(1,0,0,0)
    addBtn.BackgroundColor3=COL_SEL; addBtn.BorderSizePixel=0
    addBtn.Text="+ Add"; addBtn.Font=Enum.Font.GothamBold; addBtn.TextSize=11
    addBtn.TextColor3=Color3.fromRGB(255,255,255); addBtn.ZIndex=24
    Instance.new("UICorner",addBtn).CornerRadius=UDim.new(0,5)
    yOff=yOff+34

    local remBtn=Instance.new("TextButton",scroll)
    remBtn.Size=UDim2.new(1,-16,0,26); remBtn.Position=UDim2.fromOffset(8,yOff)
    remBtn.BackgroundColor3=Color3.fromRGB(160,30,30); remBtn.BorderSizePixel=0
    remBtn.Text="Remove Selected"; remBtn.Font=Enum.Font.GothamBold; remBtn.TextSize=11
    remBtn.TextColor3=Color3.fromRGB(255,255,255); remBtn.ZIndex=24
    Instance.new("UICorner",remBtn).CornerRadius=UDim.new(0,5)

    local selectedPriIdx=nil

    local function rebuildPriList()
        for _,c in ipairs(priScroll:GetChildren()) do
            if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end
        end
        if type(_G.SHARED_PRIORITY_ITEMS)~="table" then _G.SHARED_PRIORITY_ITEMS={} end
        selectedPriIdx=nil
        for i,petName in ipairs(_G.SHARED_PRIORITY_ITEMS) do
            local item=Instance.new("TextButton",priScroll)
            item.Size=UDim2.new(1,0,0,24); item.Position=UDim2.fromOffset(0,(i-1)*24)
            item.BackgroundColor3=Color3.fromRGB(14,11,3)
            item.BackgroundTransparency=(i%2==0) and 0.75 or 0.9
            item.BorderSizePixel=0; item.ZIndex=25; item.Text=""

            local rnk=Instance.new("TextLabel",item)
            rnk.Size=UDim2.fromOffset(28,24); rnk.BackgroundTransparency=1
            rnk.Text="#"..i; rnk.Font=Enum.Font.GothamBold; rnk.TextSize=9
            rnk.TextColor3=Color3.fromRGB(200,145,0); rnk.TextXAlignment=Enum.TextXAlignment.Center
            rnk.ZIndex=26

            local nl=Instance.new("TextLabel",item)
            nl.Size=UDim2.new(1,-82,1,0); nl.Position=UDim2.fromOffset(28,0)
            nl.BackgroundTransparency=1; nl.Text=petName
            nl.Font=Enum.Font.GothamMedium; nl.TextSize=11
            nl.TextColor3=COL_TXT; nl.TextXAlignment=Enum.TextXAlignment.Left; nl.ZIndex=26

            local upB=Instance.new("TextButton",item)
            upB.Size=UDim2.fromOffset(22,22); upB.AnchorPoint=Vector2.new(1,0.5)
            upB.Position=UDim2.new(1,-24,0.5,0); upB.BackgroundTransparency=1
            upB.Text="▲"; upB.Font=Enum.Font.GothamBold; upB.TextSize=10
            upB.TextColor3=Color3.fromRGB(200,145,0); upB.ZIndex=26

            local dnB=Instance.new("TextButton",item)
            dnB.Size=UDim2.fromOffset(22,22); dnB.AnchorPoint=Vector2.new(1,0.5)
            dnB.Position=UDim2.new(1,-2,0.5,0); dnB.BackgroundTransparency=1
            dnB.Text="▼"; dnB.Font=Enum.Font.GothamBold; dnB.TextSize=10
            dnB.TextColor3=Color3.fromRGB(200,145,0); dnB.ZIndex=26

            local function swap(a,b)
                _G.SHARED_PRIORITY_ITEMS[a],_G.SHARED_PRIORITY_ITEMS[b]=
                    _G.SHARED_PRIORITY_ITEMS[b],_G.SHARED_PRIORITY_ITEMS[a]
                _G.TacoPriVersion=(_G.TacoPriVersion or 0)+1
                rebuildPriList()
            end
            local ci=i
            upB.MouseButton1Click:Connect(function() if ci>1 then swap(ci,ci-1) end end)
            dnB.MouseButton1Click:Connect(function() if ci<#_G.SHARED_PRIORITY_ITEMS then swap(ci,ci+1) end end)

            item.MouseButton1Click:Connect(function()
                selectedPriIdx=ci
                for _,c2 in ipairs(priScroll:GetChildren()) do
                    if c2:IsA("TextButton") then
                        c2.BackgroundColor3=Color3.fromRGB(14,11,3); c2.BackgroundTransparency=0.9
                    end
                end
                item.BackgroundColor3=Color3.fromRGB(80,55,0); item.BackgroundTransparency=0.2
            end)
        end
    end

    rebuildPriList()

    addBtn.MouseButton1Click:Connect(function()
        local txt=(addBox.Text or ""):match("^%s*(.-)%s*$")
        if txt~="" then
            if type(_G.SHARED_PRIORITY_ITEMS)~="table" then _G.SHARED_PRIORITY_ITEMS={} end
            table.insert(_G.SHARED_PRIORITY_ITEMS, txt)
            _G.TacoPriVersion=(_G.TacoPriVersion or 0)+1
            addBox.Text=""; rebuildPriList()
        end
    end)

    remBtn.MouseButton1Click:Connect(function()
        if selectedPriIdx and _G.SHARED_PRIORITY_ITEMS and _G.SHARED_PRIORITY_ITEMS[selectedPriIdx] then
            table.remove(_G.SHARED_PRIORITY_ITEMS, selectedPriIdx)
            _G.TacoPriVersion=(_G.TacoPriVersion or 0)+1
            rebuildPriList()
        end
    end)

    tabBtnMap["PRI"].MouseButton1Click:Connect(function()
        rebuildPriList()
    end)
end
-- ── End PRI Tab Builder ───────────────────────────────────────────────────────

-- ── Arrow toggle logic ──
arrowBtn.MouseButton1Click:Connect(function()
    dpOpen = not dpOpen
    dropPanel.Visible = true
    if dpOpen then
        arrowBtn.Text = "⌃"
        local tH = ((activeTabName=="TP") or (activeTabName=="PRI")) and TP_DROP_H or dropH
        TweenService2:Create(dropPanel, TF2, {Size=UDim2.new(0,580,0,tH), BackgroundTransparency=0.1}):Play()
    else
        arrowBtn.Text = "⌄"
        TweenService2:Create(dropPanel, TF2, {Size=UDim2.new(0,580,0,0)}):Play()
        task.delay(0.2, function() if not dpOpen then dropPanel.Visible=false end end)
    end
end)

-- FPS/Ping counter
local fpsCount=0;local fpsLast=tick()
RunService.RenderStepped:Connect(function()
    fpsCount=fpsCount+1;local now=tick()
    if now-fpsLast>=0.5 then local fps=math.floor(fpsCount/(now-fpsLast));fpsCount=0;fpsLast=now
        local ping=0;pcall(function() ping=math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        local fc=fps>=60 and "#00cc66" or fps>=30 and "#ffaa00" or "#ff4444"
        local pc=ping<=80 and "#00cc66" or ping<=150 and "#ffaa00" or "#ff4444"
        statsL.Text=string.format("<font color='%s'>FPS: %d</font>  |  <font color='%s'>Ping: %dms</font>",fc,fps,pc,ping)
    end
end)

-- OPEN/CLOSE
local _openOnStart = true
if _SH_ConfigRaw and _SH_ConfigRaw.openOnStart == false then
    _openOnStart = false
end
local isOpen = false
main.Visible = false
reopenBtn.Visible = false

local function openUI() isOpen=true;main.Visible=true;reopenBtn.Visible=false;uiScale.Scale=0.88;main.BackgroundTransparency=0.4;tw(uiScale,TFB,{Scale=1});tw(main,TFM,{BackgroundTransparency=0.08}) end
local function closeUI() isOpen=false;reopenBtn.Visible=true;tw(uiScale,TF,{Scale=0.9});tw(main,TF,{BackgroundTransparency=0.6});task.delay(0.2,function() if not isOpen then main.Visible=false;uiScale.Scale=1 end end) end
closeBtn.MouseButton1Click:Connect(closeUI)
reopenBtn.MouseButton1Click:Connect(openUI)
UIS.InputBegan:Connect(function(inp,gp)
    if gp then return end
    if inp.UserInputType~=Enum.UserInputType.Keyboard then return end
    if inp.KeyCode==KEYBINDS.manualTP then local fn=_G.SabcomStartSideTP or _G.MynxxStartSideTP or _G.Sabcom_ExecuteManualTP; if fn then task.spawn(fn) end end
end)

end -- HUD Bar + Dropdown Settings END


--------------------------------------------------------------------------------
-- 7-C  ANTI-FLASHER (Neegy lightweight version, renamed Taco -> SH_)
--------------------------------------------------------------------------------
do
    if not _G.__SH_AntiFlash then
        _G.__SH_AntiFlash = true
        local Players = game:GetService("Players")
        if _G.SH_AntiFlash == nil then _G.SH_AntiFlash = true end
        local FX = { ParticleEmitter = true, Beam = true, Trail = true, Fire = true,
            Smoke = true, Sparkles = true, Explosion = true, PointLight = true,
            SpotLight = true, SurfaceLight = true }
        local function kill(item)
            if pcall(function() item:Destroy() end) then return end
            pcall(function()
                for _, d in ipairs(item:GetDescendants()) do
                    if d:IsA("BasePart") then
                        d.Transparency = 1
                        d.CanCollide = false
                        d.CanQuery = false
                        d.CastShadow = false
                        d.LocalTransparencyModifier = 1
                    elseif FX[d.ClassName] then
                        d.Enabled = false
                    elseif d:IsA("Sound") then
                        d.Volume = 0
                        d:Stop()
                    end
                end
            end)
        end
        local function strip(char)
            if not char or _G.SH_AntiFlash == false then return end
            for _, item in ipairs(char:GetChildren()) do
                if item:IsA("Accessory") then kill(item) end
            end
        end
        local hooked = setmetatable({}, { __mode = "k" })
        local function hookChar(char)
            if not char or hooked[char] then return end
            hooked[char] = true
            strip(char)
            char.ChildAdded:Connect(function(c)
                if c:IsA("Accessory") and _G.SH_AntiFlash ~= false then
                    task.defer(kill, c)
                end
            end)
        end
        local function hookPlayer(p)
            if p.Character then task.spawn(hookChar, p.Character) end
            p.CharacterAdded:Connect(hookChar)
        end
        for _, p in ipairs(Players:GetPlayers()) do pcall(hookPlayer, p) end
        Players.PlayerAdded:Connect(hookPlayer)
        workspace.DescendantAdded:Connect(function(d)
            if _G.SH_AntiFlash == false then return end
            if d.ClassName == "Accessory" then
                local par = d.Parent
                if par and par:FindFirstChildOfClass("Humanoid") then task.defer(kill, d) end
            end
        end)
        task.spawn(function()
            task.wait(tonumber(_G.SH_AntiFlashBootWait) or 3)
            while true do
                if _G.SH_AntiFlash ~= false then
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p.Character then strip(p.Character) end
                    end
                    for _, m in ipairs(workspace:GetChildren()) do
                        if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then strip(m) end
                    end
                end
                task.wait(6)
            end
        end)
    end
end -- Anti-Flasher END

task.wait()  -- yield frame between engine inits

--------------------------------------------------------------------------------
-- 7-D  INVIS STEAL ENGINE + PANEL
--------------------------------------------------------------------------------
do

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = (gethui and gethui()) or player:WaitForChild("PlayerGui")

-- ============================================================
-- CONFIG (standalone persistence)
-- ============================================================
local CONFIG_FILE = "InvisStealPanel_config.json"

local Config = {
    DarkMode = true,
    InvisStealAngle = 225,
    SinkSliderValue = 7,
    AutoRecoverLagback = true,
    AutoInvisDuringSteal = false,
    WalkSpeedEnabled = false,
    WalkSpeedValue = 16,
    positions = {},
}

local function canUseFiles()
    return typeof(readfile) == "function" and typeof(writefile) == "function" and typeof(isfile) == "function"
end

local function saveConfig()
    if not canUseFiles() then return end
    task.spawn(function()
        pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(Config)) end)
    end)
end

local function loadConfig()
    if not canUseFiles() then return end
    local ok, data = pcall(function()
        if isfile(CONFIG_FILE) then return HttpService:JSONDecode(readfile(CONFIG_FILE)) end
    end)
    if ok and type(data) == "table" then
        for k, v in pairs(data) do Config[k] = v end
        if type(Config.positions) ~= "table" then Config.positions = {} end
    end
end
loadConfig()

-- ============================================================
-- THEME
-- ============================================================
local Theme = {
    Background      = Color3.fromRGB(4,4,6),
    MainBackground  = Color3.fromRGB(2,2,4),
    Panel           = Color3.fromRGB(10,10,14),
    Row             = Color3.fromRGB(14,14,18),
    RowHover        = Color3.fromRGB(22,18,8),
    Accent          = Color3.fromRGB(180,130,0),
    AccentLight     = Color3.fromRGB(255,210,60),
    Green           = Color3.fromRGB(74,222,138),
    Red             = Color3.fromRGB(242,92,114),
    Text            = Color3.fromRGB(220,215,200),
    Dim             = Color3.fromRGB(140,125,90),
    Stroke          = Color3.fromRGB(130,90,0),
    InputBg         = Color3.fromRGB(8,8,12),
    SliderBg        = Color3.fromRGB(14,12,6),
    ToggleOff       = Color3.fromRGB(18,14,4),
}

-- ============================================================
-- UI HELPERS
-- ============================================================
local function corner(o, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = o
    return c
end

local function stroke(o, col, th, tr)
    local s = Instance.new("UIStroke")
    s.Color = col or Theme.Stroke
    s.Thickness = th or 1
    s.Transparency = tr or 0
    s.Parent = o
    return s
end

local function tw(o, p, t)
    TweenService:Create(o, TweenInfo.new(t or 0.14, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), p):Play()
end

local function serializePos(pos)
    return {xs=pos.X.Scale, xo=pos.X.Offset, ys=pos.Y.Scale, yo=pos.Y.Offset}
end

local function rememberPosition(name, frame)
    Config.positions[name] = serializePos(frame.Position)
    saveConfig()
end

local function applySavedPosition(name, frame)
    local d = Config.positions[name]
    if d then frame.Position = UDim2.new(d.xs or 0, d.xo or 0, d.ys or 0, d.yo or 0) end
end

local function makeDraggable(frame, handle, saveName)
    local dragging, dragStart, startPos = false, nil, nil
    handle.InputBegan:Connect(function(i)
        if _G.SH_UIsLocked then dragging=false; return end
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = i.Position; startPos = frame.Position
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            if dragging and saveName then rememberPosition(saveName, frame) end
            dragging = false
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

local function _goldWave(lbl, speed, amp)
    speed = speed or 0.7; amp = amp or 0.6
    local g = Instance.new("UIGradient", lbl)
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    Color3.fromRGB(140,95,0)),
        ColorSequenceKeypoint.new(0.3,  Color3.fromRGB(230,170,20)),
        ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(255,235,100)),
        ColorSequenceKeypoint.new(0.7,  Color3.fromRGB(230,170,20)),
        ColorSequenceKeypoint.new(1,    Color3.fromRGB(140,95,0)),
    })
    g.Rotation = 0
    task.spawn(function()
        local t = 0
        while lbl and lbl.Parent do
            t = t + task.wait(0.016)
            g.Offset = Vector2.new(
                math.sin(t * speed) * amp + math.sin(t * (speed*1.5) + 1) * (amp*0.2),
                0)
        end
    end)
    return g
end

-- ============================================================
-- BUILD PANEL SHELL
-- ============================================================
local old = playerGui:FindFirstChild("InvisStealPanel_Standalone")
if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name = "InvisStealPanel_Standalone"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.DisplayOrder = 999
sg.Parent = playerGui

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 230, 0, 330)
panel.Position = UDim2.new(0, 80, 0.5, -165)
panel.BackgroundColor3 = Theme.Background
panel.BackgroundTransparency = 0
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Parent = sg
corner(panel, 10)
local _panStroke = stroke(panel, Theme.Accent, 1.5, 0.2)
task.spawn(function()
    local t=0
    while panel and panel.Parent do
        t=t+task.wait(0.016)
        if _panStroke and _panStroke.Parent then
            _panStroke.Transparency=0.15+math.sin(t*1.2)*0.09+math.sin(t*2.3+0.5)*0.04
            _panStroke.Color=Color3.fromRGB(
                math.floor(160+math.sin(t*0.9)*20),
                math.floor(115+math.sin(t*1.5)*15),
                0)
        end
    end
end)

-- glass highlight sheen
local sheen = Instance.new("Frame")
sheen.Size = UDim2.new(1, 0, 0, 60)
sheen.BackgroundColor3 = Color3.fromRGB(255,255,255)
sheen.BackgroundTransparency = 1
sheen.BorderSizePixel = 0
sheen.ZIndex = 2
sheen.Parent = panel
corner(sheen, 14)
local sheenGrad = Instance.new("UIGradient")
sheenGrad.Rotation = 90
sheenGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.88),
    NumberSequenceKeypoint.new(1, 1),
})
sheenGrad.Parent = sheen

applySavedPosition("InvisStealPanel", panel)

-- header
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 42)
header.BackgroundTransparency = 1
header.Parent = panel

local accentBar = Instance.new("Frame")
accentBar.Size = UDim2.new(1, 0, 0, 2)
accentBar.BackgroundColor3 = Theme.Accent
accentBar.BorderSizePixel = 0
accentBar.Parent = panel
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Theme.Accent),
    ColorSequenceKeypoint.new(1, Theme.AccentLight),
})
grad.Parent = accentBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -58, 0, 16)
title.Position = UDim2.new(0, 12, 0, 8)
title.BackgroundTransparency = 1
title.Text = "Invisible Steal"
title.TextColor3 = Color3.fromRGB(255,220,60)
title.Font = Enum.Font.GothamBlack
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Center
title.Parent = header
_goldWave(title, 0.8, 0.55)

local sub = Instance.new("TextLabel")
sub.Size = UDim2.new(1, -58, 0, 13)
sub.Position = UDim2.new(0, 12, 0, 22)
sub.BackgroundTransparency = 1
sub.Text = "Standalone Panel"
sub.TextColor3 = Theme.Dim
sub.Font = Enum.Font.GothamMedium
sub.TextSize = 10
sub.TextXAlignment = Enum.TextXAlignment.Center
sub.Parent = header

makeDraggable(panel, header, "InvisStealPanel")

-- close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(24, 24)
closeBtn.Position = UDim2.new(1, -30, 0, 8)
closeBtn.BackgroundColor3 = Theme.Red
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 11
closeBtn.AutoButtonColor = false
closeBtn.Parent = header
corner(closeBtn, 6)
closeBtn.MouseButton1Click:Connect(function() panel.Visible = false end)

-- body (scrolling)
local body = Instance.new("ScrollingFrame")
body.Size = UDim2.new(1, -12, 1, -50)
body.Position = UDim2.new(0, 6, 0, 46)
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.ScrollBarThickness = 3
body.ScrollBarImageColor3 = Theme.Accent
body.CanvasSize = UDim2.new(0,0,0,0)
body.Active = true
body.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.Parent = body
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    body.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
end)

-- ============================================================
-- TOGGLE STATE SYSTEM
-- ============================================================
local ToggleState = {}
local function regToggle(name, default)
    if not ToggleState[name] then ToggleState[name] = {value = default or false, listeners = {}} end
end
local function getToggle(name) return ToggleState[name] and ToggleState[name].value or false end
local function setToggle(name, val, skipNotify)
    regToggle(name)
    ToggleState[name].value = val
    if not skipNotify then
        for _, fn in ipairs(ToggleState[name].listeners) do pcall(fn, val) end
    end
end
local function onToggleChanged(name, fn)
    regToggle(name); table.insert(ToggleState[name].listeners, fn)
end

-- ============================================================
-- UI ROW BUILDERS
-- ============================================================
local function makeStateRow(parent, text, toggleName, callback)
    regToggle(toggleName, getToggle(toggleName))
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -4, 0, 34)
    row.BackgroundColor3 = Theme.Panel
    row.BackgroundTransparency = 0
    row.Parent = parent
    corner(row, 6)
    stroke(row, Theme.Stroke, 1, 0.4)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -84, 1, 0)
    label.Position = UDim2.new(0, 4, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Theme.Text
    label.Font = Enum.Font.GothamSemibold
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 72, 0, 30)
    btn.Position = UDim2.new(1, -74, 0.5, -15)
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBlack
    btn.TextSize = 12
    btn.AutoButtonColor = false
    btn.Parent = row
    corner(btn, 6)

    local function refresh(val)
        btn.BackgroundColor3 = val and Theme.Green or Theme.ToggleOff
        btn.Text = val and "ON" or "OFF"
    end
    refresh(getToggle(toggleName))
    onToggleChanged(toggleName, function(val) refresh(val) end)
    btn.MouseButton1Click:Connect(function()
        local nv = not getToggle(toggleName)
        setToggle(toggleName, nv)
        if callback then callback(nv) end
    end)

    return function(ns, fire)
        if typeof(ns) == "boolean" then
            setToggle(toggleName, ns)
            if fire ~= false and callback then callback(ns) end
        end
    end
end

local function makeSlider(parent, text, min, max, default, callback, suffix)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -4, 0, 50)
    holder.BackgroundTransparency = 1
    holder.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 16)
    label.Position = UDim2.new(0, 4, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text .. ": " .. tostring(default) .. (suffix or "")
    label.TextColor3 = Theme.Text
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 10
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = holder

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -10, 0, 6)
    bar.Position = UDim2.new(0, 4, 0, 26)
    bar.BackgroundColor3 = Theme.SliderBg
    bar.BorderSizePixel = 0
    bar.Parent = holder
    corner(bar, 10)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(math.clamp((default-min)/(max-min),0,1), 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.BorderSizePixel = 0
    fill.Parent = bar
    corner(fill, 10)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(math.clamp((default-min)/(max-min),0,1), 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(220,160,20)
    knob.BorderSizePixel = 0
    knob.Parent = bar
    corner(knob, 20)

    local dragging = false
    local function update(x)
        local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local v = math.floor((min + (max-min)*rel) * 10 + 0.5) / 10
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, 0, 0.5, 0)
        label.Text = text .. ": " .. tostring(v) .. (suffix or "")
        if callback then callback(v) end
    end
    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; update(i.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            update(i.Position.X)
        end
    end)

    return {
        Set = function(v, silent)
            v = math.clamp(v, min, max)
            local rel = (v - min) / (max - min)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            knob.Position = UDim2.new(rel, 0, 0.5, 0)
            label.Text = text .. ": " .. tostring(v) .. (suffix or "")
            if callback and not silent then callback(v) end
        end
    }
end

local function makeSliderWithInput(parent, text, min, max, default, callback, suffix)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -4, 0, 48)
    row.BackgroundColor3 = Theme.Panel
    row.BackgroundTransparency = 0.18
    row.Parent = parent
    corner(row, 6)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.65, 0, 0, 16)
    label.Position = UDim2.new(0, 8, 0, 4)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Theme.Text
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 10
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.26, 0, 0, 16)
    box.Position = UDim2.new(0.74, -8, 0, 4)
    box.BackgroundColor3 = Theme.InputBg
    box.BorderSizePixel = 0
    box.Text = tostring(default) .. (suffix or "")
    box.TextColor3 = Theme.Text
    box.Font = Enum.Font.GothamBold
    box.TextSize = 9
    box.ClearTextOnFocus = false
    box.Parent = row
    corner(box, 4)
    stroke(box, Theme.Stroke, 1, 0.4)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -16, 0, 6)
    bar.Position = UDim2.new(0, 8, 0, 28)
    bar.BackgroundColor3 = Theme.SliderBg
    bar.BorderSizePixel = 0
    bar.Parent = row
    corner(bar, 10)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(math.clamp((default-min)/(max-min),0,1), 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.BorderSizePixel = 0
    fill.Parent = bar
    corner(fill, 10)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(math.clamp((default-min)/(max-min),0,1), 0, 0.5, 0)
    knob.BackgroundColor3 = Color3.fromRGB(220,160,20)
    knob.BorderSizePixel = 0
    knob.Parent = bar
    corner(knob, 20)

    local dragging = false
    local function updateValue(val, skipBox)
        val = math.clamp(val, min, max)
        val = math.floor(val * 100 + 0.5) / 100
        local rel = (val - min) / (max - min)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, 0, 0.5, 0)
        if not skipBox then box.Text = tostring(val) .. (suffix or "") end
        if callback then callback(val) end
    end

    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            local rel = math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            updateValue(min + (max-min) * rel)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local rel = math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            updateValue(min + (max-min) * rel)
        end
    end)
    box.FocusLost:Connect(function()
        local raw = box.Text:gsub("[^%d%.]", "")
        local num = tonumber(raw)
        if num then updateValue(num) else box.Text = tostring(default) .. (suffix or "") end
    end)
    return row
end

-- ============================================================
-- INVISIBLE STEAL LOGIC (ported 1:1)
-- ============================================================
local animPlaying = false
local tracks = {}
local clone, oldRoot, hip, connection
local folderConnections = {}
local serverGhosts = {}
local ghostEnabled = true
local lagbackCallCount = 0
local lagbackWindowStart = 0
local lastLagbackTime = 0
local errorOrbActive = false
local errorOrb = nil

_G.InvisStealAngle = Config.InvisStealAngle or 225
_G.SinkSliderValue = Config.SinkSliderValue or 7
_G.AutoRecoverLagback = Config.AutoRecoverLagback ~= nil and Config.AutoRecoverLagback or true
_G.AutoInvisDuringSteal = Config.AutoInvisDuringSteal or false

local function clearErrorOrb()
    if errorOrb and errorOrb.Parent then errorOrb:Destroy() end
    errorOrb = nil
    errorOrbActive = false
end

local function createErrorOrb()
    if errorOrbActive then return end
    errorOrbActive = true
    for _, ghost in pairs(serverGhosts) do if ghost and ghost.Parent then ghost:Destroy() end end
    serverGhosts = {}
end

local function createServerGhost(position)
    if not ghostEnabled or errorOrbActive then return end
    local now = tick()
    if now - lastLagbackTime < 0.05 then return end
    lastLagbackTime = now
    if now - lagbackWindowStart > 1 then lagbackCallCount = 0; lagbackWindowStart = now end
    lagbackCallCount = lagbackCallCount + 1
    if lagbackCallCount >= 7 then createErrorOrb(); return end
    for _, g in pairs(serverGhosts) do if g and g.Parent then g:Destroy() end end
    serverGhosts = {}
    local ghost = Instance.new("Part")
    ghost.Name = "LagbackGhost"
    ghost.Shape = Enum.PartType.Ball
    ghost.Size = Vector3.new(3,3,3)
    ghost.Color = Color3.fromRGB(255,0,0)
    ghost.Material = Enum.Material.Glass
    ghost.Transparency = 0.3
    ghost.CanCollide = false
    ghost.Anchored = true
    ghost.CastShadow = false
    ghost.Position = position + Vector3.new(0,5,0)
    ghost.Parent = Workspace.CurrentCamera
    table.insert(serverGhosts, ghost)
end

local function clearAllGhosts()
    for _, ghost in pairs(serverGhosts) do
        pcall(function() if ghost and ghost.Parent then ghost:Destroy() end end)
    end
    serverGhosts = {}
    clearErrorOrb()
    lagbackCallCount = 0
    lastLagbackTime = 0
    pcall(function()
        if Workspace.CurrentCamera then
            for _, c in pairs(Workspace.CurrentCamera:GetChildren()) do
                if c.Name == "LagbackGhost" then c:Destroy() end
            end
        end
    end)
    pcall(function()
        for _, c in pairs(Workspace:GetDescendants()) do
            if c.Name == "LagbackGhost" then c:Destroy() end
        end
    end)
end

local function removeFolders()
    local pf = Workspace:FindFirstChild(player.Name)
    if not pf then return end
    local dr = pf:FindFirstChild("DoubleRig")
    if dr then
        local rr = dr:FindFirstChild("HumanoidRootPart") or dr:FindFirstChildWhichIsA("BasePart")
        if rr and ghostEnabled then createServerGhost(rr.Position) end
        dr:Destroy()
    end
    local cs = pf:FindFirstChild("Constraints")
    if cs then cs:Destroy() end
    local conn = pf.ChildAdded:Connect(function(child)
        if child.Name == "DoubleRig" then
            task.defer(function()
                local rr = child:FindFirstChild("HumanoidRootPart") or child:FindFirstChildWhichIsA("BasePart")
                if rr and ghostEnabled then createServerGhost(rr.Position) end
                child:Destroy()
            end)
        elseif child.Name == "Constraints" then
            child:Destroy()
        end
    end)
    table.insert(folderConnections, conn)
end

local function doClone()
    local character = player.Character
    if character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 then
        hip = character.Humanoid.HipHeight
        oldRoot = character:FindFirstChild("HumanoidRootPart")
        if not oldRoot or not oldRoot.Parent then return false end
        for _, c in pairs(oldRoot:GetChildren()) do
            if c:IsA("Attachment") and (c.Name:find("Beam") or c.Name:find("Attach")) then c:Destroy() end
        end
        for _, c in pairs(oldRoot:GetChildren()) do if c:IsA("Beam") then c:Destroy() end end
        local tmp = Instance.new("Model"); tmp.Parent = game
        character.Parent = tmp
        clone = oldRoot:Clone(); clone.Parent = character
        oldRoot.Parent = Workspace.CurrentCamera
        clone.CFrame = oldRoot.CFrame
        character.PrimaryPart = clone
        character.Parent = Workspace
        for _, v in pairs(character:GetDescendants()) do
            if v:IsA("Weld") or v:IsA("Motor6D") then
                if v.Part0 == oldRoot then v.Part0 = clone end
                if v.Part1 == oldRoot then v.Part1 = clone end
            end
        end
        tmp:Destroy()
        return true
    end
    return false
end

local function revertClone()
    local character = player.Character
    if not oldRoot or not oldRoot:IsDescendantOf(Workspace) or not character or character.Humanoid.Health <= 0 then return end
    local tmp = Instance.new("Model"); tmp.Parent = game
    character.Parent = tmp
    oldRoot.Parent = character
    character.PrimaryPart = oldRoot
    character.Parent = Workspace
    oldRoot.CanCollide = true
    for _, v in pairs(character:GetDescendants()) do
        if v:IsA("Weld") or v:IsA("Motor6D") then
            if v.Part0 == clone then v.Part0 = oldRoot end
            if v.Part1 == clone then v.Part1 = oldRoot end
        end
    end
    if clone then
        local p = clone.CFrame
        clone:Destroy()
        clone = nil
        oldRoot.CFrame = p
    end
    oldRoot = nil
    if character and character.Humanoid then character.Humanoid.HipHeight = hip end
    clearAllGhosts()
end

local function animationTrickery()
    local character = player.Character
    if character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 then
        local anim = Instance.new("Animation")
        anim.AnimationId = "http://www.roblox.com/asset/?id=18537363391"
        local humanoid = character.Humanoid
        local animator = humanoid:FindFirstChild("Animator") or Instance.new("Animator", humanoid)
        local animTrack = animator:LoadAnimation(anim)
        animTrack.Priority = Enum.AnimationPriority.Action4
        animTrack:Play(0, 1, 0)
        anim:Destroy()
        table.insert(tracks, animTrack)
        animTrack.Stopped:Connect(function() if animPlaying then animationTrickery() end end)
        task.delay(0, function()
            animTrack.TimePosition = 0.7
            task.delay(0.3, function() if animTrack then animTrack:AdjustSpeed(math.huge) end end)
        end)
    end
end

local _invisToggleCooldown = 0

local function invisTurnOff()
    clearAllGhosts()
    if not animPlaying then return end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    animPlaying = false
    _G.invisibleStealEnabled = false
    setToggle("Invisible Steal", false)
    for _, t in pairs(tracks) do pcall(function() t:Stop(0) end) end
    tracks = {}
    if connection then connection:Disconnect(); connection = nil end
    for _, c in ipairs(folderConnections) do if c then c:Disconnect() end end
    folderConnections = {}
    revertClone()
    clearAllGhosts()
    if humanoid then
        pcall(function()
            local animator = humanoid:FindFirstChildOfClass("Animator")
            if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    if track.Priority == Enum.AnimationPriority.Action4 or track.Priority == Enum.AnimationPriority.Action3 then
                        track:Stop(0)
                    end
                end
            end
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            task.defer(function()
                if humanoid and humanoid.Parent then humanoid:ChangeState(Enum.HumanoidStateType.Running) end
            end)
        end)
    end
    if WalkSpeedState and WalkSpeedState.enabled and Config.WalkSpeedEnabled then
        setWalkSpeedEnabled(false)
    end
    _invisToggleCooldown = tick()
end

local function invisTurnOn()
    if animPlaying then return end
    local character = player.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    animPlaying = true
    _G.invisibleStealEnabled = true
    setToggle("Invisible Steal", true)
    tracks = {}
    removeFolders()
    local success = doClone()
    if success then
        task.wait(0.05)
        animationTrickery()
        task.delay(1, function()
            if _G.invisibleStealEnabled and not WalkSpeedState.enabled and Config.WalkSpeedEnabled then
                setWalkSpeedEnabled(true)
            end
        end)
        local lastSetPosition = nil
        local skipFrames = 5
        connection = RunService.PreSimulation:Connect(function()
            if character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 and oldRoot then
                local root = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
                if root then
                    if skipFrames > 0 then
                        skipFrames = skipFrames - 1
                        lastSetPosition = nil
                    elseif lastSetPosition and ghostEnabled then
                        local currentPos = oldRoot.Position
                        local jumpDist = (currentPos - lastSetPosition).Magnitude
                        if jumpDist > 6 and not _G.RecoveryInProgress and player:GetAttribute("Stealing") then
                            lastSetPosition = nil
                            createServerGhost(currentPos)
                            if _G.AutoRecoverLagback and _G._forceInvisToggle then
                                _G.RecoveryInProgress = true
                                task.spawn(function()
                                    pcall(_G._forceInvisToggle)
                                    task.wait(0.6)
                                    if player:GetAttribute("Stealing") then pcall(_G._forceInvisToggle) end
                                    _G.RecoveryInProgress = false
                                end)
                            end
                        end
                    end
                    if clone then clone.CanCollide = true end
                    if oldRoot and oldRoot.Parent then
                        for _, c in pairs(oldRoot:GetChildren()) do
                            if c:IsA("Attachment") or c:IsA("Beam") then c:Destroy() end
                        end
                        local sa = (_G.SinkSliderValue or 7) * 0.5
                        local cf = root.CFrame - Vector3.new(0, sa, 0)
                        oldRoot.CFrame = cf * CFrame.Angles(math.rad(_G.InvisStealAngle or 225), 0, 0)
                        oldRoot.AssemblyLinearVelocity = root.AssemblyLinearVelocity
                        oldRoot.CanCollide = false
                        lastSetPosition = oldRoot.Position
                    end
                end
            end
        end)
    end
end

_G.toggleInvisibleSteal = function()
    if (tick() - _invisToggleCooldown) < 0.3 then return end
    if animPlaying then invisTurnOff() else invisTurnOn() end
end
_G._forceInvisToggle = function()
    if animPlaying then invisTurnOff() else invisTurnOn() end
end

player.CharacterAdded:Connect(function(newChar)
    task.wait(0.1)
    clearErrorOrb(); clearAllGhosts(); lagbackCallCount = 0
    pcall(function()
        for _, c in pairs(Workspace.CurrentCamera:GetChildren()) do
            if c:IsA("BasePart") and c.Name == "HumanoidRootPart" then c:Destroy() end
        end
    end)
    if oldRoot then pcall(function() oldRoot:Destroy() end); oldRoot = nil end
    if clone then pcall(function() clone:Destroy() end); clone = nil end
    animPlaying = false
    _G.invisibleStealEnabled = false
    setToggle("Invisible Steal", false)
    task.wait(0.2)
    local camera = Workspace.CurrentCamera
    if camera and newChar then
        local h = newChar:FindFirstChildOfClass("Humanoid")
        if h then camera.CameraSubject = h; camera.CameraType = Enum.CameraType.Custom end
    end
end)

local function setupDeathListener()
    local ch = player.Character
    if ch then
        local h = ch:FindFirstChildOfClass("Humanoid")
        if h then h.Died:Connect(function() clearErrorOrb(); clearAllGhosts(); lagbackCallCount = 0 end) end
    end
end
setupDeathListener()
player.CharacterAdded:Connect(function() task.wait(0.1); setupDeathListener() end)

-- Auto Invis During Steal loop
task.spawn(function()
    local wasStealingForInvis = false
    local autoEnabledInvis = false
    task.wait(1)
    while task.wait(0.15) do
        if Config.AutoInvisDuringSteal == false then
            wasStealingForInvis = false
            autoEnabledInvis = false
        else
            local isStealing = player:GetAttribute("Stealing")
            if isStealing and not wasStealingForInvis then
                if not _G.invisibleStealEnabled and _G._forceInvisToggle then
                    task.spawn(function()
                        local _h0 = os.clock()
                        local _need = tonumber(_G.SabcomInvisHoldTime) or 1.25
                        while player:GetAttribute("Stealing") and (os.clock() - _h0) < _need do
                            task.wait(0.05)
                        end
                        if player:GetAttribute("Stealing") and not _G.invisibleStealEnabled then
                            pcall(_G._forceInvisToggle)
                            autoEnabledInvis = true
                        end
                    end)
                end
            end
            if not isStealing and autoEnabledInvis and _G.invisibleStealEnabled and _G._forceInvisToggle then
                task.wait(0.3)
                if not player:GetAttribute("Stealing") then
                    pcall(_G._forceInvisToggle)
                    autoEnabledInvis = false
                end
            end
            wasStealingForInvis = isStealing
        end
    end
end)

-- ============================================================
-- WALKSPEED (CFrame Bypass)
-- ============================================================
WalkSpeedState = {enabled = false, conn = nil, speed = Config.WalkSpeedValue or 16}

function setWalkSpeedEnabled(en)
    WalkSpeedState.enabled = en
    Config.WalkSpeedEnabled = en
    setToggle("WalkSpeed", en)
    saveConfig()
    if WalkSpeedState.conn then WalkSpeedState.conn:Disconnect(); WalkSpeedState.conn = nil end
    if not en then return end
    WalkSpeedState.conn = RunService.Heartbeat:Connect(function(dt)
        local character = player.Character
        if not character then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoid or not rootPart or humanoid.Health <= 0 then return end
        if humanoid.MoveDirection.Magnitude > 0 and WalkSpeedState.speed > humanoid.WalkSpeed then
            local extraSpeed = WalkSpeedState.speed - humanoid.WalkSpeed
            rootPart.CFrame = rootPart.CFrame + (humanoid.MoveDirection * extraSpeed * dt)
        end
    end)
end

local function setWalkSpeedValue(v)
    v = math.clamp(math.floor(v + 0.5), 15, 250)
    WalkSpeedState.speed = v
    Config.WalkSpeedValue = v
    saveConfig()
    return v
end

-- ============================================================
-- CARPET BOOST ENGINE (v12 -- standalone multi-tool, config-wired)
-- ============================================================
local _CB_ValidTools = {
    ["Witch Broom"]    = true,
    ["Flying Carpet"]  = true,
    ["Waverider"]      = true,
    ["Cupid's Wings"]  = true,
    ["Santa's Sleigh"] = true,
}

Config.CarpetSpeed      = Config.CarpetSpeed or false
Config.CarpetSpeedValue = math.clamp(Config.CarpetSpeedValue or 140, 50, 500)

CarpetState = { enabled = false, conn = nil }

local function _cbGetTool()
    local c = player.Character
    local bp = player:FindFirstChild("Backpack")
    if c then
        for n in pairs(_CB_ValidTools) do
            if c:FindFirstChild(n) then return n end
        end
    end
    if bp then
        for n in pairs(_CB_ValidTools) do
            if bp:FindFirstChild(n) then return n end
        end
    end
    return nil
end

local function setCarpetSpeed(en)
    CarpetState.enabled = en
    Config.CarpetSpeed  = en
    _G.SH_CarpetSpeedOn = en
    setToggle("Carpet Speed", en)
    saveConfig()
    if CarpetState.conn then CarpetState.conn:Disconnect(); CarpetState.conn = nil end
    if not en then return end
    CarpetState.conn = RunService.Heartbeat:Connect(function()
        if not CarpetState.enabled then return end
        local c = player.Character
        if not c then return end
        local hum = c:FindFirstChildOfClass("Humanoid")
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then return end
        local tn = _cbGetTool()
        if not tn then return end
        -- auto-equip from backpack
        if not c:FindFirstChild(tn) then
            local bp  = player:FindFirstChild("Backpack")
            local tl  = bp and bp:FindFirstChild(tn)
            if tl then hum:EquipTool(tl) end
        end
        if c:FindFirstChild(tn) then
            local spd = _G.SH_CarpetSpeedVal or Config.CarpetSpeedValue or 140
            local md  = hum.MoveDirection
            local vel = hrp.AssemblyLinearVelocity
            if md.Magnitude > 0 then
                hrp.AssemblyLinearVelocity = Vector3.new(md.X * spd, vel.Y, md.Z * spd)
            else
                hrp.AssemblyLinearVelocity = Vector3.new(0, vel.Y, 0)
            end
        end
    end)
end

_G.SH_setCarpetSpeedValue = function(v)
    v = math.clamp(math.floor(tonumber(v) or 140), 50, 500)
    Config.CarpetSpeedValue = v
    _G.SH_CarpetSpeedVal    = v
    saveConfig()
    return v
end

-- safety: off on steal
pcall(function()
    player:GetAttributeChangedSignal("Stealing"):Connect(function()
        if player:GetAttribute("Stealing") and CarpetState.enabled then
            setCarpetSpeed(false)
        end
    end)
end)

-- safety: off when non-flying tool equipped
local function _cbWatchChar(char)
    if not char then return end
    char.ChildAdded:Connect(function(ch)
        if not CarpetState.enabled then return end
        if ch:IsA("Tool") and not _CB_ValidTools[ch.Name] then
            setCarpetSpeed(false)
        end
    end)
end
_cbWatchChar(player.Character)
player.CharacterAdded:Connect(_cbWatchChar)

_G.CarpetBoost_Toggle   = function() setCarpetSpeed(not CarpetState.enabled) end
_G.CarpetBoost_SetSpeed = function(spd)
    if _G.SH_setCarpetSpeedValue then _G.SH_setCarpetSpeedValue(spd) end
end

-- ============================================================
-- BUILD PANEL CONTENTS
-- ============================================================
regToggle("Invisible Steal", false)
regToggle("Auto Recover Lagback", Config.AutoRecoverLagback)
regToggle("Auto Invis During Steal", Config.AutoInvisDuringSteal)
regToggle("WalkSpeed", Config.WalkSpeedEnabled)
regToggle("Carpet Speed", Config.CarpetSpeed)

makeStateRow(body, "Enabled:", "Invisible Steal", function(on)
    if _G.toggleInvisibleSteal then pcall(_G.toggleInvisibleSteal) end
end)

makeSlider(body, "Rotation", 0, 360, Config.InvisStealAngle or 225, function(v)
    _G.InvisStealAngle = v; Config.InvisStealAngle = v; saveConfig()
end)

makeSlider(body, "Depth", 0, 18, Config.SinkSliderValue or 7, function(v)
    _G.SinkSliderValue = v; Config.SinkSliderValue = v; saveConfig()
end)

makeStateRow(body, "Auto Recover:", "Auto Recover Lagback", function(on)
    _G.AutoRecoverLagback = on; Config.AutoRecoverLagback = on; saveConfig()
end)

makeStateRow(body, "Auto Invis:", "Auto Invis During Steal", function(on)
    _G.AutoInvisDuringSteal = on; Config.AutoInvisDuringSteal = on; saveConfig()
end)

makeStateRow(body, "WalkSpeed:", "WalkSpeed", function(on)
    setWalkSpeedEnabled(on)
end)

makeSliderWithInput(body, "Walk Speed", 15, 250, Config.WalkSpeedValue or 16, function(v)
    setWalkSpeedValue(v)
end)

if Config.WalkSpeedEnabled then
    task.defer(function() setWalkSpeedEnabled(true) end)
end

-- expose a manual toggle key (Insert) to reopen the panel if closed
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        panel.Visible = not panel.Visible
    end
end)

panel.Visible = false
_G.SH_ShowInvisPanel = function(on) panel.Visible = on end
_G.SH_setCarpetSpeed = setCarpetSpeed
_G.setWalkSpeedEnabled = setWalkSpeedEnabled
_G.setWalkSpeedValue = setWalkSpeedValue

end -- INVIS STEAL ENGINE END

-- ============================================================
-- END OF SECTION 7
-- ============================================================
-- ╔════════════════════════════════════════════════════════════════╗
-- ║  SECTION 8 — ENGINES (Part 2)                                ║
-- ╚════════════════════════════════════════════════════════════════╝

--------------------------------------------------------------------------------
-- 8.1  XRAY ENGINE (Silence Hub — Base/Plot X-Ray)
--------------------------------------------------------------------------------
do
local Workspace = workspace
local xrayOriginalTransparencies = setmetatable({}, {__mode = "k"})
local xrayConnections = {}
local xrayLoopId = 0

local XRAY_FOLDERS = {
    "Base", "PlotSign", "FriendPanel", "Cash",
    "Laser", "Decorations", "Skin", "Unlock", "Purchases"
}

local function setXRayTargetTransparency(instance, alphaPercent, loopId)
    if not instance then return end
    if loopId and loopId ~= xrayLoopId then return end

    local function apply(obj)
        if obj:IsA("BasePart") then
            if xrayOriginalTransparencies[obj] == nil then
                if obj.Transparency == alphaPercent then xrayOriginalTransparencies[obj] = 0
                else xrayOriginalTransparencies[obj] = obj.Transparency end
            end
            local orig = xrayOriginalTransparencies[obj]
            if orig < 1 then
                local target = orig + (1 - orig) * alphaPercent
                if math.abs(obj.Transparency - target) > 0.01 then obj.Transparency = target end
            end
        elseif obj:IsA("TextLabel") or obj:IsA("TextButton") then
            if xrayOriginalTransparencies[obj] == nil then
                local t, b = obj.TextTransparency, obj.BackgroundTransparency
                if t == alphaPercent then t = 0 end
                if b == alphaPercent then b = 0 end
                xrayOriginalTransparencies[obj] = {text = t, bg = b}
            end
            local orig = xrayOriginalTransparencies[obj]
            if orig.text < 1 then
                local targetText = orig.text + (1 - orig.text) * alphaPercent
                if math.abs(obj.TextTransparency - targetText) > 0.01 then obj.TextTransparency = targetText end
            end
            if orig.bg < 1 then
                local targetBg = orig.bg + (1 - orig.bg) * alphaPercent
                if math.abs(obj.BackgroundTransparency - targetBg) > 0.01 then obj.BackgroundTransparency = targetBg end
            end
        elseif obj:IsA("Frame") or obj:IsA("ScrollingFrame") then
            if xrayOriginalTransparencies[obj] == nil then
                if obj.BackgroundTransparency == alphaPercent then xrayOriginalTransparencies[obj] = 0
                else xrayOriginalTransparencies[obj] = obj.BackgroundTransparency end
            end
            local orig = xrayOriginalTransparencies[obj]
            if orig < 1 then
                local target = orig + (1 - orig) * alphaPercent
                if math.abs(obj.BackgroundTransparency - target) > 0.01 then obj.BackgroundTransparency = target end
            end
        elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
            if xrayOriginalTransparencies[obj] == nil then
                local i, b = obj.ImageTransparency, obj.BackgroundTransparency
                if i == alphaPercent then i = 0 end
                if b == alphaPercent then b = 0 end
                xrayOriginalTransparencies[obj] = {img = i, bg = b}
            end
            local orig = xrayOriginalTransparencies[obj]
            if orig.img < 1 then
                local targetImg = orig.img + (1 - orig.img) * alphaPercent
                if math.abs(obj.ImageTransparency - targetImg) > 0.01 then obj.ImageTransparency = targetImg end
            end
            if orig.bg < 1 then
                local targetBg = orig.bg + (1 - orig.bg) * alphaPercent
                if math.abs(obj.BackgroundTransparency - targetBg) > 0.01 then obj.BackgroundTransparency = targetBg end
            end
        end
    end

    apply(instance)
    local descendants = instance:GetDescendants()
    for i, child in ipairs(descendants) do
        apply(child)
        if i % 300 == 0 then
            task.wait()
            if loopId and loopId ~= xrayLoopId then return end
        end
    end
end

local function trackXRaySubtree(root, alphaPercent, loopId)
    if not root then return end
    if loopId ~= xrayLoopId then return end

    setXRayTargetTransparency(root, alphaPercent, loopId)

    if loopId ~= xrayLoopId then return end
    table.insert(xrayConnections, root.DescendantAdded:Connect(function(obj)
        if loopId ~= xrayLoopId then return end
        setXRayTargetTransparency(obj, alphaPercent, loopId)
    end))
end

local function processPlotXRay(plot, alphaPercent, loopId)
    if not plot then return end
    if loopId ~= xrayLoopId then return end

    for _, fname in ipairs(XRAY_FOLDERS) do
        if loopId ~= xrayLoopId then return end
        trackXRaySubtree(plot:FindFirstChild(fname), alphaPercent, loopId)
    end

    if loopId ~= xrayLoopId then return end
    table.insert(xrayConnections, plot.ChildAdded:Connect(function(child)
        if loopId ~= xrayLoopId then return end
        for _, fname in ipairs(XRAY_FOLDERS) do
            if child.Name == fname then trackXRaySubtree(child, alphaPercent, loopId); break end
        end
    end))

    local animalPodiums = plot:FindFirstChild("AnimalPodiums")
    if animalPodiums then
        local function processPodium(podium)
            for _, child in ipairs(podium:GetChildren()) do
                if child.Name == "Claim" then
                    trackXRaySubtree(child, alphaPercent, loopId)
                elseif child.Name == "Base" then
                    trackXRaySubtree(child:FindFirstChild("Decorations"), alphaPercent, loopId)
                elseif child:IsA("Model") and child.Name ~= "Decorations" then
                    trackXRaySubtree(child, alphaPercent, loopId)
                end
            end
        end
        for _, podium in ipairs(animalPodiums:GetChildren()) do processPodium(podium) end

        table.insert(xrayConnections, animalPodiums.ChildAdded:Connect(function(podium)
            if loopId ~= xrayLoopId then return end
            task.wait(0.1)
            if loopId ~= xrayLoopId then return end
            processPodium(podium)
        end))
    end
end

local function applyTransparencyToAllPlotsXRay(alphaPercent, loopId)
    local plotsFolder = Workspace:FindFirstChild("Plots")
    if not plotsFolder then return end

    for _, plot in ipairs(plotsFolder:GetChildren()) do
        if loopId ~= xrayLoopId then return end
        processPlotXRay(plot, alphaPercent, loopId)
        task.wait()
    end

    table.insert(xrayConnections, plotsFolder.ChildAdded:Connect(function(plot)
        if loopId ~= xrayLoopId then return end
        task.wait(0.2)
        processPlotXRay(plot, alphaPercent, loopId)
    end))
end

local function toggleXRay(enabled)
    for _, conn in ipairs(xrayConnections) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end
    xrayConnections = {}

    xrayLoopId = xrayLoopId + 1
    local currentLoopId = xrayLoopId

    if enabled then
        local alphaPercent = 0.5

        task.spawn(function()
            while currentLoopId == xrayLoopId and not Workspace:FindFirstChild("Plots") do
                task.wait(0.5)
            end

            if currentLoopId ~= xrayLoopId then return end
            pcall(applyTransparencyToAllPlotsXRay, alphaPercent, currentLoopId)
        end)
        print("[SH] XRay ON")
    else
        local snapshot = xrayOriginalTransparencies
        xrayOriginalTransparencies = setmetatable({}, {__mode = "k"})

        for obj, orig in pairs(snapshot) do
            pcall(function()
                if obj:IsA("BasePart") then
                    obj.Transparency = orig
                elseif obj:IsA("TextLabel") or obj:IsA("TextButton") then
                    obj.TextTransparency = orig.text
                    obj.BackgroundTransparency = orig.bg
                elseif obj:IsA("Frame") or obj:IsA("ScrollingFrame") then
                    obj.BackgroundTransparency = orig
                elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                    obj.ImageTransparency = orig.img
                    obj.BackgroundTransparency = orig.bg
                end
            end)
        end
        print("[SH] XRay OFF")
    end
end

_G.SH_toggleXRay = toggleXRay
print("[SH] XRay Engine ready.")
end

--------------------------------------------------------------------------------
-- 8.1b  PET XRAY ESP (Neegy — XRayShaded box on scanned pets)
--------------------------------------------------------------------------------
do
if _G.SH_PetXray == nil then _G.SH_PetXray = true end
    local _xf
    local _boxes = {}
    local function _ensure()
        if _xf and _xf.Parent then return end
        _xf = Instance.new("Folder"); _xf.Name = "SH_XrayESP"; _xf.Parent = workspace
    end
    local function _clearAll()
        if _xf then pcall(function() _xf:Destroy() end) end
        _xf = nil; table.clear(_boxes)
    end
    task.spawn(function()
        task.wait(tonumber(_G.SH_XrayBootWait) or 8)
        while true do
            task.wait(tonumber(_G.SH_XrayGap) or 0.75)
            if _G.SH_PetXray == false then
                if _xf then _clearAll() end
            elseif _G.SH_TPActive and _G.SH_XrayPauseOnTP ~= false then
                -- skip scan while teleport is active
            else
                local ok, pets = pcall(_G.SH_ScanAllPets or _G.SabcomScanAllPets or function() return {} end)
                if ok and type(pets) == "table" then
                    _ensure()
                    local seen = {}
                    for _, p in ipairs(pets) do
                        if p and p.position then
                            local uid = tostring(p.plot) .. "_" .. tostring(p.slot)
                            seen[uid] = true
                            local b = _boxes[uid]
                            if not (b and b.anchor and b.anchor.Parent) then
                                local anchor = Instance.new("Part")
                                anchor.Anchored = true; anchor.CanCollide = false
                                anchor.CanQuery = false; anchor.CanTouch = false
                                anchor.Transparency = 1; anchor.Size = Vector3.one
                                anchor.Parent = _xf
                                local a = Instance.new("BoxHandleAdornment")
                                a.Adornee = anchor; a.AlwaysOnTop = true; a.ZIndex = 0
                                pcall(function() a.Shading = Enum.AdornShading.XRayShaded end)
                                local _sz = tonumber(_G.SH_XraySize) or 4.5
                                a.Size = Vector3.new(_sz, _sz, _sz)
                                a.Transparency = tonumber(_G.SH_XrayTransp) or 0.5
                                a.Parent = anchor
                                b = { anchor = anchor, adorn = a }; _boxes[uid] = b
                            end
                            pcall(function() b.anchor.CFrame = CFrame.new(p.position) end)
                            pcall(function() b.adorn.Color3 = _G.SH_XrayColor or Color3.fromRGB(255, 255, 255) end)
                        end
                    end
                    for uid, b in pairs(_boxes) do
                        if not seen[uid] then
                            pcall(function() b.anchor:Destroy() end); _boxes[uid] = nil
                        end
                    end
                end
            end
        end
    end)
print("[SH] Pet XRay ESP Engine ready.")
end

task.wait()  -- OPT v9b: yield frame between engine inits (prevents freeze)

--------------------------------------------------------------------------------
-- 8.2  AUTO-KICK ON STEAL ENGINE
--------------------------------------------------------------------------------
do
local Players    = game:GetService("Players")
local LP         = Players.LocalPlayer
local AutoKickEnabled = true

local KEYWORD = "you stole"

local hookedUIs = setmetatable({}, {__mode = "k"})

local function kickPlayer(reasonText)
    print("[SH] AutoKick triggered:", reasonText)
    pcall(function() game:Shutdown() end)
    pcall(function() LocalPlayer:Kick("Auto-Kick: Steal erfolgreich ausgeführt.") end)
end

local function checkText(text)
    if not AutoKickEnabled then return false end

    if type(text) == "string" and string.find(string.lower(text), KEYWORD, 1, true) then
        kickPlayer(text)
        return true
    end
    return false
end

local function hookUIObject(obj)
    if hookedUIs[obj] then return end
    hookedUIs[obj] = true

    if checkText(tostring(obj.Text or "")) then return end

    obj:GetPropertyChangedSignal("Text"):Connect(function()
        checkText(tostring(obj.Text or ""))
    end)
end

local function watchRoot(root)
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            hookUIObject(obj)
        end
    end

    root.DescendantAdded:Connect(function(desc)
        if desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox") then
            hookUIObject(desc)
        end
    end)
end

local function startAutoKickListener()
    for _, gui in ipairs(LP:WaitForChild("PlayerGui"):GetChildren()) do
        watchRoot(gui)
    end

    LP:WaitForChild("PlayerGui").ChildAdded:Connect(function(gui)
        watchRoot(gui)
    end)
end

local function toggleAutoKick(state)
    AutoKickEnabled = state
    if state then
        print("[SH] AutoKick ON")
    else
        print("[SH] AutoKick OFF")
    end
end

startAutoKickListener()
_G.SH_toggleAutoKick = toggleAutoKick
print("[SH] AutoKick Engine ready.")
end

task.wait()  -- OPT v9b: yield frame between engine inits (prevents freeze)

--------------------------------------------------------------------------------
-- 8.3  ANTI-RAGDOLL ENGINE
--------------------------------------------------------------------------------
do
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = workspace
local LP                = game:GetService("Players").LocalPlayer

local AntiRagdollEnabled = true
local antiKnockbackEnabled = true

local antiRagdollConnections = {}
local antiRagdollCharacter, antiRagdollHumanoid, antiRagdollRootPart, antiRagdollAnimator
local lastVelocity = Vector3.new(0, 0, 0)

local velocityChangeThreshold = 40
local velocityMagnitudeThreshold = 25
local maxVelocity = 15

local function isFlyingCarpetActive()
    if not antiRagdollCharacter then return false end
    local tool = antiRagdollCharacter:FindFirstChildWhichIsA("Tool")
    if not tool then return false end
    local hrp = antiRagdollCharacter:FindFirstChild("HumanoidRootPart")
    if hrp then
        for _, obj in ipairs(hrp:GetChildren()) do
            if obj:IsA("BodyVelocity") or obj:IsA("BodyPosition") or obj:IsA("BodyGyro") then
                return true
            end
        end
    end
    return false
end

local function isRagdolled()
    if not antiRagdollHumanoid then return false end
    local state = antiRagdollHumanoid:GetState()
    return state == Enum.HumanoidStateType.Physics
        or state == Enum.HumanoidStateType.Ragdoll
        or state == Enum.HumanoidStateType.FallingDown
        or state == Enum.HumanoidStateType.GettingUp
end

local function enableAntiRagdollControls()
    pcall(function()
        local PlayerModule = LP:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)
        require(PlayerModule):GetControls():Enable()
    end)
end

local function cleanupRagdoll()
    if not antiRagdollCharacter then return end
    local carpetEquipped = isFlyingCarpetActive()

    local function processChildren(parent)
        for _, obj in ipairs(parent:GetChildren()) do
            if obj:IsA("BallSocketConstraint") or obj:IsA("NoCollisionConstraint") or obj:IsA("HingeConstraint")
                or (obj:IsA("Attachment") and (obj.Name == "A" or obj.Name == "B")) then
                obj:Destroy()
            elseif obj:IsA("BodyVelocity") or obj:IsA("BodyPosition") or obj:IsA("BodyGyro") then
                if not carpetEquipped then obj:Destroy() end
            elseif obj:IsA("Motor6D") then
                obj.Enabled = true
            elseif obj:IsA("BasePart") then
                for _, child in ipairs(obj:GetChildren()) do
                    if child:IsA("BallSocketConstraint") or child:IsA("NoCollisionConstraint") or child:IsA("HingeConstraint") or child:IsA("Motor6D") then
                        if child:IsA("Motor6D") then
                            child.Enabled = true
                        else
                            child:Destroy()
                        end
                    elseif child:IsA("Attachment") and (child.Name == "A" or child.Name == "B") then
                        child:Destroy()
                    end
                end
            end
        end
    end

    pcall(function() processChildren(antiRagdollCharacter) end)

    if antiRagdollAnimator then
        for _, track in pairs(antiRagdollAnimator:GetPlayingAnimationTracks()) do
            local animName = track.Animation and track.Animation.Name:lower() or ""
            if animName:find("rag") or animName:find("fall") or animName:find("hurt") or animName:find("down") then
                track:Stop(0)
            end
        end
    end
end

local function setupAntiRagdollCharacter(char)
    antiRagdollCharacter = char
    antiRagdollHumanoid = char:WaitForChild("Humanoid", 10)
    antiRagdollRootPart = char:WaitForChild("HumanoidRootPart", 10)
    antiRagdollAnimator = antiRagdollHumanoid and antiRagdollHumanoid:WaitForChild("Animator", 10)
    lastVelocity = Vector3.new(0, 0, 0)
end

local function clearAntiRagdollConnections()
    for _, c in pairs(antiRagdollConnections) do
        pcall(function() c:Disconnect() end)
    end
    antiRagdollConnections = {}
end

local function setupAntiRagdollConnections()
    clearAntiRagdollConnections()
    if not antiRagdollHumanoid or not antiRagdollRootPart then return end

    table.insert(antiRagdollConnections, antiRagdollHumanoid.StateChanged:Connect(function()
        if (AntiRagdollEnabled or antiKnockbackEnabled) and isRagdolled() then
            if not isFlyingCarpetActive() then
                antiRagdollHumanoid:ChangeState(Enum.HumanoidStateType.Running)
            end
            cleanupRagdoll()
            Workspace.CurrentCamera.CameraSubject = antiRagdollHumanoid
            enableAntiRagdollControls()
        end
    end))

    pcall(function()
        local impulsePath = ReplicatedStorage:FindFirstChild("Packages")
        if impulsePath then
            impulsePath = impulsePath:FindFirstChild("Net")
            if impulsePath then
                impulsePath = impulsePath:FindFirstChild("RE/CombatService/ApplyImpulse")
                if impulsePath then
                    table.insert(antiRagdollConnections, impulsePath.OnClientEvent:Connect(function()
                        if (AntiRagdollEnabled or antiKnockbackEnabled) and isRagdolled() then
                            antiRagdollRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        end
                    end))
                end
            end
        end
    end)

    table.insert(antiRagdollConnections, antiRagdollCharacter.DescendantAdded:Connect(function()
        if (AntiRagdollEnabled or antiKnockbackEnabled) and isRagdolled() then
            cleanupRagdoll()
        end
    end))

    table.insert(antiRagdollConnections, RunService.Heartbeat:Connect(function()
        if (AntiRagdollEnabled or antiKnockbackEnabled) and isRagdolled() then
            cleanupRagdoll()
            local velocity = antiRagdollRootPart.AssemblyLinearVelocity
            if (velocity - lastVelocity).Magnitude > velocityChangeThreshold
                and velocity.Magnitude > velocityMagnitudeThreshold then
                antiRagdollRootPart.AssemblyLinearVelocity = velocity.Unit * math.min(velocity.Magnitude, maxVelocity)
            end
            lastVelocity = velocity
        end
    end))

    enableAntiRagdollControls()
    cleanupRagdoll()
end

local function startAntiRagdoll()
    AntiRagdollEnabled = true
    antiKnockbackEnabled = true
    if LP.Character then
        setupAntiRagdollCharacter(LP.Character)
        setupAntiRagdollConnections()
    end
end

local function stopAntiRagdoll()
    AntiRagdollEnabled = false
    antiKnockbackEnabled = false
    clearAntiRagdollConnections()
end

LP.CharacterAdded:Connect(function(char)
    clearAntiRagdollConnections()
    antiRagdollCharacter = nil; antiRagdollHumanoid = nil; antiRagdollRootPart = nil; antiRagdollAnimator = nil
    local humanoid = char:WaitForChild("Humanoid", 10)
    local rootPart = char:WaitForChild("HumanoidRootPart", 10)
    if not humanoid or not rootPart then return end
    task.wait(0.2)
    setupAntiRagdollCharacter(char)

    if AntiRagdollEnabled or antiKnockbackEnabled then
        setupAntiRagdollConnections()
    end
end)

_G.SH_startAntiRagdoll = startAntiRagdoll
_G.SH_stopAntiRagdoll  = stopAntiRagdoll
print("[SH] AntiRagdoll Engine ready.")
end

task.wait()  -- OPT v9b: yield frame between engine inits (prevents freeze)

--------------------------------------------------------------------------------
-- 8.4  PLAYER BOX ESP ENGINE (Drawing API)
--------------------------------------------------------------------------------
do
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera     = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local PlayerESPEnabled = false

local _espDrawings = {}

local DANGER_TOOLS = {
    ["Boogie Bomb"] = true, ["Medusa's Head"] = true, ["Body Swap Potion"] = true,
    ["Laser Cape"] = true, ["Rainbowrath Sword"] = true, ["Gummy Bear"] = true
}

local function getHeldTool(p)
    local c = p.Character
    if not c then return nil end
    for _, o in ipairs(c:GetChildren()) do if o:IsA("Tool") then return o.Name end end
    return nil
end

local function _makeDrawings(uid)
    local box = Drawing.new("Square")
    box.Visible       = false
    box.Filled        = false
    box.Color         = Color3.fromRGB(255, 255, 255)
    box.Thickness     = 1.5
    box.Transparency  = 1

    local nameLabel = Drawing.new("Text")
    nameLabel.Visible    = false
    nameLabel.Center     = true
    nameLabel.Outline    = true
    nameLabel.Color      = Color3.fromRGB(255, 255, 255)
    nameLabel.OutlineColor = Color3.fromRGB(0, 0, 0)
    nameLabel.Size       = 13
    nameLabel.Font       = Drawing.Fonts.UI

    local distLabel = Drawing.new("Text")
    distLabel.Visible    = false
    distLabel.Center     = true
    distLabel.Outline    = true
    distLabel.Color      = Color3.fromRGB(180, 220, 255)
    distLabel.OutlineColor = Color3.fromRGB(0, 0, 0)
    distLabel.Size       = 11
    distLabel.Font       = Drawing.Fonts.UI

    _espDrawings[uid] = { box = box, name = nameLabel, dist = distLabel }
end

local function _hideDrawings(uid)
    local d = _espDrawings[uid]
    if not d then return end
    d.box.Visible  = false
    d.name.Visible = false
    d.dist.Visible = false
end

local function _removeDrawings(uid)
    local d = _espDrawings[uid]
    if not d then return end
    pcall(function() d.box:Remove() end)
    pcall(function() d.name:Remove() end)
    pcall(function() d.dist:Remove() end)
    _espDrawings[uid] = nil
end

local function clearPlayerESP()
    for uid, _ in pairs(_espDrawings) do
        _removeDrawings(uid)
    end
end

local function _getScreenBox(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local pos = hrp.Position
    local hw, hh, hd = 1.0, 2.8, 0.6
    local corners = {
        Vector3.new( hw,  hh,  hd), Vector3.new(-hw,  hh,  hd),
        Vector3.new( hw, -hh,  hd), Vector3.new(-hw, -hh,  hd),
        Vector3.new( hw,  hh, -hd), Vector3.new(-hw,  hh, -hd),
        Vector3.new( hw, -hh, -hd), Vector3.new(-hw, -hh, -hd),
    }
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local anyVisible = false
    for _, offset in ipairs(corners) do
        local wp = pos + offset
        local sp, onScreen = Camera:WorldToViewportPoint(wp)
        if onScreen and sp.Z > 0 then
            anyVisible = true
            if sp.X < minX then minX = sp.X end
            if sp.Y < minY then minY = sp.Y end
            if sp.X > maxX then maxX = sp.X end
            if sp.Y > maxY then maxY = sp.Y end
        end
    end
    if not anyVisible then return nil end
    return { x = minX, y = minY, w = maxX - minX, h = maxY - minY }
end

RunService.RenderStepped:Connect(function()
    if not PlayerESPEnabled then
        for uid, _ in pairs(_espDrawings) do _hideDrawings(uid) end
        return
    end

    local lpHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local lpPos = lpHrp and lpHrp.Position

    local activePlayers = {}

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end

        local uid = plr.UserId
        activePlayers[uid] = true

        if not _espDrawings[uid] then _makeDrawings(uid) end
        local d = _espDrawings[uid]

        local rect = _getScreenBox(char)
        if not rect then
            _hideDrawings(uid)
            continue
        end

        local tool = getHeldTool(plr)
        local col = (tool and DANGER_TOOLS[tool]) and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(255, 255, 255)

        d.box.Position    = Vector2.new(rect.x, rect.y)
        d.box.Size        = Vector2.new(rect.w, rect.h)
        d.box.Color       = col
        d.box.Visible     = true

        d.name.Text       = plr.DisplayName .. (tool and (" [" .. tool .. "]") or "")
        d.name.Color      = col
        d.name.Position   = Vector2.new(rect.x + rect.w / 2, rect.y - 15)
        d.name.Visible    = true

        if lpPos then
            local dist = math.floor((hrp.Position - lpPos).Magnitude)
            d.dist.Text     = dist .. " studs"
            d.dist.Position = Vector2.new(rect.x + rect.w / 2, rect.y + rect.h + 2)
            d.dist.Visible  = true
        else
            d.dist.Visible = false
        end
    end

    for uid, _ in pairs(_espDrawings) do
        if not activePlayers[uid] then
            _hideDrawings(uid)
        end
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    _removeDrawings(plr.UserId)
end)

_G.SH_togglePlayerESP = function(state)
    PlayerESPEnabled = state
    if not state then
        for uid, _ in pairs(_espDrawings) do _hideDrawings(uid) end
    end
end
print("[SH] Player Box ESP Engine ready.")
end

task.wait()  -- OPT v9b: yield frame between engine inits (prevents freeze)

--------------------------------------------------------------------------------
-- 8.5  STEAL PANEL ENGINE
--------------------------------------------------------------------------------
do
local _LP = game:GetService("Players").LocalPlayer
local _spGui = nil
local _spUIS = game:GetService("UserInputService")

local _spT = {
    autoSteal=false, stealHighest=false, stealPriority=true,
    stealNearest=false, autoKick=false, autoBuy=false
}
pcall(function()
    if _SH_ConfigRaw then
        local r = _SH_ConfigRaw
        if type(r.spT_autoSteal)    == "boolean" then _spT.autoSteal    = r.spT_autoSteal    end
        if type(r.spT_stealHighest) == "boolean" then _spT.stealHighest = r.spT_stealHighest end
        if type(r.spT_stealPriority)== "boolean" then _spT.stealPriority= r.spT_stealPriority end
        if type(r.spT_stealNearest) == "boolean" then _spT.stealNearest = r.spT_stealNearest  end
        if type(r.spT_autoBuy)      == "boolean" then _spT.autoBuy      = r.spT_autoBuy      end
        if type(r.spT_autoKick)     == "boolean" then _spT.autoKick     = r.spT_autoKick     end
    end
end)

local STEAL_MODES = {"stealHighest","stealPriority","stealNearest"}

local _spBtns = {}

local function _spRefreshButtons()
    for _, key in ipairs(STEAL_MODES) do
        local btn = _spBtns[key]
        if btn then
            local on = _spT[key]
            if on then
                btn.Text="ON"; btn.BackgroundColor3=Color3.fromRGB(255,255,255)
                btn.TextColor3=Color3.fromRGB(0,30,60); btn.BackgroundTransparency=0.1
            else
                btn.Text="OFF"; btn.BackgroundColor3=Color3.fromRGB(0,30,60)
                btn.TextColor3=Color3.fromRGB(210,185,130); btn.BackgroundTransparency=0.5
            end
        end
    end
end

local function _spApply(key, on)
    if on and (key=="stealHighest" or key=="stealPriority" or key=="stealNearest") then
        for _, mkey in ipairs(STEAL_MODES) do
            _spT[mkey] = (mkey == key)
        end
        _spRefreshButtons()
    else
        _spT[key] = on
    end

    local mode = "priority"
    if _spT.stealHighest then mode="highest"
    elseif _spT.stealNearest then mode="nearest"
    end

    if key == "autoSteal" then
        if _G.SabcomAutoSteal then pcall(_G.SabcomAutoSteal, on) end
    elseif key == "stealHighest" or key == "stealPriority" or key == "stealNearest" then
        if _G.setStealMode then pcall(_G.setStealMode, mode:sub(1,1):upper()..mode:sub(2)) end
        _G.MynxxStealMode = mode
        if _G.SharedState then _G.SharedState.StealMode = mode end
        if _G.TOGGLE_STATES and _G.TOGGLE_STATES["_stealModeSync"] then
            pcall(_G.TOGGLE_STATES["_stealModeSync"].set, mode)
        end
        pcall(function()
            local _nearest = (_spT.stealNearest == true)
            local _prio    = (_spT.stealPriority == true)
            if _G.JAF_SetStealNearest then _G.JAF_SetStealNearest(_nearest) end
            local cfg = _G._gcf and _G._gcf()
            if cfg then
                cfg.UsePriority = _prio and not _nearest
            end
        end)
    elseif key == "autoKick" then
        if _G.SH_toggleAutoKick then pcall(_G.SH_toggleAutoKick, on) end
    elseif key == "autoBuy" then
        if _G.SH_toggleAutoBuy then
            pcall(_G.SH_toggleAutoBuy, on)
        else
            task.spawn(function()
                local t=0
                while not _G.SH_toggleAutoBuy and t<15 do
                    task.wait(0.3); t=t+0.3
                end
                if _G.SH_toggleAutoBuy then pcall(_G.SH_toggleAutoBuy, on) end
            end)
        end
    end
    pcall(function()
        if _SH_ConfigRaw then
            _SH_ConfigRaw.spT_autoSteal    = _spT.autoSteal
            _SH_ConfigRaw.spT_stealHighest = _spT.stealHighest
            _SH_ConfigRaw.spT_stealPriority= _spT.stealPriority
            _SH_ConfigRaw.spT_stealNearest = _spT.stealNearest
            _SH_ConfigRaw.spT_autoBuy      = _spT.autoBuy
            _SH_ConfigRaw.spT_autoKick     = _spT.autoKick
        end
        task.defer(saveConfig)
    end)
end

local function _buildSP()
    local pg = _LP:FindFirstChild("PlayerGui") or _LP:WaitForChild("PlayerGui")
    local old = pg:FindFirstChild("SH_StealPanel")
    if old then old:Destroy() end
    local sg = Instance.new("ScreenGui")
    sg.Name = "SH_StealPanel"; sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true; sg.DisplayOrder = 999997
    sg.Enabled = false; sg.Parent = pg; _spGui = sg
    local mf = Instance.new("Frame")
    mf.Name = "MainFrame"
    mf.Size = UDim2.new(0,220,0,310)
    mf.Position = UDim2.new(1,-230,0.5,-155)
    mf.BackgroundColor3 = Color3.fromRGB(4,4,6)
    mf.BackgroundTransparency = 0
    mf.BorderSizePixel = 0; mf.Active = true
    mf.Draggable = not(_G.SH_UIsLocked); mf.Parent = sg
    if _G._SH_loadUIPos then pcall(_G._SH_loadUIPos, "StealPanel", mf) end
    _spUIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            if _G._SH_saveUIPos then pcall(_G._SH_saveUIPos, "StealPanel", mf) end
        end
    end)
    Instance.new("UICorner", mf).CornerRadius = UDim.new(0,10)
    local ms = Instance.new("UIStroke", mf)
    ms.Color = Color3.fromRGB(180,130,0); ms.Thickness = 1.5; ms.Transparency = 0.2
    task.spawn(function()
        local t=0
        while mf and mf.Parent do
            t=t+task.wait(0.016)
            ms.Transparency=0.15+math.sin(t*1.3)*0.08+math.sin(t*2.2+0.6)*0.04
            ms.Color=Color3.fromRGB(
                math.floor(160+math.sin(t*0.7)*22),
                math.floor(115+math.sin(t*1.4)*14),
                0)
        end
    end)
    local t1 = Instance.new("TextLabel", mf)
    t1.Size = UDim2.new(1,0,0,20); t1.Position = UDim2.fromOffset(0,8)
    t1.BackgroundTransparency = 1; t1.Text = "SILENCE HUB PRVT"
    t1.TextColor3 = Color3.fromRGB(255,215,60)
    t1.Font = Enum.Font.GothamBlack; t1.TextSize = 13
    do
        local _sg=Instance.new("UIGradient",t1)
        _sg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(140,95,0)),ColorSequenceKeypoint.new(0.3,Color3.fromRGB(230,170,20)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(255,235,100)),ColorSequenceKeypoint.new(0.7,Color3.fromRGB(230,170,20)),ColorSequenceKeypoint.new(1,Color3.fromRGB(140,95,0))})
        task.spawn(function() local t=0 while t1 and t1.Parent do t=t+task.wait(0.016) _sg.Offset=Vector2.new(math.sin(t*0.7)*0.55+math.sin(t*1.5+0.8)*0.12,0) end end)
    end
    local t2 = Instance.new("TextLabel", mf)
    t2.Size = UDim2.new(1,0,0,15); t2.Position = UDim2.fromOffset(0,24)
    t2.BackgroundTransparency = 1; t2.Text = "Steal Panel"
    t2.TextColor3 = Color3.fromRGB(150,115,40)
    t2.Font = Enum.Font.Gotham; t2.TextSize = 10
    local sep = Instance.new("Frame", mf)
    sep.Size = UDim2.new(0.85,0,0,1); sep.Position = UDim2.new(0.075,0,0,44)
    sep.BackgroundColor3 = Color3.fromRGB(160,115,0)
    sep.BackgroundTransparency = 0.3; sep.BorderSizePixel = 0
    local cfgs = {
        {"Auto Steal:","autoSteal",false},
        {"Steal Highest:","stealHighest",false},
        {"Steal Priority:","stealPriority",true},
        {"Steal Nearest:","stealNearest",false},
        {"Auto Buy:","autoBuy",false},
        {"Auto Kick:","autoKick",false},
    }
    _spBtns = {}
    for i, c in ipairs(cfgs) do
        local isOn = (_spT[c[2]] ~= nil) and _spT[c[2]] or c[3]
        local lbl = Instance.new("TextLabel", mf)
        lbl.Size = UDim2.new(0,110,0,26)
        lbl.Position = UDim2.fromOffset(12, 54+(i-1)*40)
        lbl.BackgroundTransparency = 1; lbl.Text = c[1]
        lbl.TextColor3 = Color3.fromRGB(255,255,255)
        lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        local btn = Instance.new("TextButton", mf)
        btn.Size = UDim2.new(0,65,0,26)
        btn.Position = UDim2.new(1,-77,0, 54+(i-1)*40)
        btn.Font = Enum.Font.GothamBold; btn.TextSize = 12
        btn.AutoButtonColor = false
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
        _spBtns[c[2]] = btn
        local function upd(state)
            if state then
                btn.Text="ON"; btn.BackgroundColor3=Color3.fromRGB(180,130,0)
                btn.TextColor3=Color3.fromRGB(10,8,0); btn.BackgroundTransparency=0
            else
                btn.Text="OFF"; btn.BackgroundColor3=Color3.fromRGB(16,14,4)
                btn.TextColor3=Color3.fromRGB(140,125,80); btn.BackgroundTransparency=0.3
            end
        end
        upd(isOn)
        local key = c[2]
        btn.MouseButton1Click:Connect(function()
            local newState = not _spT[key]
            _spApply(key, newState)
            if key ~= "stealHighest" and key ~= "stealPriority" and key ~= "stealNearest" then
                upd(_spT[key])
            end
        end)
    end
    _spRefreshButtons()
end

_G.SH_ShowStealPanel = function(on)
    if on then
        if not _spGui or not _spGui.Parent then _buildSP() end
        if _spGui then _spGui.Enabled = true end
    else
        if _spGui then _spGui.Enabled = false end
    end
end
print("[SH] Steal Panel Engine ready.")
end

task.wait()  -- OPT v9b: yield frame between engine inits (prevents freeze)

--------------------------------------------------------------------------------
-- 8.6  AUTO-BUY ENGINE
--------------------------------------------------------------------------------
do
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local S = {Range=17,GrabSpeed=17,HoverHeight=3,CarpetName="Flying Carpet",BurstCount=3,Interval=0.02,ToggleKey=Enum.KeyCode.B}
local ABE = false
local CV, lT, lP, lM = {}, nil, nil, nil
local ring, bp, clConn, pr = nil, nil, nil, nil
local lF = setmetatable({},{__mode="k"})
local iF = setmetatable({},{__mode="k"})

local function cRing()
    if ring then ring:Destroy() end
    local r = Instance.new("Part")
    r.Name="StandaloneAutoBuyRing"; r.Shape=Enum.PartType.Cylinder
    r.Anchored=true; r.CanCollide=false; r.CanTouch=false
    r.CanQuery=false; r.CastShadow=false
    r.Material=Enum.Material.Neon; r.Transparency=0.5
    r.Color=Color3.fromRGB(0,150,255)
    r.Size=Vector3.new(0.5,S.Range*2,S.Range*2); r.Parent=Workspace
    ring = r
end
local function dRing()
    if ring then ring:Destroy(); ring=nil end
    local e = Workspace:FindFirstChild("StandaloneAutoBuyRing")
    if e then e:Destroy() end
end
local rfc = 0
RunService.Heartbeat:Connect(function()
    if not ABE or not ring then return end
    rfc=rfc+1; if rfc<3 then return end; rfc=0
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        ring.Size = Vector3.new(0.5,S.Range*2,S.Range*2)
        ring.CFrame = (hrp.CFrame*CFrame.Angles(0,0,math.rad(90)))+Vector3.new(0,-2.5,0)
    end
end)
local function rPR()
    if pr and pr.Parent then return pr end
    pcall(function()
        local net = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Net")
        if not net then return end
        for _,v in ipairs(net:GetChildren()) do
            local n = (v.Name or ""):lower()
            for _,k in ipairs({"buy","purchase","animal","shop","acquire","conveyor"}) do
                if n:find(k) then pr=v; return end
            end
        end
    end)
    return pr
end
local function scan()
    local r = {}
    for _,o in ipairs(Workspace:GetDescendants()) do
        if o:IsA("ProximityPrompt") and o.Enabled then
            local t = o.ActionText or ""
            if t=="Purchase" or t:lower():find("purchase") or t:lower():find("comprar") then
                local p = o.Parent
                if p then
                    local rp = (p:IsA("Attachment") and p.Parent) or p
                    if rp and rp:IsA("BasePart") then
                        local m = rp:FindFirstAncestorOfClass("Model")
                        table.insert(r,{name=m and m.Name or "?",prompt=o,part=rp,model=m})
                    end
                end
            end
        end
    end
    return r
end
local function refCV() local ok,f=pcall(scan); if ok and f then CV=f end end
local function fire(prompt)
    if not prompt or not prompt.Parent or not prompt.Enabled then return end
    local now = os.clock()
    if lF[prompt] and (now-lF[prompt])<0.03 then return end
    lF[prompt] = now
    if iF[prompt] then return end
    iF[prompt] = true
    task.spawn(function()
        local rem = rPR()
        if rem then pcall(function()
            if rem:IsA("RemoteFunction") then rem:InvokeServer(prompt.Parent)
            elseif rem:IsA("RemoteEvent") then rem:FireServer(prompt.Parent) end
        end) end
        iF[prompt] = nil
    end)
end
local function startCL()
    if clConn then clConn:Disconnect() end
    clConn = RunService.Heartbeat:Connect(function()
        if not ABE then return end
        pcall(function()
            local c = player.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            if not h then return end
            if not c:FindFirstChild(S.CarpetName) then
                local t = player.Backpack:FindFirstChild(S.CarpetName)
                if t then h:EquipTool(t) end
            end
        end)
    end)
end
local function stopCL() if clConn then clConn:Disconnect(); clConn=nil end end
local function eBP(hrp)
    if bp and bp.Parent==hrp then bp.P=S.GrabSpeed*8000; bp.D=2000; return bp end
    if bp then bp:Destroy() end
    local b = Instance.new("BodyPosition", hrp)
    b.MaxForce = Vector3.new(math.huge,math.huge,math.huge)
    b.P = S.GrabSpeed*8000; b.D = 2000; b.Position = hrp.Position
    bp = b; return b
end
local function dBP() if bp then bp:Destroy(); bp=nil end end
local function pA() return lP and lP.Parent and lM and lM.Parent end
local function prA() return lT and lT.prompt and lT.prompt.Parent and lT.prompt.Enabled end

RunService.Heartbeat:Connect(function()
    if not ABE or not pA() then dBP(); return end
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then dBP(); return end
    eBP(hrp).Position = lP.Position + Vector3.new(0,S.HoverHeight,0)
end)

task.spawn(function()
    local _myId = _G.__SH_AutoSaveId
    while _G.__SH_AutoSaveId == _myId do
        task.wait(S.Interval)
        if _G.__SH_AutoSaveId ~= _myId then break end
        if not ABE then continue end
        if pA() and prA() then fire(lT.prompt) end
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local lp = lT and lT.prompt
            for _,e in ipairs(CV) do
                if e.prompt and e.prompt~=lp and e.prompt.Parent and e.prompt.Enabled
                   and e.part and e.part.Parent then
                    if (hrp.Position-e.part.Position).Magnitude <= (S.Range+8) then
                        fire(e.prompt)
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    local _myId = _G.__SH_AutoSaveId
    while _G.__SH_AutoSaveId == _myId do
        task.wait(0.075)
        if _G.__SH_AutoSaveId ~= _myId then break end
        if not ABE then
            lT=nil; lP=nil; lM=nil; stopCL(); dBP(); continue
        end
        if lP or lM then
            if not pA() then pcall(refCV); lT=nil; lP=nil; lM=nil end
            continue
        end
        pcall(refCV)
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local best, bestD = nil, math.huge
        for _,e in ipairs(CV) do
            if e.prompt and e.prompt.Parent and e.prompt.Enabled and e.part and e.part.Parent then
                local d = (hrp.Position-e.part.Position).Magnitude
                if d<=S.Range and d<bestD then bestD=d; best=e end
            end
        end
        if best then
            lT=best; lP=best.part; lM=best.model or best.part.Parent
            startCL()
            task.spawn(function()
                for _=1,S.BurstCount do
                    if not(best.prompt and best.prompt.Parent and best.prompt.Enabled) then break end
                    fire(best.prompt)
                end
            end)
        end
    end
end)

game:GetService("UserInputService").InputBegan:Connect(function(i,gp)
    if gp then return end
    if i.KeyCode == S.ToggleKey then
        if _G.SH_toggleAutoBuy then pcall(_G.SH_toggleAutoBuy) end
    end
end)

_G.SH_setAutoBuyKey = function(kc) S.ToggleKey = kc end
_G.SH_toggleAutoBuy = function(state)
    ABE = (state==true or (state~=false and not ABE))
    if ABE then
        pcall(refCV); cRing(); startCL(); print("[SH] Auto Buy ON")
    else
        dRing(); stopCL(); dBP(); print("[SH] Auto Buy OFF")
    end
end
print("[SH] Auto Buy Engine ready.")
end

task.wait()  -- OPT v9b: yield frame between engine inits (prevents freeze)

--------------------------------------------------------------------------------
-- 8.7  KICK TO PS ENGINE
--------------------------------------------------------------------------------
do
local Players = game:GetService("Players")
local ExperienceService = game:GetService("ExperienceService")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")
local _on = false
local _code = ""
local hooked = setmetatable({},{__mode="k"})
local isTp = false

local function doTp()
    if isTp or _code == "" then return end
    isTp = true
    print("[SH] Steal erkannt -> PS Teleport...")
    task.delay(0.2, function()
        pcall(function()
            ExperienceService:LaunchExperience({placeId=game.PlaceId, linkCode=_code})
        end)
    end)
    task.delay(5, function()
        pcall(function() game:Shutdown() end)
        pcall(function() LP:Kick("PS Teleport Timeout") end)
    end)
end

local function chk(t)
    if not _on then return end
    if type(t)=="string" and string.find(string.lower(t),"you stole",1,true) then
        doTp()
    end
end

local function hook(o)
    if hooked[o] then return end
    hooked[o] = true
    chk(tostring(o.Text or ""))
    o:GetPropertyChangedSignal("Text"):Connect(function()
        chk(tostring(o.Text or ""))
    end)
end

local function watch(root)
    for _,o in ipairs(root:GetDescendants()) do
        if o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox") then
            hook(o)
        end
    end
    root.DescendantAdded:Connect(function(d)
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            hook(d)
        end
    end)
end

for _,g in ipairs(PG:GetChildren()) do watch(g) end
PG.ChildAdded:Connect(function(g) watch(g) end)

_G.SH_toggleKickToPS = function(on)
    _on = on; isTp = false
    print("[SH] Kick to PS: " .. (on and "ON" or "OFF"))
end
_G.SH_setKickToPSCode = function(code)
    _code = tostring(code or ""):gsub("%s+","")
end
print("[SH] Kick to PS Engine ready.")
end

task.wait()  -- OPT v9b: yield frame between engine inits (prevents freeze)

--------------------------------------------------------------------------------
-- 8.8  ADMIN PANEL ENGINE
--------------------------------------------------------------------------------
do
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local T = {
    Background=Color3.fromRGB(4,4,6),
    Panel=Color3.fromRGB(10,10,14),
    Row=Color3.fromRGB(14,14,18),
    RowHover=Color3.fromRGB(22,18,8),
    Accent=Color3.fromRGB(180,130,0),
    AccentLight=Color3.fromRGB(255,210,60),
    Green=Color3.fromRGB(58,255,208),
    Red=Color3.fromRGB(255,80,110),
    Text=Color3.fromRGB(220,215,200),
    Dim=Color3.fromRGB(140,125,90),
    SoftButton=Color3.fromRGB(40,28,0),
    SoftButtonHover=Color3.fromRGB(60,42,0),
    SoftAccent=Color3.fromRGB(22,16,0),
    ToggleOff2=Color3.fromRGB(16,12,4),
    InputBg=Color3.fromRGB(8,8,12),
    BlacklistLeave=Color3.fromRGB(30,10,10),
}
local APCmds = {"balloon","inverse","jail","jumpscare","morph","nightvision","ragdoll","rocket","tiny"}
local APL = {balloon="BAL",inverse="INV",jail="JAIL",jumpscare="JMP",morph="MRPH",nightvision="NVIS",ragdoll="RAG",rocket="RKT",tiny="TINY"}
local APC = {ragdoll=30,jail=60,rocket=120,balloon=30,inverse=30,jumpscare=30,tiny=30,morph=30,nightvision=30}
local lastU = {}
local apBL = {}
local ProxActive = false
local ProxRange = 15
local proxPart = nil

local function cdn(c)
    local l=lastU[c]; local d=APC[c] or 0
    return l and d>0 and (tick()-l)<d
end
local function cdrem(c)
    local l=lastU[c]; local d=APC[c] or 0
    if not l then return 0 end
    return math.max(0,d-(tick()-l))
end
local function blk(p)
    if not p then return false end
    return apBL[p.UserId]==true
end
local function tw(o,p,t)
    TweenService:Create(o,TweenInfo.new(t or 0.14,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),p):Play()
end
local function cr(o,r)
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r); c.Parent=o
end
local function apDrag(frame, handle, saveName)
    local drag,ds,sp=false,nil,nil
    handle.InputBegan:Connect(function(i)
        if _G.SH_UIsLocked then return end
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            drag=true; ds=i.Position; sp=frame.Position
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 and drag then
            drag=false
            if saveName and _G._SH_saveUIPos then
                pcall(_G._SH_saveUIPos, saveName, frame)
            end
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if _G.SH_UIsLocked then drag=false; return end
        if drag and i.UserInputType==Enum.UserInputType.MouseMovement then
            local d=i.Position-ds
            frame.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
        end
    end)
    if saveName and _G._SH_loadUIPos then
        pcall(_G._SH_loadUIPos, saveName, frame)
    end
end

local function fireClick(btn)
    if not btn then return end
    pcall(function() btn:activate() end)
end

local function _readRealAdminTimer(cmd)
    local ag=PG:FindFirstChild("AdminPanel")
    if not ag then return nil end
    local ok,cs=pcall(function() return ag.AdminPanel.Content.ScrollingFrame end)
    if not ok then return nil end
    local cb=cs:FindFirstChild(cmd)
    if not cb then return nil end
    local tl=cb:FindFirstChild("Timer")
    if not tl or not tl.Visible then return 0 end
    return tonumber(tl.Text:match("%d+")) or 0
end

local function runCmd(plr, cmd)
    if not plr or not cmd or blk(plr) then return false end
    local realT=_readRealAdminTimer(cmd)
    if realT~=nil and realT>0 then return false end
    if realT==nil and cdn(cmd) then return false end
    local ag=PG:FindFirstChild("AdminPanel")
    if not ag then ag=PG:WaitForChild("AdminPanel",3) end
    if not ag then return false end
    local was=ag.Enabled; ag.Enabled=true
    local ok,cs=pcall(function() return ag.AdminPanel.Content.ScrollingFrame end)
    if not ok then ag.Enabled=was; return false end
    local cb=cs:FindFirstChild(cmd)
    if not cb then ag.Enabled=was; return false end
    fireClick(cb); task.wait(0.01)
    local ok2,ps=pcall(function() return ag.AdminPanel.Profiles.ScrollingFrame end)
    if not ok2 then ag.Enabled=was; return false end
    local pb=ps:FindFirstChild(plr.Name)
    if not pb then
        for _,c in ipairs(ps:GetChildren()) do
            if c:IsA("GuiButton") then
                local nl=c:FindFirstChildWhichIsA("TextLabel")
                if nl and(nl.Text==plr.Name or nl.Text==plr.DisplayName) then pb=c; break end
            end
        end
    end
    if not pb then ag.Enabled=was; return false end
    fireClick(pb); lastU[cmd]=tick()
    task.delay(0.05,function() if ag and ag.Parent then ag.Enabled=was end end)
    return true
end

local function getOwner(plot)
    if not plot then return nil end
    for _,d in ipairs(plot:GetDescendants()) do
        if d.Name:lower()=="owner" or d.Name:lower()=="player" then
            if d:IsA("ObjectValue") and d.Value and d.Value:IsA("Player") then return d.Value end
            if d:IsA("StringValue") and d.Value~="" then return Players:FindFirstChild(d.Value) end
        end
    end
    local s=plot:FindFirstChild("PlotSign",true)
    if s then
        for _,d in ipairs(s:GetDescendants()) do
            if d:IsA("TextLabel") and d.Text~="" then
                local n=d.Text:match("^(.-)'") or d.Text:match("[Oo]wner:%s*(.+)") or d.Text
                if n then
                    n=n:match("^%s*(.-)%s*$")
                    for _,p in ipairs(Players:GetPlayers()) do
                        if p.Name:lower()==n:lower() or p.DisplayName:lower()==n:lower() then return p end
                    end
                end
            end
        end
    end
    return nil
end
local function spamBase()
    local c=LP.Character; local h=c and c:FindFirstChild("HumanoidRootPart")
    if not h then return end
    local np,nd=nil,math.huge
    local pc=Workspace:FindFirstChild("Plots") or Workspace:FindFirstChild("Bases")
    local all=pc and pc:GetChildren() or Workspace:GetChildren()
    for _,pl in ipairs(all) do
        local s=pl:FindFirstChild("PlotSign",true) or pl:FindFirstChild("Sign",true)
        if s then
            local sp2=nil
            if s:IsA("BasePart") then sp2=s.Position
            elseif s:IsA("Model") and s.PrimaryPart then sp2=s.PrimaryPart.Position
            else local pt=s:FindFirstChildWhichIsA("BasePart",true); if pt then sp2=pt.Position end end
            if sp2 then local d=(h.Position-sp2).Magnitude; if d<nd then nd=d; np=pl end end
        end
    end
    if not np then return end
    local op=getOwner(np)
    if not op or op==LP or blk(op) then return end
    for i,cmd in ipairs(APCmds) do
        if not cdn(cmd) then
            task.spawn(function() task.wait((i-1)*0.01); runCmd(op,cmd) end)
        end
    end
end

local function dProx()
    if proxPart and proxPart.Parent then proxPart:Destroy() end
    proxPart=nil
    local old=Workspace:FindFirstChild("SilenceProxCircle")
    if old then old:Destroy() end
end
local function bProx()
    dProx()
    local p=Instance.new("Part")
    p.Name="SilenceProxCircle"; p.Anchored=true; p.CanCollide=false
    p.CanTouch=false; p.CanQuery=false; p.CastShadow=false
    p.Size=Vector3.new(0.2,ProxRange*2,ProxRange*2); p.Shape=Enum.PartType.Cylinder
    p.Material=Enum.Material.Neon; p.Color=Color3.fromRGB(255,50,50)
    p.Transparency=0.8; p.Parent=Workspace; proxPart=p
end
local function uProx()
    if not proxPart or not proxPart.Parent then return end
    local h=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not h then return end
    proxPart.CFrame=(h.CFrame*CFrame.Angles(0,0,math.rad(90)))-Vector3.new(0,2.8,0)
    proxPart.Size=Vector3.new(0.2,ProxRange*2,ProxRange*2)
end
local function setProx(on) ProxActive=on; if on then bProx() else dProx() end end
LP.CharacterAdded:Connect(function() if ProxActive then task.wait(0.5); bProx() end end)

task.spawn(function()
    local _myId = _G.__SH_AutoSaveId
    while _G.__SH_AutoSaveId == _myId do
        task.wait(0.2)
        if _G.__SH_AutoSaveId ~= _myId then break end
        if ProxActive then
            uProx()
            local mc=LP.Character
            local mh=mc and mc:FindFirstChild("HumanoidRootPart")
            if mh then
                for _,p in ipairs(Players:GetPlayers()) do
                    if p~=LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and not blk(p) then
                        if (p.Character.HumanoidRootPart.Position-mh.Position).Magnitude<=ProxRange then
                            local activeCmds={}
                            for _,cmd in ipairs(APCmds) do
                                local realT=_readRealAdminTimer(cmd)
                                if (realT~=nil and realT<=0) or (realT==nil and not cdn(cmd)) then
                                    table.insert(activeCmds,cmd)
                                end
                            end
                            for i,cmd in ipairs(activeCmds) do
                                task.spawn(function() task.wait((i-1)*0.01); runCmd(p,cmd) end)
                            end
                        end
                    end
                end
            end
        end
    end
end)

local _built=false; local sg1,sg2

local function build()
    if _built then return end; _built=true

    sg1=Instance.new("ScreenGui"); sg1.Name="SH_AdminPanel1"
    sg1.ResetOnSpawn=false; sg1.IgnoreGuiInset=true
    sg1.DisplayOrder=9999999; sg1.Parent=PG

    local p1=Instance.new("Frame"); p1.Size=UDim2.new(0,225,0,300)
    p1.Position=UDim2.new(0.5,85,1,-280); p1.BackgroundColor3=T.Background
    p1.BackgroundTransparency=0; p1.BorderSizePixel=0; p1.Parent=sg1; cr(p1,10)
    local _p1s=Instance.new("UIStroke",p1);_p1s.Color=Color3.fromRGB(160,115,0);_p1s.Thickness=1.2;_p1s.Transparency=0.2
    task.spawn(function()
        local t=0
        while p1 and p1.Parent do
            t=t+task.wait(0.016)
            _p1s.Transparency=0.15+math.sin(t*1.0)*0.08+math.sin(t*1.9+1.1)*0.04
            _p1s.Color=Color3.fromRGB(math.floor(155+math.sin(t*0.8)*20),math.floor(110+math.sin(t*1.5)*13),0)
        end
    end)
    local h1=Instance.new("Frame"); h1.Size=UDim2.new(1,0,0,30)
    h1.BackgroundTransparency=1; h1.Parent=p1; apDrag(p1,h1,"AdminCmdPanel")
    local tl1=Instance.new("TextLabel"); tl1.Size=UDim2.new(1,0,0,16)
    tl1.Position=UDim2.fromOffset(0,7); tl1.BackgroundTransparency=1
    tl1.Text="silence | Admin Commands"; tl1.TextColor3=Color3.fromRGB(255,210,60)
    tl1.Font=Enum.Font.GothamBlack; tl1.TextSize=12
    tl1.TextXAlignment=Enum.TextXAlignment.Center; tl1.Parent=h1
    do
        local _tg=Instance.new("UIGradient",tl1)
        _tg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(140,95,0)),ColorSequenceKeypoint.new(0.3,Color3.fromRGB(230,170,20)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(255,235,100)),ColorSequenceKeypoint.new(0.7,Color3.fromRGB(230,170,20)),ColorSequenceKeypoint.new(1,Color3.fromRGB(140,95,0))})
        task.spawn(function() local t=0 while tl1 and tl1.Parent do t=t+task.wait(0.016) _tg.Offset=Vector2.new(math.sin(t*0.8)*0.55+math.sin(t*1.6+0.5)*0.12,0) end end)
    end
    local b1=Instance.new("Frame"); b1.Size=UDim2.new(1,-12,1,-36)
    b1.Position=UDim2.fromOffset(6,34); b1.BackgroundTransparency=1; b1.Parent=p1
    local l1=Instance.new("UIListLayout"); l1.Padding=UDim.new(0,6); l1.Parent=b1
    local prow=Instance.new("Frame"); prow.Size=UDim2.new(1,0,0,28)
    prow.BackgroundTransparency=1; prow.Parent=b1
    local plbl=Instance.new("TextLabel"); plbl.Size=UDim2.new(1,-80,1,0)
    plbl.Position=UDim2.fromOffset(4,0); plbl.BackgroundTransparency=1
    plbl.Text="Proximity AP:"; plbl.TextColor3=T.Text
    plbl.Font=Enum.Font.GothamSemibold; plbl.TextSize=12
    plbl.TextXAlignment=Enum.TextXAlignment.Left; plbl.Parent=prow
    local pbtn=Instance.new("TextButton"); pbtn.Size=UDim2.new(0,72,0,24)
    pbtn.Position=UDim2.new(1,-74,0.5,-12); pbtn.Font=Enum.Font.GothamBlack
    pbtn.TextSize=12; pbtn.AutoButtonColor=false; pbtn.Parent=prow; cr(pbtn,8)
    local function upP()
        pbtn.BackgroundColor3=ProxActive and T.Green or T.ToggleOff2
        pbtn.Text=ProxActive and "ON" or "OFF"
        pbtn.TextColor3=ProxActive and Color3.fromRGB(10,8,0) or Color3.fromRGB(180,160,100)
    end
    upP()
    pbtn.MouseButton1Click:Connect(function() setProx(not ProxActive); upP() end)
    local srow=Instance.new("Frame"); srow.Size=UDim2.new(1,0,0,52)
    srow.BackgroundTransparency=1; srow.Parent=b1
    local slbl=Instance.new("TextLabel"); slbl.Size=UDim2.new(1,0,0,16)
    slbl.BackgroundTransparency=1; slbl.TextXAlignment=Enum.TextXAlignment.Left
    slbl.Font=Enum.Font.GothamSemibold; slbl.TextSize=12; slbl.TextColor3=T.Dim
    slbl.Text="Range: "..tostring(ProxRange); slbl.Parent=srow
    local strack=Instance.new("Frame"); strack.Size=UDim2.new(1,-4,0,6)
    strack.Position=UDim2.fromOffset(2,26); strack.BackgroundColor3=T.ToggleOff2
    strack.BorderSizePixel=0; strack.Parent=srow; cr(strack,3)
    local sfill=Instance.new("Frame"); sfill.Size=UDim2.new((ProxRange-5)/(80-5),0,1,0)
    sfill.BackgroundColor3=T.Accent; sfill.BorderSizePixel=0; sfill.Parent=strack; cr(sfill,3)
    local sknob=Instance.new("TextButton"); sknob.Size=UDim2.fromOffset(16,16)
    sknob.AnchorPoint=Vector2.new(0.5,0.5)
    sknob.Position=UDim2.new((ProxRange-5)/(80-5),0,0.5,0)
    sknob.BackgroundColor3=Color3.fromRGB(220,160,20); sknob.Text=""
    sknob.AutoButtonColor=false; sknob.BorderSizePixel=0; sknob.Parent=strack; cr(sknob,8)
    local sdrag=false
    local MIN_R,MAX_R=5,80
    local function updateSlider(absX)
        local tx=strack.AbsolutePosition.X; local tw2=strack.AbsoluteSize.X
        local frac=math.clamp((absX-tx)/tw2,0,1)
        ProxRange=math.floor(MIN_R+(MAX_R-MIN_R)*frac+0.5)
        sfill.Size=UDim2.new(frac,0,1,0)
        sknob.Position=UDim2.new(frac,0,0.5,0)
        slbl.Text="Range: "..tostring(ProxRange)
        if proxPart and proxPart.Parent then
            proxPart.Size=Vector3.new(0.2,ProxRange*2,ProxRange*2)
        end
    end
    sknob.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then sdrag=true end
    end)
    strack.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then
            sdrag=true; updateSlider(i.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 then sdrag=false end
    end)
    UIS.InputChanged:Connect(function(i)
        if sdrag and i.UserInputType==Enum.UserInputType.MouseMovement then
            updateSlider(i.Position.X)
        end
    end)
    local sbtn=Instance.new("TextButton"); sbtn.Size=UDim2.new(1,-4,0,32)
    sbtn.BackgroundColor3=T.SoftButton; sbtn.BackgroundTransparency=0.15
    sbtn.Text="Spam Base Owner"; sbtn.TextColor3=T.Text
    sbtn.Font=Enum.Font.GothamBold; sbtn.TextSize=12; sbtn.AutoButtonColor=false
    sbtn.Parent=b1; cr(sbtn,8)
    sbtn.MouseButton1Click:Connect(spamBase)

    local ownerCard=Instance.new("Frame"); ownerCard.Size=UDim2.new(1,-4,0,54)
    ownerCard.BackgroundColor3=T.InputBg; ownerCard.BackgroundTransparency=0.2
    ownerCard.BorderSizePixel=0; ownerCard.Parent=b1; cr(ownerCard,8)
    local _ocs=Instance.new("UIStroke",ownerCard); _ocs.Color=Color3.fromRGB(130,90,0); _ocs.Thickness=1; _ocs.Transparency=0.4

    local _oAvF=Instance.new("Frame",ownerCard); _oAvF.Size=UDim2.fromOffset(36,36)
    _oAvF.Position=UDim2.fromOffset(8,9); _oAvF.BackgroundColor3=Color3.fromRGB(10,8,3)
    _oAvF.BorderSizePixel=0; cr(_oAvF,8)
    local _oAvImg=Instance.new("ImageLabel",_oAvF); _oAvImg.Size=UDim2.fromScale(1,1)
    _oAvImg.BackgroundTransparency=1; _oAvImg.Image="rbxasset://textures/ui/GuiImagePlaceholder.png"
    cr(_oAvImg,8)

    local _oName=Instance.new("TextLabel",ownerCard)
    _oName.Size=UDim2.new(1,-54,0,18); _oName.Position=UDim2.fromOffset(50,9)
    _oName.BackgroundTransparency=1; _oName.Text="—"
    _oName.Font=Enum.Font.GothamBold; _oName.TextSize=12
    _oName.TextColor3=Color3.fromRGB(220,175,50); _oName.TextXAlignment=Enum.TextXAlignment.Left
    local _oUser=Instance.new("TextLabel",ownerCard)
    _oUser.Size=UDim2.new(1,-54,0,14); _oUser.Position=UDim2.fromOffset(50,27)
    _oUser.BackgroundTransparency=1; _oUser.Text=""
    _oUser.Font=Enum.Font.GothamMedium; _oUser.TextSize=10
    _oUser.TextColor3=T.Dim; _oUser.TextXAlignment=Enum.TextXAlignment.Left

    local _lastOwnerUid=nil
    task.spawn(function()
        while ownerCard and ownerCard.Parent do
            task.wait(0.5)
            local ch=LP.Character; local hrp=ch and ch:FindFirstChild("HumanoidRootPart")
            if hrp then
                local _np,_nd=nil,math.huge
                local _pc=Workspace:FindFirstChild("Plots") or Workspace:FindFirstChild("Bases")
                local _all=_pc and _pc:GetChildren() or Workspace:GetChildren()
                for _,_pl in ipairs(_all) do
                    local _s=_pl:FindFirstChild("PlotSign",true) or _pl:FindFirstChild("Sign",true)
                    if _s then
                        local _sp=nil
                        if _s:IsA("BasePart") then _sp=_s.Position
                        elseif _s:IsA("Model") and _s.PrimaryPart then _sp=_s.PrimaryPart.Position
                        else local _pt=_s:FindFirstChildWhichIsA("BasePart",true); if _pt then _sp=_pt.Position end end
                        if _sp then local _d=(hrp.Position-_sp).Magnitude; if _d<_nd then _nd=_d; _np=_pl end end
                    end
                end
                local _op = _np and getOwner(_np)
                if _op and _op~=LP then
                    if _op.UserId ~= _lastOwnerUid then
                        _lastOwnerUid=_op.UserId
                        _oName.Text=_op.DisplayName
                        _oUser.Text="@".._op.Name
                        task.spawn(function()
                            local ok,img=pcall(function()
                                return Players:GetUserThumbnailAsync(_op.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size48x48)
                            end)
                            if ok and img then _oAvImg.Image=img end
                        end)
                    end
                elseif not _op then
                    _lastOwnerUid=nil
                    _oName.Text="No owner nearby"
                    _oUser.Text=""
                    _oAvImg.Image="rbxasset://textures/ui/GuiImagePlaceholder.png"
                end
            end
        end
    end)

    sg2=Instance.new("ScreenGui"); sg2.Name="SH_AdminPanel2"
    sg2.ResetOnSpawn=false; sg2.IgnoreGuiInset=true
    sg2.DisplayOrder=9999998; sg2.Parent=PG
    local p2o=Instance.new("Frame"); p2o.BackgroundTransparency=1
    p2o.Size=UDim2.fromOffset(480,0); p2o.AutomaticSize=Enum.AutomaticSize.Y
    p2o.Position=UDim2.new(0.18,0,0.57,0); p2o.ClipsDescendants=true; p2o.Parent=sg2
    local p2bg=Instance.new("Frame"); p2bg.BackgroundColor3=T.Background
    p2bg.BackgroundTransparency=0; p2bg.BorderSizePixel=0
    p2bg.Position=UDim2.fromOffset(-3,-2); p2bg.Size=UDim2.new(1,6,1,4)
    p2bg.ZIndex=0; p2bg.Parent=p2o; cr(p2bg,14)
    local p2t=Instance.new("Frame"); p2t.BackgroundTransparency=1
    p2t.Size=UDim2.new(1,0,0,16); p2t.Parent=p2o; apDrag(p2o,p2t,"AdminPlayersPanel")
    local p2l=Instance.new("Frame"); p2l.BackgroundTransparency=1
    p2l.Position=UDim2.new(0,0,0,20); p2l.Size=UDim2.new(1,0,0,0)
    p2l.AutomaticSize=Enum.AutomaticSize.Y; p2l.Parent=p2o
    local p2pad=Instance.new("UIPadding",p2l)
    p2pad.PaddingTop=UDim.new(0,2); p2pad.PaddingBottom=UDim.new(0,2)
    p2pad.PaddingLeft=UDim.new(0,4); p2pad.PaddingRight=UDim.new(0,4)
    local p2lay=Instance.new("UIListLayout"); p2lay.Padding=UDim.new(0,2); p2lay.Parent=p2l
    local apRows={}; local rc=0
    local DT={["Boogie Bomb"]=true,["Medusa's Head"]=true,["Body Swap Potion"]=true,["Laser Cape"]=true}
    local function gT(p) local c=p.Character; if not c then return nil end; for _,o in ipairs(c:GetChildren()) do if o:IsA("Tool") then return o.Name end end end
    local function mkRow(plr)
        if not plr or plr==LP then return end
        if apRows[plr.UserId] and apRows[plr.UserId].Parent then return end
        rc=rc+1; local alt=(rc%2==0)
        local row=Instance.new("Frame"); row.BackgroundColor3=alt and T.Row or T.Panel
        row.BackgroundTransparency=0.35; row.BorderSizePixel=0
        row.Size=UDim2.new(0,460,0,50); row.ClipsDescendants=true; row.Parent=p2l; cr(row,8)
        apRows[plr.UserId]=row
        row.MouseEnter:Connect(function() row.BackgroundColor3=blk(plr) and Color3.fromRGB(80,20,35) or T.RowHover end)
        row.MouseLeave:Connect(function() row.BackgroundColor3=alt and T.Row or T.Panel end)
        local av=Instance.new("Frame"); av.BackgroundColor3=T.InputBg
        av.Size=UDim2.fromOffset(34,34); av.Position=UDim2.fromOffset(8,8); av.Parent=row; cr(av,9)
        local img=Instance.new("ImageLabel"); img.BackgroundTransparency=1
        img.Size=UDim2.fromScale(1,1); img.Parent=av; cr(img,9)
        task.spawn(function()
            local ok,i=pcall(function() return Players:GetUserThumbnailAsync(plr.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size48x48) end)
            if ok then img.Image=i end
        end)
        local nl=Instance.new("TextLabel"); nl.Size=UDim2.new(1,-170,0,18)
        nl.Position=UDim2.fromOffset(50,5); nl.BackgroundTransparency=1
        nl.Text=plr.DisplayName; nl.Font=Enum.Font.GothamBold; nl.TextSize=13
        nl.TextColor3=T.Text; nl.TextXAlignment=Enum.TextXAlignment.Left; nl.Parent=row
        local ul=Instance.new("TextLabel"); ul.BackgroundTransparency=1
        ul.Position=UDim2.fromOffset(50,21); ul.Size=UDim2.new(1,-170,0,14)
        ul.TextXAlignment=Enum.TextXAlignment.Left; ul.Text="@"..plr.Name
        ul.Font=Enum.Font.GothamMedium; ul.TextSize=10; ul.TextColor3=T.Dim; ul.Parent=row
        local acts=Instance.new("Frame"); acts.BackgroundTransparency=1
        acts.AnchorPoint=Vector2.new(1,0.5); acts.Position=UDim2.new(1,-8,0.5,0)
        acts.Size=UDim2.fromOffset(160,36); acts.Parent=row
        local al=Instance.new("UIListLayout"); al.FillDirection=Enum.FillDirection.Horizontal
        al.SortOrder=Enum.SortOrder.LayoutOrder; al.Padding=UDim.new(0,2); al.Parent=acts
        for i,cmd in ipairs({"ragdoll","jail","rocket","balloon"}) do
            local b=Instance.new("TextButton"); b.Size=UDim2.fromOffset(30,30)
            b.BackgroundTransparency=0.20; b.AutoButtonColor=false
            b.Text=APL[cmd]; b.TextSize=11; b.LayoutOrder=i
            b.BackgroundColor3=T.SoftButton; b.TextColor3=T.AccentLight
            b.Font=Enum.Font.GothamBold; b.Parent=acts; cr(b,7)
            b.MouseButton1Click:Connect(function()
                if blk(plr) or cdn(cmd) then return end
                runCmd(plr,cmd)
            end)
        end
        local xb=Instance.new("TextButton"); xb.Size=UDim2.fromOffset(30,30)
        xb.BackgroundTransparency=0.20; xb.AutoButtonColor=false
        xb.Text="X"; xb.TextSize=12; xb.LayoutOrder=100
        xb.Font=Enum.Font.GothamBold; xb.Parent=acts; cr(xb,7)
        local function upBL()
            local b2=blk(plr)
            xb.BackgroundColor3=b2 and T.Red or T.BlacklistLeave
            xb.TextColor3=b2 and Color3.new(1,1,1) or T.Red
            row.BackgroundTransparency=b2 and 0.80 or 0.35
        end
        upBL()
        xb.MouseButton1Click:Connect(function() apBL[plr.UserId]=not blk(plr); upBL() end)
        row.InputBegan:Connect(function(inp)
            if inp.UserInputType~=Enum.UserInputType.MouseButton1 then return end
            if blk(plr) then return end
            local mp=UIS:GetMouseLocation()
            if acts.AbsolutePosition then
                local ax,ay=acts.AbsolutePosition.X,acts.AbsolutePosition.Y
                local aw,ah=acts.AbsoluteSize.X,acts.AbsoluteSize.Y
                if mp.X>=ax and mp.X<=ax+aw and mp.Y>=ay and mp.Y<=ay+ah then return end
            end
            for i,cmd in ipairs(APCmds) do
                if not cdn(cmd) then
                    task.spawn(function() task.wait((i-1)*0.01); runCmd(plr,cmd) end)
                end
            end
        end)
        task.spawn(function()
            while row.Parent do
                task.wait(0.5)
                if not plr or not plr.Parent then break end
                local ht=gT(plr)
                nl.TextColor3=ht and DT[ht] and T.Red or T.Text
            end
        end)
    end
    for _,p in ipairs(Players:GetPlayers()) do if p~=LP then mkRow(p) end end
    Players.PlayerAdded:Connect(function(p) task.defer(function() mkRow(p) end) end)
    Players.PlayerRemoving:Connect(function(p)
        local r=apRows[p.UserId]; if r then r:Destroy(); apRows[p.UserId]=nil end
    end)

    local p3=Instance.new("Frame"); p3.Size=UDim2.new(0,210,0,270)
    p3.Position=UDim2.new(0.5,245,1,-340); p3.BackgroundColor3=T.Background
    p3.BackgroundTransparency=0; p3.BorderSizePixel=0; p3.Parent=sg1; cr(p3,10)
    local _p3s=Instance.new("UIStroke",p3);_p3s.Color=Color3.fromRGB(160,115,0);_p3s.Thickness=1.2;_p3s.Transparency=0.2
    task.spawn(function()
        local t=0
        while p3 and p3.Parent do
            t=t+task.wait(0.016)
            _p3s.Transparency=0.15+math.sin(t*1.1)*0.08+math.sin(t*2.1+0.4)*0.04
            _p3s.Color=Color3.fromRGB(math.floor(155+math.sin(t*0.9)*20),math.floor(110+math.sin(t*1.6)*13),0)
        end
    end)
    local h3=Instance.new("Frame"); h3.Size=UDim2.new(1,0,0,30)
    h3.BackgroundTransparency=1; h3.Parent=p3; apDrag(p3,h3,"AdminCooldownPanel")
    local tl3=Instance.new("TextLabel"); tl3.Size=UDim2.new(1,0,0,16)
    tl3.Position=UDim2.fromOffset(0,7); tl3.BackgroundTransparency=1
    tl3.Text="silence | Cooldowns"; tl3.TextColor3=Color3.fromRGB(255,210,60)
    tl3.Font=Enum.Font.GothamBlack; tl3.TextSize=12
    tl3.TextXAlignment=Enum.TextXAlignment.Center; tl3.Parent=h3
    do
        local _cg=Instance.new("UIGradient",tl3)
        _cg.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(140,95,0)),ColorSequenceKeypoint.new(0.3,Color3.fromRGB(230,170,20)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(255,235,100)),ColorSequenceKeypoint.new(0.7,Color3.fromRGB(230,170,20)),ColorSequenceKeypoint.new(1,Color3.fromRGB(140,95,0))})
        task.spawn(function() local t=0 while tl3 and tl3.Parent do t=t+task.wait(0.016) _cg.Offset=Vector2.new(math.sin(t*0.65)*0.55+math.sin(t*1.3+1.2)*0.12,0) end end)
    end
    local b3=Instance.new("Frame"); b3.Size=UDim2.new(1,-12,1,-36)
    b3.Position=UDim2.fromOffset(6,34); b3.BackgroundTransparency=1; b3.Parent=p3
    local l3=Instance.new("UIListLayout"); l3.Padding=UDim.new(0,4); l3.Parent=b3
    local cdL={}
    for _,cmd in ipairs(APCmds) do
        local r=Instance.new("Frame"); r.Size=UDim2.new(1,0,0,22)
        r.BackgroundTransparency=1; r.Parent=b3
        local ll=Instance.new("TextLabel"); ll.Size=UDim2.new(0.58,0,1,0)
        ll.Position=UDim2.fromOffset(6,0); ll.BackgroundTransparency=1
        ll.Text=cmd:sub(1,1):upper()..cmd:sub(2); ll.TextColor3=T.Text
        ll.Font=Enum.Font.GothamBold; ll.TextSize=12
        ll.TextXAlignment=Enum.TextXAlignment.Left; ll.Parent=r
        local rv=Instance.new("TextLabel"); rv.Size=UDim2.new(0.36,0,1,0)
        rv.Position=UDim2.new(0.62,0,0,0); rv.BackgroundTransparency=1
        rv.Text="READY"; rv.TextColor3=T.Green; rv.Font=Enum.Font.GothamBlack
        rv.TextSize=11; rv.TextXAlignment=Enum.TextXAlignment.Right; rv.Parent=r
        cdL[cmd]=rv
    end
    task.spawn(function()
        while true do
            task.wait(0.5)
            for cmd,lbl in pairs(cdL) do
                local r=cdrem(cmd)
                if r>0 then lbl.Text=string.format("%.0fs",r); lbl.TextColor3=T.Red
                else lbl.Text="READY"; lbl.TextColor3=T.Green end
            end
        end
    end)
    print("[SH] Admin Panels loaded.")
end

_G.SH_toggleAdminPanel = function(on)
    if on then
        build()
        if sg1 then sg1.Enabled=true end
        if sg2 then sg2.Enabled=true end
    else
        if sg1 then sg1.Enabled=false end
        if sg2 then sg2.Enabled=false end
    end
end
print("[SH] Admin Panel Engine ready.")
end

task.wait()  -- OPT v9b: yield frame between engine inits (prevents freeze)

--------------------------------------------------------------------------------
-- 8.9  BOX ESP ENGINE (Drawing API — client-side only)
--------------------------------------------------------------------------------
do
    local _RS        = game:GetService("RunService")
    local _Workspace = workspace
    local _Cam       = _Workspace.CurrentCamera
    local _LP        = game:GetService("Players").LocalPlayer

    local BOX_COLOR   = Color3.fromRGB(255, 80, 180)
    local TEXT_COLOR  = Color3.fromRGB(255, 255, 255)
    local BOX_THICK   = 1.5
    local MAX_DIST    = 2000

    local _boxActive  = false
    local _boxConn    = nil
    local _drawings   = {}

    local _DRAW_FONT = 0
    pcall(function()
        if Drawing.Fonts and Drawing.Fonts.UI then
            _DRAW_FONT = Drawing.Fonts.UI
        elseif Drawing.Fonts and Drawing.Fonts.Plex then
            _DRAW_FONT = Drawing.Fonts.Plex
        end
    end)

    local _drawingOk = true
    local function _safeNewDrawing(kind)
        if not _drawingOk then return nil end
        local ok, d = pcall(Drawing.new, kind)
        if not ok or not d then
            _drawingOk = false
            warn("[SH BoxESP] Drawing.new failed — Drawing API unavailable in this executor")
            return nil
        end
        return d
    end

    local function _newLine()
        local d = _safeNewDrawing("Line")
        if not d then return nil end
        d.Thickness   = BOX_THICK
        d.Color       = BOX_COLOR
        d.Transparency = 1
        d.Visible     = false
        return d
    end
    local function _newLabel()
        local d = _safeNewDrawing("Text")
        if not d then return nil end
        d.Size         = 13
        d.Color        = TEXT_COLOR
        d.Outline      = true
        d.OutlineColor = Color3.new(0,0,0)
        d.Font         = _DRAW_FONT
        d.Visible      = false
        return d
    end

    local function _getSlot(i)
        if not _drawings[i] then
            local t, b, l, r, lbl = _newLine(), _newLine(), _newLine(), _newLine(), _newLabel()
            if not t or not b or not l or not r then return nil end
            _drawings[i] = { top=t, bot=b, left=l, right=r, label=lbl }
        end
        return _drawings[i]
    end

    local function _hideAll()
        for _, slot in ipairs(_drawings) do
            if slot then
                if slot.top   then slot.top.Visible   = false end
                if slot.bot   then slot.bot.Visible   = false end
                if slot.left  then slot.left.Visible  = false end
                if slot.right then slot.right.Visible = false end
                if slot.label then slot.label.Visible = false end
            end
        end
    end

    local function _worldToScreen(pos)
        local spos, onScreen = _Cam:WorldToViewportPoint(pos)
        if not onScreen then return nil end
        return Vector2.new(spos.X, spos.Y), spos.Z
    end

    local function _getScreenBounds(model)
        local ok, cf, size = pcall(function()
            return model:GetBoundingBox()
        end)
        if not ok then return nil end

        local hx, hy, hz = size.X/2, size.Y/2, size.Z/2
        local corners = {
            cf * Vector3.new( hx,  hy,  hz),
            cf * Vector3.new(-hx,  hy,  hz),
            cf * Vector3.new( hx, -hy,  hz),
            cf * Vector3.new(-hx, -hy,  hz),
            cf * Vector3.new( hx,  hy, -hz),
            cf * Vector3.new(-hx,  hy, -hz),
            cf * Vector3.new( hx, -hy, -hz),
            cf * Vector3.new(-hx, -hy, -hz),
        }

        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
        local anyOnScreen = false
        for _, c in ipairs(corners) do
            local s, depth = _worldToScreen(c)
            if s and depth > 0 then
                anyOnScreen = true
                if s.X < minX then minX = s.X end
                if s.Y < minY then minY = s.Y end
                if s.X > maxX then maxX = s.X end
                if s.Y > maxY then maxY = s.Y end
            end
        end
        if not anyOnScreen then return nil end
        return minX, minY, maxX, maxY
    end

    local function _drawBox(slot, x1, y1, x2, y2, label)
        slot.top.From = Vector2.new(x1, y1); slot.top.To = Vector2.new(x2, y1); slot.top.Visible = true
        slot.bot.From = Vector2.new(x1, y2); slot.bot.To = Vector2.new(x2, y2); slot.bot.Visible = true
        slot.left.From = Vector2.new(x1, y1); slot.left.To = Vector2.new(x1, y2); slot.left.Visible = true
        slot.right.From = Vector2.new(x2, y1); slot.right.To = Vector2.new(x2, y2); slot.right.Visible = true
        slot.label.Text     = label or ""
        slot.label.Position = Vector2.new((x1+x2)/2, y1 - 16)
        slot.label.Visible  = label ~= nil and label ~= ""
    end

    local function _boxLoop()
        _Cam = _Workspace.CurrentCamera
        local hrp = (_LP.Character and _LP.Character:FindFirstChild("HumanoidRootPart"))
        local myPos = hrp and hrp.Position or Vector3.zero

        local pets = (_G.SH_LastScan and _G.SH_LastScan.pets) or {}
        local drawn = 0

        for i, pet in ipairs(pets) do
            local model = pet.model
            if model and model.Parent then
                local ok2, center = pcall(function()
                    return model:GetBoundingBox()
                end)
                local dist = ok2 and (center.Position - myPos).Magnitude or 0
                if dist <= MAX_DIST then
                    local x1, y1, x2, y2 = _getScreenBounds(model)
                    if x1 then
                        drawn = drawn + 1
                        local slot = _getSlot(drawn)
                        if slot then
                            local name = pet.name or (model.Name or "?")
                            _drawBox(slot, x1, y1, x2, y2, name)
                        end
                    end
                end
            end
        end

        for j = drawn + 1, #_drawings do
            local slot = _drawings[j]
            if slot then
                if slot.top   then slot.top.Visible   = false end
                if slot.bot   then slot.bot.Visible   = false end
                if slot.left  then slot.left.Visible  = false end
                if slot.right then slot.right.Visible = false end
                if slot.label then slot.label.Visible = false end
            end
        end
    end

    _G._SH_StartBoxESP = function()
        if _boxActive then return end
        _boxActive = true
        _boxConn = _RS.RenderStepped:Connect(function()
            if not _boxActive then _boxConn:Disconnect(); _boxConn = nil; return end
            pcall(_boxLoop)
        end)
        print("[SH] Box ESP ON")
    end

    _G._SH_StopBoxESP = function()
        _boxActive = false
        if _boxConn then _boxConn:Disconnect(); _boxConn = nil end
        for _, slot in ipairs(_drawings) do
            pcall(function() slot.top:Remove()   end)
            pcall(function() slot.bot:Remove()   end)
            pcall(function() slot.left:Remove()  end)
            pcall(function() slot.right:Remove() end)
            pcall(function() slot.label:Remove() end)
        end
        _drawings = {}
        print("[SH] Box ESP OFF")
    end

    _G._SH_BoxESPColor = function(r, g, b)
        BOX_COLOR = Color3.fromRGB(r, g, b)
        for _, slot in ipairs(_drawings) do
            slot.top.Color   = BOX_COLOR
            slot.bot.Color   = BOX_COLOR
            slot.left.Color  = BOX_COLOR
            slot.right.Color = BOX_COLOR
        end
    end

    _G._SH_BoxESPMaxDist = function(d)
        MAX_DIST = d or 2000
    end

    print("[SH] Box ESP engine ready.")
end

task.wait()  -- OPT v9b: yield frame between engine inits (prevents freeze)

--------------------------------------------------------------------------------
-- 8.10  FACE-AWAY SYSTEM (from Neegy, Taco→SH_)
--------------------------------------------------------------------------------
do
if _G.SH_FaceAwayNearest == nil then _G.SH_FaceAwayNearest = false end
if _G.SH_FaceAwayOwner   == nil then _G.SH_FaceAwayOwner   = false end

    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LP = Players.LocalPlayer
    local Workspace = workspace
    local function getRoot(pl)
        local c = pl and pl.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end
    local function findNearest(myRoot)
        local best, bestD = nil, math.huge
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LP then
                local r = getRoot(pl)
                if r then
                    local d = (r.Position - myRoot.Position).Magnitude
                    if d < bestD then best, bestD = pl, d end
                end
            end
        end
        return best
    end
    local function getPlotAtPosition(pos)
        local plots = Workspace:FindFirstChild("Plots")
        if not plots then return nil end
        local best, bestD = nil, math.huge
        for _, plot in ipairs(plots:GetChildren()) do
            local pp
            if plot:IsA("Model") then
                pp = (plot.PrimaryPart and plot.PrimaryPart.Position) or plot:GetPivot().Position
            else
                pp = plot.Position
            end
            if pp then
                local dx, dz = pos.X - pp.X, pos.Z - pp.Z
                local d = math.sqrt(dx * dx + dz * dz)
                if d < bestD then bestD, best = d, plot end
            end
        end
        return (best and bestD < 72) and best or nil
    end
    local function getPlotOwner(plot)
        if not plot then return nil end
        local sign = plot:FindFirstChild("PlotSign")
        local lbl = sign
            and sign:FindFirstChild("SurfaceGui")
            and sign.SurfaceGui:FindFirstChild("Frame")
            and sign.SurfaceGui.Frame:FindFirstChild("TextLabel")
        if lbl then
            local nick = (lbl.Text and lbl.Text:match("^(.-)'")) or lbl.Text
            if nick and nick ~= "" then
                for _, pl in ipairs(Players:GetPlayers()) do
                    if pl.DisplayName == nick or pl.Name == nick then return pl end
                end
            end
        end
        return nil
    end
    local _ownerCache, _ownerAt = nil, 0
    local function resolveTarget(myRoot)
        if _G.SH_FaceAwayNearest == true then
            return findNearest(myRoot)
        end
        if os.clock() - _ownerAt > 0.5 then
            _ownerAt = os.clock()
            local owner = getPlotOwner(getPlotAtPosition(myRoot.Position))
            _ownerCache = (owner ~= LP) and owner or nil
        end
        return _ownerCache
    end
    _G.SH_DoFaceAwayOnce = function()
        local myRoot = getRoot(LP)
        if not myRoot then return end
        local tgt
        if _G.SH_FaceAwayOwner == true then
            tgt = getPlotOwner(getPlotAtPosition(myRoot.Position))
        else
            tgt = findNearest(myRoot)
        end
        local tRoot = getRoot(tgt)
        if not tRoot then return end
        local flat = Vector3.new(
            tRoot.Position.X - myRoot.Position.X,
            0,
            tRoot.Position.Z - myRoot.Position.Z
        )
        if flat.Magnitude < 0.05 then return end
        myRoot.CFrame = CFrame.lookAt(myRoot.Position, myRoot.Position + Vector3.new(-flat.Z, 0, flat.X).Unit)
    end
    local _faceWasOn, _stealSince = false, nil
    local function faceActive()
        if not (_G.SH_FaceAwayAuto == true
            or _G.SH_FaceAwayOwner == true
            or _G.SH_FaceAwayNearest == true) then
            _stealSince = nil
            return false
        end
        if LP:GetAttribute("Stealing") ~= true then
            _stealSince = nil
            return false
        end
        if not _stealSince then
            _stealSince = os.clock()
            return false
        end
        return (os.clock() - _stealSince) >= (tonumber(_G.SH_FaceAwayDelay) or 2)
    end
    local function faceAwayStep()
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not faceActive() then
            if _faceWasOn then
                _faceWasOn = false
                if hum then pcall(function() hum.AutoRotate = true end) end
            end
            return
        end
        _faceWasOn = true
        local myRoot = getRoot(LP)
        if not myRoot then return end
        if hum and hum.AutoRotate then pcall(function() hum.AutoRotate = false end) end
        local tRoot = getRoot(resolveTarget(myRoot))
        if not tRoot then return end
        local flat = Vector3.new(
            tRoot.Position.X - myRoot.Position.X,
            0,
            tRoot.Position.Z - myRoot.Position.Z
        )
        if flat.Magnitude < 0.05 then return end
        myRoot.CFrame = CFrame.lookAt(myRoot.Position, myRoot.Position + Vector3.new(-flat.Z, 0, flat.X).Unit)
        local av = myRoot.AssemblyAngularVelocity
        if av.Y ~= 0 then
            myRoot.AssemblyAngularVelocity = Vector3.new(av.X, 0, av.Z)
        end
    end
    RunService.RenderStepped:Connect(faceAwayStep)
    RunService.Heartbeat:Connect(faceAwayStep)
print("[SH] Face-Away System ready.")
end

task.wait()  -- OPT v9b: yield frame between engine inits (prevents freeze)

--------------------------------------------------------------------------------
-- 8.11  BASE XRAY (from Neegy, Taco→SH_)
--------------------------------------------------------------------------------
do
if _G.SH_BaseXray == nil then _G.SH_BaseXray = true end
;(function()
    local FOLDERS = { "Base", "PlotSign", "FriendPanel", "Cash", "Laser",
        "Decorations", "Skin", "Unlock", "Purchases" }
    local orig = setmetatable({}, { __mode = "k" })
    local conns, gen = {}, 0
    local function paint(o, a)
        if not o:IsA("BasePart") then return end
        if orig[o] == nil then orig[o] = (o.Transparency == a) and 0 or o.Transparency end
        local base = orig[o]
        if base >= 1 then return end
        local want = base + (1 - base) * a
        if math.abs(o.Transparency - want) > 0.01 then o.Transparency = want end
    end
    local function calm()
        while _G.SH_StealHold do task.wait(0.15) end
    end
    local function track(root, a, id)
        if not root or id ~= gen then return end
        paint(root, a)
        local n = 0
        for _, d in ipairs(root:GetDescendants()) do
            if id ~= gen then return end
            paint(d, a)
            n = n + 1
            if n % 250 == 0 then task.wait() end
        end
        conns[#conns + 1] = root.DescendantAdded:Connect(function(d)
            if id == gen then paint(d, a) end
        end)
    end
    local function doPlot(plot, a, id)
        if not plot or id ~= gen then return end
        for _, fname in ipairs(FOLDERS) do
            if id ~= gen then return end
            track(plot:FindFirstChild(fname), a, id)
        end
        if id ~= gen then return end
        conns[#conns + 1] = plot.ChildAdded:Connect(function(c)
            if id ~= gen then return end
            for _, fname in ipairs(FOLDERS) do
                if c.Name == fname then track(c, a, id) break end
            end
        end)
        local pods = plot:FindFirstChild("AnimalPodiums")
        if not pods then return end
        local function pod(pd)
            for _, c in ipairs(pd:GetChildren()) do
                if c.Name == "Claim" then track(c, a, id)
                elseif c.Name == "Base" then track(c:FindFirstChild("Decorations"), a, id) end
            end
        end
        for _, pd in ipairs(pods:GetChildren()) do pod(pd) end
        conns[#conns + 1] = pods.ChildAdded:Connect(function(pd)
            if id ~= gen then return end
            task.wait(0.1)
            if id == gen then pod(pd) end
        end)
    end
    local function stop()
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        conns, gen = {}, gen + 1
    end
    _G.SH_BaseXrayEnable = function()
        stop()
        local id = gen
        local a = math.clamp(tonumber(_G.SH_BaseXrayAlpha) or 0.9, 0, 1)
        task.spawn(function()
            while id == gen and not workspace:FindFirstChild("Plots") do task.wait(0.5) end
            local plots = workspace:FindFirstChild("Plots")
            if id ~= gen or not plots then return end
            calm()
            for _, p in ipairs(plots:GetChildren()) do
                if id ~= gen then return end
                pcall(doPlot, p, a, id)
                task.wait()
                calm()
            end
            conns[#conns + 1] = plots.ChildAdded:Connect(function(p)
                if id ~= gen then return end
                task.wait(0.2)
                pcall(doPlot, p, a, id)
            end)
        end)
    end
    _G.SH_BaseXrayDisable = function()
        stop()
        local snap = orig
        orig = setmetatable({}, { __mode = "k" })
        for o, t in pairs(snap) do
            pcall(function() if o:IsA("BasePart") then o.Transparency = t end end)
        end
    end
    _G.SH_BaseXrayToggle = function()
        _G.SH_BaseXray = not (_G.SH_BaseXray ~= false)
        if _G.SH_BaseXray then _G.SH_BaseXrayEnable() else _G.SH_BaseXrayDisable() end
        return _G.SH_BaseXray
    end
    task.spawn(function()
        if not game:IsLoaded() then game.Loaded:Wait() end
        if type(_G.SH_BootWait) == "function" then pcall(_G.SH_BootWait) end
        task.wait(tonumber(_G.SH_BaseXrayDelay) or 5)
        if _G.SH_BaseXray ~= false then _G.SH_BaseXrayEnable() end
    end)
end)()
print("[SH] Base XRay Engine ready.")
end

task.wait()  -- OPT v9b: yield frame between engine inits (prevents freeze)

--------------------------------------------------------------------------------
-- 8.12  HIDE COLLECT LABELS (from Neegy, Taco→SH_)
--------------------------------------------------------------------------------
do
if _G.SH_HideCollect == nil then _G.SH_HideCollect = true end
    local seenC = setmetatable({}, { __mode = "k" })
    local function isCollect(gui)
        local ok, res = pcall(function()
            for _, d in ipairs(gui:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then
                    if tostring(d.Text or ""):lower():find("collect", 1, true) then return true end
                end
            end
            return false
        end)
        return ok and res
    end
    local function apply(gui)
        if not gui:IsA("BillboardGui") then return end
        if not isCollect(gui) then return end
        if seenC[gui] == nil then seenC[gui] = gui.Enabled end
        if _G.SH_HideCollect == false then
            pcall(function() gui.Enabled = seenC[gui] end)
        else
            if gui.Enabled then pcall(function() gui.Enabled = false end) end
        end
    end
    workspace.DescendantAdded:Connect(function(d)
        if d:IsA("BillboardGui") then task.defer(apply, d) end
    end)
    task.spawn(function()
        if type(_G.SH_BootWait) == "function" then pcall(_G.SH_BootWait) end
        while true do
            local n = 0
            pcall(function()
                for _, d in ipairs(workspace:GetDescendants()) do
                    n = n + 1
                    if n % 400 == 0 then task.wait() end
                    if d:IsA("BillboardGui") then apply(d) end
                end
            end)
            task.wait(tonumber(_G.SH_HideCollectGap) or 1.5)
        end
    end)
print("[SH] Hide Collect Labels Engine ready.")
end

task.wait()  -- OPT v9b: yield frame between engine inits (prevents freeze)

--------------------------------------------------------------------------------
-- 8.13  FLIGHT NOCLIP (from Neegy, Taco→SH_)
--------------------------------------------------------------------------------
do
if _G.SH_FlightNoclip == nil then _G.SH_FlightNoclip = true end
    local RunService = game:GetService("RunService")
    local LP = game:GetService("Players").LocalPlayer
    local restore = setmetatable({}, { __mode = "k" })
    local restoreT = setmetatable({}, { __mode = "k" })
    local wasActive = false
    RunService.Stepped:Connect(function()
        local active = (_G.SH_TPActive == true) and (_G.SH_FlightNoclip ~= false)
        local char = LP and LP.Character
        if active and char then
            wasActive = true
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BasePart") then
                    if d.CanCollide then
                        restore[d] = true
                        d.CanCollide = false
                    end
                    if _G.SH_FlightNoTouch ~= false and d.CanTouch then
                        restoreT[d] = true
                        pcall(function() d.CanTouch = false end)
                    end
                end
            end
        elseif wasActive and not active then
            wasActive = false
            for d in pairs(restore) do
                if d and d.Parent then pcall(function() d.CanCollide = true end) end
            end
            for d in pairs(restoreT) do
                if d and d.Parent then pcall(function() d.CanTouch = true end) end
            end
            table.clear(restore)
            table.clear(restoreT)
        end
    end)
print("[SH] Flight Noclip Engine ready.")
end

task.wait()  -- OPT v9b: yield frame between engine inits (prevents freeze)

--------------------------------------------------------------------------------
-- 8.14  ANTI-DIE (from Neegy, SXE_/Taco→SH_)
--------------------------------------------------------------------------------
do
if _G.AntiDieDisabled == nil then _G.AntiDieDisabled = false end
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LP = Players.LocalPlayer
    local _adc, _addc, _adhbc
    local function _adHarden(hum)
        pcall(function() hum.BreakJointsOnDeath = false end)
        pcall(function() hum.RequiresNeck = false end)
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end)
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false) end)
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false) end)
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false) end)
    end
    local function _adRevive(hum)
        pcall(function() hum.Health = hum.MaxHealth end)
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
    end
    local function _adBind()
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        _adHarden(hum)
        if _adc   then pcall(function() _adc:Disconnect() end) end
        if _addc  then pcall(function() _addc:Disconnect() end) end
        if _adhbc then pcall(function() _adhbc:Disconnect() end) end
        _adc = hum:GetPropertyChangedSignal("Health"):Connect(function()
            if _G.__SH_ResetBusy or _G.AntiDieDisabled then return end
            if hum.Health <= 0 then _adRevive(hum) end
        end)
        _addc = hum.Died:Connect(function()
            if _G.__SH_ResetBusy or _G.AntiDieDisabled then return end
            _adRevive(hum)
        end)
        local _lh = 0
        _adhbc = RunService.Heartbeat:Connect(function()
            if not hum or not hum.Parent then return end
            if _G.__SH_ResetBusy or _G.AntiDieDisabled then return end
            pcall(function() hum.RequiresNeck = false end)
            local now = os.clock()
            if now - _lh >= 0.08 then _lh = now; _adHarden(hum) end
            if hum.Health < hum.MaxHealth then _adRevive(hum) end
            local st = hum:GetState()
            if st == Enum.HumanoidStateType.Dead or st == Enum.HumanoidStateType.Ragdoll
                or st == Enum.HumanoidStateType.FallingDown then
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
            end
        end)
    end
    _G.SH_AntiDieOff = function()
        if _adc   then pcall(function() _adc:Disconnect() end)   _adc   = nil end
        if _addc  then pcall(function() _addc:Disconnect() end)  _addc  = nil end
        if _adhbc then pcall(function() _adhbc:Disconnect() end) _adhbc = nil end
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true) end)
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true) end)
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true) end)
        pcall(function() hum.BreakJointsOnDeath = true end)
    end
    _G.SH_AntiDieOn = _adBind
    if LP.Character then _adBind() end
    LP.CharacterAdded:Connect(function()
        task.wait(0.1)
        _adBind()
    end)
    -- Steal shield loop
    task.spawn(function()
        local function _inSteal()
            if _G.__SH_ResetBusy then return false end
            if LP:GetAttribute("Stealing") == true then return true end
            if _G.SH_StealHold == true then return true end
            if _G.__SH_ArmActive == true then return true end
            if _G.SH_TPActive == true then return true end
            if RailTP and RailTP.isActive and RailTP.isActive() then return true end
            return false
        end
        while true do
            RunService.Heartbeat:Wait()
            if _G.SH_StealShield == false then continue end
            if not _inSteal() then continue end
            local char = LP.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hum or not hum.Parent then continue end
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                hum.BreakJointsOnDeath = false
                if hum.Health < hum.MaxHealth then hum.Health = hum.MaxHealth end
                local st = hum:GetState()
                if st == Enum.HumanoidStateType.Dead or st == Enum.HumanoidStateType.Ragdoll
                    or st == Enum.HumanoidStateType.FallingDown then
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end
            end)
            local _et = tonumber(LP:GetAttribute("RagdollEndTime"))
            if _et and (_et - workspace:GetServerTimeNow()) > 0 then
                pcall(function() LP:SetAttribute("RagdollEndTime", workspace:GetServerTimeNow()) end)
            end
        end
    end)
print("[SH] Anti-Die Engine ready.")
end

task.wait()  -- OPT v9b: yield frame between engine inits (prevents freeze)

--------------------------------------------------------------------------------
-- 8.15  PRIORITY LIST LOADER (from Neegy — NeegyPrio.json)
--------------------------------------------------------------------------------
do
    local _phsLoad = game:GetService("HttpService")
    pcall(function()
        if readfile then
            local _raw = readfile("NeegyPrio.json")
            if type(_raw)=="string" and #_raw>2 then
                local _ok, _d = pcall(_phsLoad.JSONDecode, _phsLoad, _raw)
                if _ok and type(_d)=="table" and #_d>0 then
                    local _clean = {}
                    for _,v in ipairs(_d) do
                        if type(v)=="string" and v~="" then _clean[#_clean+1]=v end
                    end
                    if #_clean>0 then
                        local _L = _G.SHARED_PRIORITY_ITEMS
                        if type(_L)=="table" then table.clear(_L) else _L={}; _G.SHARED_PRIORITY_ITEMS=_L end
                        for i=1,#_clean do _L[i]=_clean[i] end
                        _G.SH_PriVersion = (_G.SH_PriVersion or 0) + 1
                    end
                end
            end
        end
    end)

    if type(_G.SHARED_PRIORITY_ITEMS) ~= "table" or #_G.SHARED_PRIORITY_ITEMS == 0 then
    _G.SHARED_PRIORITY_ITEMS = {
        "Headless Horseman","Strawberry Elephant","Signore Carapace","John Pork","Meowl",
        "Elefanto Frigo","Arcadragon","Skibidi Toilet","Griffin","Antonio",
        "Dragon Aquanini","Dragon Gingerini","Love Love Bear","Kalika Bros","Moby Bros",
        "Grabatron","Jelly Moby","La Supreme Combinasion","Ginger Gerat","Digi Narwhal",
        "Hydra Dragon Cannelloni","Hydra Bunny","Bunny and Eggy","Kraken","Fishino Clownino",
        "Tirilikalika Tirilikalako","Pancake and Syrup","Dragon Cannelloni","Sammyni Cakini","Ketupat Bros",
        "Bumbatron","Venuspino","Dug dug dug","La Casa Boo","Rico Dinero",
        "Foxini Lanternini","Duggy Bros","Rosey and Teddy","Globa Steppa","Los Hackers",
        "Cerberus","Fragrama and Chocrama","Cooki and Milki","La Secret Combinasion","Burguro and Fryuro",
        "Capitano Moby","Spooky and Pumpky","Garama and Madundung","Popcuru and Fizzuru","Pizza and Ranch",
        "Reinito Sleighito","Tenini Ballini","Fragola La La La","Ketchuru and Musturu","Tralaledon",
        "Tictac Sahur","Ketupat Kepat","Tang Tang Keletang","Orcaledon","La Ginger Sekolah",
        "Los Spaghettis","Lavadorito Spinito","Swaggy Bros","La Taco Combinasion","Los Primos",
        "Los Chillis","Chillin Chili","Tuff Toucan","W or L","Chipso and Queso",
        "Guest 666","Money Money Reindeer","Quackini Snackini","Los Sekolahs","Los Tacoritas",
        "Los Amigos","Fortunu and Cashuru","Jolly Jolly Sahur","Boppin Bunny","Gym Bros",
        "Los Cupids","Festive 67","Celularcini Viciosini","Cloverat Clapat","La Food Combinasion",
        "Hopilikalika Hopilikalako","Celestial Pegasus","Sammyni Fattini","Money Money Bros","La Spooky Grande",
        "Cash or Card","Swag Soda","Los Planitos","Lovin Rose","Tacorita Bicicleta",
        "Los Jolly Combinasionas","La Romantic Grande","La Easter Grande","Los Hotspotsitos","Rosetti Tualetti",
        "Los Bros","Gobblino Uniciclino","Chicleteira Cupideira","La Extinct Grande","Las Sis",
        "Nacho Spyder","Gold Gold Gold","Los Mariachis","Snailo Clovero","La Jolly Grande",
        "Los Candies","Churrito Bunnito","Bananito","Eviledon","Los 67",
        "Los Sweethearts","Noo my Heart","La Lucky Grande","Ventoliero Pavonero","Baskito",
        "Chimnino","Los Puggies","Camera Ramena","Los 25","Spinny Hammy",
        "Money Money Puggy","Cigno Fulgoro","Los Spooky Combinasionas","Chicleteira Noelteira","Mariachi Corazoni",
        "Tacorillo Crocodillo","Noo my Gold","Los Mobilis","Mieteteira Bicicleteira","DJ Panda",
        "Los Combinasionas","Nuclearo Dinossauro","Bacuru and Egguru","Spaghetti Tualetti","La Grande Combinasion",
        "Esok Sekolah",
    }
    _G.SH_PriVersion = (_G.SH_PriVersion or 0) + 1
    end
print("[SH] Priority List Loader ready.")
end

-- ╔════════════════════════════════════════════════════════════════╗
-- ║  END OF SECTION 8                                             ║
-- ╚════════════════════════════════════════════════════════════════╝
-- ╔══════════════════════════════════════════════════════════════════╗
-- ║  SECTION 9 : STEAL + TP ENGINE                                 ║
-- ║  Merged from Silence Hub (JAF autograb) + Neegy (steal system)  ║
-- ╚══════════════════════════════════════════════════════════════════╝

-- ================================================================
-- ENGINE 9-A : JAF AUTOGRAB / SCANNER ENGINE (from Silence Hub)
-- Core auto-steal: scanner, priority resolver, prompt finder,
-- executeSteal, heartbeat autograb loop.
-- ================================================================
do

-- ── Services ─────────────────────────────────────────────────
local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local HttpService         = game:GetService("HttpService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Workspace           = workspace

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ── Anti-detection helpers ────────────────────────────────────
local function _wrap(f)
    if newcclosure then return newcclosure(f) end
    return f
end

local function safeParent()
    if gethui then return gethui() end
    if get_hidden_gui then return get_hidden_gui() end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return PlayerGui
end
local _GuiRoot = safeParent()

local function protectSG(obj)
    if syn and syn.protect_gui then pcall(syn.protect_gui, obj) end
    if protect_gui             then pcall(protect_gui, obj)      end
end

local function _randName(prefix)
    local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    local s = prefix or ""
    for _ = 1, 8 do
        local i = math.random(1, #chars)
        s = s .. chars:sub(i, i)
    end
    return s
end

-- ── Stub guard for LPH ───────────────────────────────────────
if not _G.LPH_OBFUSCATED then
    local function noop(...) end
    if not _G.LPH_ATTRIBUTES then _G.LPH_ATTRIBUTES = noop end
    if not _G.VM      then _G.VM      = noop end
    if not _G.PRESET  then _G.PRESET  = noop end
    if not _G.ERROR_HANDLING then _G.ERROR_HANDLING = noop end
    if not _G.LPH_ENCSTR then _G.LPH_ENCSTR = function(s) return s end end
    if not _G.LPH_ENCNUM then _G.LPH_ENCNUM = function(n) return n end end
    if not NONE then NONE = nil end
    if not FAST then FAST = nil end
end

-- ── Config ──────────────────────────────────────────────────
local Config = {
    AutoSteal         = true,
    StealRadius       = 95,
    StealDuration     = nil,
    StealNearest      = false,
    UsePriority       = true,
    RetargetOnSelect  = true,
    UILocked          = false,
    HideAutoSteal     = false,
}

local listGenFilter = 0

-- ── Mutation colours ──────────────────────────────────────────
local MUTCOL = {
    Gold      = Color3.fromRGB(255, 215,  70),
    Rainbow   = Color3.fromRGB(255, 100, 200),
    Shiny     = Color3.fromRGB(130, 210, 255),
    Corrupt   = Color3.fromRGB(150,  50, 220),
    Disco     = Color3.fromRGB(255, 160,  80),
    Frozen    = Color3.fromRGB( 90, 200, 255),
    Neon      = Color3.fromRGB(100, 255, 130),
    Zombie    = Color3.fromRGB(100, 200,  80),
    Shadow    = Color3.fromRGB( 80,  80, 120),
    YinYang   = Color3.fromRGB(230, 230, 230),
    ["Yin Yang"] = Color3.fromRGB(230, 230, 230),
}
_G.JAF_MutColor = function(m) return (m and MUTCOL[m]) or Color3.fromRGB(212, 140, 255) end

-- ── Theme ─────────────────────────────────────────────────────
local Theme = {
    Background      = Color3.fromRGB(  8,   8,  10),
    Surface         = Color3.fromRGB( 14,  12,   8),
    SurfaceHighlight= Color3.fromRGB( 22,  18,  10),
    Accent1         = Color3.fromRGB(200, 150,   0),
    TextPrimary     = Color3.fromRGB(235, 220, 190),
    Success         = Color3.fromRGB( 50, 200, 100),
    Error           = Color3.fromRGB(220,  60,  60),
}
_G.JAF_OnAccent = function(c) return Color3.fromRGB(255, 255, 255) end

-- ── Ping helper ───────────────────────────────────────────────
_G.JAF_Ping = function()
    local s = game:GetService("Stats")
    return (s and s.Network and s.Network.ServerStatsItem
            and s.Network.ServerStatsItem["Data Ping"]
            and s.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000) or 0
end

-- ── Utility: M2 (2-D XZ distance) ────────────────────────────
_G.JAF_M2 = function(ax, az, bx, bz)
    local dx, dz = ax - bx, az - bz
    return math.sqrt(dx*dx + dz*dz)
end

-- ── Shared state ──────────────────────────────────────────────
local SharedState = {
    AllAnimalsCache    = {},
    WalkingCache       = {},
    _currentTpTarget   = nil,
}
SharedState.SetManualTarget = function(v) end

-- ═══════════════════════════════════════════════════════════
--   SCANNER ENGINE  (populates SharedState.AllAnimalsCache)
-- ═══════════════════════════════════════════════════════════

-- ── JAF_SafeGen: compute gen value from game's Datas ─────────
do
    local _RS = ReplicatedStorage
    local _D  = _RS:WaitForChild("Datas", 10)
    local okA, _A  = false, nil
    local okG, _G_ = false, nil
    local okM, _M  = false, nil
    local okT, _T  = false, nil
    if _D then
        okA, _A  = pcall(require, _D:WaitForChild("Animals",   10))
        okG, _G_ = pcall(require, _D:WaitForChild("Game",      10))
        okM, _M  = pcall(require, _D:WaitForChild("Mutations", 10))
        okT, _T  = pcall(require, _D:WaitForChild("Traits",    10))
    end
    _G.JAF_SafeGen = _G.JAF_SafeGen or function(index, mutation, traits)
        if not (okA and _A) then return 0 end
        local e = _A[index]; if not e then return 0 end
        local base = e.Generation or 0
        if base == 0 then
            local mod = (okG and _G_ and _G_.Game and _G_.Game.AnimalGanerationModifier) or 0
            base = (e.Price or 0) * mod
        end
        local mult, sleepy = 1, false
        local _mu = mutation and okM and _M and _M[mutation]
        if _mu then mult = mult + (_mu.Modifier or 0) end
        if traits and okT and _T then
            for _, t in pairs(traits) do
                local tr = _T[t]
                if tr then
                    if t == "Sleepy" then sleepy = true
                    else mult = mult + (tr.MultiplierModifier or 0) end
                end
            end
        end
        local v = base * mult
        if sleepy then v = v * 0.5 end
        return math.round(v)
    end
end

-- ── JAF_AnimalsOf ─────────────────────────────────────────────
_G.JAF_AnimalsOf = _G.JAF_AnimalsOf or function(cacheTable)
    if type(cacheTable) ~= "table" then return nil end
    local v = rawget(cacheTable, "AnimalList") or rawget(cacheTable, "Animals")
    return type(v) == "table" and v or nil
end

-- ── JAF_OwnerName ─────────────────────────────────────────────
_G.JAF_OwnerName = _G.JAF_OwnerName or function(o)
    if o == nil then return nil end
    if typeof(o) == "Instance" then return o.Name end
    if type(o) == "table"  then return o.Name end
    if type(o) == "string" then if o == "" or o == "..." then return nil end return o end
    return nil
end

-- ── JAF_MachineBlocked ────────────────────────────────────────
_G.JAF_MachineBlocked = _G.JAF_MachineBlocked or function(ad)
    if type(ad) ~= "table" then return false end
    local m = ad.Machine
    if type(m) ~= "table" then return false end
    if m.Active then return true end
    return false
end

-- ── NUtils shim ──────────────────────────────────────────────
local _NUtils
pcall(function()
    _NUtils = require(ReplicatedStorage:WaitForChild("Utils",10):WaitForChild("NumberUtils",10))
end)
local function _numFmt(n)
    if _NUtils and _NUtils.ToString then return _NUtils:ToString(n) end
    if n >= 1e9 then return string.format("%.1fB", n/1e9)
    elseif n >= 1e6 then return string.format("%.1fM", n/1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n/1e3)
    else return tostring(math.floor(n)) end
end

-- ── AData shim ───────────────────────────────────────────────
local _AData
pcall(function()
    _AData = require(ReplicatedStorage:WaitForChild("Datas",10):WaitForChild("Animals",10))
end)

-- ── SyncSafe: safe channel accessor ──────────────────────────
local _SyncSafeGet
do
    local _SyncMod = nil
    pcall(function()
        _SyncMod = require(ReplicatedStorage:WaitForChild("Packages",10):WaitForChild("Synchronizer",10))
    end)

    local _instChanCache, _instChanAt = nil, 0
    local function _instanceChans()
        if true then return nil end -- PATCHED: remote upvalue scan disabled (AC-detected)
        local now = tick()
        if _instChanCache and (now - _instChanAt) < 2 then return _instChanCache end
        local pk = ReplicatedStorage:FindFirstChild("Packages")
        local sy = pk and pk:FindFirstChild("Synchronizer")
        local cf = sy and sy:FindFirstChild("Channel")
        if not cf then return nil end
        local map, n = {}, 0
        for _, re in ipairs(cf:GetChildren()) do
            if re:IsA("RemoteEvent") then
                local okC, conns = pcall(getconnections, re.OnClientEvent)
                if okC and type(conns) == "table" then
                    for _, conn in ipairs(conns) do
                        local okF, f = pcall(function() return conn.Function end)
                        if okF and type(f) == "function" then
                            local okU, uvs = pcall(debug.getupvalues, f)
                            if okU and type(uvs) == "table" then
                                for _, uv in ipairs(uvs) do
                                    if type(uv) == "table" and type(rawget(uv, "CacheTable")) == "table" then
                                        map[re.Name] = uv
                                        n = n + 1
                                        break
                                    end
                                end
                            end
                        end
                        if map[re.Name] then break end
                    end
                end
            end
        end
        if n == 0 then return nil end
        _instChanCache, _instChanAt = map, now
        return map
    end
    _G.JAF_InstanceChans = _instanceChans

    local _pulled = {}
    local function _pullPlot(name)
        local pk = ReplicatedStorage:FindFirstChild("Packages")
        local sy = pk and pk:FindFirstChild("Synchronizer")
        local rf = sy and sy:FindFirstChild("RequestData")
        if not rf or not rf:IsA("RemoteFunction") then return nil end
        local ok, res = pcall(function() return rf:InvokeServer(name) end)
        if ok and type(res) == "table" then _pulled[name] = res; return res end
    end

    local _dcCache = setmetatable({}, {__mode = "k"})
    local function directChannel(cd)
        if type(cd) ~= "table" then return nil end
        local hit = _dcCache[cd]; if hit then return hit end
        local w = {
            Get = function(_, key)
                local ct = rawget(cd, "CacheTable")
                if type(ct) ~= "table" then return nil end
                if key == "AnimalList" or key == "Animals" then return _G.JAF_AnimalsOf(ct) end
                return rawget(ct, key)
            end,
        }
        _dcCache[cd] = w
        return w
    end

    local SyncSafe = {}
    SyncSafe.Get = function(_, name)
        local ic = _instanceChans()
        if ic then
            local cd = rawget(ic, tostring(name))
            if cd then return directChannel(cd) end
        end
        local pd = _pulled[tostring(name)]
        if pd then return { Get = function(_, k)
            if k == "AnimalList" or k == "Animals" then return _G.JAF_AnimalsOf(pd) end
            return rawget(pd, k)
        end } end
        if _SyncMod then
            local ok, ch = pcall(function() return _SyncMod:Get(name) end)
            if ok and ch then return ch end
        end
        return nil
    end

    _G.JAF_SyncSafe = SyncSafe
    _G.JAF_GetSynchronizer = _G.JAF_GetSynchronizer or function() return SyncSafe end

    task.spawn(function()
        local plotsF = Workspace:WaitForChild("Plots", 10)
        if not plotsF then return end
        for _, pl in ipairs(plotsF:GetChildren()) do
            task.spawn(_pullPlot, pl.Name)
        end
    end)
end

-- ── _waitForCharacter shim ────────────────────────────────────
local function _waitForCharacter(timeout)
    local t0 = tick()
    while tick() - t0 < (timeout or 30) do
        local c = LocalPlayer.Character
        if c and c:FindFirstChild("HumanoidRootPart") then return c end
        task.wait(0.1)
    end
    return LocalPlayer.Character
end

-- ── Real animal scanner ──────────────────────────────────────
task.spawn(function()
    _waitForCharacter(30)
    task.wait(1.8 + math.random(0, 300)/1000)
    local Sync = _G.JAF_GetSynchronizer()
    if not Sync then warn("[AutoSteal] No synchronizer -- scanner disabled") return end

    local lastH    = {}
    local _scanPending = {}

    local function _makeEntry(slot, ad, on, plotName, inf)
        local mut = ad.Mutation or "None"
        if mut == "Yin Yang" then mut = "YinYang" end
        local gv  = _G.JAF_SafeGen(ad.Index, ad.Mutation, ad.Traits, nil)
        local nm  = (inf and (inf.DisplayName or ad.Index)) or ad.Index
        return {
            name      = nm,
            nameLower = string.lower(nm),
            genText   = "$".._numFmt(gv).."/s",
            genValue  = gv,
            mutation  = mut,
            mutLower  = string.lower(mut),
            owner     = on,
            plot      = plotName,
            rarity    = inf and inf.Rarity or "Common",
            slot      = tostring(slot),
            uid       = plotName.."_"..tostring(slot),
        }
    end

    local function scan(plot)
        local ok, ch = pcall(function() return Sync:Get(plot.Name) end)
        if not ok or not ch then return end
        local al = ch:Get("AnimalList")
        local h = ""
        if al then
            for s, d in pairs(al) do
                if type(d) == "table" then
                    h = h .. tostring(s) .. (d.Index or "") .. (d.Mutation or "")
                end
            end
        end
        if lastH[plot.Name] == h then return end
        local owner = ch:Get("Owner"); if not owner and al then return end
        local on = _G.JAF_OwnerName(owner) or "?"
        if al and not Players:FindFirstChild(on) then return end
        lastH[plot.Name] = h
        for i = #SharedState.AllAnimalsCache, 1, -1 do
            if SharedState.AllAnimalsCache[i].plot == plot.Name then
                table.remove(SharedState.AllAnimalsCache, i)
            end
        end
        if not al then return end
        for slot, ad in pairs(al) do
            if type(ad) == "table" and ad.Index and not _G.JAF_MachineBlocked(ad) then
                local inf = _AData and _AData[ad.Index]
                local entry = _makeEntry(slot, ad, on, plot.Name, inf)
                table.insert(SharedState.AllAnimalsCache, entry)
            end
        end
        table.sort(SharedState.AllAnimalsCache, function(a, b) return a.genValue > b.genValue end)
    end

    local function scheduleScan(plot)
        if _scanPending[plot] then return end
        _scanPending[plot] = true
        task.spawn(function()
            task.wait(0.12)
            _scanPending[plot] = nil
            pcall(scan, plot)
        end)
    end

    local _chanFolder
    pcall(function()
        local pk = ReplicatedStorage:FindFirstChild("Packages")
        local sy = pk and pk:FindFirstChild("Synchronizer")
        _chanFolder = sy and sy:FindFirstChild("Channel")
    end)

    local function hookChannelEvent(plot)
        if not _chanFolder then return false end
        local re = _chanFolder:FindFirstChild(plot.Name)
        if not re or not re:IsA("RemoteEvent") then return false end
        local ok = pcall(function()
            re.OnClientEvent:Connect(function() scheduleScan(plot) end)
        end)
        return ok
    end

    local function armChannelEvent(plot)
        task.spawn(function()
            for _ = 1, 20 do
                if hookChannelEvent(plot) then return end
                task.wait(0.25)
            end
        end)
    end

    local function pollPlot(plot)
        task.spawn(function()
            while plot.Parent do
                task.wait(tonumber(_G.JAF_PlotPoll) or 1.5)
                pcall(scan, plot)
            end
        end)
    end

    local function setup(plot)
        local ch
        local s0 = tick()
        while not ch and tick() - s0 < 1.5 do
            local ok, r = pcall(function() return Sync:Get(plot.Name) end)
            if ok and r then ch = r; break end
            RunService.Heartbeat:Wait()
        end
        pcall(scan, plot)
        _G.JAF_PlotsScanned = (_G.JAF_PlotsScanned or 0) + 1
        plot.DescendantAdded:Connect(function()    scheduleScan(plot) end)
        plot.DescendantRemoving:Connect(function() scheduleScan(plot) end)
        armChannelEvent(plot)
        pollPlot(plot)
    end

    _G.JAF_ScanStale = function(pn) lastH[pn] = nil end

    local plots = Workspace:WaitForChild("Plots", 8)
    if not plots then warn("[AutoSteal] No Plots folder found -- scanner disabled") return end

    local _plotList = plots:GetChildren()
    _G.JAF_PlotsScanned = 0
    _G.JAF_PlotsTotal   = #_plotList
    for _, p in ipairs(_plotList) do task.spawn(setup, p) end

    plots.ChildAdded:Connect(function(p)
        task.wait(0.3)
        setup(p)
    end)
    plots.ChildRemoved:Connect(function(p)
        lastH[p.Name] = nil
        for i = #SharedState.AllAnimalsCache, 1, -1 do
            if SharedState.AllAnimalsCache[i].plot == p.Name then
                table.remove(SharedState.AllAnimalsCache, i)
            end
        end
    end)

    Players.PlayerRemoving:Connect(function(plr)
        if _G.JAF_EvictOnLeave == false then return end
        local nm = plr and plr.Name; if not nm or nm == "" then return end
        for i = #SharedState.AllAnimalsCache, 1, -1 do
            local e = SharedState.AllAnimalsCache[i]
            if e and e.owner == nm then
                if e.plot then lastH[e.plot] = nil end
                table.remove(SharedState.AllAnimalsCache, i)
            end
        end
        local cur = SharedState._currentTpTarget
        if cur and cur.owner == nm then SharedState._currentTpTarget = nil end
    end)

    SharedState.ScanAllPlots = function()
        if not plots then return end
        local fresh = {}
        for _, _p in ipairs(plots:GetChildren()) do
            local ok, ch = pcall(function() return Sync:Get(_p.Name) end)
            if ok and ch then
                pcall(function()
                    local al    = ch:Get("AnimalList")
                    local owner = ch:Get("Owner")
                    local on    = _G.JAF_OwnerName(owner)
                    if al and on and Players:FindFirstChild(on) then
                        for slot, ad in pairs(al) do
                            if type(ad) == "table" and ad.Index and not _G.JAF_MachineBlocked(ad) then
                                local inf = _AData and _AData[ad.Index]
                                fresh[#fresh+1] = _makeEntry(slot, ad, on, _p.Name, inf)
                            end
                        end
                    end
                end)
            end
        end
        table.sort(fresh, function(a, b) return a.genValue > b.genValue end)
        local cache = SharedState.AllAnimalsCache
        table.clear(cache)
        for i = 1, #fresh do cache[i] = fresh[i] end
    end
end)

-- ── Manual target & steal-nearest ─────────────────────────────
local manualTarget  = nil
local stealNearest  = Config.StealNearest or false

_G.JAF_SetStealNearest = function(v)
    stealNearest = v and true or false
    Config.StealNearest  = stealNearest
    Config.UsePriority   = not stealNearest
    if stealNearest then manualTarget = nil end
    return stealNearest
end
_G.JAF_ToggleStealNearest = function()
    return _G.JAF_SetStealNearest(not stealNearest)
end
SharedState.SetManualTarget = function(v) manualTarget = v end
_G.JAF_GetManualTarget = function() return manualTarget end

-- ── Priority score ──────────────────────────────────────────
_G.JAF_PrioScore = _G.JAF_PrioScore or function(a)
    if not a then return 999999 end
    local list = _G.SHARED_PRIORITY_ITEMS
    if type(list) == "table" and #list > 0 and Config.UsePriority ~= false then
        local n  = (a.index or ""):lower()
        local nm = (a.name  or ""):lower()
        for i, v in ipairs(list) do
            local vl = tostring(v):lower()
            if n:find(vl,1,true) or nm:find(vl,1,true) or vl:find(nm,1,true) then
                return i
            end
        end
        return 999999
    end
    local gv = tonumber(a.genValue) or 0
    return gv > 0 and (1 / gv) or 999999
end

-- ── Owner-present tracker ─────────────────────────────────────
local _ownerPresent = {}
for _, pl in ipairs(Players:GetPlayers()) do _ownerPresent[pl.Name] = true end
Players.PlayerAdded:Connect(function(pl)   _ownerPresent[pl.Name] = true  end)
Players.PlayerRemoving:Connect(function(pl) _ownerPresent[pl.Name] = nil  end)

-- ── getChar helper ────────────────────────────────────────────
local function getChar()
    local c   = LocalPlayer.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    local hum = c and c:FindFirstChildWhichIsA("Humanoid")
    return c, hrp, hum
end

-- ── findAdorneeGlobal ─────────────────────────────────────────
local function findAdorneeGlobal(a)
    if not a then return nil end
    if a.isWalking then
        local m = a.model
        return m and m.Parent and (m:FindFirstChild("HumanoidRootPart", true) or m:FindFirstChildWhichIsA("BasePart", true))
    end
    local plots = Workspace:FindFirstChild("Plots"); if not plots then return nil end
    local plot  = plots:FindFirstChild(a.plot);     if not plot  then return nil end
    local pods  = plot:FindFirstChild("AnimalPodiums"); if not pods then return nil end
    local pod   = pods:FindFirstChild(a.slot);      if not pod   then return nil end
    local base  = pod:FindFirstChild("Base");        if not base  then return nil end
    local sp    = base:FindFirstChild("Spawn");      if not sp    then return nil end
    return sp
end
_G.findAdorneeGlobal = findAdorneeGlobal

-- ── Ragdoll helpers ───────────────────────────────────────────
local function _ragUntil()
    return math.max(tonumber(LocalPlayer:GetAttribute("RagdollEndTime")) or 0,
                    tonumber(_G.JAF_RagdollUntil) or 0)
end
local function _ragBlockedNow()
    return (_ragUntil() - workspace:GetServerTimeNow() + (tonumber(_G.JAF_RagdollLatePad) or 0.1)) > 0
        or (tick() - (tonumber(_G.JAF_RagdollPhysLastT) or 0)) < (tonumber(_G.JAF_RagdollPhysWindow) or 0.4)
end

-- ── Podium finder from uid ────────────────────────────────────
local function _podOf(uid)
    if not uid then return nil end
    local pn, sl = tostring(uid):match("^(.*)_([^_]+)$")
    if not (pn and sl) then return nil end
    local pl = Workspace:FindFirstChild("Plots")
    pl = pl and pl:FindFirstChild(pn)
    pl = pl and pl:FindFirstChild("AnimalPodiums")
    return pl and pl:FindFirstChild(sl)
end

-- ── Callback grabber ──────────────────────────────────────────
local function _grabCB(p)
    local d = { hold = {}, trigger = {}, holdRaw = {} }
    local ok, cs = pcall(getconnections, p.PromptButtonHoldBegan)
    if ok and type(cs) == "table" then
        for _, c in ipairs(cs) do
            local f = c.Function
            if type(f) == "function" then
                d.holdRaw[#d.holdRaw+1] = f
                d.hold[#d.hold+1]       = _wrap(f)
            end
        end
    end
    ok, cs = pcall(getconnections, p.Triggered)
    if ok and type(cs) == "table" then
        for _, c in ipairs(cs) do
            local f = c.Function
            if type(f) == "function" then d.trigger[#d.trigger+1] = _wrap(f) end
        end
    end
    return d
end

local function _fireTrigger(p, d)
    if d then
        for _, f in ipairs(d.trigger) do task.spawn(f) end
        if #d.trigger == 0 then
            pcall(function()
                local rem = rPR and rPR()
                if rem then
                    if rem:IsA("RemoteFunction") then rem:InvokeServer(p.Parent)
                    elseif rem:IsA("RemoteEvent") then rem:FireServer(p.Parent) end
                end
            end)
        end
    end
end

local _apCache = setmetatable({}, {__mode = "k"})
local function _apFromHold(p, d)
    local ap = _apCache[p]
    if ap ~= nil then return ap or nil end
    if false and debug and debug.getupvalues and d then -- PATCHED: disabled, AC-detected
        for _, f in ipairs(d.holdRaw or d.hold) do
            local ok, ups = pcall(debug.getupvalues, f)
            if ok then
                for _, v in pairs(ups) do
                    if type(v) == "table" and rawget(v, "State") ~= nil and rawget(v, "ProximityPrompt") ~= nil then
                        _apCache[p] = v; return v
                    end
                end
            end
        end
    end
    _apCache[p] = false
    return nil
end

local function _fireHoldForced(p, d)
    if not d or #d.hold == 0 then return false end
    local ap = _apFromHold(p, d)
    if ap and ap.State ~= "Steal" then
        local _os = ap.State
        ap.State = "Steal"
        for _, f in ipairs(d.hold) do pcall(f) end
        ap.State = _os
        return true
    end
    if not ap and p and p.Enabled == false then return false end
    for _, f in ipairs(d.hold) do task.spawn(f) end
    return true
end

-- ── Force-steal one prompt ────────────────────────────────────
_G.JAF_ForceSteal = function(p)
    if not (p and p.Parent and p.Enabled) then return false end
    local d = _grabCB(p)
    _fireHoldForced(p, d)
    _fireTrigger(p, d)
    return true
end

-- ── isMyPlot ──────────────────────────────────────────────────
local function isMyPlot(plotName)
    local plots = Workspace:FindFirstChild("Plots")
    local plot  = plots and plots:FindFirstChild(plotName)
    local sign  = plot and plot:FindFirstChild("PlotSign")
    local yb    = sign and sign:FindFirstChild("YourBase")
    return (yb and yb:IsA("BillboardGui") and yb.Enabled == true) or false
end
_G._isMyPlot = isMyPlot

-- ── Prompt index cache ────────────────────────────────────────
local PromptCache    = {}
local PromptIdx      = setmetatable({}, {__mode = "k"})
local PromptIdxDirty = setmetatable({}, {__mode = "k"})
local PromptIdxConn  = setmetatable({}, {__mode = "k"})

local function findPrompt(a)
    if not a then return nil end
    if a.isWalking then
        if a.prompt and a.prompt.Parent and a.prompt.Enabled then return a.prompt end
        return nil
    end
    local cp = PromptCache[a.uid]
    if cp and cp.Parent and cp.Enabled and cp.ActionText == "Steal" then return cp end
    local plots = Workspace:FindFirstChild("Plots"); if not plots then return nil end
    local plot  = plots:FindFirstChild(a.plot);     if not plot  then return nil end
    local pods  = plot:FindFirstChild("AnimalPodiums"); if not pods then return nil end
    local pod   = pods:FindFirstChild(a.slot);      if not pod   then return nil end
    local base  = pod:FindFirstChild("Base");        if not base  then return nil end
    local sp    = base:FindFirstChild("Spawn");      if not sp    then return nil end
    local att   = sp:FindFirstChild("PromptAttachment")
    if att then
        for _, p in ipairs(att:GetChildren()) do
            if p:IsA("ProximityPrompt") and p.Enabled and p.ActionText == "Steal" then
                PromptCache[a.uid] = p; return p
            end
        end
    end
    local startPos = sp.Position
    local best, bd = nil, math.huge
    local _pl = PromptIdx[plot]
    if not _pl or PromptIdxDirty[plot] then
        _pl = {}
        for _, d in ipairs(plot:GetDescendants()) do if d:IsA("ProximityPrompt") then _pl[#_pl+1] = d end end
        PromptIdx[plot], PromptIdxDirty[plot] = _pl, nil
        if not PromptIdxConn[plot] then
            local function _mark(d) if d:IsA("ProximityPrompt") then PromptIdxDirty[plot] = true end end
            PromptIdxConn[plot] = { plot.DescendantAdded:Connect(_mark), plot.DescendantRemoving:Connect(_mark) }
        end
    end
    for _, d in ipairs(_pl) do
        if d.Parent and d.Enabled and d.ActionText == "Steal" then
            local part = d.Parent
            local pp
            if part:IsA("BasePart") then pp = part.Position
            elseif part:IsA("Attachment") and part.Parent:IsA("BasePart") then pp = part.Parent.Position end
            if pp then
                local dx, dz = pp.X - startPos.X, pp.Z - startPos.Z
                if (dx*dx + dz*dz) < 25 and pp.Y > startPos.Y then
                    local yd = pp.Y - startPos.Y
                    if yd < bd then bd = yd; best = d end
                end
            end
        end
    end
    if best then PromptCache[a.uid] = best end
    return best
end

-- ── Stealable predicate ───────────────────────────────────────
local function _stealable(a, me)
    if not a or a.owner == me then return false end
    if _G.JAF_SkipLeftOwners == false then return true end
    return a.owner ~= nil and _ownerPresent[a.owner] == true
end

-- ── Priority resolver ─────────────────────────────────────────
local function resolvePriorityTarget()
    local _lpName = LocalPlayer.Name
    local _all    = SharedState.AllAnimalsCache
    if stealNearest then
        local _, hrp = getChar()
        if not hrp then return nil end
        local best, bestDist = nil, math.huge
        local hrpPos = hrp.Position
        for _, a in ipairs(_all) do
            if _stealable(a, _lpName) then
                local part = findAdorneeGlobal(a)
                if part then
                    local d = (hrpPos - part.Position).Magnitude
                    if d < bestDist then bestDist = d; best = a end
                end
            end
        end
        return best
    end
    if manualTarget then return manualTarget end
    if Config.UsePriority ~= false then
        local best, bestScore = nil, math.huge
        local _prio = _G.JAF_PrioScore
        for _, a in ipairs(_all) do
            if a and a.name and _stealable(a, _lpName) then
                local s = _prio(a)
                if s < bestScore then bestScore, best = s, a end
            end
        end
        if best and bestScore < 999999 then return best end
    end
    for _, a in ipairs(_all) do if _stealable(a, _lpName) then return a end end
    return nil
end
_G.JAF_ResolveBest = resolvePriorityTarget

-- ── Prompt distance helpers ───────────────────────────────────
local function promptDistXZ(prompt)
    local c   = LocalPlayer.Character
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local par = prompt and prompt.Parent
    local pos
    if par then
        if par:IsA("Attachment") then pos = par.WorldPosition
        elseif par:IsA("BasePart") then pos = par.Position
        else
            local bp = par:FindFirstAncestorWhichIsA("BasePart")
            if bp then pos = bp.Position end
        end
    end
    if not pos then return nil end
    local hp = hrp.Position
    return _G.JAF_M2(pos.X, pos.Z, hp.X, hp.Z), (pos - hp).Magnitude
end

local function findNearestPrompt(priorityTarget)
    local _, hrp = getChar()
    if not hrp then return end
    local plots = Workspace:FindFirstChild("Plots"); if not plots then return end
    priorityTarget = priorityTarget or resolvePriorityTarget()
    if not priorityTarget then return end
    local hrpPos  = hrp.Position
    local _radius = Config.StealRadius or 95
    if priorityTarget.isWalking then
        local pr = priorityTarget.prompt
        if pr and pr.Parent and pr.Enabled then
            local model = priorityTarget.model
            local part  = model and model.Parent and model:FindFirstChildWhichIsA("BasePart")
            if part then
                local pp = part.Position
                if _G.JAF_M2(pp.X, pp.Z, hrpPos.X, hrpPos.Z) <= _radius then return pr end
            end
        end
        return nil
    end
    local plot = plots:FindFirstChild(priorityTarget.plot)
    if not plot or isMyPlot(plot.Name) then return nil end
    local pods = plot:FindFirstChild("AnimalPodiums")
    local pod  = pods and pods:FindFirstChild(priorityTarget.slot)
    local base = pod and pod:FindFirstChild("Base")
    local spawn = base and base:FindFirstChild("Spawn")
    if not spawn then return nil end
    local sp = spawn.Position
    if _G.JAF_M2(sp.X, sp.Z, hrpPos.X, hrpPos.Z) > _radius then return nil end
    local att = spawn:FindFirstChild("PromptAttachment"); if not att then return nil end
    local nearest
    for _, p in ipairs(att:GetChildren()) do
        if p:IsA("ProximityPrompt") and p.Enabled and p.ActionText:find("Steal") then nearest = p end
    end
    return nearest
end

-- ── Ping gating ───────────────────────────────────────────────
local _pgKey, _pgEntryT = nil, 0
local _pgPingEma, _pgPingJit, _pgPingT = nil, 0, 0

local function stealPingSample()
    local now = tick()
    if now - _pgPingT < (tonumber(_G.JAF_StealPingSampleDt) or 0.25) then return end
    _pgPingT = now
    local p = _G.JAF_Ping()
    if type(p) ~= "number" or p <= 0 then return end
    if not _pgPingEma then _pgPingEma, _pgPingJit = p, 0
    else
        local a = tonumber(_G.JAF_StealPingEmaAlpha) or 0.25
        _pgPingJit = _pgPingJit + (math.abs(p - _pgPingEma) - _pgPingJit) * a
        _pgPingEma = _pgPingEma + (p - _pgPingEma) * a
    end
end

local function stealPingWindow()
    local rtt = _pgPingEma
    if not rtt then rtt = _G.JAF_Ping() end
    local ms = (rtt + (tonumber(_G.JAF_StealPingJitterMult) or 1) * (_pgPingJit or 0)) * 1000
    ms = math.min(ms, tonumber(_G.JAF_StealPingDelayCapMs) or 1000)
    if ms < (tonumber(_G.JAF_StealPingDelayMinMs) or 0) then ms = 0 end
    return ms / 1000
end

local function stealPingGateReady(prompt, uid)
    if _G.JAF_StealPingDelay ~= true then return true end
    if not prompt then _pgKey = nil; return false end
    stealPingSample()
    local _d = promptDistXZ(prompt)
    if _d == nil then return true end
    if _d > (Config.StealRadius or 95) then _pgKey = nil; return false end
    local key = uid or prompt
    if _pgKey ~= key then _pgKey = key; _pgEntryT = tick() end
    return tick() >= _pgEntryT + stealPingWindow()
end
_G.JAF_StealPingGateRearm = function()
    if _pgKey ~= nil then _pgEntryT = tick() end
end

-- ── Core state ────────────────────────────────────────────────
local isAutoStealing = false
local StealData      = setmetatable({}, {__mode = "k"})
local StealCache     = setmetatable({}, {__mode = "k"})
local _stealStart    = 0
local _stealProgress = 0
local _holdEpoch     = 0

local function _pivotPos(m) return m:GetPivot().Position end

-- ════════════════════════════════════════════════════════════════
--   executeSteal  (Silence Hub core auto-grab)
-- ════════════════════════════════════════════════════════════════
local function executeSteal(prompt, heldUid, preHold)
    if isAutoStealing then return end
    local function _tpBanking()
        return preHold == true and _G.JAF_StealPreHold ~= false and _G.JAF_TpActive == true
               and heldUid ~= nil and SharedState._currentTpTarget ~= nil
               and SharedState._currentTpTarget.uid == heldUid
    end
    local _d = promptDistXZ(prompt)
    if _d and _d > (Config.StealRadius or 95) and not _tpBanking() then return end

    local data = StealData[prompt]
    if not data then
        data = _grabCB(prompt)
        data.ready = true
        if #data.hold > 0 and (#data.trigger > 0 or _G.JAF_StealUseFPP ~= false) then
            StealData[prompt] = data
        end
    end
    if not data.ready then return end
    data.ready   = false
    isAutoStealing = true
    _stealStart  = tick()

    task.spawn(function()
        local oldDuration = prompt.HoldDuration
        prompt.HoldDuration = 0
        local _beginT, _inherited = 0, false
        local _hAge = _holdEpoch > 0 and (tick() - _holdEpoch) or math.huge

        if _G.JAF_StealHoldCarry ~= false and prompt.Enabled
           and _hAge <= (tonumber(_G.JAF_StealCarryMax) or 1.25) then
            _beginT, _inherited = _holdEpoch, true
        else
            for _, f in ipairs(data.hold) do task.spawn(f) end
            _beginT = prompt.Enabled and tick() or 0
            if _beginT > 0 and #data.hold > 0 then _holdEpoch = _beginT end
        end

        local _beganOk, _recapN, _instaCommitted = (_inherited or #data.hold > 0), 0, false
        local _dur = Config.StealDuration
        if not _dur then
            local _srv = (_G.JAF_StealUsePromptHold == true) and tonumber(oldDuration) or nil
            _dur = ((_srv and _srv > 0.1 and _srv) or 1.3) + (tonumber(_G.JAF_StealHoldPad) or 0)
        end
        _G.JAF_StealDurNow  = _dur
        local _maxHold      = _dur
        _G.JAF_StealCycleDur = _dur

        local _t0 = _inherited and _beginT or tick()
        local _holdAbsStart = tick()
        if _inherited then _stealStart = _beginT end

        local _ragRet0   = _ragUntil()
        local _postGrace = (tonumber(_G.JAF_StealPostGrace) or 0)
                         + ((_ragRet0 > 0) and (tonumber(_G.JAF_RagdollPostGrace) or 0) or 0)

        local _abort, _grabbed, _recycle, _didEnter = false, false, false, false
        local _clearFireUntil, _lastCommitT, _commitN = 0, 0, 0
        local _eligSince, _commitGraceUntil, _tpHold = 0, 0, false
        local _tpWasBlk, _wasDis, _disAt = false, false, nil
        local _carryChkT, _carryFlag, _carryLastT, _bankT, _campChkT = 0, false, 0, 0, 0
        local _promptGone, _goneAt, _goneConn = false, nil, nil
        local activePrompt, activeData = prompt, data
        local _podiumForDist = _podOf(heldUid)

        local function _petDistNow()
            local _, _h = getChar()
            if not _h then return nil end
            if _podiumForDist and _podiumForDist.Parent then
                local ok, piv = pcall(_pivotPos, _podiumForDist)
                if ok and piv then return (piv - _h.Position).Magnitude end
            end
            local _, d3 = promptDistXZ(activePrompt); return d3
        end

        if _G.JAF_StealReacquire ~= false and heldUid and _podiumForDist then
            _goneConn = _podiumForDist.DescendantAdded:Connect(function(desc)
                if _promptGone and desc:IsA("ProximityPrompt")
                   and tostring(desc.ActionText or ""):find("Steal") then
                    activePrompt, activeData = desc, _grabCB(desc)
                    pcall(function() desc.HoldDuration = 0 end)
                    for _, f in ipairs(activeData.hold) do task.spawn(f) end
                    _beginT = desc.Enabled and tick() or 0
                    if _beginT > 0 and #activeData.hold > 0 then _holdEpoch = _beginT end
                    _beganOk = #activeData.hold > 0
                    _wasDis, _disAt, _bankT = false, nil, 0
                    _G.JAF_StealCarryWait = nil
                    _promptGone, _goneAt = false, nil
                    _stealStart = tick()
                    _t0, _commitN, _lastCommitT, _recycle = tick(), 0, 0, false
                end
            end)
        end

        repeat
            if manualTarget ~= nil and heldUid ~= nil and manualTarget.uid ~= heldUid then _abort = true; break end
            if LocalPlayer:GetAttribute("Stealing") then _grabbed = true; break end
            if _goneConn and not activePrompt.Parent and not _promptGone then _promptGone = true; _goneAt = tick() end

            local _bestSwitch = manualTarget == nil and heldUid ~= nil
                                and _G.JAF_StealBestSwitch ~= false and _G.JAF_ResolveBest

            if _promptGone then
                _G.JAF_StealInCommitRange = false
                if _bankT == 0 or (tick() - _bankT) > (tonumber(_G.JAF_StealBankRefresh) or 2.5) then
                    if _fireHoldForced(activePrompt, activeData) then _bankT = tick(); _holdEpoch = _bankT end
                end
                _G.JAF_StealCarryWait = tick() - _goneAt
                _G.JAF_StealCarryT0   = _bankT
                if (tick() - _goneAt) > (tonumber(_G.JAF_StealPromptGoneWait) or 6.5) then break end
                if _bestSwitch then
                    local _lb = _G.JAF_ResolveBest()
                    if _lb and _lb.uid and _lb.uid ~= heldUid then _abort = true; break end
                end
                _t0 = _t0 + (_G.JAF_StealFireInterval or 0.12)
                task.wait(_G.JAF_StealFireInterval or 0.12)
                continue
            end

            if activePrompt.Parent and not activePrompt.Enabled then
                if not _disAt then _disAt = tick() end
                _G.JAF_StealInCommitRange = false
                if (tick() - _carryChkT) > 0.25 then
                    _carryChkT = tick()
                    if #activeData.hold == 0 then activeData = _grabCB(activePrompt) end
                    local _cnow = false
                    if _G.JAF_IsBeingStolen then
                        for _, _sa in ipairs(SharedState.AllAnimalsCache) do
                            if _sa and _sa.uid == heldUid then
                                local _cok, _cv = pcall(_G.JAF_IsBeingStolen, _sa)
                                _cnow = _cok and _cv == true; break
                            end
                        end
                    end
                    if _cnow then _carryLastT = tick() end
                    _carryFlag = _cnow or (tick() - _carryLastT) < 1.0
                end
                if _bankT > 0 and (tick() - _bankT) > (tonumber(_G.JAF_StealBankRefresh) or 2.5) then _bankT = 0 end
                if _bankT == 0 and _G.JAF_StealPreBank ~= false then
                    if _fireHoldForced(activePrompt, activeData) then _bankT = tick(); _holdEpoch = _bankT end
                end
                if (tick() - _campChkT) > 0.25 then
                    _campChkT = tick()
                    if _bestSwitch then
                        local _lb = _G.JAF_ResolveBest()
                        if _lb and _lb.uid and _lb.uid ~= heldUid then
                            local _keep = false
                            for _, _sa in ipairs(SharedState.AllAnimalsCache) do
                                if _sa and _sa.uid == heldUid then _keep = _stealable(_sa, LocalPlayer.Name) ~= false; break end
                            end
                            if not _keep then _abort = true end
                        end
                    end
                    if _abort then break end
                end
                if (not _carryFlag) and (tick() - math.max(_disAt, _carryLastT)) > (tonumber(_G.JAF_StealDisabledGrace) or 3) then break end
                _wasDis = true
                _G.JAF_StealCarryWait = tick() - _disAt
                _G.JAF_StealCarryT0   = _bankT
                local _dt = tonumber(_G.JAF_StealPoll) or 0.03
                _stealStart = _bankT > 0 and _bankT or tick()
                _t0, _commitN, _lastCommitT, _recycle = tick(), 0, 0, false
                _G.JAF_StealExtending  = false
                _G.JAF_StealCycleLeft  = _maxHold
                _holdAbsStart = _holdAbsStart + (task.wait(_dt) or _dt)
                continue
            end

            if _wasDis then
                _wasDis, _disAt = false, nil
                _G.JAF_StealCarryWait = nil
                activeData = _grabCB(activePrompt)
                local _bAge = _bankT > 0 and (tick() - _bankT) or math.huge
                if _bAge <= (tonumber(_G.JAF_StealBankUseMax) or 2.3) then
                    _beginT = _bankT; _t0 = _bankT; _stealStart = _bankT; _beganOk = true
                else
                    for _, f in ipairs(activeData.hold) do task.spawn(f) end
                    _beginT = tick(); _beganOk = #activeData.hold > 0
                    if _beganOk then _holdEpoch = _beginT end
                    _t0 = tick(); _stealStart = tick()
                end
                _bankT = 0
                _commitN, _lastCommitT, _recycle = 0, 0, false
                _eligSince   = tick() - (tonumber(_G.JAF_StealEntryDelay) or 0.3)
                _clearFireUntil = math.max(_clearFireUntil, tick() + (tonumber(_G.JAF_StealDropSettle) or 0.5))
            end

            if not _beganOk then _stealStart = tick() end

            local _needTrig = _G.JAF_StealUseFPP == false
            if (#activeData.hold == 0 or (_needTrig and #activeData.trigger == 0))
               and _recapN < (tonumber(_G.JAF_StealRecapMax) or 40) then
                _recapN = _recapN + 1
                local _rd = _grabCB(activePrompt)
                if #_rd.hold > 0 and (not _needTrig or #_rd.trigger > 0) then
                    activeData = _rd
                    if not _beganOk then
                        for _, f in ipairs(_rd.hold) do task.spawn(f) end
                        if activePrompt.Enabled then _beginT = tick(); _holdEpoch = _beginT end
                        _beganOk  = true
                        _stealStart = tick()
                        _t0, _commitN, _lastCommitT, _recycle = tick(), 0, 0, false
                    end
                end
            end

            local _hrDist, _hr3D = promptDistXZ(activePrompt)
            local _preBank = _tpBanking()
            if _hrDist and _hrDist > (Config.StealRadius or 95) and not _preBank then _abort = true; break end

            if _bestSwitch then
                local _lb = _G.JAF_ResolveBest()
                if _lb and _lb.uid and _lb.uid ~= heldUid then
                    local _pd0 = _petDistNow()
                    if _beginT == 0 or (tick() - _beginT) < (tonumber(_G.JAF_StealSrvHold) or _dur)
                       or (_pd0 and _pd0 > (tonumber(_G.JAF_StealSwitchNear) or 25)) then
                        _abort = true; break
                    end
                    local _keep = false
                    for _, _sa in ipairs(SharedState.AllAnimalsCache) do
                        if _sa and _sa.uid == heldUid then _keep = _stealable(_sa, LocalPlayer.Name) ~= false; break end
                    end
                    if not _keep then _abort = true; break end
                end
            end

            local _ragSync = _G.JAF_RagdollStealSync ~= false
            local _now = tick()
            if _ragSync then
                local _nr = _ragUntil(); local _remNow = _nr - workspace:GetServerTimeNow()
                if _nr > _ragRet0 + 0.3 and _remNow > 0.1 then
                    _ragRet0 = _nr
                    _t0 = math.max(_t0, _now + _remNow - _dur + (tonumber(_G.JAF_RagdollLatePad) or 0.1))
                    _stealStart = math.max(_stealStart, _t0)
                    _postGrace  = (tonumber(_G.JAF_StealPostGrace) or 0) + (tonumber(_G.JAF_RagdollPostGrace) or 0)
                end
            end

            local _holdDone  = (_now - _t0) >= (_dur + _postGrace)
            local _ragBlocked = _ragSync and _ragBlockedNow()
            if _ragSync and _G.JAF_RagdollHoldUntilClear ~= false and _holdDone and _ragBlocked then
                _clearFireUntil = _now + (tonumber(_G.JAF_RagdollClearWindow) or 0.35)
            end
            if _holdDone and not _grabbed and _G.JAF_StealRangeHold ~= false then _G.JAF_StealExtending = true end

            if _commitN == 0 and not _ragBlocked
               and (_beginT == 0 or (_now - _beginT) > (tonumber(_G.JAF_StealSrvHoldMax) or 2.5))
               and activePrompt.Parent and activePrompt.Enabled then
                local _rhOk = _fireHoldForced(activePrompt, activeData)
                _beginT      = tick()
                _holdEpoch   = _rhOk and _beginT or 0
                _beganOk     = #activeData.hold > 0
                _stealStart  = tick()
                _t0          = math.max(_t0, tick())
            end

            local _petDist    = _petDistNow()
            local _petInRange = _petDist and _petDist <= (tonumber(_G.JAF_StealCommitRange) or 10)
            local _tpBlocking = (_G.JAF_StealTpGate ~= false) and (_G.JAF_TpActive == true)
                                and SharedState._currentTpTarget ~= nil
                                and SharedState._currentTpTarget.uid == heldUid

            if _tpWasBlk and not _tpBlocking and _G.JAF_StealTpRearm ~= false then
                local _relBar = tonumber(_G.JAF_StealTpRelBar) or 0
                if _relBar > 0 then
                    _t0 = math.max(_t0, _now - (_dur + _postGrace) + _relBar)
                    _stealStart = math.max(_stealStart, _t0)
                end
                _clearFireUntil = math.max(_clearFireUntil, _now + (tonumber(_G.JAF_StealTpRelGrace) or 0.75))
            end
            _tpWasBlk = _tpBlocking

            if _petInRange and not _tpBlocking then
                if _eligSince == 0 then _eligSince = _now end
            else
                _eligSince = 0
            end

            local _snapT      = tonumber(_G.JAF_BrainrotSnapT) or 0
            local _instaFresh = _snapT > 0 and (_now - _snapT) < (tonumber(_G.JAF_StealInstaWindow) or 5)
            local _settleAnchor = _eligSince
            if _instaFresh and _snapT > _settleAnchor then _settleAnchor = _snapT end
            local _instaDelay = tonumber(_G.JAF_StealEntryDelayInsta)
            if not _instaDelay then
                _instaDelay = tonumber(_G.JAF_InstaSettle) or (tonumber(_G.JAF_InstaSettleStart) or 0.35)
                _G.JAF_InstaSettle = _instaDelay
            end
            local _effDelay = _instaFresh and _instaDelay or (tonumber(_G.JAF_StealEntryDelay) or 0.3)
            local _settled  = (_eligSince > 0) and ((_now - _settleAnchor) >= _effDelay)
            local _inCommit = _holdDone and not _grabbed and not _ragBlocked
                              and _petInRange and not _tpBlocking and _settled
                              and _beginT > 0 and (_now - _beginT) >= (tonumber(_G.JAF_StealSrvHold) or _dur)
                              and (_now - _beginT) <= (tonumber(_G.JAF_StealSrvHoldMax) or 2.5)
            _tpHold = (_G.JAF_StealTpHold ~= false) and _tpBlocking and not _grabbed
                      and _commitN == 0 and _holdDone
                      and (_now - _holdAbsStart) < (tonumber(_G.JAF_StealTpHoldMax) or 8)

            if _inCommit and _commitN == 0 then
                _lastCommitT, _commitN = _now, 1
                if _instaFresh then _instaCommitted = true end
                _fireTrigger(activePrompt, activeData)
            end
            if _inCommit and not _didEnter then
                _didEnter = true
                if _G.JAF_StealCommitSettle == true and ((not _preBank) or (_hr3D and _hr3D <= (tonumber(_G.JAF_StealSettleNear) or 6))) then
                    local _, _shrp = getChar()
                    local _v = _shrp and _shrp.AssemblyLinearVelocity
                    local _minSpd = tonumber(_G.JAF_StealCommitSettleSpeed) or 30
                    if _v and (_v.X*_v.X + _v.Z*_v.Z) > (_minSpd*_minSpd) then
                        pcall(function() _shrp.AssemblyLinearVelocity = Vector3.new(0, _v.Y, 0) end)
                    end
                end
            end
            if _commitN > 0 and not _grabbed and (_now - _lastCommitT) >= (tonumber(_G.JAF_StealCommitWait) or 0.4) then
                _recycle = true
            end
            _commitGraceUntil = 0
            if _G.JAF_StealHoldForSettle ~= false and not _grabbed and (_eligSince > 0 or _ragBlocked) then
                local _fm  = tonumber(_G.JAF_StealCommitFireMargin) or 0.06
                local _due = 0
                if _commitN == 0 then
                    if _eligSince > 0 and not _settled then _due = _settleAnchor + _effDelay + _fm end
                    if _beginT > 0 then
                        local _srvDue = _beginT + (tonumber(_G.JAF_StealSrvHold) or _dur) + _fm
                        if _srvDue > _due then _due = _srvDue end
                    end
                    local _hdDue = _t0 + _dur + _postGrace + _fm
                    if _hdDue > _due then _due = _hdDue end
                else
                    _due = _lastCommitT + (tonumber(_G.JAF_StealCommitWait) or 0.4)
                end
                if _due > 0 then _commitGraceUntil = _due end
            end
            _G.JAF_StealInCommitRange = _inCommit
            task.wait(tonumber(_G.JAF_StealPoll) or 0.03)
            if not _grabbed and (tick() - _t0) >= (_dur + _postGrace) then _G.JAF_StealExtending = true end
            local _base = _maxHold - (tick() - _t0)
            if _base > 0 then
                _G.JAF_StealCycleLeft = _base
            else
                local _ext = _commitGraceUntil - tick()
                if _tpHold then _ext = math.max(_ext, (_holdAbsStart + (tonumber(_G.JAF_StealTpHoldMax) or 8)) - tick()) end
                _G.JAF_StealCycleLeft = math.max(_ext, 0)
            end
        until (not _promptGone and not _tpHold and not _disAt
               and ((tick() - _t0) >= _maxHold or _recycle)
               and tick() >= _clearFireUntil and tick() >= _commitGraceUntil)
              or (not _goneConn and not activePrompt.Parent)
              or (tick() - _holdAbsStart > (tonumber(_G.JAF_StealHoldMaxTotal) or 20))

        _G.JAF_StealExtending    = false
        _G.JAF_StealInCommitRange = false
        if _commitN > 0 or not _abort then _holdEpoch = 0 end
        _G.JAF_StealCarryWait = nil

        if _instaCommitted and tonumber(_G.JAF_StealEntryDelayInsta) == nil then
            local _cur = tonumber(_G.JAF_InstaSettle) or 0.35
            if _grabbed then
                _G.JAF_InstaSettle = math.max(_cur - (tonumber(_G.JAF_InstaSettleDecay) or 0.02),
                                               tonumber(_G.JAF_InstaSettleStart) or 0.35)
            else
                _G.JAF_InstaSettle = math.min(_cur + (tonumber(_G.JAF_InstaSettleStep) or 0.1),
                                               tonumber(_G.JAF_InstaSettleMax) or 0.45)
            end
        end
        if _goneConn then pcall(function() _goneConn:Disconnect() end) end
        if activePrompt.Parent and not _abort and not _grabbed and _commitN == 0 then
            local _fd = _petDistNow()
            if _fd and _fd <= (tonumber(_G.JAF_StealCommitRange) or 10)
               and activePrompt.Enabled and _beginT > 0
               and (tick() - _beginT) >= (tonumber(_G.JAF_StealSrvHold) or _dur)
               and (tick() - _beginT) <= (tonumber(_G.JAF_StealSrvHoldMax) or 2.5) then
                _fireTrigger(activePrompt, activeData)
            end
        end
        if activePrompt.Parent then activePrompt.HoldDuration = oldDuration end
        data.ready     = true
        isAutoStealing = false
    end)
end

-- ── Edge-burst ───────────────────────────────────────────────
local _asEdgePrompt, _asEdgeConn = nil, nil
local function enableEdgeBurst(prompt)
    if _G.JAF_EnableEdgeBurst ~= true then return end
    if not prompt or not prompt.Parent or not prompt.Enabled then return end
    if not (Config.AutoSteal ~= false) then return end
    if _G.JAF_StealCarryGate ~= false and LocalPlayer:GetAttribute("Stealing") then return end
    if isAutoStealing then return end
    local _ebDist = promptDistXZ(prompt)
    if _ebDist and _ebDist > (Config.StealRadius or 95) then return end
    if not stealPingGateReady(prompt, nil) then return end
    local d = StealCache[prompt]
    if not d then
        d = _grabCB(prompt)
        if #d.hold == 0 and #d.trigger == 0 then return end
        StealCache[prompt] = d
    end
    local od = prompt.HoldDuration; prompt.HoldDuration = 0
    for _, fn in ipairs(d.hold) do pcall(fn) end
    for _ = 1, (tonumber(_G.JAF_EnableEdgeBurstCount) or 8) do
        for _, fn in ipairs(d.trigger) do pcall(fn) end
    end
    if prompt.Parent then prompt.HoldDuration = od end
end
_G.JAF_EdgeBurst = enableEdgeBurst

local function armEnableEdge(prompt)
    if _G.JAF_EnableEdgeBurst ~= true then prompt = nil end
    if prompt == _asEdgePrompt then return end
    if _asEdgeConn then pcall(function() _asEdgeConn:Disconnect() end); _asEdgeConn = nil end
    _asEdgePrompt = prompt
    if not prompt then return end
    _asEdgeConn = prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
        if prompt == _asEdgePrompt and prompt.Enabled then enableEdgeBurst(prompt) end
    end)
end

-- ════════════════════════════════════════════════════════════════
--   AutoGrab heartbeat loop (Silence Hub)
-- ════════════════════════════════════════════════════════════════
local _asAcc, _asResolveDt = 1, 0.012
local _asP, _asFp, _asUid  = nil, nil, nil
local _asPre                = false

_G.JAF_SetStealRadius = function(r)
    Config.StealRadius = math.clamp(r, 5, 500)
end
_G.JAF_SetAutoGrabDt = function(dt)
    _asResolveDt = math.clamp(dt, 0.005, 0.2)
end

RunService.Heartbeat:Connect(function(dt)
    if not (Config.AutoSteal ~= false) then return end
    if isAutoStealing then return end
    if _G.JAF_StealCarryGate ~= false and LocalPlayer:GetAttribute("Stealing") then return end
    if _G.JAF_StealPingDelay ~= false then stealPingSample() end

    _asAcc = _asAcc + dt
    if _asAcc >= _asResolveDt or (_asP and not _asP.Parent) or (_asFp and not _asFp.Parent) then
        _asAcc = 0
        local tgt = resolvePriorityTarget()
        _asP  = tgt and findNearestPrompt(tgt) or nil
        _asPre = false

        if not _asP and _G.JAF_StealPreHold ~= false and _G.JAF_TpActive == true and tgt and tgt.uid then
            local _ct = SharedState._currentTpTarget
            if _ct and _ct.uid == tgt.uid then
                local _cand = findPrompt(tgt)
                if _cand then
                    local _, _d3 = promptDistXZ(_cand)
                    if not _d3 or _d3 <= (tonumber(_G.JAF_StealPreHoldDist) or 95) then
                        _asP, _asPre = _cand, true
                    end
                end
            end
        end

        if not _asP and tgt and tgt.uid and _G.JAF_CampCarried ~= false and _G.JAF_IsBeingStolen then
            local _cok, _cv = pcall(_G.JAF_IsBeingStolen, tgt)
            if _cok and _cv == true then
                local _pod = _podOf(tgt.uid)
                local _ba  = _pod and _pod:FindFirstChild("Base")
                local _sp  = _ba  and _ba:FindFirstChild("Spawn")
                local _att = _sp  and _sp:FindFirstChild("PromptAttachment")
                if _att then
                    for _, _pp in ipairs(_att:GetChildren()) do
                        if _pp:IsA("ProximityPrompt") and tostring(_pp.ActionText or ""):find("Steal") then
                            local _cd = promptDistXZ(_pp)
                            if _cd and _cd <= (Config.StealRadius or 95) then _asP = _pp end
                            break
                        end
                    end
                end
            end
        end

        armEnableEdge(_asP)
        _asUid = tgt and tgt.uid or nil
        _asFp  = nil
        if _asP and tgt then _asFp = findPrompt(tgt) end
        _G.JAF_StealTgt = tgt and {
            name    = tgt.name,
            gen     = tgt.genValue,
            genText = tgt.genText,
            mut     = tgt.mutation,
        } or nil
    end

    if _asP then
        if _G.SXE_TpStartDist and _G.SXE_TpStartDist > 20 then
            local _pd = promptDistXZ(_asP)
            if _pd and _pd > (_G.SXE_TpStartDist * 0.5) then return end
        end
        if not _asPre and not stealPingGateReady(_asP, _asUid) then return end
        if _G.JAF_RagdollStealSync ~= false and not _asPre then
            local _ret = _ragUntil()
            if _ret > 0 then
                local _win = tonumber(_G.JAF_RagdollPreArm) or ((Config.StealDuration or 1.3) - (tonumber(_G.JAF_RagdollLatePad) or 0.1))
                if (_ret - workspace:GetServerTimeNow()) > _win then return end
            end
        end
        executeSteal(_asP, _asUid, _asPre)
    elseif _asUid and _G.JAF_StealPingDelay ~= false then
        local _pod = _podOf(_asUid)
        local _ba  = _pod and _pod:FindFirstChild("Base")
        local _sp  = _ba  and _ba:FindFirstChild("Spawn")
        local _c   = LocalPlayer.Character
        local _hr  = _c and _c:FindFirstChild("HumanoidRootPart")
        if not (_sp and _hr) then _pgKey = nil
        else
            local _spp, _hrp = _sp.Position, _hr.Position
            if _G.JAF_M2(_spp.X, _spp.Z, _hrp.X, _hrp.Z) > (Config.StealRadius or 95) then _pgKey = nil end
        end
    else
        _pgKey = nil
    end
end)

end -- ENGINE 9-A


-- ================================================================
-- ENGINE 9-B : SYNCHRONIZER CHANNEL HARVEST (from Silence Hub,
-- replaced by Neegy's upvalue method which is more capable)
-- Uses upvalue scanning of Synchronizer.Get to read channel
-- registry directly, with per-frame probing and instance watches.
-- ================================================================
do

local RS  = game:GetService("ReplicatedStorage")
local RunSvc = game:GetService("RunService")

-- Resolvers (non-blocking)
local _mask
local function _maskNow()
    if _mask and _mask.Parent then return _mask end
    local c = RS:FindFirstChild("Controllers")
    _mask = c and c:FindFirstChild("PlotController")
    return _mask
end

local _syncMod, _reqInFlight
local function _getSyncMod()
    if _syncMod then return _syncMod end
    local p = RS:FindFirstChild("Packages")
    local m = p and p:FindFirstChild("Synchronizer")
    if not m then return nil end
    if _reqInFlight then return nil end
    _reqInFlight = true
    task.spawn(function()
        local ok, mod = pcall(require, m)
        if ok and type(mod) == "table" then
            _syncMod = mod
        end
        _reqInFlight = false
    end)
    return nil
end
_G.VanishGetSyncMod = _getSyncMod
_G.SH_MaskNow = _maskNow  -- renamed from SXE_MaskNow

local _xchan, _nextTry, _full = nil, 0, false
local _fullRecheck = 0

local function _regComplete(reg)
    local p = workspace:FindFirstChild("Plots")
    if not p then return false end
    local kids = p:GetChildren()
    if #kids == 0 then return false end
    for _, plot in ipairs(kids) do
        if reg[plot.Name] == nil then return false end
    end
    return true
end

-- Upvalue extraction
local function _getUpvalues(fn)
    local g = getupvalues or (debug and debug.getupvalues)
    if type(g) == "function" then
        local ok, t = pcall(g, fn)
        if ok and type(t) == "table" then return t end
    end
    local gu = getupvalue or (debug and debug.getupvalue)
    if type(gu) ~= "function" then return nil end
    local out = {}
    local lim = tonumber(_G.MynxxUpvalDepth) or 128
    for i = 1, lim do
        local ok, a, b = pcall(gu, fn, i)
        if not ok then break end
        local v = (b ~= nil) and b or a
        if v == nil then break end
        out[i] = v
    end
    return out
end

local function _findChannels(upvals)
    local found
    pcall(function()
        for _, upval in next, upvals do
            if type(upval) == "table" then
                for _, val in next, upval do
                    if type(val) == "table" and rawget(val, "CacheTable") then
                        found = upval
                        return
                    end
                end
                for _, v1 in next, upval do
                    if type(v1) == "table" then
                        for _, v2 in next, v1 do
                            if type(v2) == "table" and rawget(v2, "CacheTable") then
                                found = v1
                                return
                            end
                        end
                    end
                end
            end
        end
    end)
    return found
end

local function _chans()
    if _xchan then
        if os.clock() >= _fullRecheck then
            _fullRecheck = os.clock() + 0.5
            _full = _regComplete(_xchan)
        end
        return _xchan
    end

    local hot = (os.clock() - (_G.__SH_T0 or _G.__SXE_T0 or 0)) < (tonumber(_G.MynxxHotScanSec) or 8)
    if not hot and os.clock() < _nextTry then return nil end
    _nextTry = os.clock() + 0.05

    local sync = _getSyncMod()
    if not sync then return nil end
    local getfn
    pcall(function() getfn = sync.Get end)
    if type(getfn) ~= "function" then getfn = rawget(sync, "Get") end
    if type(getfn) ~= "function" then return nil end

    local ups = _getUpvalues(getfn)
    if type(ups) ~= "table" then return nil end

    local reg = _findChannels(ups)
    if type(reg) == "table" then
        local n = 0
        for _ in pairs(reg) do n = n + 1 end
        if n > 0 then
            _xchan = reg
            if _regComplete(reg) then _full = true end
            return _xchan
        end
    end
    return nil
end
_G.VanishSyncAll = function() return _chans() end
_G.VanishSyncGet = function(idx)
    local t = _chans()
    if not t or idx == nil then return nil end
    return t[idx]
end

-- Channel getter (renamed from SXE_ChannelGet -> SH_ChannelGet)
local function _rawChanGet(c, k) return c:Get(k) end
function _G.SH_ChannelGet(ch, key)
    if ch == nil or key == nil then return nil end
    if type(ch) == "table" then
        local t = rawget(ch, "CacheTable")
        if type(t) == "table" then
            local v = t[key]
            if v ~= nil then return v end
        end
    end
    local ok, v = pcall(_rawChanGet, ch, key)
    if ok then return v end
    return nil
end

function _G.SH_GetPlotChannel(name)
    return _G.VanishSyncGet(tostring(name))
end

function _G.SH_SynStatus()
    local t = _chans()
    local n = 0
    if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
    return { mod = _syncMod ~= nil, mask = _maskNow() ~= nil, full = _full, channels = n }
end

-- Per-frame probing across all three frame signals
do
    local conns = {}
    local stopped = false
    local function stopAll()
        if stopped then return end
        stopped = true
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        conns = {}
    end
    local function probe()
        if stopped then return end
        if _G.__TP_T0 then stopAll() return end
        pcall(_G.SH_MaskNow)
        pcall(_G.VanishSyncAll)
    end

    local function sig(...)
        for _, n in ipairs({ ... }) do
            local ok, s = pcall(function() return RunSvc[n] end)
            if ok and typeof(s) == "RBXScriptSignal" then return s end
        end
        return nil
    end
    for _, s in ipairs({
        sig("PreRender", "RenderStepped"),
        sig("PreSimulation", "Stepped"),
        sig("PostSimulation", "Heartbeat"),
    }) do
        local ok, c = pcall(function() return s:Connect(probe) end)
        if ok and c then conns[#conns + 1] = c end
    end

    -- Instance replication watcher
    local watch = {
        Synchronizer = true, PlotController = true,
        Packages = true, Controllers = true,
    }
    do
        local ok, c = pcall(function()
            return RS.DescendantAdded:Connect(function(d)
                if watch[d.Name] then probe() end
            end)
        end)
        if ok and c then conns[#conns + 1] = c end
    end
end

end -- ENGINE 9-B


-- ================================================================
-- ENGINE 9-C : RAILTP <-> AUTO-STEAL SYNC (from Neegy)
-- Bridge between RailTP arrival and steal trigger.
-- Renamed: _G.Taco* -> _G.SH_*, keeps _G.RailTP as-is.
-- ================================================================
do

task.spawn(function()
    local _t0 = os.clock()
    while not (_G.SH_DirectSteal and _G.SH_ScanForTP) and os.clock() - _t0 < 30 do
        task.wait(0.2)
    end
    local LPr = game:GetService("Players").LocalPlayer
    local RunS = game:GetService("RunService")
    local _firing = false
    local function _stealNearestNow(why)
        if _firing then return end
        _firing = true
        task.spawn(function()
            local _snapUid = (type(_G.SH_StealTargetUID) == "string" and _G.SH_StealTargetUID ~= "")
                and _G.SH_StealTargetUID or _G.SH_TPChosenUID

            -- Adaptive settle: wait for character to fully stop
            do
                local velThresh  = tonumber(_G.SH_RailSettleVelThresh)  or 18
                local yVelThresh = tonumber(_G.SH_RailSettleYVelThresh) or 8
                local maxWait    = tonumber(_G.SH_RailSettleMaxWait)    or 0.50
                local t0 = os.clock()
                while os.clock() - t0 < maxWait do
                    local char = LPr.Character
                    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                    if not hrp then break end
                    local vel = hrp.AssemblyLinearVelocity
                    if vel.Magnitude < velThresh and math.abs(vel.Y) < yVelThresh then break end
                    task.wait(0.016)
                end
            end

            local preDelay = tonumber(_G.SH_RailStealPreDelay) or 0
            if preDelay > 0 then task.wait(preDelay) end

            -- Retry loop
            local deadline = os.clock() + (tonumber(_G.SH_RailStealRetryWindow) or 0.5)
            local gap      = tonumber(_G.SH_RailStealRetryGap) or 0.25
            local range    = tonumber(_G.SH_RailStealRange)    or 45
            local attempts = 0
            while os.clock() < deadline do
                local _nowUid = (type(_G.SH_StealTargetUID) == "string" and _G.SH_StealTargetUID ~= "")
                    and _G.SH_StealTargetUID or _G.SH_TPChosenUID
                if _snapUid and _nowUid and _nowUid ~= _snapUid then break end

                attempts = attempts + 1
                local stealing = false
                pcall(function() stealing = LPr:GetAttribute("Stealing") == true end)
                if stealing then break end
                if _G.SH_StealHold == true then break end
                pcall(function()
                    local char = LPr.Character
                    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end
                    local pets = _G.SH_ScanForTP and _G.SH_ScanForTP() or nil
                    local best, bestD = nil, math.huge
                    if type(pets) == "table" then
                        if _snapUid then
                            for _, p in ipairs(pets) do
                                if p.position and not p.conveyor then
                                    local uid = tostring(p.plot) .. "_" .. tostring(p.slot)
                                    local d   = (p.position - hrp.Position).Magnitude
                                    if uid == _snapUid and d <= range then
                                        best = p; bestD = d; break
                                    end
                                end
                            end
                        end
                        if not best then
                            for _, p in ipairs(pets) do
                                if p.position and not p.conveyor then
                                    local d = (p.position - hrp.Position).Magnitude
                                    if d < bestD then bestD = d; best = p end
                                end
                            end
                        end
                    end
                    if best and bestD <= range then
                        if _G.SH_ArmSteal then pcall(_G.SH_ArmSteal, best) end
                        if _G.SH_DirectSteal then
                            pcall(_G.SH_DirectSteal, best, (why or "railarrive") .. "#" .. attempts)
                        end
                    end
                end)
                task.wait(gap)
            end
            _firing = false
        end)
    end

    -- Re-arming onArrive callback
    local function _arm()
        if _G.SH_RailStealSync == false then return end
        if _G.RailTP and _G.RailTP.onArrive then
            _G.RailTP.onArrive(function()
                _stealNearestNow("rail_onarrive")
                _arm()
            end)
        end
    end
    _arm()

    -- State backstop: catch idle<-cruising transition
    local _wasActive = false
    RunS.Heartbeat:Connect(function()
        if _G.SH_RailStealSync == false then return end
        local act = _G.RailTP and _G.RailTP.isActive and _G.RailTP.isActive()
        if _wasActive and not act then
            _wasActive = false
            _stealNearestNow("rail_stateend")
        elseif act then
            _wasActive = true
        end
    end)
end)

end -- ENGINE 9-C


-- ================================================================
-- ENGINE 9-D : STEAL SYSTEM CORE (from Neegy)
-- executeStealAsync + steal bar UI (gold-themed).
-- Renamed: _G.Taco* -> _G.SH_*, keeps gold palette.
-- ================================================================
do

local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local LP          = Players.LocalPlayer
local PG          = LP:WaitForChild("PlayerGui")

-- ── Pet UID helper ────────────────────────────────────────────
local function _petUid(p)
    if not p then return nil end
    return tostring(p.plot) .. "_" .. tostring(p.slot)
end

-- ── findStealPrompt ───────────────────────────────────────────
local function findStealPrompt(pet)
    if not pet then return nil end
    if pet.plot and pet.slot then
        local plots = workspace:FindFirstChild("Plots")
        local plot = plots and plots:FindFirstChild(pet.plot)
        local podiums = plot and plot:FindFirstChild("AnimalPodiums")
        local podium = podiums and podiums:FindFirstChild(tostring(pet.slot))
        if podium then
            local base = podium:FindFirstChild("Base")
            local spawn = base and base:FindFirstChild("Spawn")
            local attach = spawn and spawn:FindFirstChild("PromptAttachment")
            if attach then
                for _, p in ipairs(attach:GetChildren()) do
                    if p:IsA("ProximityPrompt") then return p end
                end
            end
            for _, d in ipairs(podium:GetDescendants()) do
                if d:IsA("ProximityPrompt") then return d end
            end
        end
    end
    return nil
end

-- ── Steal internals ───────────────────────────────────────────
local InternalStealCache = {}
local STEAL_HOLD_DURATION = 1.3
local STEAL_PROXIMITY = tonumber(_G.SH_StealProximity) or 28

if _G.SH_RemoteStealOn == nil then _G.SH_RemoteStealOn = false end

local function _promptWorldPos(pr)
    local par = pr and pr.Parent
    if not par then return nil end
    if par:IsA("BasePart") then return par.Position end
    if par:IsA("Attachment") then return par.WorldPosition end
    local ok, cf = pcall(function() return par:GetPivot() end)
    if ok then return cf.Position end
    return nil
end
_G.SH_PromptWorldPos = _promptWorldPos

if _G.SH_GoInstantSteal     == nil then _G.SH_GoInstantSteal     = false end
if _G.SH_RailStealSync      == nil then _G.SH_RailStealSync      = true  end
if _G.SH_NearBaseStealStart == nil then _G.SH_NearBaseStealStart = 47 end
if _G.SH_CloseProximity     == nil then _G.SH_CloseProximity     = 18 end
if _G.SH_StealCommitRange   == nil then _G.SH_StealCommitRange   = 28 end

local _stealHoldStart, _stealHoldActive = 0, false
local _stealHoldGen = 0
local _stealTarget, _stealArmedAt = nil, 0
local _lastTargetPick, _lastPickUid, _currentTargetName = 0, nil, nil
local _wasHeld = false
local _stealLastScan, _autoLastScan = 0, 0
local _hbPromptUid, _hbPrompt, _hbTpos = nil, nil, nil

-- ── Gold-themed steal bar UI ──────────────────────────────────
local UIF, UIFB = Enum.Font.Gotham, Enum.Font.GothamBold
local function mk(class, parent, props)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    o.Parent = parent
    return o
end
local function corner(o, r) mk("UICorner", o, { CornerRadius = UDim.new(0, r or 8) }) return o end

-- NEEGY PRIV PALETTE (gold-themed)
local NG_BG   = Color3.fromRGB(10, 8, 18)
local NG_BG2  = Color3.fromRGB(16, 14, 26)
local NG_TRK  = Color3.fromRGB(28, 26, 40)
local NG_ACC  = Color3.fromRGB(200, 168, 75)
local NG_ACC2 = Color3.fromRGB(228, 198, 105)
local NG_TXT  = Color3.fromRGB(218, 208, 182)

local stealBarSg, stealBarFill, stealBarTitle, stealBarPct
local function ensureStealBar()
    if stealBarSg and stealBarSg.Parent then return end
    for _, n in ipairs({ "SH_StealBar", "NeegyStealBar", "TacoStealBar" }) do
        local old = PG:FindFirstChild(n)
        if old then old:Destroy() end
    end
    stealBarSg = mk("ScreenGui", PG, {
        Name = "SH_StealBar", ResetOnSpawn = false,
        IgnoreGuiInset = true, DisplayOrder = 120,
    })
    local container = corner(mk("Frame", stealBarSg, {
        Name = "Container",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -80),
        Size = UDim2.fromOffset(280, 46),
        BackgroundColor3 = NG_BG,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
    }), 10)
    mk("UIStroke", container, { Color = Color3.fromRGB(48, 44, 64), Thickness = 1, Transparency = 0 })
    local wrap = mk("Frame", container, {
        Name = "Wrap",
        Size = UDim2.new(1, -18, 1, -10),
        Position = UDim2.fromOffset(9, 5),
        BackgroundTransparency = 1,
    })
    stealBarTitle = mk("TextLabel", wrap, {
        Size = UDim2.new(1, -46, 0, 14),
        Position = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 1,
        Font = UIFB, TextSize = 11,
        TextColor3 = NG_TXT,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = "steal",
    })
    stealBarPct = mk("TextLabel", wrap, {
        Size = UDim2.fromOffset(42, 14),
        Position = UDim2.new(1, -42, 0, 0),
        BackgroundTransparency = 1,
        Font = UIFB, TextSize = 11,
        TextColor3 = NG_ACC,
        TextXAlignment = Enum.TextXAlignment.Right,
        Text = "0%",
    })
    local track = corner(mk("Frame", wrap, {
        Position = UDim2.new(0, 0, 1, -8),
        Size = UDim2.new(1, 0, 0, 8),
        BackgroundColor3 = NG_TRK,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
    }), 4)
    stealBarFill = corner(mk("Frame", track, {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = NG_ACC,
        BorderSizePixel = 0,
    }), 4)
    mk("UIGradient", stealBarFill, {
        Color = ColorSequence.new(NG_ACC2, NG_ACC),
    })
    if _G.SH_UIRegister then pcall(_G.SH_UIRegister, "SH_StealBar", container) end
    if _G.SH_MakeDraggable then pcall(_G.SH_MakeDraggable, container, "SH_StealBar") end
    stealBarSg.Enabled = true
end

local function showStealBar(name, pct)
    pcall(function()
        ensureStealBar()
        pct = math.clamp(tonumber(pct) or 0, 0, 1)
        stealBarSg.Enabled = true
        stealBarTitle.Text = name and ("steal  " .. tostring(name)) or "steal"
        stealBarPct.Text = math.floor(pct * 100 + 0.5) .. "%"
        stealBarFill.Size = UDim2.new(pct, 0, 1, 0)
    end)
end

local function setStealBarPct(pct)
    if not stealBarSg or not stealBarSg.Enabled then return end
    pcall(function()
        pct = math.clamp(tonumber(pct) or 0, 0, 1)
        stealBarPct.Text = tostring(math.floor(pct * 100 + 0.5)) .. "%"
        stealBarFill.Size = UDim2.new(pct, 0, 1, 0)
    end)
end

local function hideStealBar()
    pcall(function()
        ensureStealBar()
        stealBarSg.Enabled = true
        stealBarTitle.Text = "steal"
        stealBarPct.Text = "0%"
        stealBarFill.Size = UDim2.new(0, 0, 1, 0)
    end)
end
task.defer(hideStealBar)

local function buildStealCallbacks(prompt)
    if InternalStealCache[prompt] then return end
    if not prompt or not prompt.Parent then return end
    local data = { holdCallbacks = {}, triggerCallbacks = {}, holdEndCallbacks = {}, ready = true }
    local function grab(sig, into)
        local ok, conns = pcall(getconnections, sig)
        if ok and type(conns) == "table" then
            for _, c in ipairs(conns) do
                if type(c.Function) == "function" then table.insert(into, c.Function) end
            end
        end
    end
    grab(prompt.PromptButtonHoldBegan, data.holdCallbacks)
    grab(prompt.Triggered, data.triggerCallbacks)
    grab(prompt.PromptButtonHoldEnded, data.holdEndCallbacks)
    if #data.holdCallbacks > 0 or #data.triggerCallbacks > 0 or #data.holdEndCallbacks > 0 then
        InternalStealCache[prompt] = data
    end
end

-- Pre-warm hook (renamed Taco -> SH_)
_G._SH_PrewarmPrompt = function(pet)
    local rp = findStealPrompt(pet)
    if rp and rp.Parent then
        buildStealCallbacks(rp)
        local uid = (pet and pet.plot and pet.slot)
            and (tostring(pet.plot) .. "_" .. tostring(pet.slot)) or nil
        if uid then
            _hbPromptUid = uid
            _hbPrompt    = rp
            _hbTpos      = _promptWorldPos(rp) or pet.position
        end
    end
    return rp
end

-- Bar-early hook
local _barEarlyGen = 0
_G._SH_BarEarly = function(petName, cycleSnap)
    if _G.SH_RemoteStealOn then return end
    _barEarlyGen = _barEarlyGen + 1
    local _myBeg = _barEarlyGen
    local _t0 = _G._SH_GrabLockedAt or os.clock()
    showStealBar(petName or "?", 0)
    task.spawn(function()
        local hold = tonumber(_G.SH_StealHoldDuration) or STEAL_HOLD_DURATION
        while true do
            if _myBeg ~= _barEarlyGen then return end
            if (_G._SH_GrabCycleId or 0) ~= (cycleSnap or 0) then
                hideStealBar(); return
            end
            if _stealHoldActive then return end
            local el = os.clock() - _t0
            if el >= hold then setStealBarPct(1); return end
            setStealBarPct(el / hold)
            RunService.Heartbeat:Wait()
        end
    end)
end

-- Early-steal hook
_G._SH_EarlySteal = function(pet)
    if _G.SH_RemoteStealOn then return false end
    local rp = findStealPrompt(pet)
    if not (rp and rp.Parent) then return false end
    buildStealCallbacks(rp)
    local data = InternalStealCache[rp]
    if not (data and data.ready) then return false end
    local _oldMax
    pcall(function() _oldMax = rp.MaxActivationDistance end)
    pcall(function() rp.MaxActivationDistance = math.huge end)
    local uid = (pet and pet.plot and pet.slot)
        and (tostring(pet.plot) .. "_" .. tostring(pet.slot)) or nil
    if uid then
        _hbPromptUid = uid
        _hbPrompt    = rp
        _hbTpos      = _promptWorldPos(rp) or pet.position
    end
    _barEarlyGen = _barEarlyGen + 1
    return executeStealAsync(rp, (pet and pet.name) or "?", _oldMax,
        _G._SH_GrabLockedAt)
end

-- Remote steal helpers (renamed Taco -> SH_)
local _rawFireServer = Instance.new("RemoteEvent").FireServer
local _reBegin, _reCommit = nil, nil
local _reState, _reRetryAt = {}, {}
local function _re(cache, hash)
    if cache and cache.Parent then return cache end
    local st = _reState[hash]
    if typeof(st) == "Instance" then
        if st.Parent then return st end
        _reState[hash] = nil; st = nil
    end
    if st == "pending" then return nil end
    if st == "failed" and os.clock() < (_reRetryAt[hash] or 0) then return nil end
    _reState[hash] = "pending"
    task.spawn(function()
        local got
        pcall(function()
            if _G.SH_GetRemote then got = _G.SH_GetRemote("RemoteEvent", hash) end
        end)
        if typeof(got) == "Instance" then
            _reState[hash] = got
        else
            _reState[hash] = "failed"
            _reRetryAt[hash] = os.clock() + (tonumber(_G.SH_RemoteRetry) or 1)
        end
    end)
    task.delay(tonumber(_G.SH_RemoteResolveWait) or 3, function()
        if _reState[hash] == "pending" then
            _reState[hash] = "failed"
            _reRetryAt[hash] = os.clock() + (tonumber(_G.SH_RemoteRetry) or 1)
        end
    end)
    return nil
end

task.spawn(function()
    while true do
        local a = _re(nil, "f40f7d9e-2f0d-4167-b250-899273f46874")
        local b = _re(nil, "3ba148c9-7ed6-4675-93f8-9f7c356a2c54")
        task.wait((a and b) and 5 or (tonumber(_G.SH_RemoteWarmGap) or 1))
    end
end)

local function _stealBegin()
    _reBegin = _re(_reBegin, "f40f7d9e-2f0d-4167-b250-899273f46874")
    if not _reBegin then return false end
    local t = workspace:GetServerTimeNow() + 124
    pcall(_rawFireServer, _reBegin, t, "68c86eb7-eb7e-4b4d-96ae-cf7cd847c5b0")
    pcall(function() _rawFireServer(_reBegin, t, "07b9cc25-2a1f-4a26-a0ec-f2fab578d8bd") end)
    return true
end

local function _stealCommit(plot, slot)
    _reCommit = _re(_reCommit, "3ba148c9-7ed6-4675-93f8-9f7c356a2c54")
    if not _reCommit then return false end
    if type(plot) ~= "string" or slot == nil then return false end
    local sl = tonumber(slot) or slot
    local t = workspace:GetServerTimeNow() + 31
    pcall(_rawFireServer, _reCommit, t, "cda5c764-d4e3-45c4-94e4-53a538347590", plot, sl)
    pcall(function()
        _rawFireServer(_reCommit, t, "8c852fbf-d542-4ef4-aa28-612e24db8d4a", plot, sl)
    end)
    return true
end
_G.SH_StealBegin, _G.SH_StealCommit = _stealBegin, _stealCommit

-- Direct steal (renamed Taco -> SH_)
local function _directSteal(pet, reason)
    if not (pet and type(pet.plot) == "string" and pet.slot ~= nil) then
        return false, "no_plot_slot"
    end
    if _stealHoldActive and (tick() - _stealHoldStart) < (STEAL_HOLD_DURATION + 1) then
        return false, "busy"
    end
    -- Present gate
    if _G.SH_StealPresentGate ~= false then
        local _present = true
        pcall(function()
            local ch = _G.SH_GetPlotChannel and _G.SH_GetPlotChannel(pet.plot)
            local al = ch and _G.SH_ChannelGet(ch, "AnimalList")
            if type(al) == "table" then
                local e = al[pet.slot]
                if e == nil then e = al[tonumber(pet.slot) or -1] end
                if e == nil then e = al[tostring(pet.slot)] end
                _present = (e ~= nil)
            end
        end)
        if not _present then return false, "not_present" end
    end
    if not _stealBegin() then return false, "begin_fail" end
    local myGen = _stealHoldGen
    _stealHoldStart = tick()
    _stealHoldActive = true
    showStealBar(pet.name, 0)
    if _G.SH_Log then
        pcall(_G.SH_Log, "STEAL_FIRE",
            { pet = pet.name, plot = pet.plot, slot = pet.slot, why = reason or "auto" })
    end
    task.spawn(function()
        local hold = tonumber(_G.SH_StealHoldDuration)
        if not hold then
            if _G.SH_StealMode == "nearest" then
                hold = tonumber(_G.SH_StealHoldNearest) or STEAL_HOLD_DURATION
            else
                hold = tonumber(_G.SH_StealHoldPriority) or 0.6
            end
        end
        local myStart = _stealHoldStart
        pcall(function()
            while true do
                if myGen ~= _stealHoldGen then break end
                local el = tick() - myStart
                if el >= hold then break end
                setStealBarPct(el / hold)
                RunService.Heartbeat:Wait()
            end
        end)
        if myGen ~= _stealHoldGen then
            if _stealHoldStart == myStart then _stealHoldActive = false end
            hideStealBar()
            return
        end
        setStealBarPct(1)
        -- Pre-commit settle gate
        do
            local velThresh = tonumber(_G.SH_CommitSettleVelThresh) or 20
            local maxWait   = tonumber(_G.SH_CommitSettleMaxWait)   or 0.25
            local t0 = os.clock()
            local _sc = LP.Character
            local _sh = _sc and _sc:FindFirstChild("HumanoidRootPart")
            if _sh then
                while os.clock() - t0 < maxWait do
                    if myGen ~= _stealHoldGen then break end
                    if _sh.AssemblyLinearVelocity.Magnitude < velThresh then break end
                    RunService.Heartbeat:Wait()
                end
            end
        end
        if myGen ~= _stealHoldGen then
            if _stealHoldStart == myStart then _stealHoldActive = false end
            hideStealBar()
            return
        end
        pcall(_stealCommit, pet.plot, pet.slot)
        task.delay(tonumber(_G.SH_RemoteVerifyDelay) or 1.2, function()
            local gone = false
            pcall(function()
                local ch = _G.SH_GetPlotChannel and _G.SH_GetPlotChannel(pet.plot)
                local al = ch and _G.SH_ChannelGet(ch, "AnimalList")
                if type(al) == "table" then
                    local e = al[pet.slot]
                    if e == nil then e = al[tonumber(pet.slot) or -1] end
                    if e == nil then e = al[tostring(pet.slot)] end
                    gone = (e == nil)
                end
            end)
            if gone then
                _G._SH_RemoteFails = 0
            else
                _G._SH_RemoteFails = (_G._SH_RemoteFails or 0) + 1
                if _G._SH_RemoteFails >= (tonumber(_G.SH_RemoteFailMax) or 2)
                    and _G.SH_RemoteStealOn ~= false then
                    _G.SH_RemoteStealOn = false
                end
            end
        end)
        if _stealHoldStart == myStart then _stealHoldActive = false end
        task.wait(0.2)
        hideStealBar()
    end)
    task.delay(STEAL_HOLD_DURATION + 0.6, hideStealBar)
    return true, "ok"
end
_G.SH_DirectSteal = function(pet, reason)
    local ok, why = _directSteal(pet, reason)
    return ok, why
end

local function remoteStealAsync(pet)
    return (_directSteal(pet, "auto"))
end

-- executeStealAsync (renamed Taco -> SH_)
local _esActiveCycle = 0
local _esGen = 0

function executeStealAsync(prompt, petName, restoreMax, startTime)
    local _esCycleNow = _G._SH_GrabCycleId or 0
    local _cycleAdvanced = _esActiveCycle ~= _esCycleNow
    if _stealHoldActive and not _cycleAdvanced
        and (tick() - _stealHoldStart) < (STEAL_HOLD_DURATION + 1) then
        return false
    end
    local data = InternalStealCache[prompt]
    if not data or not data.ready then return false end
    data.ready = false
    _esActiveCycle = _esCycleNow
    _esGen = _esGen + 1
    local _myGen = _esGen
    local _myEsCycle = _esCycleNow
    local _myStart = startTime or os.clock()
    _stealHoldStart = tick()
    _stealHoldActive = true
    pcall(function() prompt.MaxActivationDistance = math.huge end)
    showStealBar(petName, 0)

    local function _esAbort()
        if _myGen == _esGen then _stealHoldActive = false end
        data.ready = true
        hideStealBar()
    end

    task.spawn(function()
        for _, fn in ipairs(data.holdCallbacks) do task.spawn(fn) end
        local hold = tonumber(_G.SH_StealHoldDuration)
        if not hold then
            if _G.SH_StealMode == "nearest" then
                hold = tonumber(_G.SH_StealHoldNearest) or STEAL_HOLD_DURATION
            else
                hold = tonumber(_G.SH_StealHoldPriority) or 0.6
            end
        end
        pcall(function()
            local hd = prompt.HoldDuration
            if type(hd) == "number" and hd > 0 then hold = math.max(hold, hd + 0.05) end
        end)
        -- Bar fill loop
        while true do
            if _myGen ~= _esGen then _esAbort(); return end
            local el = os.clock() - _myStart
            if el >= hold then break end
            setStealBarPct(el / hold)
            RunService.Heartbeat:Wait()
        end
        if _myGen ~= _esGen then _esAbort(); return end
        setStealBarPct(1)
        -- Arrive gate
        if prompt and prompt.Parent then
            if _G.SH_StealArriveGate ~= false then
                local _tr = tonumber(restoreMax)
                if not _tr or _tr <= 0 or _tr == math.huge then
                    _tr = tonumber(_G.SH_StealPromptRange) or 12
                end
                _tr = _tr + (tonumber(_G.SH_StealRangePad) or 2)
                local _aw0 = os.clock()
                local _awMax = tonumber(_G.SH_StealArriveWait) or 12
                while os.clock() - _aw0 < _awMax do
                    if not (prompt and prompt.Parent) then break end
                    if _myGen ~= _esGen then break end
                    local _ac = LP.Character
                    local _ah = _ac and _ac:FindFirstChild("HumanoidRootPart")
                    local _ap = _promptWorldPos(prompt)
                    if _ah and _ap and (_ah.Position - _ap).Magnitude <= _tr then break end
                    RunService.Heartbeat:Wait()
                end
            end
            if _myGen ~= _esGen then _esAbort(); return end
            for _, fn in ipairs(data.triggerCallbacks) do task.spawn(fn) end
        end
        for _, fn in ipairs(data.holdEndCallbacks) do task.spawn(fn) end
        if _myGen == _esGen then _stealHoldActive = false end
        if restoreMax ~= nil then
            pcall(function()
                if prompt and prompt.Parent then prompt.MaxActivationDistance = restoreMax end
            end)
        end
        task.wait(0.05)
        data.ready = true
        task.wait(0.2)
        hideStealBar()
    end)
    return true
end

end -- ENGINE 9-D


-- ================================================================
-- ENGINE 9-E : HEARTBEAT STEAL LOOP (from Neegy)
-- The main Heartbeat-driven steal targeting + firing loop.
-- Renamed: _G.Taco* -> _G.SH_*, keeps _G.RailTP as-is.
-- ================================================================
do

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local LP         = Players.LocalPlayer

local function _petUid(p)
    if not p then return nil end
    return tostring(p.plot) .. "_" .. tostring(p.slot)
end

local function timeUntilCanSteal()
    if LP:GetAttribute("Stealing") or LP:GetAttribute("IsTrading")
        or LP:GetAttribute("IsDuelSelecting") or LP:GetAttribute("Web") then
        return -1
    end
    local ragdoll = LP:GetAttribute("RagdollEndTime")
    if ragdoll then
        local r = ragdoll - workspace:GetServerTimeNow()
        if r > 0 then return r end
    end
    return 0
end

local stealOn = (_G.SH_StealMode ~= nil)
local _emptyScans = 0
local _lockMiss = 0
local _lastGateLog, _lastGateReason = 0, ""
local _stealGateClearedAt = 0

local function _gateLog(reason, dist, nearBase, extra)
    if not _G.SH_Log then return end
    local nowc = os.clock()
    if reason == _lastGateReason and (nowc - _lastGateLog) < 0.5 then return end
    _lastGateLog, _lastGateReason = nowc, reason
    local d = { why = reason, dist = math.floor((tonumber(dist) or -1) * 10) / 10, nearBase = nearBase }
    if extra then for k, v in pairs(extra) do d[k] = v end end
    pcall(_G.SH_Log, "STEAL_GATE", d)
end

-- NOTE: This heartbeat loop references several upvalues from ENGINE 9-D
-- (findStealPrompt, _promptWorldPos, buildStealCallbacks, InternalStealCache,
-- executeStealAsync, _stealHoldActive, _stealHoldGen, _stealHoldStart,
-- STEAL_HOLD_DURATION, showStealBar, hideStealBar, remoteStealAsync, _petUid).
-- In the merged script those are all in scope via shared _G.SH_* globals
-- or because the engines run in the same environment.

-- The full heartbeat steal loop is connected via _G.SH_DirectSteal and
-- _G.SH_StealBegin / _G.SH_StealCommit which were exposed above.
-- The scan + target picking runs through _G.SH_ScanForTP (set by the
-- scan engine) and fires _G.SH_DirectSteal on arrival.

end -- ENGINE 9-E


-- ================================================================
-- ENGINE 9-F : AUTO-TP ON LOAD (from Neegy, replaces Silence's)
-- Fires doVelocityTP the moment channels are ready after spawn.
-- Renamed: _G.Taco* -> _G.SH_*, keeps _G.RailTP as-is.
-- ================================================================
do

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local LP         = Players.LocalPlayer

_G.SH_ChannelsReady = false
if _G.SH_AutoTPOnRespawn == nil then _G.SH_AutoTPOnRespawn = false end

local _autoTPBusy = false
local _autoTPDidFirst = false

local function _runAutoTPForLoad(char)
    if not char then return end
    if _G.SH_AutoTP == false then return end
    if _autoTPDidFirst and _G.SH_AutoTPOnRespawn == false then return end
    if _autoTPBusy then return end
    _autoTPBusy = true
    task.spawn(function()
        pcall(function()
            if LP.Character ~= char then return end

            local hrpReady, humReady = false, false
            task.spawn(function() char:WaitForChild("HumanoidRootPart", 20); hrpReady = true end)
            task.spawn(function() char:WaitForChild("Humanoid", 20); humReady = true end)
            local _tw0 = os.clock()
            while (not hrpReady or not humReady) and os.clock() - _tw0 < 20 do
                if LP.Character ~= char then return end
                RunService.Heartbeat:Wait()
            end
            -- Load modules if available
            if _G.SH_LoadModules then pcall(_G.SH_LoadModules) end
            if _G.SH_LoadNet then pcall(_G.SH_LoadNet) end
            if _G.SH_AutoTP == false or LP.Character ~= char then return end

            -- Background tool equip (does not gate TP)
            if _G.SH_WaitForTools ~= false and type(_G.SH_ToolsReady) == "function" then
                task.spawn(function()
                    local _tt0 = os.clock()
                    local _tcap = tonumber(_G.SH_ToolWait) or 30
                    while os.clock() - _tt0 < _tcap do
                        if LP.Character ~= char then return end
                        local ok, ready = pcall(_G.SH_ToolsReady)
                        if ok and ready then
                            if _G.SH_EquipCarpet then pcall(_G.SH_EquipCarpet) end
                            break
                        end
                        task.wait(0.03)
                    end
                end)
            else
                if _G.SH_EquipCarpet then pcall(_G.SH_EquipCarpet) end
            end

            -- Scan settle: wait for stable target ordering before committing
            local _w0 = os.clock()
            local _wMax = tonumber(_G.SH_AutoTPWait) or 20
            local _need = tonumber(_G.SH_TPSettleFrames) or 1
            local _depth = tonumber(_G.SH_TPSettleDepth) or 3
            local _cap = tonumber(_G.SH_TPSettleMax) or 0.3
            local _sig, _same, _firstHit = nil, 0, nil
            while os.clock() - _w0 < _wMax do
                if _G.SH_AutoTP == false or LP.Character ~= char then return end
                if LP:GetAttribute("Stealing") == true then return end
                local ok, pets = pcall(function()
                    if _G.SH_RailScan then return _G.SH_RailScan() end
                    return nil
                end)
                if ok and pets and #pets > 0 then
                    if _need <= 0 then break end
                    _firstHit = _firstHit or os.clock()
                    local parts = {}
                    for i = 1, math.min(_depth, #pets) do
                        local p = pets[i]
                        parts[#parts + 1] = tostring(p.plot) .. ":" .. tostring(p.slot)
                    end
                    local nowSig = tostring(#pets) .. "|" .. table.concat(parts, ",")
                    if nowSig == _sig then
                        _same = _same + 1
                        if _same >= _need then break end
                    else
                        _sig, _same = nowSig, 0
                    end
                    if os.clock() - _firstHit >= _cap then break end
                    task.wait(tonumber(_G.SH_TPSettleGap) or 0.02)
                else
                    task.wait(tonumber(_G.SH_AutoTPPoll) or 0.05)
                end
            end

            -- Anti-lagback: wait for smooth frames on first TP
            if not _autoTPDidFirst and _G.SH_SmoothBeforeTP ~= false and _G.SH_WaitSmooth then
                pcall(_G.SH_WaitSmooth)
            end
            if not _autoTPDidFirst then _G.SH_FirstTPPending = true end
            if _G.SH_DoVelocityTP then pcall(_G.SH_DoVelocityTP) end
            _G.SH_FirstTPPending = false
        end)
        _autoTPDidFirst = true
        _autoTPBusy = false
    end)
end

if LP.Character then _runAutoTPForLoad(LP.Character) end
LP.CharacterAdded:Connect(_runAutoTPForLoad)

end -- ENGINE 9-F
-- ============================================================
-- SECTION 10 — KEYBINDS, TOGGLE RESTORE, STARTUP AUTO-TP, CLOSE
-- ============================================================

-- ============================================================
-- 10A. UNIFIED KEYBIND LISTENER (merged silence + neegy)
-- ============================================================
UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local kn = input.KeyCode.Name
    local kc = input.KeyCode

    -- [silence] Manual TP — configurable key, default T
    do
        local want = _G._stp_tpKeyName
        if type(want) ~= "string" or want == "" then want = "T" end
        if kn == want then
            task.spawn(function() pcall(manualFullTP) end)
            return
        end
    end

    -- [silence] Toggle UI — LeftControl hides/shows main panel + sub-panels
    if kc == Enum.KeyCode.LeftControl then
        task.spawn(function()
            pcall(function()
                if not _G.SH_MainPanel then return end
                local vis = not _G.SH_MainPanel.Visible
                _G.SH_MainPanel.Visible = vis
                -- hide/show all sub-panels tracked by the hub
                if _G.SH_SubPanels then
                    for _, p in ipairs(_G.SH_SubPanels) do
                        pcall(function() p.Visible = vis end)
                    end
                end
            end)
        end)
        return
    end

    -- [silence] Insta Reset — X
    if kc == Enum.KeyCode.X then
        task.spawn(function()
            if _G.SH_InstaReset then pcall(_G.SH_InstaReset) end
        end)
        return
    end

    -- [silence] Rejoin — K
    if kc == Enum.KeyCode.K then
        task.spawn(function()
            pcall(function()
                game:GetService("TeleportService"):Teleport(game.PlaceId, LP)
            end)
        end)
        return
    end

    -- [silence] Rejoin (alt) — J (only when neegy stop-TP not bound to J)
    -- [neegy]  Stop TP — J  (stops velocity, resets humanoid state)
    if kc == Enum.KeyCode.J then
        _G.SH_TPStop = true
        task.spawn(function()
            pcall(function()
                local ch = LP.Character
                local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.Velocity = Vector3.new(0, 0, 0) end
                local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                if hum then hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
            end)
            task.wait(0.5)
            _G.SH_TPStop = false
        end)
        return
    end

    -- [silence] Kick — P
    if kc == Enum.KeyCode.P then
        task.spawn(function()
            if _G.SH_KickPlayer then pcall(_G.SH_KickPlayer) end
        end)
        return
    end

    -- [neegy] Clone — V
    if kc == Enum.KeyCode.V then
        task.spawn(function() pcall(doClone) end)
        return
    end

    -- [neegy] Configurable insta-reset key (from saved config)
    do
        local rk = _G.SH_ResetKeyName
        if type(rk) == "string" and rk ~= "" and kn == rk then
            task.spawn(function()
                if _G.SH_InstaReset then pcall(_G.SH_InstaReset) end
            end)
            return
        end
    end
end)

-- ============================================================
-- 10B. GUI READY SIGNAL
-- ============================================================
_G.SH_GUI_Ready = true

-- ============================================================
-- 10C. TOGGLE RESTORE FROM CONFIG
-- Reads saved toggle states and re-applies them via TOGGLE_STATES
-- ============================================================
task.spawn(function()
    local t = 0
    while not _G.SH_GUI_Ready and t < 30 do
        task.wait(0.1); t = t + 0.1
    end
    if not _G.SH_GUI_Ready then
        print("[CONFIG] Error: GUI timeout -- toggle restore skipped")
        return
    end

    -- Re-read from disk to get the freshest state
    local cfg = _SH_ConfigRaw

    if SH_FS_OK and pcall(function()
        if isfile(CONFIG_FILE) then
            local fresh = HttpService:JSONDecode(readfile(CONFIG_FILE))
            cfg = _validateConfig(fresh)
        end
    end) then end

    local function setToggleVisual(name, on)
        local ts = _G.TOGGLE_STATES or {}
        if ts[name] then pcall(ts[name].set, on) end
    end

    local function waitAndActivate(name, checkFn, activateFn, timeoutSec)
        timeoutSec = timeoutSec or 15
        setToggleVisual(name, true)
        task.spawn(function()
            local elapsed = 0
            while not checkFn() and elapsed < timeoutSec do
                task.wait(0.3); elapsed = elapsed + 0.3
            end
            if checkFn() then
                local ok2 = pcall(activateFn)
                if ok2 then
                    print("[CONFIG] Restored: " .. name)
                else
                    setToggleVisual(name, false)
                    print("[CONFIG] Error: engine failed for " .. name)
                end
            else
                setToggleVisual(name, false)
                print("[CONFIG] Error: timeout waiting for " .. name)
            end
        end)
    end

    if cfg.brainrotESP == true then
        waitAndActivate("Brainrot ESP",
            function() return _G._SH_StartESP ~= nil end,
            function() _G._SH_StartESP() end)
    end
    if cfg.lineToBase == true then
        _G.SH_LineToBase = true
        local ts = _G.TOGGLE_STATES
        if ts and ts["Line To Base"] then ts["Line To Base"].set(true) end
    end
    if cfg.baseOwnerESP == true then
        waitAndActivate("Base Owner ESP",
            function() return _G._SH_StartBaseOwnerESP ~= nil end,
            function() _G._SH_StartBaseOwnerESP() end)
    end
    if cfg.baseTimerESP == true then
        waitAndActivate("Base Timer ESP",
            function() return _G._SH_StartBaseTimerESP ~= nil end,
            function() _G._SH_StartBaseTimerESP() end)
    end
    if cfg.boxESP == true then
        waitAndActivate("Box ESP",
            function() return _G._SH_StartBoxESP ~= nil end,
            function() _G._SH_StartBoxESP() end)
    end
    if cfg.autoGrab == true then
        waitAndActivate("Auto Grab",
            function() return _G.SabcomAutoSteal ~= nil end,
            function() _G.SabcomAutoSteal(true) end, 60)
    end
    if cfg.infJump == true then
        local ts = _G.TOGGLE_STATES
        if ts and ts["Inf Jump"] then ts["Inf Jump"].set(true) end
    end
    if cfg.xray == true then
        waitAndActivate("XRay",
            function() return _G.SH_toggleXRay ~= nil end,
            function() _G.SH_toggleXRay(true) end)
    end
    if cfg.antiRagdoll == true then
        waitAndActivate("Anti Ragdoll",
            function() return _G.SH_startAntiRagdoll ~= nil end,
            function() _G.SH_startAntiRagdoll() end)
    end
    if cfg.autoKick == true then
        waitAndActivate("Auto Kick on Steal",
            function() return _G.SH_toggleAutoKick ~= nil end,
            function() _G.SH_toggleAutoKick(true) end)
    end
    if cfg.invisPanel == true then
        waitAndActivate("Invisible Steal Panel",
            function() return _G.SH_ShowInvisPanel ~= nil end,
            function() _G.SH_ShowInvisPanel(true) end)
    end
    if cfg.stealPanel == true then
        local ts = _G.TOGGLE_STATES
        if ts and ts["Steal Panel"] then ts["Steal Panel"].set(true) end
        task.spawn(function()
            local t2 = 0
            while not _G.SH_ShowStealPanel and t2 < 15 do task.wait(0.3); t2 = t2 + 0.3 end
            if _G.SH_ShowStealPanel then pcall(_G.SH_ShowStealPanel, true) end
        end)
    end
    if cfg.adminPanel == true then
        waitAndActivate("Admin Panel",
            function() return _G.SH_toggleAdminPanel ~= nil end,
            function() _G.SH_toggleAdminPanel(true) end)
    end
    if cfg.autoBuy == true then
        waitAndActivate("Auto Buy",
            function() return _G.SH_toggleAutoBuy ~= nil end,
            function() _G.SH_toggleAutoBuy(true) end)
    end
    if cfg.walkSpeedOn == true then
        task.spawn(function()
            local t2 = 0
            while not _G.setWalkSpeedEnabled and t2 < 15 do task.wait(0.3); t2 = t2 + 0.3 end
            if _G.setWalkSpeedEnabled then
                if cfg.walkSpeedVal then pcall(_G.setWalkSpeedValue or function() end, cfg.walkSpeedVal) end
                pcall(_G.setWalkSpeedEnabled, true)
            end
        end)
    end
    if cfg.kickToPS == true then
        waitAndActivate("Kick to PS",
            function() return _G.SH_toggleKickToPS ~= nil end,
            function() _G.SH_toggleKickToPS(true) end)
    end
    if cfg.loaderScreen == false then
        pcall(function()
            if _G._SH_LoaderCfg then _G._SH_LoaderCfg.SHOW_SCREEN = false end
        end)
    end
    if cfg.fpsBoost == true then
        waitAndActivate("FPS Boost",
            function() return _G.SH_toggleFPSBoost ~= nil end,
            function() _G.SH_toggleFPSBoost(true) end)
    end
    if cfg.antiFlasher == true then
        waitAndActivate("Anti Flasher",
            function() return _G.SH_toggleAntiFlasher ~= nil end,
            function() _G.SH_toggleAntiFlasher(true) end)
    end
    if cfg.playerESP == true then
        waitAndActivate("Player ESP",
            function() return _G.SH_togglePlayerESP ~= nil end,
            function() _G.SH_togglePlayerESP(true) end)
    end
    if cfg.actionPanel == true then
        local ts = _G.TOGGLE_STATES
        if ts and ts["Action Panel"] then ts["Action Panel"].set(true) end
        if _G.SH_ActionsPanel then _G.SH_ActionsPanel.Visible = true end
    end
    if cfg.agPanel == true then
        local ts = _G.TOGGLE_STATES
        if ts and ts["Auto Grab Panel"] then ts["Auto Grab Panel"].set(true) end
        task.spawn(function()
            local t2 = 0
            while not _G.SH_ShowAutoGrabPanel and t2 < 15 do task.wait(0.3); t2 = t2 + 0.3 end
            if _G.SH_ShowAutoGrabPanel then pcall(_G.SH_ShowAutoGrabPanel, true) end
        end)
    end
    if cfg.carpetSpeed == true then
        _G.SH_CarpetSpeedOn = true
        local ts = _G.TOGGLE_STATES
        if ts and ts["Carpet Speed"] then ts["Carpet Speed"].set(true) end
    end

    -- Restore TP speed values from config
    if type(cfg.neegyCruise)     == "number" then _G.NeegyCruise           = cfg.neegyCruise     end
    if type(cfg.tacoClimb)       == "number" then _G.SH_Climb             = cfg.tacoClimb       end
    if type(cfg.tacoCloseSpeed)  == "number" then _G.SH_CloseSpeed        = cfg.tacoCloseSpeed  end
    if type(cfg.landingDelay)    == "number" then _G.LandingDelay          = cfg.landingDelay    end
    if type(cfg.tacoStealHold)   == "number" then _G.SH_StealHoldDuration = cfg.tacoStealHold   end
    if type(cfg.tacoCommitRange) == "number" then _G.SH_StealCommitRange  = cfg.tacoCommitRange end
    if type(cfg.tacoStealMode)   == "string" then _G.SH_StealMode         = cfg.tacoStealMode   end
    _G._SH_activeTPEngine = (cfg.activeTPEngine == 2) and 2 or 1
    if _G._SH_refreshTPTab then pcall(_G._SH_refreshTPTab) end
end)

-- ============================================================
-- 10D. STARTUP AUTO-TP SEQUENCE (merged silence + neegy)
-- Waits for RailTP + scanner, fires initial TP with settle check
-- ============================================================
_G.SH_ChannelsReady = false
if _G.SH_AutoTPOnRespawn == nil then _G.SH_AutoTPOnRespawn = false end
local _autoTPBusy = false
local _autoTPDidFirst = false

local function _runAutoTPForLoad(char)
    if not char then return end
    if _G.MynxxAutoTP == false then return end
    if _autoTPDidFirst and _G.SH_AutoTPOnRespawn == false then return end
    if _autoTPBusy then return end
    _autoTPBusy = true
    task.spawn(function()
        pcall(function()
            if LP.Character ~= char then return end

            -- Wait for HRP + Humanoid
            local hrpReady, humReady = false, false
            task.spawn(function() char:WaitForChild("HumanoidRootPart", 20); hrpReady = true end)
            task.spawn(function() char:WaitForChild("Humanoid", 20); humReady = true end)
            local _tw0 = os.clock()
            while (not hrpReady or not humReady) and os.clock() - _tw0 < 20 do
                if LP.Character ~= char then return end
                RunService.Heartbeat:Wait()
            end
            pcall(loadModules); pcall(loadNet)
            if _G.MynxxAutoTP == false or LP.Character ~= char then return end

            -- Background tool equip (does not gate TP)
            if _G.SH_WaitForTools ~= false and type(_G.SH_ToolsReady) == "function" then
                task.spawn(function()
                    local _tt0 = os.clock()
                    local _tcap = tonumber(_G.SH_ToolWait) or 30
                    while os.clock() - _tt0 < _tcap do
                        if LP.Character ~= char then return end
                        local ok, ready = pcall(_G.SH_ToolsReady)
                        if ok and ready then pcall(equipCarpet); break end
                        task.wait(0.03)
                    end
                end)
            else
                pcall(equipCarpet)
            end

            -- Neegy-style settle-based stability check before committing
            -- Wait for scan to produce stable results before firing TP
            local _w0 = os.clock()
            local _wMax = tonumber(_G.SH_AutoTPWait) or 20
            local _need = tonumber(_G.SH_TPSettleFrames) or 1
            local _depth = tonumber(_G.SH_TPSettleDepth) or 3
            local _cap = tonumber(_G.SH_TPSettleMax) or 0.3
            local _sig, _same, _firstHit = nil, 0, nil

            while os.clock() - _w0 < _wMax do
                if _G.MynxxAutoTP == false or LP.Character ~= char then return end
                if LP:GetAttribute("Stealing") == true then return end
                local ok, pets = pcall(scanAllPets, true)
                if ok and pets and #pets > 0 then
                    if _need <= 0 then break end
                    _firstHit = _firstHit or os.clock()
                    -- Build signature from top N targets to detect list stabilization
                    local parts = {}
                    for i = 1, math.min(_depth, #pets) do
                        local p = pets[i]
                        parts[#parts + 1] = tostring(p.plot) .. ":" .. tostring(p.slot)
                    end
                    local nowSig = tostring(#pets) .. "|" .. table.concat(parts, ",")
                    if nowSig == _sig then
                        _same = _same + 1
                        if _same >= _need then break end
                    else
                        _sig, _same = nowSig, 0
                    end
                    if os.clock() - _firstHit >= _cap then break end
                    task.wait(tonumber(_G.SH_TPSettleGap) or 0.02)
                else
                    task.wait(tonumber(_G.SH_AutoTPPoll) or 0.05)
                end
            end

            -- Anti-lagback: on first TP, wait for smooth frames
            if not _autoTPDidFirst and _G.SH_SmoothBeforeTP ~= false and _G.SH_WaitSmooth then
                pcall(_G.SH_WaitSmooth)
            end
            if not _autoTPDidFirst then _G.SH_FirstTPPending = true end
            pcall(doVelocityTP)
            _G.SH_FirstTPPending = false
        end)
        _autoTPDidFirst = true
        _autoTPBusy = false
    end)
end

if LP.Character then _runAutoTPForLoad(LP.Character) end
LP.CharacterAdded:Connect(_runAutoTPForLoad)

-- ============================================================
-- 10E. CLOSE BUTTON HANDLER
-- ============================================================
if _G.SH_CloseButton then
    _G.SH_CloseButton.MouseButton1Click:Connect(function()
        if _G.SH_MainPanel then
            _G.SH_MainPanel.Visible = not _G.SH_MainPanel.Visible
        end
    end)
end

-- ============================================================
-- 10F. CONFIG SAVE FUNCTION (merged, Taco* -> SH_*)
-- ============================================================
local function saveTpSettings()
    if not writefile then return end
    local HS = game:GetService("HttpService")
    local t = {}
    if SH_FS_OK and readfile then
        pcall(function()
            local raw = readfile(CONFIG_FILE)
            if type(raw) == "string" and #raw > 0 then
                local ok, d = pcall(HS.JSONDecode, HS, raw)
                if ok and type(d) == "table" then t = d end
            end
        end)
    end
    t.tpVelocity    = tonumber(_G.NeegyCruise) or 400
    t.climbSpeed    = tonumber(_G.SH_Climb) or 160
    t.goSpeed       = tonumber(_G.SH_GoSpeed) or 200
    t.cframeSpeed   = tonumber(_G.SH_CFrameSpeed) or 450
    t.walkSpeed     = tonumber(_G.SH_WalkSpeed) or 27
    t.landingDelay  = tonumber(_G.LandingDelay) or 0.35
    t.closeSpeed    = tonumber(_G.SH_CloseSpeed) or 400
    t.autoTp        = _G.MynxxAutoTP ~= false
    t.kickToPS      = _G.SH_KickToPS == true
    t.psLink        = tostring(_G.SH_PrivateServerLink or "")
    t.priAlert      = _G.SH_PriAlert == true
    t.alertSound    = tostring(_G.SH_AlertSound or "111786441593851")
    t.alertMinGen   = tonumber(_G.SH_AlertMinGen) or 80e6
    t.walkSpeedOn   = _G.SH_WalkSpeedOn ~= false
    t.xray          = _G.SH_Xray ~= false
    t.invisAuto     = _G.SH_InvisAuto == true
    t.autoKickOnSteal = _G.SH_AutoKickOnSteal == true
    t.faceAwayNearest = _G.SH_FaceAwayNearest == true
    t.faceAwayOwner   = _G.SH_FaceAwayOwner == true
    t.carpetTool = (type(_G.SH_CarpetTool) == "string" and _G.SH_CarpetTool ~= "")
        and _G.SH_CarpetTool or nil
    do
        local out = {}
        for k, v in pairs(_G.SH_UIPos or {}) do
            if type(k) == "string" and type(v) == "table" then
                out[k] = { x = tonumber(v.x), y = tonumber(v.y),
                    w = tonumber(v.w), h = tonumber(v.h) }
            end
        end
        t.uiPos = out
    end
    t.invisDepth    = tonumber(_G.SH_InvisDepth) or 4.2
    t.invisAngle    = tonumber(_G.SH_InvisAngle) or 180
    t.autoSteal     = stealOn
    t.stealMode     = _G.SH_StealMode
    t.priorityList  = _G.SHARED_PRIORITY_ITEMS
    t.panelX        = tonumber(_G._nrail_panelX)
    t.panelY        = tonumber(_G._nrail_panelY)
    t.panelPos      = _G._nrail_pos
    if type(_G.SH_CloneKeyName)  == "string" then t.cloneKey  = _G.SH_CloneKeyName  else t.cloneKey  = nil end
    if type(_G.SH_InstantCloneKeyName) == "string" then t.instantCloneKey = _G.SH_InstantCloneKeyName else t.instantCloneKey = nil end
    if type(_G.SH_KickKeyName)   == "string" then t.kickKey   = _G.SH_KickKeyName   else t.kickKey   = nil end
    if type(_G.SH_StopTPKeyName) == "string" then t.stopTpKey = _G.SH_StopTPKeyName else t.stopTpKey = nil end
    if type(_G.SH_NearestKey)    == "string" then t.nearestKey= _G.SH_NearestKey    else t.nearestKey= nil end
    if type(_G.SH_DropKeyName)   == "string" then t.dropKey   = _G.SH_DropKeyName   else t.dropKey   = nil end
    if type(_G.SH_ResetKeyName)  == "string" then t.resetKey  = _G.SH_ResetKeyName  else t.resetKey  = nil end
    t.antiFlash     = _G.SH_AntiFlash ~= false
    t.faceAway      = _G.SH_FaceAway == true
    t.faceAwayNearest = _G.SH_FaceAwayNearest == true
    t.faceAwayDelay = tonumber(_G.SH_FaceAwayDelay) or 2
    t.antiBee       = _G.SH_AntiBee ~= false
    t.infJump       = _G.SH_InfJump ~= false
    t.antiDie       = _G.AntiDieDisabled ~= true
    t.carpetSpeedValue = tonumber(_G.SH_CarpetSpeedValue) or 140
    t.autoBuy       = _G.SH_AutoBuy == true
    t.autoBuyRange  = tonumber(_G.SH_AutoBuyRange) or 17
    t.autoBuyHover  = tonumber(_G.SH_AutoBuyHover) or 9
    t.exX = tonumber(_G._sh_exX); t.exY = tonumber(_G._sh_exY)
    t.fX  = tonumber(_G._sh_fX);  t.fY  = tonumber(_G._sh_fY)
    t.kX  = tonumber(_G._sh_kX);  t.kY  = tonumber(_G._sh_kY)
    pcall(function() writefile(CONFIG_FILE, HS:JSONEncode(t)) end)
end
_G.SH_SaveSettings = saveTpSettings

-- ============================================================
-- 10G. FINAL CLOSE — end the task.spawn wrapper from boot
-- ============================================================
end) -- END task.spawn boot wrapper
