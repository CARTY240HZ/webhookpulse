--[[
  ZEX v7.3.3 COMPLETE — PREMIUM GUI + 40+ COMMANDS + PERMISSIONS
  Architecture: Modular · Memory-Safe · Consent-Gated · Strict-Typed
  Palette: #0C0C0E bg · #D4E83A lime · Gotham · No emojis
  Keybind: RightShift toggle · 7 Tabs · 40+ Commands · Permission System
  Author: Principal Luau Engineer — AAA Client Engineering
]]

--!strict

-- ═══════════════════════════════════════════════════════════════════════════════
-- 0. EXECUTOR GLOBAL DECLARATIONS (strict mode compliance)
-- ═══════════════════════════════════════════════════════════════════════════════
-- Executor globals detected dynamically via pcall(). Do NOT use "declare".

type ServicesTable = {
    Players: Players?, RunService: RunService?, TweenService: TweenService?,
    UserInputService: UserInputService?, HttpService: HttpService?,
    TeleportService: TeleportService?, Lighting: Lighting?, Workspace: Workspace?,
    ReplicatedStorage: ReplicatedStorage?, TextService: TextService?,
    StarterGui: StarterGui?, SoundService: SoundService?,
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. SERVICES (cached once at boot under pcall)
-- ═══════════════════════════════════════════════════════════════════════════════

local Services: ServicesTable = {}
pcall(function()
    Services.Players = game:GetService("Players")
    Services.RunService = game:GetService("RunService")
    Services.TweenService = game:GetService("TweenService")
    Services.UserInputService = game:GetService("UserInputService")
    Services.HttpService = game:GetService("HttpService")
    Services.TeleportService = game:GetService("TeleportService")
    Services.Lighting = game:GetService("Lighting")
    Services.Workspace = game:GetService("Workspace")
    Services.ReplicatedStorage = game:GetService("ReplicatedStorage")
    Services.TextService = game:GetService("TextService")
    Services.StarterGui = game:GetService("StarterGui")
    Services.SoundService = game:GetService("SoundService")
end)

assert(Services.Players, "Players service required")
assert(Services.RunService, "RunService required")
assert(Services.TweenService, "TweenService required")
assert(Services.UserInputService, "UserInputService required")
assert(Services.HttpService, "HttpService required")
assert(Services.TeleportService, "TeleportService required")
assert(Services.Lighting, "Lighting required")
assert(Services.Workspace, "Workspace required")

local Players = Services.Players
local RunService = Services.RunService
local TweenService = Services.TweenService
local UserInputService = Services.UserInputService
local HttpService = Services.HttpService
local TeleportService = Services.TeleportService
local Lighting = Services.Lighting
local Workspace = Services.Workspace

local localPlayer = Players.LocalPlayer

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. EXECUTOR FEATURE DETECTION
-- ═══════════════════════════════════════════════════════════════════════════════

export type ExecutorApi = {
    getgenv: (() -> { [string]: any })?, gethui: (() -> Instance)?,
    request: ((options: { [string]: any }) -> { [string]: any })?,
    setclipboard: ((text: string) -> boolean)?,
    sethiddenproperty: ((instance: Instance, prop: string, value: any) -> boolean)?,
    cloneref: ((instance: Instance) -> Instance)?, loadstring: ((src: string) -> (...any) -> ...any)?,
    hookmetamethod: ((obj: any, meta: string, hook: (...any) -> ...any) -> any)?,
    getrawmetatable: ((obj: any) -> { [string]: any })?, getnamecallmethod: (() -> string)?,
}

local Executor: ExecutorApi = { getgenv=nil, gethui=nil, request=nil, setclipboard=nil,
    sethiddenproperty=nil, cloneref=nil, loadstring=nil, hookmetamethod=nil,
    getrawmetatable=nil, getnamecallmethod=nil }

pcall(function() local g=_G["getgenv"]; if type(g)=="function" then Executor.getgenv=g::any end end)
pcall(function() local g=_G["gethui"]; if type(g)=="function" then Executor.gethui=g::any end end)
pcall(function()
    local syn=_G["syn"]; local req=_G["request"]; local httpReq=_G["http_request"]; local fluxus=_G["fluxus"]
    if type(syn)=="table" and type(syn.request)=="function" then Executor.request=syn.request
    elseif type(req)=="function" then Executor.request=req
    elseif type(httpReq)=="function" then Executor.request=httpReq
    elseif type(fluxus)=="table" and type(fluxus.request)=="function" then Executor.request=fluxus.request end
end)
pcall(function() local g=_G["setclipboard"]; if type(g)=="function" then Executor.setclipboard=g::any end end)
pcall(function() local g=_G["sethiddenproperty"]; if type(g)=="function" then Executor.sethiddenproperty=g::any end end)
pcall(function() local g=_G["cloneref"]; if type(g)=="function" then Executor.cloneref=g::any end end)
pcall(function() local g=_G["loadstring"]; if type(g)=="function" then Executor.loadstring=g::any end end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. TYPE ALIASES
-- ═══════════════════════════════════════════════════════════════════════════════

export type Palette = { bg:Color3, surface:Color3, elevated:Color3, card:Color3, border:Color3,
    borderHi:Color3, text:Color3, text2:Color3, text3:Color3, lime:Color3, lime2:Color3,
    limeGlow:Color3, danger:Color3, success:Color3, info:Color3, warn:Color3, clear:Color3 }
export type MaidTask = RBXScriptConnection|Instance|Tween|thread|(() -> ())
export type Maid = { _tasks:{MaidTask}, GiveTask:(self:Maid, task:MaidTask)->(), Destroy:(self:Maid)->() }
export type CommandDef = { name:string, desc:string, category:string, perm:number, run:(args:{string})->() }
export type ConsentMode = "MINIMAL"|"IDENTITY"|"CHARACTER"|"FULL"
export type HttpResponse = { success:boolean, status:number?, body:string?, error:string? }

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. MAID / LIFECYCLE
-- ═══════════════════════════════════════════════════════════════════════════════

local Maid = {}; Maid.__index = Maid
function Maid.new(): Maid
    return setmetatable({ _tasks={} :: {MaidTask} }, Maid)
end
function Maid:GiveTask(task: MaidTask)
    table.insert(self._tasks, task)
end
function Maid:Destroy()
    for _, t in self._tasks do
        if typeof(t)=="RBXScriptConnection" then pcall(function()(t::RBXScriptConnection):Disconnect()end)
        elseif typeof(t)=="Instance" then pcall(function()(t::Instance):Destroy()end)
        elseif typeof(t)=="Tween" then pcall(function()(t::Tween):Cancel()end) pcall(function()(t::Tween):Destroy()end)
        elseif typeof(t)=="thread" then pcall(function()task.cancel(t::thread)end)
        elseif type(t)=="function" then pcall(t) end
    end
    table.clear(self._tasks)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. CONSTANTS & PALETTE
-- ═══════════════════════════════════════════════════════════════════════════════

local Z: Palette = {
    bg=Color3.fromRGB(10,10,12), surface=Color3.fromRGB(18,18,20), elevated=Color3.fromRGB(26,26,28),
    card=Color3.fromRGB(22,22,24), border=Color3.fromRGB(38,38,42), borderHi=Color3.fromRGB(60,60,65),
    text=Color3.fromRGB(252,252,252), text2=Color3.fromRGB(160,160,170), text3=Color3.fromRGB(100,100,110),
    lime=Color3.fromRGB(212,232,58), lime2=Color3.fromRGB(235,252,110), limeGlow=Color3.fromRGB(180,200,40),
    danger=Color3.fromRGB(239,68,68), success=Color3.fromRGB(34,197,94), info=Color3.fromRGB(59,130,246),
    warn=Color3.fromRGB(245,158,11), clear=Color3.fromRGB(0,0,0),
}

local TWEEN_INSTANT = TweenInfo.new(0)
local TWEEN_FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_SMOOTH = TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
local TWEEN_SLOW = TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TWEEN_SPRING = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_PULSE = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local FONT_HEADER = Enum.Font.GothamBold
local FONT_BODY = Enum.Font.GothamMedium
local FONT_LABEL = Enum.Font.Gotham
local FONT_DATA = Enum.Font.GothamMedium
local FONT_BUTTON = Enum.Font.GothamBold
local FONT_CONSOLE = Enum.Font.Code

local LOG_MAX = 300

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. LOGGING + CONSOLE CAPTURE
-- ═══════════════════════════════════════════════════════════════════════════════

local logs: {string} = {}
local logVersion = 0

local function log(level: "INFO"|"WARN"|"ERROR"|"DEBUG"|"OUTPUT", message: string)
    local timestamp = os.date("%H:%M:%S")
    local entry = string.format("[%s] [%s] %s", timestamp, level, message)
    table.insert(logs, entry)
    if #logs > LOG_MAX then table.remove(logs, 1) end
    logVersion += 1
end

local function safeCall<T>(fn: ()->T, context: string): (boolean, T?)
    return xpcall(fn, function(err)
        log("ERROR", context .. ": " .. tostring(err) .. "\n" .. debug.traceback())
    end)
end

-- Capture print / warn / error into console
pcall(function()
    if not _G["ZEX_ORIGINAL_PRINT"] then
        _G["ZEX_ORIGINAL_PRINT"] = print
        _G["ZEX_ORIGINAL_WARN"] = warn
        _G["ZEX_ORIGINAL_ERROR"] = error
    end
    local origPrint = _G["ZEX_ORIGINAL_PRINT"]
    local origWarn = _G["ZEX_ORIGINAL_WARN"]
    local origError = _G["ZEX_ORIGINAL_ERROR"]
    _G.print = function(...)
        local args = {...}
        local msg = table.concat(args, " ")
        log("OUTPUT", "[print] " .. msg)
        origPrint(...)
    end
    _G.warn = function(...)
        local args = {...}
        local msg = table.concat(args, " ")
        log("WARN", "[warn] " .. msg)
        origWarn(...)
    end
    _G.error = function(...)
        local args = {...}
        local msg = table.concat(args, " ")
        log("ERROR", "[error] " .. msg)
        origError(...)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 7. HTTP ENGINE (whitelisted, rate-limited, SSRF-protected)
-- ═══════════════════════════════════════════════════════════════════════════════

local WHITELIST: {string} = { "webhookpulse.vercel.app", "discord.com", "discordapp.com", "hooks.slack.com" }
local rateBuckets: { [string]: { tokens:number, last:number } } = {}
local RATE_MAX = 5; local RATE_WINDOW = 10

local function checkRateLimit(endpoint: string): boolean
    local now = os.clock()
    local host = endpoint:match("^https://([^/]+)")
    if not host then return false end
    host = host:gsub(":%d+$", "")
    local bucket = rateBuckets[host]
    if not bucket then rateBuckets[host] = { tokens=RATE_MAX-1, last=now }; return true end
    local elapsed = math.max(0, now - bucket.last)
    bucket.tokens = math.min(RATE_MAX, bucket.tokens + elapsed * (RATE_MAX/RATE_WINDOW))
    bucket.last = now
    if bucket.tokens >= 1 then bucket.tokens -= 1; return true end
    return false
end

local function escapePattern(s: string): string
    return s:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
end

local function validateUrl(url: string): (boolean, string)
    if type(url)~="string" then return false, "URL must be string" end
    if not url:match("^https://") then return false, "HTTPS required" end
    if url:match("^https://%d+%.%d+%.%d+%.%d+") then return false, "IP not allowed" end
    if url:lower():match("^https://localhost") then return false, "localhost not allowed" end
    local host = url:match("^https://([^/]+)")
    if not host then return false, "Invalid URL" end
    host = host:gsub(":%d+$", "")
    for _, domain in ipairs(WHITELIST) do
        if host==domain or host:match("%" .. escapePattern(domain) .. "$") then return true, "" end
    end
    return false, "Domain not whitelisted"
end

local function httpRequest(options: { [string]: any }): HttpResponse
    local result: HttpResponse = { success=false, status=nil, body=nil, error=nil }
    local timeout = options.Timeout or 15000
    local startTime = os.clock()
    local function checkTimeout(): boolean return (os.clock()-startTime)*1000 >= timeout end
    local layers = {
        function() if Executor.request then local ok,res=pcall(function()return Executor.request(options)end); if ok then return res end end; return nil end,
        function() if Services.HttpService then local ok,body=pcall(function()return Services.HttpService:PostAsync(options.Url, options.Body or "", Enum.HttpContentType.ApplicationJson, false, options.Headers or {})end); if ok then return {success=true,body=body,status=200} end end; return nil end,
        function() if Services.HttpService and Services.HttpService.RequestAsync then local ok,res=pcall(function()return Services.HttpService:RequestAsync({Url=options.Url,Method=options.Method or "POST",Headers=options.Headers or {},Body=options.Body})end); if ok then return res end end; return nil end,
    }
    for _, layer in ipairs(layers) do
        if checkTimeout() then result.error="Timeout"; return result end
        local res = layer()
        if res then
            if res.StatusCode and (res.StatusCode>=300 and res.StatusCode<400) then result.error="Redirects blocked (SSRF)"; return result end
            if res.StatusCode==200 or res.status==200 or res.success then
                result.success=true; result.status=res.StatusCode or res.status or 200; result.body=res.Body or res.body or ""; return result
            end
        end
    end
    result.error="All HTTP layers failed"; return result
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 8. PERMISSION SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

local PERM = { USER=1, MOD=2, ADMIN=3, OWNER=4 }
local userRank = PERM.OWNER -- Default; can be changed in Settings

local function canRun(cmdPerm: number): boolean
    return userRank >= cmdPerm
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 9. COMMAND STATE
-- ═══════════════════════════════════════════════════════════════════════════════

local CMD_STATE = {
    fly = false, noclip = false, godmode = false, invisible = false,
    esp = false, aimbot = false, clicktp = false, spin = false,
    antifling = false, antiafk = false, fullbright = false,
    noclipConn = nil, flyConn = nil, spinConn = nil, espInstances = {},
    aimbotConn = nil, clicktpConn = nil, antiflingConn = nil, antiafkConn = nil,
}

local function getCharacter(): Model?
    if not localPlayer then return nil end
    return localPlayer.Character
end

local function getHumanoid(): Humanoid?
    local char = getCharacter()
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid") :: Humanoid?
end

local function getRootPart(): Part?
    local char = getCharacter()
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") :: Part?
end

local function getPlayerByName(name: string): Player?
    local lower = name:lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():find(lower) or p.DisplayName:lower():find(lower) then return p end
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 10. COMMAND REGISTRY (40+ commands)
-- ═══════════════════════════════════════════════════════════════════════════════

local CommandRegistry: { [string]: CommandDef } = {}

local function reg(name: string, desc: string, category: string, perm: number, run: (args:{string})->())
    CommandRegistry[name:lower()] = { name=name, desc=desc, category=category, perm=perm, run=run }
end

-- PLAYER COMMANDS
reg("fly", "Toggle fly mode", "Player", PERM.USER, function(args)
    CMD_STATE.fly = not CMD_STATE.fly
    local char = getCharacter(); if not char then log("WARN", "No character"); return end
    local hum = getHumanoid(); if not hum then log("WARN", "No humanoid"); return end
    local root = getRootPart(); if not root then log("WARN", "No HRP"); return end
    if CMD_STATE.fly then
        log("INFO", "Fly ON")
        hum.PlatformStand = true
        local bv = Instance.new("BodyVelocity")
        bv.Name = "ZEX_Fly"; bv.MaxForce = Vector3.new(9e9,9e9,9e9); bv.Velocity = Vector3.zero; bv.Parent = root
        CMD_STATE.flyConn = RunService.RenderStepped:Connect(function()
            if not CMD_STATE.fly then return end
            local cam = Workspace.CurrentCamera
            local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.new(0,1,0) end
            local speed = tonumber(args[1]) or 50
            bv.Velocity = dir.Unit * speed
            if dir.Magnitude == 0 then bv.Velocity = Vector3.zero end
        end)
    else
        log("INFO", "Fly OFF")
        hum.PlatformStand = false
        if CMD_STATE.flyConn then CMD_STATE.flyConn:Disconnect(); CMD_STATE.flyConn = nil end
        local bv = root:FindFirstChild("ZEX_Fly"); if bv then bv:Destroy() end
    end
end)

reg("noclip", "Toggle noclip", "Player", PERM.USER, function(args)
    CMD_STATE.noclip = not CMD_STATE.noclip
    local char = getCharacter(); if not char then return end
    if CMD_STATE.noclip then
        log("INFO", "Noclip ON")
        CMD_STATE.noclipConn = RunService.Stepped:Connect(function()
            if not CMD_STATE.noclip then return end
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("BasePart") then v.CanCollide = false end
            end
        end)
    else
        log("INFO", "Noclip OFF")
        if CMD_STATE.noclipConn then CMD_STATE.noclipConn:Disconnect(); CMD_STATE.noclipConn = nil end
        for _, v in ipairs(char:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide = true end end
    end
end)

reg("clip", "Disable noclip", "Player", PERM.USER, function(args)
    CMD_STATE.noclip = false
    if CMD_STATE.noclipConn then CMD_STATE.noclipConn:Disconnect(); CMD_STATE.noclipConn = nil end
    local char = getCharacter(); if char then for _, v in ipairs(char:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide = true end end end
    log("INFO", "Noclip OFF")
end)

reg("unfly", "Disable fly", "Player", PERM.USER, function(args)
    CMD_STATE.fly = false
    if CMD_STATE.flyConn then CMD_STATE.flyConn:Disconnect(); CMD_STATE.flyConn = nil end
    local char = getCharacter(); if not char then return end
    local hum = getHumanoid(); if hum then hum.PlatformStand = false end
    local root = getRootPart(); if root then local bv = root:FindFirstChild("ZEX_Fly"); if bv then bv:Destroy() end end
    log("INFO", "Fly OFF")
end)

reg("speed", "Set walkspeed", "Player", PERM.USER, function(args)
    local val = tonumber(args[1]) or 50
    local hum = getHumanoid(); if hum then hum.WalkSpeed = val; log("INFO", "WalkSpeed = " .. val) end
end)

reg("jump", "Set jumppower", "Player", PERM.USER, function(args)
    local val = tonumber(args[1]) or 75
    local hum = getHumanoid(); if hum then hum.JumpPower = val; log("INFO", "JumpPower = " .. val) end
end)

reg("gravity", "Set workspace gravity", "World", PERM.USER, function(args)
    local val = tonumber(args[1]) or 196.2
    Workspace.Gravity = val; log("INFO", "Gravity = " .. val)
end)

reg("heal", "Restore health", "Player", PERM.USER, function(args)
    local hum = getHumanoid(); if hum then hum.Health = hum.MaxHealth; log("INFO", "Healed") end
end)

reg("kill", "Break joints (suicide)", "Player", PERM.USER, function(args)
    local char = getCharacter(); if char then char:BreakJoints(); log("INFO", "Killed character") end
end)

reg("godmode", "Toggle godmode", "Player", PERM.MOD, function(args)
    CMD_STATE.godmode = not CMD_STATE.godmode
    local char = getCharacter(); if not char then return end
    local hum = getHumanoid(); if not hum then return end
    if CMD_STATE.godmode then
        log("INFO", "Godmode ON")
        hum.Health = hum.MaxHealth
        hum:GetPropertyChangedSignal("Health"):Connect(function()
            if CMD_STATE.godmode and hum.Health < hum.MaxHealth then hum.Health = hum.MaxHealth end
        end)
    else
        log("INFO", "Godmode OFF")
    end
end)

reg("ungodmode", "Disable godmode", "Player", PERM.MOD, function(args)
    CMD_STATE.godmode = false; log("INFO", "Godmode OFF")
end)

reg("invisible", "Toggle invisibility", "Player", PERM.MOD, function(args)
    CMD_STATE.invisible = not CMD_STATE.invisible
    local char = getCharacter(); if not char then return end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") or v:IsA("Decal") or v:IsA("Texture") then
            v.Transparency = CMD_STATE.invisible and 1 or 0
        end
        if v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled = not CMD_STATE.invisible end
    end
    log("INFO", CMD_STATE.invisible and "Invisible ON" or "Invisible OFF")
end)

reg("visible", "Disable invisibility", "Player", PERM.MOD, function(args)
    CMD_STATE.invisible = false
    local char = getCharacter(); if not char then return end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then v.Transparency = 0
        elseif v:IsA("Decal") or v:IsA("Texture") then v.Transparency = 0
        elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled = true end
    end
    log("INFO", "Visible")
end)

reg("sit", "Force sit", "Player", PERM.USER, function(args)
    local hum = getHumanoid(); if hum then hum.Sit = true; log("INFO", "Sitting") end
end)

reg("unsit", "Force stand", "Player", PERM.USER, function(args)
    local hum = getHumanoid(); if hum then hum.Sit = false; log("INFO", "Standing") end
end)

reg("freeze", "Freeze character", "Player", PERM.MOD, function(args)
    local char = getCharacter(); if not char then return end
    for _, v in ipairs(char:GetDescendants()) do if v:IsA("BasePart") then v.Anchored = true end end
    log("INFO", "Frozen")
end)

reg("thaw", "Unfreeze character", "Player", PERM.MOD, function(args)
    local char = getCharacter(); if not char then return end
    for _, v in ipairs(char:GetDescendants()) do if v:IsA("BasePart") then v.Anchored = false end end
    log("INFO", "Thawed")
end)

reg("anchor", "Anchor character", "Player", PERM.MOD, function(args) CommandRegistry["freeze"].run({}) end)
reg("unanchor", "Unanchor character", "Player", PERM.MOD, function(args) CommandRegistry["thaw"].run({}) end)

reg("spin", "Toggle spin", "Player", PERM.USER, function(args)
    CMD_STATE.spin = not CMD_STATE.spin
    local char = getCharacter(); if not char then return end
    local root = getRootPart(); if not root then return end
    if CMD_STATE.spin then
        log("INFO", "Spin ON")
        CMD_STATE.spinConn = RunService.RenderStepped:Connect(function()
            if not CMD_STATE.spin then return end
            root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(10), 0)
        end)
    else
        log("INFO", "Spin OFF")
        if CMD_STATE.spinConn then CMD_STATE.spinConn:Disconnect(); CMD_STATE.spinConn = nil end
    end
end)

reg("unspin", "Stop spin", "Player", PERM.USER, function(args)
    CMD_STATE.spin = false
    if CMD_STATE.spinConn then CMD_STATE.spinConn:Disconnect(); CMD_STATE.spinConn = nil end
    log("INFO", "Spin OFF")
end)

reg("dance", "Play dance emote", "Player", PERM.USER, function(args)
    local hum = getHumanoid(); if hum then local anim=Instance.new("Animation"); anim.AnimationId="rbxassetid://507771019"; local track=hum:LoadAnimation(anim); track:Play(); log("INFO", "Dancing") end
end)

reg("reset", "Reset character", "Player", PERM.USER, function(args)
    if localPlayer then localPlayer.Character = nil; log("INFO", "Reset") end
end)

reg("refresh", "Respawn at same position", "Player", PERM.USER, function(args)
    local char = getCharacter(); if not char then return end
    local root = getRootPart(); if not root then return end
    local pos = root.CFrame
    if localPlayer then localPlayer.Character = nil end
    task.delay(0.5, function()
        local newChar = localPlayer and localPlayer.Character
        if newChar then task.wait(0.3); local newRoot = newChar:WaitForChild("HumanoidRootPart", 3); if newRoot then newRoot.CFrame = pos end end
    end)
    log("INFO", "Refresh")
end)

-- COMBAT / ESP
reg("esp", "Toggle ESP", "Combat", PERM.MOD, function(args)
    CMD_STATE.esp = not CMD_STATE.esp
    if CMD_STATE.esp then
        log("INFO", "ESP ON")
        local function addESP(p: Player)
            if p == localPlayer then return end
            local char = p.Character; if not char then return end
            local head = char:FindFirstChild("Head"); if not head then return end
            local hl = Instance.new("Highlight")
            hl.Name = "ZEX_ESP"; hl.FillColor = Z.danger; hl.OutlineColor = Z.lime; hl.FillTransparency = 0.7; hl.OutlineTransparency = 0.3; hl.Parent = char
            local bg = Instance.new("BillboardGui")
            bg.Name = "ZEX_ESP"; bg.AlwaysOnTop = true; bg.Size = UDim2.new(0,100,0,20); bg.StudsOffset = Vector3.new(0,2,0); bg.Parent = head
            local tl = Instance.new("TextLabel")
            tl.Size = UDim2.new(1,0,1,0); tl.BackgroundTransparency = 1; tl.TextColor3 = Z.lime; tl.Font = FONT_BODY; tl.TextSize = 12; tl.Text = p.Name; tl.Parent = bg
            table.insert(CMD_STATE.espInstances, hl); table.insert(CMD_STATE.espInstances, bg)
        end
        for _, p in ipairs(Players:GetPlayers()) do addESP(p) end
        CMD_STATE.espConn = Players.PlayerAdded:Connect(addESP)
    else
        log("INFO", "ESP OFF")
        if CMD_STATE.espConn then CMD_STATE.espConn:Disconnect(); CMD_STATE.espConn = nil end
        for _, inst in ipairs(CMD_STATE.espInstances) do pcall(function() inst:Destroy() end) end
        table.clear(CMD_STATE.espInstances)
    end
end)

reg("unesp", "Disable ESP", "Combat", PERM.MOD, function(args)
    CMD_STATE.esp = false
    if CMD_STATE.espConn then CMD_STATE.espConn:Disconnect(); CMD_STATE.espConn = nil end
    for _, inst in ipairs(CMD_STATE.espInstances) do pcall(function() inst:Destroy() end) end
    table.clear(CMD_STATE.espInstances)
    log("INFO", "ESP OFF")
end)

reg("clicktp", "Toggle click teleport", "Combat", PERM.USER, function(args)
    CMD_STATE.clicktp = not CMD_STATE.clicktp
    if CMD_STATE.clicktp then
        log("INFO", "ClickTP ON (Hold Ctrl+Click)")
        CMD_STATE.clicktpConn = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                local mouse = localPlayer and localPlayer:GetMouse()
                if mouse then
                    local root = getRootPart(); if root then root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0,3,0)) end
                end
            end
        end)
    else
        log("INFO", "ClickTP OFF")
        if CMD_STATE.clicktpConn then CMD_STATE.clicktpConn:Disconnect(); CMD_STATE.clicktpConn = nil end
    end
end)

reg("btools", "Give building tools", "Utility", PERM.MOD, function(args)
    local backpack = localPlayer and localPlayer:FindFirstChildOfClass("Backpack"); if not backpack then return end
    for _, class in ipairs({"HopperBin", "Tool"}) do
        local t = Instance.new(class)
        if class == "HopperBin" then t.BinType = Enum.BinType.Grab end
        t.Parent = backpack
    end
    log("INFO", "BTools given")
end)

reg("removetools", "Remove tools", "Utility", PERM.MOD, function(args)
    local backpack = localPlayer and localPlayer:FindFirstChildOfClass("Backpack"); if not backpack then return end
    for _, v in ipairs(backpack:GetChildren()) do if v:IsA("Tool") or v:IsA("HopperBin") then v:Destroy() end end
    local char = getCharacter(); if char then for _, v in ipairs(char:GetChildren()) do if v:IsA("Tool") then v:Destroy() end end end
    log("INFO", "Tools removed")
end)

reg("nameresp", "Name respawn", "Utility", PERM.USER, function(args)
    if not localPlayer then return end
    local dn = localPlayer.DisplayName
    localPlayer.DisplayName = " "; task.wait(0.1); localPlayer.DisplayName = dn
    log("INFO", "Name respawned")
end)

reg("view", "View player", "Utility", PERM.MOD, function(args)
    local target = getPlayerByName(args[1] or "")
    if target and target.Character then
        Workspace.CurrentCamera.CameraSubject = target.Character:FindFirstChildOfClass("Humanoid") or target.Character
        log("INFO", "Viewing " .. target.Name)
    end
end)

reg("unview", "Reset camera", "Utility", PERM.MOD, function(args)
    local char = getCharacter(); local hum = getHumanoid()
    if hum then Workspace.CurrentCamera.CameraSubject = hum end
    log("INFO", "Camera reset")
end)

reg("antiafk", "Toggle anti-AFK", "Utility", PERM.USER, function(args)
    CMD_STATE.antiafk = not CMD_STATE.antiafk
    if CMD_STATE.antiafk then
        log("INFO", "Anti-AFK ON")
        CMD_STATE.antiafkConn = RunService.Heartbeat:Connect(function()
            if not CMD_STATE.antiafk then return end
            local hum = getHumanoid(); if hum then hum:ChangeState(Enum.HumanoidStateType.RunningNoPhysics) end
        end)
    else
        log("INFO", "Anti-AFK OFF")
        if CMD_STATE.antiafkConn then CMD_STATE.antiafkConn:Disconnect(); CMD_STATE.antiafkConn = nil end
    end
end)

reg("fullbright", "Enable fullbright", "World", PERM.USER, function(args)
    Lighting.Brightness = 10; Lighting.GlobalShadows = false; Lighting.ClockTime = 12
    log("INFO", "Fullbright ON")
end)

reg("time", "Set lighting time", "World", PERM.USER, function(args)
    local val = tonumber(args[1]) or 12
    Lighting.ClockTime = val; log("INFO", "Time = " .. val)
end)

reg("fog", "Set fog", "World", PERM.USER, function(args)
    local val = tonumber(args[1]) or 0
    Lighting.FogEnd = val; log("INFO", "Fog = " .. val)
end)

reg("rejoin", "Rejoin server", "Server", PERM.USER, function(args)
    log("INFO", "Rejoining...")
    TeleportService:Teleport(game.PlaceId, localPlayer)
end)

reg("serverhop", "Join different server", "Server", PERM.USER, function(args)
    log("INFO", "Server hopping...")
    local success, result = pcall(function() return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")) end)
    if success and result and result.data then
        for _, server in ipairs(result.data) do
            if server.id ~= game.JobId and server.playing < server.maxPlayers then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, localPlayer)
                return
            end
        end
    end
    log("WARN", "Server hop failed")
end)

reg("teleport", "Teleport to player", "Server", PERM.MOD, function(args)
    local target = getPlayerByName(args[1] or "")
    if target and target.Character then
        local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
        local root = getRootPart()
        if tRoot and root then root.CFrame = tRoot.CFrame; log("INFO", "Teleported to " .. target.Name) end
    end
end)
reg("tp", "Teleport to player", "Server", PERM.MOD, function(args) CommandRegistry["teleport"].run(args) end)

reg("bring", "Bring player", "Server", PERM.ADMIN, function(args)
    local target = getPlayerByName(args[1] or "")
    if target and target.Character and localPlayer and localPlayer.Character then
        local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
        local root = getRootPart()
        if tRoot and root then tRoot.CFrame = root.CFrame; log("INFO", "Brought " .. target.Name) end
    end
end)

reg("goto", "Goto player", "Server", PERM.MOD, function(args)
    CommandRegistry["teleport"].run(args)
end)

reg("fling", "Fling player", "Server", PERM.ADMIN, function(args)
    local target = getPlayerByName(args[1] or "")
    if target and target.Character then
        local tRoot = target.Character:FindFirstChild("HumanoidRootPart")
        if tRoot then
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(9e9,9e9,9e9); bv.Velocity = Vector3.new(0,500,0); bv.Parent = tRoot
            task.delay(0.5, function() bv:Destroy() end)
            log("INFO", "Flung " .. target.Name)
        end
    end
end)

reg("kick", "Kick player (local visual)", "Server", PERM.ADMIN, function(args)
    local target = getPlayerByName(args[1] or "")
    if target and target ~= localPlayer then
        log("INFO", "Kicking " .. target.Name)
        pcall(function() target:Kick("Kicked by ZEX Admin") end)
    end
end)

reg("killall", "Kill all players", "Server", PERM.OWNER, function(args)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer and p.Character then pcall(function() p.Character:BreakJoints() end) end
    end
    log("INFO", "Killed all")
end)

reg("bringall", "Bring all players", "Server", PERM.OWNER, function(args)
    local root = getRootPart(); if not root then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer and p.Character then
            local tRoot = p.Character:FindFirstChild("HumanoidRootPart")
            if tRoot then tRoot.CFrame = root.CFrame end
        end
    end
    log("INFO", "Brought all")
end)

reg("flingall", "Fling all players", "Server", PERM.OWNER, function(args)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer and p.Character then
            local tRoot = p.Character:FindFirstChild("HumanoidRootPart")
            if tRoot then
                local bv = Instance.new("BodyVelocity")
                bv.MaxForce = Vector3.new(9e9,9e9,9e9); bv.Velocity = Vector3.new(math.random(-500,500),500,math.random(-500,500)); bv.Parent = tRoot
                task.delay(0.5, function() bv:Destroy() end)
            end
        end
    end
    log("INFO", "Flung all")
end)

reg("speedall", "Set speed for all", "Server", PERM.OWNER, function(args)
    local val = tonumber(args[1]) or 50
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then local hum = p.Character:FindFirstChildOfClass("Humanoid"); if hum then hum.WalkSpeed = val end end
    end
    log("INFO", "Speed all = " .. val)
end)

reg("jumppowerall", "Set jumppower for all", "Server", PERM.OWNER, function(args)
    local val = tonumber(args[1]) or 75
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then local hum = p.Character:FindFirstChildOfClass("Humanoid"); if hum then hum.JumpPower = val end end
    end
    log("INFO", "JumpPower all = " .. val)
end)

reg("gravityall", "Set gravity for all", "World", PERM.OWNER, function(args)
    local val = tonumber(args[1]) or 196.2
    Workspace.Gravity = val; log("INFO", "Gravity all = " .. val)
end)

reg("clearterrain", "Clear terrain", "World", PERM.ADMIN, function(args)
    if Workspace:FindFirstChildOfClass("Terrain") then
        Workspace.Terrain:Clear()
        log("INFO", "Terrain cleared")
    end
end)

reg("aimbot", "Toggle aimbot (nearest)", "Combat", PERM.MOD, function(args)
    CMD_STATE.aimbot = not CMD_STATE.aimbot
    if CMD_STATE.aimbot then
        log("INFO", "Aimbot ON")
        CMD_STATE.aimbotConn = RunService.RenderStepped:Connect(function()
            if not CMD_STATE.aimbot then return end
            local cam = Workspace.CurrentCamera
            local nearest = nil; local dist = math.huge
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= localPlayer and p.Character then
                    local head = p.Character:FindFirstChild("Head")
                    if head then
                        local d = (head.Position - cam.CFrame.Position).Magnitude
                        if d < dist then dist = d; nearest = head end
                    end
                end
            end
            if nearest then cam.CFrame = CFrame.new(cam.CFrame.Position, nearest.Position) end
        end)
    else
        log("INFO", "Aimbot OFF")
        if CMD_STATE.aimbotConn then CMD_STATE.aimbotConn:Disconnect(); CMD_STATE.aimbotConn = nil end
    end
end)

reg("unaimbot", "Disable aimbot", "Combat", PERM.MOD, function(args)
    CMD_STATE.aimbot = false
    if CMD_STATE.aimbotConn then CMD_STATE.aimbotConn:Disconnect(); CMD_STATE.aimbotConn = nil end
    log("INFO", "Aimbot OFF")
end)

reg("antifling", "Toggle antifling", "Player", PERM.USER, function(args)
    CMD_STATE.antifling = not CMD_STATE.antifling
    if CMD_STATE.antifling then
        log("INFO", "AntiFling ON")
        CMD_STATE.antiflingConn = RunService.Heartbeat:Connect(function()
            if not CMD_STATE.antifling then return end
            local char = getCharacter(); if not char then return end
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("BasePart") then v.Velocity = Vector3.zero; v.RotVelocity = Vector3.zero end
            end
        end)
    else
        log("INFO", "AntiFling OFF")
        if CMD_STATE.antiflingConn then CMD_STATE.antiflingConn:Disconnect(); CMD_STATE.antiflingConn = nil end
    end
end)

reg("walkspeed", "Set walkspeed", "Player", PERM.USER, function(args) CommandRegistry["speed"].run(args) end)
reg("jumppower", "Set jumppower", "Player", PERM.USER, function(args) CommandRegistry["jump"].run(args) end)
reg("ws", "Set walkspeed", "Player", PERM.USER, function(args) CommandRegistry["speed"].run(args) end)
reg("jp", "Set jumppower", "Player", PERM.USER, function(args) CommandRegistry["jump"].run(args) end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 11. TWEEN ENGINE
-- ═══════════════════════════════════════════════════════════════════════════════

local activeTweens: { [Instance]: Tween } = {}

local function tweenSafe(obj: Instance, props: { [string]: any }, info: TweenInfo, maid: Maid?): Tween?
    if not obj or not obj.Parent then return nil end
    if activeTweens[obj] then pcall(function() activeTweens[obj]:Cancel() end) pcall(function() activeTweens[obj]:Destroy() end) activeTweens[obj]=nil end
    local ok, tw = pcall(function() return TweenService:Create(obj, info, props) end)
    if not ok or not tw then return nil end
    activeTweens[obj] = tw
    local conn = tw.Completed:Connect(function()
        if activeTweens[obj]==tw then activeTweens[obj]=nil end
        pcall(function() tw:Destroy() end)
    end)
    if maid then maid:GiveTask(function() if activeTweens[obj]==tw then activeTweens[obj]=nil end pcall(function() conn:Disconnect() end) pcall(function() tw:Cancel() end) pcall(function() tw:Destroy() end) end) end
    tw:Play()
    return tw
end

local function applyHoverEffect(instance: GuiObject, maid: Maid, normalProps: { [string]: any }, hoverProps: { [string]: any })
    maid:GiveTask(instance.MouseEnter:Connect(function() tweenSafe(instance, hoverProps, TWEEN_FAST, maid) end))
    maid:GiveTask(instance.MouseLeave:Connect(function() tweenSafe(instance, normalProps, TWEEN_FAST, maid) end))
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 12. PARTICLE SYSTEM (Large, visible, glowing)
-- ═══════════════════════════════════════════════════════════════════════════════

local function createParticles(parent: Frame, maid: Maid, count: number)
    count = count or 15
    local particles = {}
    for i = 1, count do
        local p = Instance.new("Frame")
        p.Size = UDim2.new(0, math.random(3,6), 0, math.random(3,6))
        p.Position = UDim2.new(math.random(), 0, math.random(), 0)
        p.BackgroundColor3 = Z.lime; p.BackgroundTransparency = 0.7; p.BorderSizePixel = 0; p.ZIndex = 2; p.Parent = parent
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1,0); c.Parent = p
        table.insert(particles, { frame=p, sx=(math.random()-0.5)*0.0005, sy=(math.random()-0.5)*0.0005, phase=math.random()*6.28 })
    end
    local running = true; maid:GiveTask(function() running = false end)
    local conn = RunService.RenderStepped:Connect(function()
        if not running then return end
        local t = tick()
        for _, p in ipairs(particles) do
            local pos = p.frame.Position
            p.frame.Position = UDim2.new(pos.X.Scale + p.sx, 0, pos.Y.Scale + p.sy, 0)
            p.frame.BackgroundTransparency = 0.5 + 0.3 * math.sin(t*1.5 + p.phase)
            if pos.X.Scale > 1 then p.frame.Position = UDim2.new(0,0,pos.Y.Scale,0) end
            if pos.X.Scale < 0 then p.frame.Position = UDim2.new(1,0,pos.Y.Scale,0) end
            if pos.Y.Scale > 1 then p.frame.Position = UDim2.new(pos.X.Scale,0,0,0) end
            if pos.Y.Scale < 0 then p.frame.Position = UDim2.new(pos.X.Scale,0,1,0) end
        end
    end)
    maid:GiveTask(conn)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 13. UI FACTORY
-- ═══════════════════════════════════════════════════════════════════════════════

local function corner(radius: number): UICorner
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, radius); return c
end
local function stroke(color: Color3, thickness: number): UIStroke
    local s = Instance.new("UIStroke"); s.Color = color; s.Thickness = thickness; return s
end
local function frame(props: { [string]: any }): Frame
    local f = Instance.new("Frame")
    for k,v in pairs(props) do if k ~= "Parent" then (f::any)[k] = v end end
    if props.Parent then f.Parent = props.Parent end
    return f
end
local function label(props: { [string]: any }): TextLabel
    local l = Instance.new("TextLabel")
    for k,v in pairs(props) do if k ~= "Parent" then (l::any)[k] = v end end
    if props.Parent then l.Parent = props.Parent end
    return l
end
local function button(props: { [string]: any }): TextButton
    local b = Instance.new("TextButton")
    for k,v in pairs(props) do if k ~= "Parent" then (b::any)[k] = v end end
    if props.Parent then b.Parent = props.Parent end
    return b
end
local function textbox(props: { [string]: any }): TextBox
    local t = Instance.new("TextBox")
    for k,v in pairs(props) do if k ~= "Parent" then (t::any)[k] = v end end
    if props.Parent then t.Parent = props.Parent end
    return t
end
local function scrolling(props: { [string]: any }): ScrollingFrame
    local s = Instance.new("ScrollingFrame")
    for k,v in pairs(props) do if k ~= "Parent" then (s::any)[k] = v end end
    if props.Parent then s.Parent = props.Parent end
    return s
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 14. SCREEN GUI + MAIN FRAME
-- ═══════════════════════════════════════════════════════════════════════════════

local rootMaid = Maid.new()

local screenGui: ScreenGui
local mainContainer: Frame

pcall(function()
    local parent: Instance
    if Executor.gethui then local ok,hui=pcall(Executor.gethui); if ok and hui then parent=hui end end
    if not parent and Executor.cloneref then local ok,ref=pcall(function() return Executor.cloneref(game.CoreGui) end); if ok and ref then parent=ref end end
    if not parent then parent = game.CoreGui end
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ZEX_v733"; screenGui.ResetOnSpawn = false; screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; screenGui.Parent = parent
    rootMaid:GiveTask(screenGui)
end)

if not screenGui then log("ERROR", "Failed to create ScreenGui"); return end

-- Backdrop
local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.new(1,0,1,0); backdrop.Position = UDim2.new(0,0,0,0); backdrop.BackgroundColor3 = Z.bg
backdrop.BackgroundTransparency = 0.35; backdrop.BorderSizePixel = 0; backdrop.ZIndex = 1; backdrop.Parent = screenGui
rootMaid:GiveTask(backdrop)

-- Main container
mainContainer = frame({
    Name = "MainContainer", Size = UDim2.new(0,900,0,560), Position = UDim2.new(0.5,-450,0.5,-280),
    BackgroundColor3 = Z.surface, BackgroundTransparency = 0.08, BorderSizePixel = 0, ClipsDescendants = true, Parent = screenGui,
})
corner(12).Parent = mainContainer
local mainStroke = stroke(Z.border, 1); mainStroke.Parent = mainContainer

-- Glow border
local glowBorder = stroke(Z.lime, 0); glowBorder.Transparency = 0.9; glowBorder.Parent = mainContainer

-- Particles
local particleLayer = Instance.new("Frame")
particleLayer.Size = UDim2.new(1,0,1,0); particleLayer.BackgroundTransparency = 1; particleLayer.ZIndex = 11; particleLayer.Parent = mainContainer
createParticles(particleLayer, rootMaid, 18)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 15. TITLE BAR
-- ═══════════════════════════════════════════════════════════════════════════════

local titleBar = frame({ Name="TitleBar", Size=UDim2.new(1,0,0,44), BackgroundColor3=Z.card, BackgroundTransparency=0.05, BorderSizePixel=0, Parent=mainContainer })
corner(12).Parent = titleBar

local accentLine = frame({ Name="AccentLine", Size=UDim2.new(1,0,0,2), Position=UDim2.new(0,0,1,-2), BackgroundColor3=Z.lime, BorderSizePixel=0, ZIndex=13, Parent=titleBar })
tweenSafe(accentLine, { BackgroundColor3=Z.lime2 }, TWEEN_PULSE, rootMaid)

local titleText = label({ Text="ZEX v7.3.3", Font=FONT_HEADER, TextSize=16, TextColor3=Z.lime, Size=UDim2.new(0,200,1,0), Position=UDim2.new(0,16,0,0), BackgroundTransparency=1, TextXAlignment=Enum.TextXAlignment.Left, ZIndex=13, Parent=titleBar })
local permLabel = label({ Text="OWNER", Font=FONT_BODY, TextSize=11, TextColor3=Z.lime, Size=UDim2.new(0,80,0,20), Position=UDim2.new(0,110,0,12), BackgroundTransparency=1, ZIndex=13, Parent=titleBar })

local closeBtn = button({ Text="X", Font=FONT_HEADER, TextSize=14, TextColor3=Z.text2, Size=UDim2.new(0,30,0,30), Position=UDim2.new(1,-38,0,7), BackgroundColor3=Z.card, BackgroundTransparency=0.5, BorderSizePixel=0, AutoButtonColor=false, ZIndex=13, Parent=titleBar })
corner(6).Parent = closeBtn
applyHoverEffect(closeBtn, rootMaid, {TextColor3=Z.text2}, {TextColor3=Z.danger})
rootMaid:GiveTask(closeBtn.MouseButton1Click:Connect(function()
    tweenSafe(mainContainer, { Position=UDim2.new(0.5,-450,1.5,0) }, TWEEN_SMOOTH, rootMaid)
    task.delay(0.5, function() screenGui:Destroy(); rootMaid:Destroy() end)
end))

-- ═══════════════════════════════════════════════════════════════════════════════
-- 16. SIDEBAR (7 icons)
-- ═══════════════════════════════════════════════════════════════════════════════

local sidebar = frame({ Name="Sidebar", Size=UDim2.new(0,54,1,-44), Position=UDim2.new(0,0,0,44), BackgroundColor3=Z.card, BackgroundTransparency=0.05, BorderSizePixel=0, ZIndex=12, Parent=mainContainer })

local sidebarConfig = {
    { id="Dashboard", icon="D" }, { id="Commands", icon="C" }, { id="Player", icon="P" },
    { id="Server", icon="S" }, { id="Editor", icon="E" }, { id="Console", icon=">" }, { id="Settings", icon="*" },
}
local sidebarButtons: { TextButton } = {}
local activeSidebarBtn: TextButton? = nil

for i, cfg in ipairs(sidebarConfig) do
    local btn = button({ Text=cfg.icon, Font=FONT_BUTTON, TextSize=14, TextColor3=Z.text3, Size=UDim2.new(0,40,0,40), Position=UDim2.new(0,7,0,8+(i-1)*50), BackgroundColor3=Z.card, BackgroundTransparency=0.5, BorderSizePixel=0, AutoButtonColor=false, ZIndex=13, Parent=sidebar })
    corner(8).Parent = btn
    local btnStroke = stroke(Z.border, 1); btnStroke.Parent = btn
    table.insert(sidebarButtons, btn)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 17. CONTENT AREA
-- ═══════════════════════════════════════════════════════════════════════════════

local contentArea = frame({ Name="ContentArea", Size=UDim2.new(1,-54,1,-44), Position=UDim2.new(0,54,0,44), BackgroundColor3=Z.bg, BackgroundTransparency=0.05, BorderSizePixel=0, ZIndex=12, Parent=mainContainer })

-- ═══════════════════════════════════════════════════════════════════════════════
-- 18. TAB SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

local tabsBuild: { [string]: (parent:Frame, maid:Maid)->Frame } = {}
local activeTabMaid: Maid? = nil
local activeTabFrame: Frame? = nil

local function switchTab(tabId: string)
    if activeTabMaid then activeTabMaid:Destroy() end
    activeTabMaid = Maid.new()
    if activeTabFrame then activeTabFrame:Destroy() end
    activeTabFrame = nil

    for i, cfg in ipairs(sidebarConfig) do
        local btn = sidebarButtons[i]
        if cfg.id == tabId then
            activeSidebarBtn = btn
            tweenSafe(btn, { TextColor3=Z.lime, BackgroundColor3=Z.elevated }, TWEEN_FAST, activeTabMaid)
            btn.BackgroundTransparency = 0.05
        else
            tweenSafe(btn, { TextColor3=Z.text3, BackgroundColor3=Z.card }, TWEEN_FAST, activeTabMaid)
            btn.BackgroundTransparency = 0.5
        end
    end

    local builder = tabsBuild[tabId]
    if builder then
        activeTabFrame = builder(contentArea, activeTabMaid)
        if activeTabFrame then
            activeTabFrame.Size = UDim2.new(1,-16,1,-16); activeTabFrame.Position = UDim2.new(0,8,0,8)
            activeTabFrame.BackgroundTransparency = 1; activeTabFrame.Parent = contentArea
            tweenSafe(activeTabFrame, { Position=UDim2.new(0,8,0,8) }, TWEEN_SPRING, activeTabMaid)
        end
    end
end

rootMaid:GiveTask(function() if activeTabMaid then activeTabMaid:Destroy(); activeTabMaid=nil end; if activeTabFrame then activeTabFrame:Destroy(); activeTabFrame=nil end end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 19. TAB BUILDERS
-- ═══════════════════════════════════════════════════════════════════════════════

-- DASHBOARD
local function buildDashboard(parent: Frame, maid: Maid): Frame
    local f = frame({ Name="Dashboard", BackgroundTransparency=1, Size=UDim2.new(1,0,1,0), Parent=parent })
    local running = true; maid:GiveTask(function() running = false end)

    local cards = {
        { label="FPS", color=Z.lime, value="--" },
        { label="MEMORY", color=Z.info, value="-- MB" },
        { label="PING", color=Z.success, value="-- ms" },
        { label="PLAYERS", color=Z.warn, value="--" },
    }
    local valueLabels: { TextLabel } = {}
    for i, card in ipairs(cards) do
        local cardFrame = frame({ Size=UDim2.new(0.48,0,0,60), Position=UDim2.new((i-1)%2==0 and 0.02 or 0.52, 0, math.floor((i-1)/2)*0.25, 0), BackgroundColor3=Z.elevated, BackgroundTransparency=0.3, BorderSizePixel=0, Parent=f })
        corner(8).Parent = cardFrame; stroke(Z.border,1).Parent = cardFrame
        label({ Text=card.label, Font=FONT_BODY, TextSize=10, TextColor3=Z.text3, Size=UDim2.new(1,0,0,18), BackgroundTransparency=1, Parent=cardFrame })
        local val = label({ Text=card.value, Font=FONT_DATA, TextSize=20, TextColor3=card.color, Size=UDim2.new(1,0,0,30), Position=UDim2.new(0,0,0,22), BackgroundTransparency=1, Parent=cardFrame })
        table.insert(valueLabels, val)
    end

    local fps = 0; local last = os.clock()
    maid:GiveTask(RunService.RenderStepped:Connect(function()
        fps += 1; local now = os.clock(); if now-last >= 1 then valueLabels[1].Text = string.format("%d", fps); fps = 0; last = now end
    end))
    task.spawn(function()
        while running and task.wait(1) do
            valueLabels[2].Text = string.format("%.2f MB", collectgarbage("count")/1024)
            valueLabels[4].Text = tostring(#Players:GetPlayers())
        end
    end)
    return f
end

-- COMMANDS (40+ buttons grid)
local function buildCommands(parent: Frame, maid: Maid): Frame
    local f = frame({ Name="Commands", BackgroundTransparency=1, Size=UDim2.new(1,0,1,0), Parent=parent })

    local scroll = scrolling({ Size=UDim2.new(1,0,1,-30), BackgroundTransparency=1, ScrollBarThickness=4, ScrollBarImageColor3=Z.border, Parent=f })
    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0,130,0,32); grid.CellPadding = UDim2.new(0,6,0,6); grid.FillDirectionMaxCells = 5
    grid.Parent = scroll

    local categories = { "Player", "Combat", "World", "Server", "Utility" }
    local categoryColors = { Player=Z.lime, Combat=Z.danger, World=Z.info, Server=Z.warn, Utility=Z.text2 }

    for _, cat in ipairs(categories) do
        local catLabel = label({ Text=cat:upper(), Font=FONT_HEADER, TextSize=11, TextColor3=categoryColors[cat], Size=UDim2.new(1,0,0,20), BackgroundTransparency=1, Parent=scroll })
        for name, cmd in pairs(CommandRegistry) do
            if cmd.category == cat then
                local btn = button({ Text=cmd.name, Font=FONT_BUTTON, TextSize=10, TextColor3=Z.text, Size=UDim2.new(0,130,0,32), BackgroundColor3=Z.card, BorderSizePixel=0, AutoButtonColor=false, Parent=scroll })
                corner(6).Parent = btn; stroke(Z.border,1).Parent = btn
                applyHoverEffect(btn, maid, {BackgroundColor3=Z.card}, {BackgroundColor3=Z.elevated})
                maid:GiveTask(btn.MouseButton1Click:Connect(function()
                    if not canRun(cmd.perm) then log("WARN", "No permission for " .. cmd.name); return end
                    safeCall(function() cmd.run({}) end, "Command " .. cmd.name)
                end))
            end
        end
    end

    task.delay(0.1, function() scroll.CanvasSize = UDim2.new(0, 0, 0, grid.AbsoluteContentSize.Y + 20) end)
    return f
end

-- PLAYER
local function buildPlayer(parent: Frame, maid: Maid): Frame
    local f = frame({ Name="Player", BackgroundTransparency=1, Size=UDim2.new(1,0,1,0), Parent=parent })
    local running = true; maid:GiveTask(function() running = false end)

    local infoLabel = label({ Text="Loading...", Font=FONT_LABEL, TextSize=11, TextColor3=Z.text2, Size=UDim2.new(1,0,0,140), BackgroundTransparency=1, TextWrapped=true, Parent=f })
    local function update()
        if not localPlayer then return end
        local lines = {}
        table.insert(lines, "User: " .. localPlayer.Name .. " (@" .. localPlayer.DisplayName .. ")")
        table.insert(lines, "UserId: " .. tostring(localPlayer.UserId))
        table.insert(lines, "Age: " .. tostring(localPlayer.AccountAge) .. " days")
        table.insert(lines, "Membership: " .. tostring(localPlayer.MembershipType))
        local char = localPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                table.insert(lines, "Health: " .. string.format("%.1f", hum.Health) .. " / " .. tostring(hum.MaxHealth))
                table.insert(lines, "WalkSpeed: " .. tostring(hum.WalkSpeed))
                table.insert(lines, "JumpPower: " .. tostring(hum.JumpPower))
                if hum.RootPart then table.insert(lines, "Position: " .. tostring(math.floor(hum.RootPart.Position.X)) .. ", " .. tostring(math.floor(hum.RootPart.Position.Z))) end
            end
        end
        infoLabel.Text = table.concat(lines, "\n")
    end
    update()
    if localPlayer then maid:GiveTask(localPlayer.CharacterAdded:Connect(function() task.wait(0.5) update() end)) end
    task.spawn(function() while running and task.wait(1) do update() end end)

    -- Sliders
    local function makeSlider(y: number, labelText: string, default: number, min: number, max: number, apply: (val:number)->())
        local l = label({ Text=labelText .. ": " .. tostring(default), Font=FONT_BODY, TextSize=11, TextColor3=Z.text2, Size=UDim2.new(1,0,0,18), Position=UDim2.new(0,0,0,y), BackgroundTransparency=1, Parent=f })
        local box = textbox({ Text=tostring(default), Font=FONT_CONSOLE, TextSize=11, TextColor3=Z.text, Size=UDim2.new(0,60,0,22), Position=UDim2.new(0,0,0,y+20), BackgroundColor3=Z.card, Parent=f })
        corner(4).Parent = box; stroke(Z.border,1).Parent = box
        local setBtn = button({ Text="Set", Font=FONT_BUTTON, TextSize=10, TextColor3=Z.bg, Size=UDim2.new(0,40,0,22), Position=UDim2.new(0,66,0,y+20), BackgroundColor3=Z.lime, Parent=f })
        corner(4).Parent = setBtn
        maid:GiveTask(setBtn.MouseButton1Click:Connect(function() local val=tonumber(box.Text) or default; apply(val); l.Text=labelText .. ": " .. tostring(val) end))
    end

    makeSlider(160, "WalkSpeed", 16, 0, 500, function(v) local hum=getHumanoid(); if hum then hum.WalkSpeed=v end end)
    makeSlider(210, "JumpPower", 50, 0, 500, function(v) local hum=getHumanoid(); if hum then hum.JumpPower=v end end)
    makeSlider(260, "Gravity", 196.2, 0, 500, function(v) Workspace.Gravity=v end)

    return f
end

-- SERVER
local function buildServer(parent: Frame, maid: Maid): Frame
    local f = frame({ Name="Server", BackgroundTransparency=1, Size=UDim2.new(1,0,1,0), Parent=parent })
    local info = {}
    table.insert(info, "Game: " .. game.Name)
    table.insert(info, "PlaceId: " .. tostring(game.PlaceId))
    table.insert(info, "JobId: " .. tostring(game.JobId))
    table.insert(info, "Players: " .. tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers))
    table.insert(info, "Time: " .. tostring(Lighting.TimeOfDay))
    table.insert(info, "Gravity: " .. tostring(Workspace.Gravity))
    table.insert(info, "FPS Cap: " .. tostring(Settings and Settings["SavedQualityLevels"] and "--" or "--"))
    label({ Text=table.concat(info, "\n"), Font=FONT_LABEL, TextSize=11, TextColor3=Z.text2, Size=UDim2.new(1,0,0,200), BackgroundTransparency=1, TextWrapped=true, Parent=f })

    local btnY = 220
    local function srvBtn(text: string, y: number, color: Color3, action: ()->())
        local btn = button({ Text=text, Font=FONT_BUTTON, TextSize=11, TextColor3=Z.bg, Size=UDim2.new(0,140,0,28), Position=UDim2.new(0,0,0,y), BackgroundColor3=color, BorderSizePixel=0, Parent=f })
        corner(6).Parent = btn
        maid:GiveTask(btn.MouseButton1Click:Connect(function() safeCall(action, text) end))
    end

    srvBtn("Rejoin", btnY, Z.lime, function() CommandRegistry["rejoin"].run({}) end)
    srvBtn("Server Hop", btnY+36, Z.info, function() CommandRegistry["serverhop"].run({}) end)
    srvBtn("Fullbright", btnY+72, Z.warn, function() CommandRegistry["fullbright"].run({}) end)
    srvBtn("Clear Terrain", btnY+108, Z.danger, function() CommandRegistry["clearterrain"].run({}) end)

    return f
end

-- EDITOR
local function buildEditor(parent: Frame, maid: Maid): Frame
    local f = frame({ Name="Editor", BackgroundTransparency=1, Size=UDim2.new(1,0,1,0), Parent=parent })

    local editor = textbox({
        Size=UDim2.new(1,-10,0.55,-5), Position=UDim2.new(0,5,0,5), BackgroundColor3=Z.bg, BackgroundTransparency=0.3,
        TextColor3=Z.text, Font=FONT_CONSOLE, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top,
        ClearTextOnFocus=false, MultiLine=true,
        Text="-- ZEX Script Editor v7.3.3\n-- Write Lua code here and press Execute\n\nprint('Hello from ZEX')",
        Parent=f,
    })
    corner(8).Parent = editor; stroke(Z.border,1).Parent = editor

    local execBtn = button({ Text="Execute", Font=FONT_BUTTON, TextSize=12, TextColor3=Z.bg, Size=UDim2.new(0,120,0,30), Position=UDim2.new(0,5,0.55,5), BackgroundColor3=Z.lime, BorderSizePixel=0, Parent=f })
    corner(6).Parent = execBtn
    applyHoverEffect(execBtn, maid, {BackgroundColor3=Z.lime}, {BackgroundColor3=Z.lime2})

    local clearBtn = button({ Text="Clear", Font=FONT_BUTTON, TextSize=11, TextColor3=Z.text, Size=UDim2.new(0,80,0,30), Position=UDim2.new(0,132,0.55,5), BackgroundColor3=Z.card, BorderSizePixel=0, Parent=f })
    corner(6).Parent = clearBtn

    local output = label({
        Size=UDim2.new(1,-10,0.45,-45), Position=UDim2.new(0,5,0.55,42), BackgroundColor3=Z.bg, BackgroundTransparency=0.3,
        TextColor3=Z.text2, Font=FONT_CONSOLE, TextSize=10, TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top,
        Text="> Console output will appear here...", Parent=f,
    })
    corner(8).Parent = output; stroke(Z.border,1).Parent = output

    maid:GiveTask(execBtn.MouseButton1Click:Connect(function()
        local src = editor.Text
        if #src == 0 then output.Text = "> Error: Empty script"; output.TextColor3 = Z.danger; return end
        output.Text = "> Executing..."; output.TextColor3 = Z.info
        log("INFO", "Script execution started")
        local ok, fn = pcall(function()
            if Executor.loadstring then return Executor.loadstring(src) end
            return loadstring(src)
        end)
        if not ok or not fn then output.Text = "> Syntax Error:\n" .. tostring(fn); output.TextColor3 = Z.danger; log("ERROR", "Loadstring failed: " .. tostring(fn)); return end
        local ok2, err = pcall(fn)
        if not ok2 then output.Text = "> Runtime Error:\n" .. tostring(err); output.TextColor3 = Z.danger; log("ERROR", "Runtime: " .. tostring(err))
        else output.Text = "> Execution completed successfully"; output.TextColor3 = Z.success; log("INFO", "Script executed OK") end
    end))

    maid:GiveTask(clearBtn.MouseButton1Click:Connect(function() editor.Text = ""; output.Text = "> Cleared"; output.TextColor3 = Z.text3 end))

    return f
end

-- CONSOLE
local function buildConsole(parent: Frame, maid: Maid): Frame
    local f = frame({ Name="Console", BackgroundTransparency=1, Size=UDim2.new(1,0,1,0), Parent=parent })
    local running = true; maid:GiveTask(function() running = false end)

    local scroll = scrolling({ Size=UDim2.new(1,0,1,-36), BackgroundTransparency=1, ScrollBarThickness=4, ScrollBarImageColor3=Z.border, Parent=f })
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder; listLayout.Parent = scroll

    local lastLogVersion = 0
    local function rebuildConsole()
        if logVersion == lastLogVersion then return end
        lastLogVersion = logVersion
        for _, child in ipairs(scroll:GetChildren()) do if child:IsA("TextLabel") then child:Destroy() end end
        for _, entry in ipairs(logs) do
            local color = Z.text2
            if entry:find("ERROR") then color = Z.danger elseif entry:find("WARN") then color = Z.warn elseif entry:find("DEBUG") then color = Z.info elseif entry:find("OUTPUT") then color = Z.success end
            label({ Text=entry, Font=FONT_CONSOLE, TextSize=10, TextColor3=color, Size=UDim2.new(1,0,0,16), BackgroundTransparency=1, TextXAlignment=Enum.TextXAlignment.Left, Parent=scroll })
        end
        scroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
        scroll.CanvasPosition = Vector2.new(0, listLayout.AbsoluteContentSize.Y)
    end

    task.spawn(function() while running and task.wait(0.3) do rebuildConsole() end end)

    local copyBtn = button({ Text="Copy", Font=FONT_BUTTON, TextSize=10, TextColor3=Z.bg, Size=UDim2.new(0,70,0,24), Position=UDim2.new(0,0,1,-28), BackgroundColor3=Z.lime, Parent=f })
    corner(6).Parent = copyBtn
    maid:GiveTask(copyBtn.MouseButton1Click:Connect(function() if Executor.setclipboard then pcall(function() Executor.setclipboard(table.concat(logs, "\n")) end) end end))

    local clearBtn = button({ Text="Clear", Font=FONT_BUTTON, TextSize=10, TextColor3=Z.text, Size=UDim2.new(0,70,0,24), Position=UDim2.new(0,76,1,-28), BackgroundColor3=Z.card, Parent=f })
    corner(6).Parent = clearBtn
    maid:GiveTask(clearBtn.MouseButton1Click:Connect(function() table.clear(logs); logVersion += 1; rebuildConsole() end))

    return f
end

-- SETTINGS
local function buildSettings(parent: Frame, maid: Maid): Frame
    local f = frame({ Name="Settings", BackgroundTransparency=1, Size=UDim2.new(1,0,1,0), Parent=parent })

    local y = 0
    local function settingLabel(text: string, yPos: number)
        label({ Text=text, Font=FONT_BODY, TextSize=12, TextColor3=Z.text2, Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,0,0,yPos), BackgroundTransparency=1, Parent=f })
    end

    settingLabel("Permission Level:", y)
    local permNames = { [1]="USER", [2]="MOD", [3]="ADMIN", [4]="OWNER" }
    local permBtn = button({ Text=permNames[userRank], Font=FONT_BUTTON, TextSize=11, TextColor3=Z.bg, Size=UDim2.new(0,120,0,26), Position=UDim2.new(0,0,0,y+22), BackgroundColor3=Z.lime, Parent=f })
    corner(6).Parent = permBtn
    maid:GiveTask(permBtn.MouseButton1Click:Connect(function()
        userRank = (userRank % 4) + 1
        permBtn.Text = permNames[userRank]
        permLabel.Text = permNames[userRank]
        log("INFO", "Rank changed to " .. permNames[userRank])
    end))

    settingLabel("Theme: Dark (locked)", y+60)
    settingLabel("Keybind: RightShift", y+90)
    settingLabel("Auto-inject: Off", y+120)

    settingLabel("Webhook URL:", y+160)
    local urlBox = textbox({ PlaceholderText="https://webhookpulse.vercel.app/api/...", Size=UDim2.new(1,0,0,28), Position=UDim2.new(0,0,0,y+182), BackgroundColor3=Z.card, TextColor3=Z.text, Font=FONT_CONSOLE, TextSize=10, Parent=f })
    corner(6).Parent = urlBox; stroke(Z.border,1).Parent = urlBox

    settingLabel("Secret:", y+220)
    local secretBox = textbox({ PlaceholderText="X-Webhook-Secret", Size=UDim2.new(1,0,0,28), Position=UDim2.new(0,0,0,y+242), BackgroundColor3=Z.card, TextColor3=Z.text, Font=FONT_CONSOLE, TextSize=10, Parent=f })
    corner(6).Parent = secretBox; stroke(Z.border,1).Parent = secretBox

    local testBtn = button({ Text="Test Webhook", Font=FONT_BUTTON, TextSize=10, TextColor3=Z.bg, Size=UDim2.new(0,120,0,26), Position=UDim2.new(0,0,0,y+280), BackgroundColor3=Z.info, Parent=f })
    corner(6).Parent = testBtn
    maid:GiveTask(testBtn.MouseButton1Click:Connect(function()
        local url = urlBox.Text
        local valid, err = validateUrl(url)
        if not valid then log("WARN", "Invalid URL: " .. err); return end
        if not checkRateLimit(url) then log("WARN", "Rate limited"); return end
        local payload = { UserId = localPlayer and localPlayer.UserId or "N/A", Username = localPlayer and localPlayer.Name or "N/A", Test = true }
        local res = httpRequest({ Url=url, Method="POST", Headers={ ["Content-Type"]="application/json", ["X-Webhook-Secret"]=secretBox.Text:gsub("[%z\r\n]", "") }, Body=HttpService:JSONEncode({ embeds={{ title="ZEX Test", color=0xD4E83A, fields={{ name="User", value=tostring(localPlayer and localPlayer.Name or "N/A"), inline=true }}, timestamp=os.date("!%Y-%m-%dT%H:%M:%SZ") }} }) })
        if res.success then log("INFO", "Webhook sent"); secretBox.Text = "" else log("WARN", "Webhook failed: " .. (res.error or "Unknown")) end
    end))

    return f
end

tabsBuild = {
    Dashboard = buildDashboard, Commands = buildCommands, Player = buildPlayer,
    Server = buildServer, Editor = buildEditor, Console = buildConsole, Settings = buildSettings,
}

for i, cfg in ipairs(sidebarConfig) do
    maid:GiveTask(sidebarButtons[i].MouseButton1Click:Connect(function() switchTab(cfg.id) end))
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 20. DRAG SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

local dragMaid: Maid? = nil
rootMaid:GiveTask(function() if dragMaid then dragMaid:Destroy(); dragMaid=nil end end)

rootMaid:GiveTask(titleBar.InputBegan:Connect(function(input: InputObject)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if dragMaid then dragMaid:Destroy() end
        dragMaid = Maid.new()
        local dragInputType = input.UserInputType
        local dragOffset = Vector2.new(input.Position.X, input.Position.Y) - mainContainer.AbsolutePosition
        dragMaid:GiveTask(UserInputService.InputChanged:Connect(function(input2: InputObject)
            if input2.UserInputType == Enum.UserInputType.MouseMovement or input2.UserInputType == Enum.UserInputType.Touch then
                local pos = Vector2.new(input2.Position.X, input2.Position.Y) - dragOffset
                local vp = Workspace.CurrentCamera.ViewportSize
                local fw, fh = mainContainer.AbsoluteSize.X, mainContainer.AbsoluteSize.Y
                pos = Vector2.new(math.clamp(pos.X, 0, math.max(0, vp.X - fw)), math.clamp(pos.Y, 0, math.max(0, vp.Y - fh)))
                mainContainer.Position = UDim2.new(0, pos.X, 0, pos.Y)
            end
        end))
        dragMaid:GiveTask(UserInputService.InputEnded:Connect(function(input2: InputObject)
            if input2.UserInputType == dragInputType then
                if dragMaid then dragMaid:Destroy(); dragMaid = nil end
            end
        end))
    end
end))

-- ═══════════════════════════════════════════════════════════════════════════════
-- 21. KEYBIND TOGGLE (RightShift)
-- ═══════════════════════════════════════════════════════════════════════════════

local visible = true
rootMaid:GiveTask(UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        visible = not visible
        if visible then tweenSafe(mainContainer, { Position=UDim2.new(0.5,-450,0.5,-280) }, TWEEN_SMOOTH, rootMaid)
        else tweenSafe(mainContainer, { Position=UDim2.new(0.5,-450,1.5,0) }, TWEEN_SMOOTH, rootMaid) end
    end
end))

-- ═══════════════════════════════════════════════════════════════════════════════
-- 22. ENTRY ANIMATION (staggered fade)
-- ═══════════════════════════════════════════════════════════════════════════════

mainContainer.BackgroundTransparency = 1
for _, child in ipairs(mainContainer:GetDescendants()) do
    if child:IsA("GuiObject") then
        child.BackgroundTransparency = 1
        if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then child.TextTransparency = 1 end
    end
end

task.delay(0.1, function()
    if not screenGui or not screenGui.Parent then return end
    tweenSafe(mainContainer, { BackgroundTransparency=0.08 }, TWEEN_SLOW, rootMaid)
    tweenSafe(glowBorder, { Thickness=2, Transparency=0.7 }, TWEEN_SLOW, rootMaid)
    tweenSafe(backdrop, { BackgroundTransparency=0.35 }, TWEEN_SLOW, rootMaid)
    for i, child in ipairs(mainContainer:GetDescendants()) do
        if child:IsA("GuiObject") then
            task.delay(i * 0.012, function()
                if not screenGui or not screenGui.Parent then return end
                if not child or not child.Parent then return end
                local bt = child.BackgroundTransparency
                if bt > 0.9 then tweenSafe(child, { BackgroundTransparency= bt > 0.95 and 0.3 or 0.05 }, TWEEN_FAST, rootMaid) end
                if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then tweenSafe(child, { TextTransparency=0 }, TWEEN_FAST, rootMaid) end
            end)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 23. TEARDOWN + BOOT
-- ═══════════════════════════════════════════════════════════════════════════════

rootMaid:GiveTask(screenGui.Destroying:Connect(function() rootMaid:Destroy(); log("INFO", "ZEX v7.3.3 teardown") end))

switchTab("Dashboard")

log("INFO", "ZEX v7.3.3 booted — Commands: " .. tostring(function()
    local cc = 0; for _ in pairs(CommandRegistry) do cc += 1 end

log("INFO", "ZEX v7.3.3 booted — Commands: " .. tostring(cc) .. " — Rank: " .. ({[1]="USER", [2]="MOD", [3]="ADMIN", [4]="OWNER"})[userRank])
