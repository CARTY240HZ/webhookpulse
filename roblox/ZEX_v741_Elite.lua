--[[
  ZEX v7.4.1 ELITE — AAA EXECUTOR GUI · COMPONENT LIBRARY · 58+ COMMANDS
  ─────────────────────────────────────────────────────────────────────────────
  Fused architecture: Claude v7.4.0 GUI (blur, shadow, components, vector icons)
  + v7.3.3 backend (58 commands, permissions, console, editor, HTTP engine)
  
  Palette: #0C0C0E bg · #D4E83A lime · Gotham · solid colours · no emojis
  Keybind: RightShift (configurable) · 8 Tabs · 58+ Commands · 4 Permission Levels
  Lifecycle: Maid · Spring Motion · Connection Pool · Vector Icon System
  
  Director: Senior Luau Engineer — 25+ years AAA gaming
]]

--!strict

-- ═══════════════════════════════════════════════════════════════════════════════
-- 0. TYPE DECLARATIONS
-- ═══════════════════════════════════════════════════════════════════════════════

type ServicesTable = {
    Players: Players?, RunService: RunService?, TweenService: TweenService?,
    UserInputService: UserInputService?, HttpService: HttpService?,
    TeleportService: TeleportService?, Lighting: Lighting?, Workspace: Workspace?,
    ReplicatedStorage: ReplicatedStorage?, TextService: TextService?,
    StarterGui: StarterGui?, SoundService: SoundService?, Stats: Stats?,
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. SERVICES — individual pcall per service (no hard-crash)
-- ═══════════════════════════════════════════════════════════════════════════════

local function getService(name: string): Instance?
    local ok, svc = pcall(function() return game:GetService(name) end)
    if ok and svc then return svc end
    return nil
end

local Services: ServicesTable = {}
Services.Players          = getService("Players")         :: Players?
Services.RunService       = getService("RunService")      :: RunService?
Services.TweenService     = getService("TweenService")    :: TweenService?
Services.UserInputService = getService("UserInputService") :: UserInputService?
Services.HttpService      = getService("HttpService")      :: HttpService?
Services.TeleportService  = getService("TeleportService")  :: TeleportService?
Services.Lighting         = getService("Lighting")         :: Lighting?
Services.Workspace        = getService("Workspace")        :: Workspace?
Services.ReplicatedStorage= getService("ReplicatedStorage") :: ReplicatedStorage?
Services.TextService      = getService("TextService")      :: TextService?
Services.StarterGui       = getService("StarterGui")       :: StarterGui?
Services.SoundService     = getService("SoundService")     :: SoundService?
Services.Stats            = getService("Stats")            :: Stats?

-- Graceful fallback: log missing, don't crash
local missing: {string} = {}
for k, v in pairs(Services) do if v == nil then table.insert(missing, k) end end
if #missing > 0 then
    warn("[ZEX] Missing services: " .. table.concat(missing, ", "))
end

local Players         = Services.Players         :: Players
local RunService      = Services.RunService      :: RunService
local TweenService    = Services.TweenService    :: TweenService
local UserInputService= Services.UserInputService:: UserInputService
local HttpService     = Services.HttpService     :: HttpService
local TeleportService = Services.TeleportService :: TeleportService
local Lighting        = Services.Lighting        :: Lighting
local Workspace       = Services.Workspace       :: Workspace

local localPlayer = Players.LocalPlayer

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. EXECUTOR FEATURE DETECTION
-- ═══════════════════════════════════════════════════════════════════════════════

export type ExecutorApi = {
    getgenv: (() -> { [string]: any })?, gethui: (() -> Instance)?,
    request: ((opts: { [string]: any }) -> { [string]: any })?,
    setclipboard: ((text: string) -> boolean)?,
    sethiddenproperty: ((inst: Instance, prop: string, val: any) -> boolean)?,
    cloneref: ((inst: Instance) -> Instance)?,
    loadstring: ((src: string) -> (...any) -> ...any)?,
    hookmetamethod: ((obj: any, meta: string, hook: (...any) -> ...any) -> any)?,
    getrawmetatable: ((obj: any) -> { [string]: any })?,
    getnamecallmethod: (() -> string)?,
}

local Executor: ExecutorApi = {
    getgenv=nil, gethui=nil, request=nil, setclipboard=nil,
    sethiddenproperty=nil, cloneref=nil, loadstring=nil,
    hookmetamethod=nil, getrawmetatable=nil, getnamecallmethod=nil,
}

local function detectFn<T>(key: string): T?
    local ok, v = pcall(function() return _G[key] end)
    return if ok and type(v) == "function" then v :: T else nil
end

Executor.getgenv          = detectFn("getgenv")
Executor.gethui             = detectFn("gethui")
Executor.setclipboard       = detectFn("setclipboard")
Executor.sethiddenproperty  = detectFn("sethiddenproperty")
Executor.cloneref           = detectFn("cloneref")
Executor.loadstring         = detectFn("loadstring")
Executor.hookmetamethod     = detectFn("hookmetamethod")
Executor.getrawmetatable    = detectFn("getrawmetatable")
Executor.getnamecallmethod  = detectFn("getnamecallmethod")

pcall(function()
    local syn    = _G["syn"]        :: any
    local req    = _G["request"]    :: any
    local httpR  = _G["http_request"] :: any
    local fluxus = _G["fluxus"]       :: any
    if type(syn) == "table" and type(syn.request) == "function" then Executor.request = syn.request
    elseif type(req) == "function" then Executor.request = req
    elseif type(httpR) == "function" then Executor.request = httpR
    elseif type(fluxus) == "table" and type(fluxus.request) == "function" then Executor.request = fluxus.request
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. TYPES
-- ═══════════════════════════════════════════════════════════════════════════════

export type Palette = {
    bg: Color3, surface: Color3, elevated: Color3, card: Color3, hover: Color3,
    border: Color3, borderHi: Color3, text: Color3, text2: Color3, text3: Color3,
    lime: Color3, lime2: Color3, limeDim: Color3,
    danger: Color3, success: Color3, info: Color3, warn: Color3, black: Color3,
}
export type MaidTask  = RBXScriptConnection | Instance | Tween | thread | (() -> ())
export type Maid      = { _tasks: { MaidTask }, GiveTask: (self: Maid, t: MaidTask) -> (), Destroy: (self: Maid) -> () }
export type CommandDef = { name: string, desc: string, category: string, perm: number, run: (args: { string }) -> () }
export type HttpResponse = { success: boolean, status: number?, body: string?, error: string? }
export type ToastLevel = "info" | "warn" | "success" | "danger"

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. MAID
-- ═══════════════════════════════════════════════════════════════════════════════

local Maid = {}; Maid.__index = Maid
function Maid.new(): Maid
    return setmetatable({ _tasks = {} :: { MaidTask } }, Maid)
end
function Maid:GiveTask(t: MaidTask)
    table.insert(self._tasks, t)
end
function Maid:Destroy()
    local tasks = self._tasks
    self._tasks = {}
    for _, t in tasks do
        if typeof(t) == "RBXScriptConnection" then pcall(function() (t :: RBXScriptConnection):Disconnect() end)
        elseif typeof(t) == "Instance"          then pcall(function() (t :: Instance):Destroy() end)
        elseif typeof(t) == "Tween"            then pcall(function() (t :: Tween):Cancel() end); pcall(function() (t :: Tween):Destroy() end)
        elseif typeof(t) == "thread"           then pcall(function() task.cancel(t :: thread) end)
        elseif type(t) == "function"           then pcall(t)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. CONSTANTS & PALETTE
-- ═══════════════════════════════════════════════════════════════════════════════

local Z: Palette = {
    bg       = Color3.fromRGB(12, 12, 14),       surface  = Color3.fromRGB(18, 18, 21),
    elevated = Color3.fromRGB(26, 26, 30),       card     = Color3.fromRGB(22, 22, 26),
    hover    = Color3.fromRGB(34, 34, 40),
    border   = Color3.fromRGB(38, 38, 44),       borderHi = Color3.fromRGB(58, 58, 66),
    text     = Color3.fromRGB(250, 250, 252),    text2    = Color3.fromRGB(158, 158, 170),
    text3    = Color3.fromRGB(98, 98, 110),
    lime     = Color3.fromRGB(212, 232, 58),     lime2    = Color3.fromRGB(232, 249, 106),
    limeDim  = Color3.fromRGB(150, 168, 40),
    danger   = Color3.fromRGB(239, 68, 68),       success  = Color3.fromRGB(46, 204, 113),
    info     = Color3.fromRGB(59, 130, 246),     warn     = Color3.fromRGB(245, 170, 30),
    black    = Color3.fromRGB(0, 0, 0),
}

local SPRING = TweenInfo.new(0.45, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)
local SMOOTH = TweenInfo.new(0.30, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
local FAST   = TweenInfo.new(0.12, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local GENTLE = TweenInfo.new(0.50, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local PULSE  = TweenInfo.new(1.6,  Enum.EasingStyle.Sine,  Enum.EasingDirection.InOut, -1, true)

local F_HEAD = Enum.Font.GothamBold
local F_BODY = Enum.Font.GothamMedium
local F_THIN = Enum.Font.Gotham
local F_BTN  = Enum.Font.GothamBold
local F_CODE = Enum.Font.Code

local LOG_MAX    = 300
local CMD_PREFIX = ";"

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. LOGGING + CONSOLE CAPTURE
-- ═══════════════════════════════════════════════════════════════════════════════

local logs: { string } = {}
local logVersion = 0

local function log(level: "INFO" | "WARN" | "ERROR" | "DEBUG" | "OUTPUT", message: string)
    local entry = string.format("[%s] [%s] %s", os.date("%H:%M:%S"), level, message)
    table.insert(logs, entry)
    if #logs > LOG_MAX then table.remove(logs, 1) end
    logVersion += 1
end

local function safeCall<T>(fn: () -> T, ctx: string): (boolean, T?)
    return xpcall(fn, function(err)
        log("ERROR", ctx .. ": " .. tostring(err) .. "\n" .. debug.traceback())
    end)
end

pcall(function()
    if not _G["ZEX_ORIG_PRINT"] then
        _G["ZEX_ORIG_PRINT"] = print
        _G["ZEX_ORIG_WARN"]  = warn
    end
    local op = _G["ZEX_ORIG_PRINT"] :: (...any) -> ()
    local ow = _G["ZEX_ORIG_WARN"]  :: (...any) -> ()
    _G.print = function(...)
        local msg = table.concat({ ... }, " ")
        log("OUTPUT", "[print] " .. msg)
        op(...)
    end
    _G.warn = function(...)
        local msg = table.concat({ ... }, " ")
        log("WARN", "[warn] " .. msg)
        ow(...)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 7. HTTP ENGINE — SSRF-protected, rate-limited, whitelisted
-- ═══════════════════════════════════════════════════════════════════════════════

local WHITELIST: { string } = {
    "webhookpulse.vercel.app", "discord.com", "discordapp.com", "hooks.slack.com",
    "games.roblox.com", "api.roblox.com", "friends.roblox.com", "catalog.roblox.com",
}
local rateBuckets: { [string]: { tokens: number, last: number } } = {}
local RATE_MAX = 5; local RATE_WINDOW = 10

local function checkRateLimit(endpoint: string): boolean
    local now  = os.clock()
    local host = endpoint:match("^https://([^/]+)")
    if not host then return false end
    host = host:gsub(":%d+$", "")
    local b = rateBuckets[host]
    if not b then rateBuckets[host] = { tokens = RATE_MAX - 1, last = now }; return true end
    local elapsed = math.max(0, now - b.last)
    b.tokens = math.min(RATE_MAX, b.tokens + elapsed * (RATE_MAX / RATE_WINDOW))
    b.last = now
    if b.tokens >= 1 then b.tokens -= 1; return true end
    return false
end

local function isDomainAllowed(host: string): boolean
    for _, domain in ipairs(WHITELIST) do
        if host == domain or host:sub(-(#domain + 1)) == "." .. domain then return true end
    end
    return false
end

local function validateUrl(url: string): (boolean, string)
    if type(url) ~= "string"                   then return false, "URL must be string" end
    if not url:match("^https://")               then return false, "HTTPS required" end
    if url:match("^https://%d+%.%d+%.%d+%.%d+") then return false, "Direct IP not allowed" end
    if url:lower():match("^https://localhost")  then return false, "localhost blocked" end
    if url:lower():match("^https://0%.0%.0%.0") then return false, "0.0.0.0 blocked" end
    local host = url:match("^https://([^/?#]+)")
    if not host then return false, "Invalid URL" end
    host = host:gsub(":%d+$", ""):lower()
    if not isDomainAllowed(host)                then return false, "Not whitelisted: " .. host end
    return true, ""
end

local function httpRequest(options: { [string]: any }): HttpResponse
    local result: HttpResponse = { success = false, status = nil, body = nil, error = nil }
    local layers: { () -> { [string]: any }? } = {
        function()
            if not Executor.request then return nil end
            local ok, res = pcall(function() return (Executor.request :: (any) -> any)(options) end)
            return if ok then res else nil
        end,
        function()
            if not Services.HttpService then return nil end
            local ok, body = pcall(function()
                return (Services.HttpService :: HttpService):PostAsync(options.Url, options.Body or "",
                    Enum.HttpContentType.ApplicationJson, false, options.Headers or {})
            end)
            return if ok then { success = true, body = body, StatusCode = 200 } else nil
        end,
        function()
            local hs = Services.HttpService :: any
            if not hs or not hs.RequestAsync then return nil end
            local ok, res = pcall(function()
                return hs:RequestAsync({ Url = options.Url, Method = options.Method or "POST",
                    Headers = options.Headers or {}, Body = options.Body })
            end)
            return if ok then res else nil
        end,
    }
    for _, layer in ipairs(layers) do
        local res = layer()
        if res then
            local code = (res.StatusCode or res.status) :: number?
            if code and code >= 300 and code < 400 then result.error = "Redirect blocked (SSRF)"; return result end
            if (code and code >= 200 and code < 300) or res.success == true then
                result.success = true; result.status = code or 200
                result.body = (res.Body or res.body or "") :: string; return result
            end
        end
    end
    result.error = "All HTTP layers failed"; return result
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 8. PERMISSION SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

local PERM      = { USER = 1, MOD = 2, ADMIN = 3, OWNER = 4 }
local PERM_NAMES: { [number]: string } = { [1] = "USER", [2] = "MOD", [3] = "ADMIN", [4] = "OWNER" }
local userRank  = PERM.OWNER
local function canRun(p: number): boolean return userRank >= p end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 9. COMMAND STATE
-- ═══════════════════════════════════════════════════════════════════════════════

type CmdState = {
    fly: boolean, noclip: boolean, godmode: boolean, invisible: boolean,
    esp: boolean, aimbot: boolean, clicktp: boolean, spin: boolean,
    antifling: boolean, antiafk: boolean, fullbright: boolean,
    flyConn: RBXScriptConnection?, noclipConn: RBXScriptConnection?,
    spinConn: RBXScriptConnection?, espConn: RBXScriptConnection?,
    aimbotConn: RBXScriptConnection?, clicktpConn: RBXScriptConnection?,
    antiflingConn: RBXScriptConnection?, antiafkConn: RBXScriptConnection?,
    godmodeConn: RBXScriptConnection?, espInstances: { Instance },
}

local CMD_STATE: CmdState = {
    fly = false, noclip = false, godmode = false, invisible = false,
    esp = false, aimbot = false, clicktp = false, spin = false,
    antifling = false, antiafk = false, fullbright = false,
    flyConn = nil, noclipConn = nil, spinConn = nil, espConn = nil,
    aimbotConn = nil, clicktpConn = nil, antiflingConn = nil, antiafkConn = nil,
    godmodeConn = nil, espInstances = {},
}

local espMaid: Maid? = nil

-- ═══════════════════════════════════════════════════════════════════════════════
-- 10. CHARACTER HELPERS
-- ═══════════════════════════════════════════════════════════════════════════════

local function getCharacter(): Model?     return localPlayer and localPlayer.Character end
local function getHumanoid(): Humanoid?
    local c = getCharacter(); return c and c:FindFirstChildOfClass("Humanoid") :: Humanoid?
end
local function getRootPart(): Part?
    local c = getCharacter(); return c and c:FindFirstChild("HumanoidRootPart") :: Part?
end
local function getAnimator(): Animator?
    local h = getHumanoid(); return h and h:FindFirstChildOfClass("Animator") :: Animator?
end

local function getPlayerByName(name: string): Player?
    local lo = name:lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():find(lo, 1, true) or p.DisplayName:lower():find(lo, 1, true) then return p end
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 11. NOTIFICATION BRIDGE
-- ═══════════════════════════════════════════════════════════════════════════════

local showNotification: ((title: string, msg: string, level: ToastLevel) -> ())? = nil

local function notify(msg: string, level: ToastLevel?)
    local lv: ToastLevel = level or "info"
    log(if lv == "danger" then "ERROR" elseif lv == "warn" then "WARN" else "INFO", msg)
    if showNotification then
        local title = if lv == "danger" then "Error" elseif lv == "warn" then "Warning"
                      elseif lv == "success" then "Success" else "ZEX"
        showNotification(title, msg, lv)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 12. COMMAND REGISTRY (58 commands)
-- ═══════════════════════════════════════════════════════════════════════════════

local CommandRegistry: { [string]: CommandDef } = {}

local function reg(name: string, desc: string, cat: string, perm: number, run: (args: { string }) -> ())
    CommandRegistry[name:lower()] = { name = name, desc = desc, category = cat, perm = perm, run = run }
end

-- ── PLAYER ───────────────────────────────────────────────────────────────────
reg("fly", "Toggle fly", "Player", PERM.USER, function(args)
    CMD_STATE.fly = not CMD_STATE.fly
    local char = getCharacter(); if not char then notify("No character", "warn"); CMD_STATE.fly = false; return end
    local hum = getHumanoid(); if not hum then notify("No humanoid", "warn"); CMD_STATE.fly = false; return end
    local root = getRootPart(); if not root then notify("No HRP", "warn"); CMD_STATE.fly = false; return end
    if CMD_STATE.fly then
        hum.PlatformStand = true
        local bv = Instance.new("BodyVelocity")
        bv.Name = "ZEX_Fly"; bv.MaxForce = Vector3.new(9e9, 9e9, 9e9); bv.Velocity = Vector3.zero; bv.Parent = root
        CMD_STATE.flyConn = RunService.RenderStepped:Connect(function()
            if not CMD_STATE.fly then return end
            local cam = Workspace.CurrentCamera; local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.yAxis end
            bv.Velocity = if dir.Magnitude > 0 then dir.Unit * (tonumber(args[1]) or 50) else Vector3.zero
        end)
        notify("Fly ON", "success")
    else
        hum.PlatformStand = false
        if CMD_STATE.flyConn then CMD_STATE.flyConn:Disconnect(); CMD_STATE.flyConn = nil end
        local bv = root:FindFirstChild("ZEX_Fly"); if bv then bv:Destroy() end
        notify("Fly OFF")
    end
end)
reg("unfly", "Disable fly", "Player", PERM.USER, function(_) if CMD_STATE.fly then CommandRegistry["fly"].run({}) end end)

reg("noclip", "Toggle noclip", "Player", PERM.USER, function(_)
    CMD_STATE.noclip = not CMD_STATE.noclip
    local char = getCharacter(); if not char then CMD_STATE.noclip = false; return end
    if CMD_STATE.noclip then
        CMD_STATE.noclipConn = RunService.Stepped:Connect(function()
            if not CMD_STATE.noclip then return end
            local c = getCharacter(); if not c then return end
            for _, v in ipairs(c:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide = false end end
        end)
        notify("Noclip ON", "success")
    else
        if CMD_STATE.noclipConn then CMD_STATE.noclipConn:Disconnect(); CMD_STATE.noclipConn = nil end
        for _, v in ipairs(char:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide = true end end
        notify("Noclip OFF")
    end
end)
reg("clip", "Disable noclip", "Player", PERM.USER, function(_) if CMD_STATE.noclip then CommandRegistry["noclip"].run({}) end end)

reg("speed", "Set walkspeed", "Player", PERM.USER, function(args)
    local v = math.clamp(tonumber(args[1]) or 50, 0, 9999)
    local h = getHumanoid(); if h then h.WalkSpeed = v; notify("WalkSpeed = " .. v) end
end)
reg("ws", "WalkSpeed alias", "Player", PERM.USER, function(a) CommandRegistry["speed"].run(a) end)

reg("jump", "Set jumppower", "Player", PERM.USER, function(args)
    local v = math.clamp(tonumber(args[1]) or 75, 0, 9999)
    local h = getHumanoid(); if h then h.JumpPower = v; h.UseJumpPower = true; notify("JumpPower = " .. v) end
end)
reg("jp", "JumpPower alias", "Player", PERM.USER, function(a) CommandRegistry["jump"].run(a) end)

reg("gravity", "Set gravity", "World", PERM.USER, function(args)
    local v = tonumber(args[1]) or 196.2; Workspace.Gravity = v; notify("Gravity = " .. v)
end)
reg("heal", "Restore health", "Player", PERM.USER, function(_)
    local h = getHumanoid(); if h then h.Health = h.MaxHealth; notify("Healed", "success") end
end)
reg("kill", "Kill self", "Player", PERM.USER, function(_)
    local h = getHumanoid(); if h then h.Health = 0; notify("Killed") end
end)

reg("godmode", "Toggle godmode", "Player", PERM.MOD, function(_)
    CMD_STATE.godmode = not CMD_STATE.godmode
    if CMD_STATE.godmode then
        local hum = getHumanoid(); if not hum then notify("No humanoid", "warn"); CMD_STATE.godmode = false; return end
        hum.Health = hum.MaxHealth
        CMD_STATE.godmodeConn = hum:GetPropertyChangedSignal("Health"):Connect(function()
            if CMD_STATE.godmode and hum.Health < hum.MaxHealth then hum.Health = hum.MaxHealth end
        end)
        notify("Godmode ON", "success")
    else
        if CMD_STATE.godmodeConn then CMD_STATE.godmodeConn:Disconnect(); CMD_STATE.godmodeConn = nil end
        notify("Godmode OFF")
    end
end)
reg("ungodmode", "Disable godmode", "Player", PERM.MOD, function(_) if CMD_STATE.godmode then CommandRegistry["godmode"].run({}) end end)

reg("invisible", "Toggle invisibility", "Player", PERM.MOD, function(_)
    CMD_STATE.invisible = not CMD_STATE.invisible
    local char = getCharacter(); if not char then CMD_STATE.invisible = false; return end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") or v:IsA("Decal") or v:IsA("Texture") then
            v.Transparency = if CMD_STATE.invisible then 1 else 0
        end
        if v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled = not CMD_STATE.invisible end
    end
    notify(if CMD_STATE.invisible then "Invisible ON" else "Visible", if CMD_STATE.invisible then "success" else nil)
end)
reg("visible", "Disable invisibility", "Player", PERM.MOD, function(_) if CMD_STATE.invisible then CommandRegistry["invisible"].run({}) end end)

reg("sit", "Force sit", "Player", PERM.USER, function(_) local h = getHumanoid(); if h then h.Sit = true end end)
reg("unsit", "Force stand", "Player", PERM.USER, function(_) local h = getHumanoid(); if h then h.Sit = false end end)

reg("freeze", "Freeze character", "Player", PERM.MOD, function(_)
    local c = getCharacter(); if not c then return end
    for _, v in ipairs(c:GetDescendants()) do if v:IsA("BasePart") then v.Anchored = true end end
    notify("Frozen", "warn")
end)
reg("thaw", "Unfreeze", "Player", PERM.MOD, function(_)
    local c = getCharacter(); if not c then return end
    for _, v in ipairs(c:GetDescendants()) do if v:IsA("BasePart") then v.Anchored = false end end
    notify("Thawed")
end)
reg("anchor", "Anchor character", "Player", PERM.MOD, function(_) CommandRegistry["freeze"].run({}) end)
reg("unanchor", "Unanchor character", "Player", PERM.MOD, function(_) CommandRegistry["thaw"].run({}) end)

reg("spin", "Toggle spin", "Player", PERM.USER, function(_)
    CMD_STATE.spin = not CMD_STATE.spin
    if CMD_STATE.spin then
        CMD_STATE.spinConn = RunService.RenderStepped:Connect(function()
            if not CMD_STATE.spin then return end
            local r = getRootPart(); if r then r.CFrame = r.CFrame * CFrame.Angles(0, math.rad(10), 0) end
        end)
        notify("Spin ON")
    else
        if CMD_STATE.spinConn then CMD_STATE.spinConn:Disconnect(); CMD_STATE.spinConn = nil end
        notify("Spin OFF")
    end
end)

reg("dance", "Play dance emote", "Player", PERM.USER, function(_)
    local anim = getAnimator()
    if anim then
        local a = Instance.new("Animation"); a.AnimationId = "rbxassetid://507771019"
        anim:LoadAnimation(a):Play(); notify("Dancing", "success")
    else notify("No animator", "warn") end
end)
reg("reset", "Reset character", "Player", PERM.USER, function(_)
    pcall(function() localPlayer:LoadCharacter() end); notify("Reset")
end)
reg("refresh", "Respawn in place", "Player", PERM.USER, function(_)
    local root = getRootPart(); if not root then return end
    local pos = root.CFrame
    pcall(function() localPlayer:LoadCharacter() end)
    task.delay(0.5, function()
        local nc = localPlayer and localPlayer.Character; if not nc then return end
        local nr = nc:WaitForChild("HumanoidRootPart", 3) :: Part?; if nr then nr.CFrame = pos end
    end)
    notify("Refresh")
end)

reg("antiafk", "Toggle anti-AFK", "Utility", PERM.USER, function(_)
    CMD_STATE.antiafk = not CMD_STATE.antiafk
    if CMD_STATE.antiafk then
        notify("Anti-AFK ON", "success")
        task.spawn(function()
            while CMD_STATE.antiafk do
                local h = getHumanoid()
                if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.RunningNoPhysics) end) end
                task.wait(55)
            end
        end)
    else notify("Anti-AFK OFF") end
end)

reg("antifling", "Toggle anti-fling", "Player", PERM.USER, function(_)
    CMD_STATE.antifling = not CMD_STATE.antifling
    if CMD_STATE.antifling then
        CMD_STATE.antiflingConn = RunService.Heartbeat:Connect(function()
            if not CMD_STATE.antifling then return end
            local char = getCharacter(); if not char then return end
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
                    v.Velocity = Vector3.zero; v.RotVelocity = Vector3.zero
                end
            end
        end)
        notify("Anti-Fling ON", "success")
    else
        if CMD_STATE.antiflingConn then CMD_STATE.antiflingConn:Disconnect(); CMD_STATE.antiflingConn = nil end
        notify("Anti-Fling OFF")
    end
end)

-- ── COMBAT ───────────────────────────────────────────────────────────────────
reg("esp", "Toggle ESP", "Combat", PERM.MOD, function(_)
    CMD_STATE.esp = not CMD_STATE.esp
    if CMD_STATE.esp then
        if espMaid then espMaid:Destroy() end
        local em = Maid.new(); espMaid = em
        notify("ESP ON", "success")
        local function attachChar(p: Player, char: Model)
            local pMaid = Maid.new(); em:GiveTask(function() pMaid:Destroy() end)
            local head = char:FindFirstChild("Head") :: BasePart?; if not head then return end
            local hl = Instance.new("Highlight"); hl.Name = "ZEX_ESP"
            hl.FillColor = Z.danger; hl.OutlineColor = Z.lime
            hl.FillTransparency = 0.72; hl.OutlineTransparency = 0.25; hl.Parent = char; pMaid:GiveTask(hl)
            local bg = Instance.new("BillboardGui"); bg.Name = "ZEX_ESP"; bg.AlwaysOnTop = true
            bg.Size = UDim2.new(0, 120, 0, 40); bg.StudsOffset = Vector3.new(0, 2.8, 0); bg.Parent = head; pMaid:GiveTask(bg)
            local nameL = Instance.new("TextLabel"); nameL.Size = UDim2.new(1, 0, 0, 16); nameL.BackgroundTransparency = 1
            nameL.TextColor3 = Z.lime; nameL.Font = F_BODY; nameL.TextSize = 12; nameL.Text = p.Name
            nameL.TextStrokeTransparency = 0.5; nameL.Parent = bg
            local distL = Instance.new("TextLabel"); distL.Size = UDim2.new(1, 0, 0, 14); distL.Position = UDim2.new(0, 0, 0, 16)
            distL.BackgroundTransparency = 1; distL.TextColor3 = Z.text2; distL.Font = F_THIN; distL.TextSize = 10
            distL.Text = "? studs"; distL.TextStrokeTransparency = 0.6; distL.Parent = bg
            local hpBg = Instance.new("Frame"); hpBg.Size = UDim2.new(1, 0, 0, 4); hpBg.Position = UDim2.new(0, 0, 0, 32)
            hpBg.BackgroundColor3 = Z.elevated; hpBg.BorderSizePixel = 0; hpBg.Parent = bg
            local cc1 = Instance.new("UICorner"); cc1.CornerRadius = UDim.new(0, 2); cc1.Parent = hpBg
            local hpFill = Instance.new("Frame"); hpFill.Size = UDim2.new(1, 0, 1, 0); hpFill.BackgroundColor3 = Z.success
            hpFill.BorderSizePixel = 0; hpFill.Parent = hpBg
            local cc2 = Instance.new("UICorner"); cc2.CornerRadius = UDim.new(0, 2); cc2.Parent = hpFill
            local hum = char:FindFirstChildOfClass("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
            pMaid:GiveTask(RunService.RenderStepped:Connect(function()
                if not hum or not hum.Parent then return end
                local hp = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                hpFill.Size = UDim2.new(hp, 0, 1, 0)
                hpFill.BackgroundColor3 = if hp > 0.5 then Z.success elseif hp > 0.25 then Z.warn else Z.danger
                local mc = localPlayer.Character
                if hrp and mc then
                    local myHrp = mc:FindFirstChild("HumanoidRootPart") :: BasePart?
                    if myHrp then distL.Text = math.floor((hrp.Position - myHrp.Position).Magnitude) .. " studs" end
                end
            end))
        end
        local function addESP(p: Player)
            if p == localPlayer then return end
            if p.Character then attachChar(p, p.Character) end
            em:GiveTask(p.CharacterAdded:Connect(function(char) task.wait(0.3); attachChar(p, char) end))
        end
        for _, p in ipairs(Players:GetPlayers()) do addESP(p) end
        CMD_STATE.espConn = Players.PlayerAdded:Connect(addESP)
        em:GiveTask(function() if CMD_STATE.espConn then CMD_STATE.espConn:Disconnect(); CMD_STATE.espConn = nil end end)
    else
        if espMaid then espMaid:Destroy(); espMaid = nil end
        notify("ESP OFF")
    end
end)
reg("unesp", "Disable ESP", "Combat", PERM.MOD, function(_) if CMD_STATE.esp then CommandRegistry["esp"].run({}) end end)

reg("aimbot", "Toggle aimbot", "Combat", PERM.MOD, function(_)
    CMD_STATE.aimbot = not CMD_STATE.aimbot
    if CMD_STATE.aimbot then
        CMD_STATE.aimbotConn = RunService.RenderStepped:Connect(function()
            if not CMD_STATE.aimbot then return end
            local cam = Workspace.CurrentCamera; local best = math.huge; local nearest: BasePart? = nil
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= localPlayer and p.Character then
                    local h = p.Character:FindFirstChild("Head") :: BasePart?
                    if h then
                        local d = (h.Position - cam.CFrame.Position).Magnitude
                        if d < best then best = d; nearest = h end
                    end
                end
            end
            if nearest then cam.CFrame = CFrame.new(cam.CFrame.Position, nearest.Position) end
        end)
        notify("Aimbot ON", "success")
    else
        if CMD_STATE.aimbotConn then CMD_STATE.aimbotConn:Disconnect(); CMD_STATE.aimbotConn = nil end
        notify("Aimbot OFF")
    end
end)
reg("unaimbot", "Disable aimbot", "Combat", PERM.MOD, function(_) if CMD_STATE.aimbot then CommandRegistry["aimbot"].run({}) end end)

reg("clicktp", "Toggle click-TP (Ctrl+Click)", "Combat", PERM.USER, function(_)
    CMD_STATE.clicktp = not CMD_STATE.clicktp
    if CMD_STATE.clicktp then
        CMD_STATE.clicktpConn = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1
                and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                local mouse = localPlayer:GetMouse()
                local root = getRootPart()
                if mouse and root then
                    local ray = Workspace.CurrentCamera:ViewportPointToRay(input.Position.X, input.Position.Y)
                    local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000)
                    if result then root.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0))
                    else root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0)) end
                end
            end
        end)
        notify("ClickTP ON")
    else
        if CMD_STATE.clicktpConn then CMD_STATE.clicktpConn:Disconnect(); CMD_STATE.clicktpConn = nil end
        notify("ClickTP OFF")
    end
end)

-- ── WORLD ────────────────────────────────────────────────────────────────────
reg("fullbright", "Toggle fullbright", "World", PERM.USER, function(_)
    CMD_STATE.fullbright = not CMD_STATE.fullbright
    if CMD_STATE.fullbright then
        Lighting.Brightness = 2; Lighting.GlobalShadows = false; Lighting.ClockTime = 12; Lighting.FogEnd = 1e6
        notify("Fullbright ON", "success")
    else notify("Fullbright OFF") end
end)
reg("time", "Set lighting time", "World", PERM.USER, function(args)
    local v = tonumber(args[1]) or 12; Lighting.ClockTime = v; notify("Time = " .. v)
end)
reg("fog", "Set fog end", "World", PERM.USER, function(args)
    local v = tonumber(args[1]) or 100000; Lighting.FogEnd = v; notify("Fog = " .. v)
end)
reg("clearterrain", "Clear terrain", "World", PERM.ADMIN, function(_)
    local t = Workspace:FindFirstChildOfClass("Terrain"); if t then t:Clear(); notify("Terrain cleared", "warn") end
end)

-- ── SERVER ───────────────────────────────────────────────────────────────────
reg("rejoin", "Rejoin server", "Server", PERM.USER, function(_)
    notify("Rejoining..."); TeleportService:Teleport(game.PlaceId, localPlayer)
end)
reg("serverhop", "Hop to different server", "Server", PERM.USER, function(_)
    if not Executor.request then notify("Executor HTTP unavailable", "danger"); return end
    notify("Server hopping...")
    task.spawn(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local res = httpRequest({ Url = url, Method = "GET", Headers = {} })
        if not res.success or not res.body then notify("Serverhop failed", "warn"); return end
        local ok, data = pcall(function() return HttpService:JSONDecode(res.body :: string) end)
        if ok and data and data.data then
            for _, server in ipairs(data.data) do
                if server.id ~= game.JobId and server.playing < server.maxPlayers then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, localPlayer); return
                end
            end
        end
        notify("No available servers", "warn")
    end)
end)
reg("teleport", "Teleport to player", "Server", PERM.MOD, function(args)
    local t = getPlayerByName(args[1] or ""); if not t then notify("Not found", "warn"); return end
    local tr = t.Character and t.Character:FindFirstChild("HumanoidRootPart") :: Part?
    local r = getRootPart()
    if tr and r then r.CFrame = tr.CFrame; notify("Teleported to " .. t.Name, "success") end
end)
reg("tp", "Teleport alias", "Server", PERM.MOD, function(a) CommandRegistry["teleport"].run(a) end)
reg("bring", "Bring player [local]", "Server", PERM.ADMIN, function(args)
    local t = getPlayerByName(args[1] or ""); if not t or not t.Character then return end
    local tr = t.Character:FindFirstChild("HumanoidRootPart") :: Part?; local r = getRootPart()
    if tr and r then tr.CFrame = r.CFrame; notify("Brought " .. t.Name .. " [local]", "warn") end
end)
reg("fling", "Fling player [local]", "Server", PERM.ADMIN, function(args)
    local t = getPlayerByName(args[1] or ""); if not t or not t.Character then return end
    local tr = t.Character:FindFirstChild("HumanoidRootPart") :: Part?
    if tr then
        local bv = Instance.new("BodyVelocity"); bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        bv.Velocity = Vector3.new(0, 500, 0); bv.Parent = tr; task.delay(0.5, function() bv:Destroy() end)
        notify("Flung " .. t.Name .. " [local]", "warn")
    end
end)
reg("killall", "Kill all [local]", "Server", PERM.OWNER, function(_)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer and p.Character then
            local h = p.Character:FindFirstChildOfClass("Humanoid") :: Humanoid?
            if h then pcall(function() h.Health = 0 end) end
        end
    end
    notify("Killed all [local]", "warn")
end)

-- ── UTILITY ──────────────────────────────────────────────────────────────────
reg("btools", "Give build tool", "Utility", PERM.MOD, function(_)
    local bp = localPlayer:FindFirstChildOfClass("Backpack"); if not bp then return end
    local t = Instance.new("Tool"); t.RequiresHandle = false; t.ToolTip = "ZEX Build"; t.Parent = bp; notify("BTools given")
end)
reg("removetools", "Remove all tools", "Utility", PERM.MOD, function(_)
    local bp = localPlayer:FindFirstChildOfClass("Backpack")
    if bp then for _, v in ipairs(bp:GetChildren()) do if v:IsA("Tool") then v:Destroy() end end end
    local char = getCharacter()
    if char then for _, v in ipairs(char:GetChildren()) do if v:IsA("Tool") then v:Destroy() end end end
    notify("Tools removed")
end)
reg("view", "View player camera", "Utility", PERM.MOD, function(args)
    local t = getPlayerByName(args[1] or "")
    if t and t.Character then
        local h = t.Character:FindFirstChildOfClass("Humanoid") :: Humanoid?
        Workspace.CurrentCamera.CameraSubject = h or t.Character; notify("Viewing " .. t.Name)
    end
end)
reg("unview", "Reset camera", "Utility", PERM.MOD, function(_)
    local h = getHumanoid(); if h then Workspace.CurrentCamera.CameraSubject = h; notify("Camera reset") end
end)
reg("copypos", "Copy position to clipboard", "Utility", PERM.USER, function(_)
    local root = getRootPart(); if not root then notify("No HRP", "warn"); return end
    local p = root.Position; local s = string.format("%.2f, %.2f, %.2f", p.X, p.Y, p.Z)
    if Executor.setclipboard then pcall(function() (Executor.setclipboard :: (string) -> boolean)(s) end); notify("Copied: " .. s, "success")
    else notify("Pos: " .. s) end
end)
reg("nameresp", "Name respawn", "Utility", PERM.USER, function(_)
    if not localPlayer then return end
    local dn = localPlayer.DisplayName; localPlayer.DisplayName = " "; task.wait(0.1); localPlayer.DisplayName = dn
    notify("Name respawned")
end)
reg("walkspeed", "Set walkspeed", "Player", PERM.USER, function(a) CommandRegistry["speed"].run(a) end)
reg("jumppower", "Set jumppower", "Player", PERM.USER, function(a) CommandRegistry["jump"].run(a) end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 13. MOTION ENGINE — tween · ripple · hover
-- ═══════════════════════════════════════════════════════════════════════════════

local activeTweens: { [Instance]: Tween } = {}

local function tween(obj: Instance, props: { [string]: any }, info: TweenInfo?, maid: Maid?): Tween?
    if not obj or not obj.Parent then return nil end
    if activeTweens[obj] then
        pcall(function() activeTweens[obj]:Cancel() end); pcall(function() activeTweens[obj]:Destroy() end)
        activeTweens[obj] = nil
    end
    local ok, tw = pcall(function() return TweenService:Create(obj, info or SMOOTH, props) end)
    if not ok or not tw then return nil end
    activeTweens[obj] = tw
    local conn = (tw :: Tween).Completed:Connect(function()
        if activeTweens[obj] == tw then activeTweens[obj] = nil end
        pcall(function() (tw :: Tween):Destroy() end)
    end)
    if maid then maid:GiveTask(function()
        if activeTweens[obj] == tw then activeTweens[obj] = nil end
        pcall(function() conn:Disconnect() end)
        pcall(function() (tw :: Tween):Cancel() end); pcall(function() (tw :: Tween):Destroy() end)
    end) end
    (tw :: Tween):Play(); return tw
end

local function hoverFx(inst: GuiObject, maid: Maid, normal: { [string]: any }, hover: { [string]: any })
    maid:GiveTask(inst.MouseEnter:Connect(function() tween(inst, hover, FAST, maid) end))
    maid:GiveTask(inst.MouseLeave:Connect(function() tween(inst, normal, FAST, maid) end))
end

local function ripple(btn: GuiObject, color: Color3?)
    if not btn or not btn.Parent then return end
    local r = Instance.new("Frame")
    r.BackgroundColor3 = color or Z.lime; r.BackgroundTransparency = 0.78; r.BorderSizePixel = 0
    r.AnchorPoint = Vector2.new(0.5, 0.5); r.ZIndex = btn.ZIndex + 5
    local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(1, 0); cc.Parent = r
    local mp = UserInputService:GetMouseLocation()
    local rel = Vector2.new(mp.X, mp.Y) - btn.AbsolutePosition
    r.Position = UDim2.fromOffset(rel.X, rel.Y); r.Size = UDim2.fromOffset(0, 0); r.Parent = btn
    local big = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y) * 2.2
    TweenService:Create(r, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.fromOffset(big, big), BackgroundTransparency = 1 }):Play()
    task.delay(0.52, function() if r then r:Destroy() end end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 14. UI PRIMITIVES
-- ═══════════════════════════════════════════════════════════════════════════════

local function corner(r: number): UICorner
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); return c
end
local function stroke(col: Color3, t: number): UIStroke
    local s = Instance.new("UIStroke"); s.Color = col; s.Thickness = t; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; return s
end
local function pad(all: number): UIPadding
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, all); p.PaddingBottom = UDim.new(0, all)
    p.PaddingLeft = UDim.new(0, all); p.PaddingRight = UDim.new(0, all); return p
end
local function mk<T>(class: string, props: { [string]: any }): T
    local o = Instance.new(class)
    for k, v in pairs(props) do if k ~= "Parent" then (o :: any)[k] = v end end
    if props.Parent then o.Parent = props.Parent end
    return o :: T
end
local function Frame(p: { [string]: any }): Frame return mk("Frame", p) end
local function Label(p: { [string]: any }): TextLabel
    p.BackgroundTransparency = p.BackgroundTransparency or 1; p.Font = p.Font or F_BODY
    p.TextColor3 = p.TextColor3 or Z.text; p.TextSize = p.TextSize or 12
    return mk("TextLabel", p)
end
local function Button(p: { [string]: any }): TextButton
    p.AutoButtonColor = false; p.BorderSizePixel = 0; p.Font = p.Font or F_BTN
    return mk("TextButton", p)
end
local function TextBox(p: { [string]: any }): TextBox
    p.BorderSizePixel = 0; p.Font = p.Font or F_CODE; p.ClearTextOnFocus = p.ClearTextOnFocus or false
    return mk("TextBox", p)
end
local function Scroll(p: { [string]: any }): ScrollingFrame
    p.BorderSizePixel = 0; p.ScrollBarThickness = p.ScrollBarThickness or 3
    p.ScrollBarImageColor3 = p.ScrollBarImageColor3 or Z.border; p.ScrollBarImageTransparency = 0.3
    return mk("ScrollingFrame", p)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 15. VECTOR ICON SYSTEM — drawn from Frames, no asset dependency
-- ═══════════════════════════════════════════════════════════════════════════════

local function drawIcon(name: string, parent: GuiObject, color: Color3): Frame
    local c = Frame({ Name = "Icon", BackgroundTransparency = 1, Size = UDim2.fromOffset(20, 20),
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = parent })
    local function bit(w: number, h: number, x: number, y: number, rot: number?, round: number?): Frame
        local f = Frame({ BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(w, h), Position = UDim2.new(0.5, x, 0.5, y), Rotation = rot or 0, Parent = c })
        local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, round or 1); cc.Parent = f; return f
    end
    local function ring(d: number, th: number, x: number, y: number)
        local f = Frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(d, d), Position = UDim2.new(0.5, x, 0.5, y), Parent = c })
        local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(1, 0); cc.Parent = f
        local s = stroke(color, th); s.Parent = f
    end
    if name == "dashboard" then
        for _, o in { {-4, -4}, {4, -4}, {-4, 4}, {4, 4} } do bit(7, 7, o[1], o[2], 0, 2) end
    elseif name == "commands" then
        bit(14, 2.5, 0, -5, 0, 1); bit(14, 2.5, 0, 0, 0, 1); bit(10, 2.5, -2, 5, 0, 1)
    elseif name == "player" then
        local h = bit(7, 7, 0, -5); h:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)
        bit(13, 7, 0, 5, 0, 3)
    elseif name == "combat" then
        ring(16, 2, 0, 0); bit(3, 3, 0, 0, 0, 1); bit(2, 5, 0, -9, 0, 1); bit(2, 5, 0, 9, 0, 1); bit(5, 2, -9, 0, 0, 1); bit(5, 2, 9, 0, 0, 1)
    elseif name == "world" then
        bit(13, 2, 0, -5, 0, 1); bit(13, 2, 0, 0, 0, 1); bit(13, 2, 0, 5, 0, 1)
        bit(2, 16, -6, 0, 0, 1)
    elseif name == "server" then
        for _, y in { -6, 0, 6 } do bit(15, 4, 0, y, 0, 2) end
    elseif name == "editor" then
        bit(7, 2, -4, -3, 55, 1); bit(7, 2, -4, 3, -55, 1)
        bit(7, 2, 4, -3, -55, 1); bit(7, 2, 4, 3, 55, 1)
    elseif name == "console" then
        bit(6, 2, -3, -2, 40, 1); bit(6, 2, -3, 2, -40, 1); bit(7, 2, 3, 5, 0, 1)
    elseif name == "settings" then
        ring(13, 2, 0, 0); bit(4, 4, 0, 0, 0, 1)
        for _, o in { {0, -9}, {9, 0}, {0, 9}, {-9, 0} } do bit(4, 4, o[1], o[2], 0, 1) end
    elseif name == "close" then
        bit(16, 2, 0, 0, 45, 1); bit(16, 2, 0, 0, -45, 1)
    elseif name == "minimize" then
        bit(14, 2, 0, 6, 0, 1)
    elseif name == "search" then
        ring(11, 2, -2, -2); bit(6, 2, 5, 5, 45, 1)
    elseif name == "bolt" then
        bit(4, 8, -1, -3, 18, 1); bit(4, 8, 1, 3, 18, 1)
    else
        bit(10, 10, 0, 0, 0, 2)
    end
    return c
end

local function recolorIcon(iconC: Frame, color: Color3)
    for _, ch in ipairs(iconC:GetChildren()) do
        if ch:IsA("Frame") then
            if ch.BackgroundTransparency < 1 then ch.BackgroundColor3 = color end
            local s = ch:FindFirstChildOfClass("UIStroke"); if s then s.Color = color end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 16. SCREEN GUI · BLUR · WINDOW · SHADOW
-- ═══════════════════════════════════════════════════════════════════════════════

local rootMaid = Maid.new()
local screenGui: ScreenGui

pcall(function()
    local parent: Instance
    if Executor.gethui then
        local ok, hui = pcall(Executor.gethui :: () -> Instance)
        if ok and hui then parent = hui end
    end
    if not parent and Executor.cloneref then
        local ok, ref = pcall(function() return (Executor.cloneref :: (Instance) -> Instance)(game.CoreGui) end)
        if ok and ref then parent = ref end
    end
    if not parent then parent = game.CoreGui end
    screenGui = mk("ScreenGui", { Name = "ZEX_v741", ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999, Parent = parent })
    rootMaid:GiveTask(screenGui)
end)
if not screenGui then log("ERROR", "[ZEX] ScreenGui failed"); return end

local WIN_W, WIN_H = 760, 500

-- background blur
local blurEnabled = true
local blur: BlurEffect = mk("BlurEffect", { Name = "ZEX_Blur", Size = 0, Parent = Lighting })
rootMaid:GiveTask(blur)

-- dim layer
local dim = Frame({ Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Z.black,
    BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1, Parent = screenGui })
rootMaid:GiveTask(dim)

-- holder (draggable, carries shadow + window)
local holder = Frame({ Name = "Holder", Size = UDim2.fromOffset(WIN_W, WIN_H),
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    BackgroundTransparency = 1, ZIndex = 2, Parent = screenGui })

-- drop shadow (9-slice)
mk("ImageLabel", { Name = "Shadow", BackgroundTransparency = 1, Image = "rbxassetid://6015897843",
    ImageColor3 = Z.black, ImageTransparency = 0.35, ScaleType = Enum.ScaleType.Slice,
    SliceCenter = Rect.new(49, 49, 450, 450), Size = UDim2.new(1, 90, 1, 90),
    Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 1, Parent = holder })

-- window
local window = Frame({ Name = "Window", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Z.surface,
    BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 2, Parent = holder })
corner(12).Parent = window
stroke(Z.border, 1).Parent = window
local uiScale = mk("UIScale", { Scale = 1, Parent = window })

-- ═══════════════════════════════════════════════════════════════════════════════
-- 17. TITLE BAR
-- ═══════════════════════════════════════════════════════════════════════════════

local topbar = Frame({ Name = "TopBar", Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = Z.card,
    BorderSizePixel = 0, ZIndex = 3, Parent = window })
Frame({ Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = Z.border,
    BorderSizePixel = 0, ZIndex = 4, Parent = topbar })

-- brand mark
local mark = Frame({ Size = UDim2.fromOffset(22, 22), Position = UDim2.new(0, 16, 0.5, 0),
    AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Z.lime, BorderSizePixel = 0, ZIndex = 4, Parent = topbar })
corner(6).Parent = mark
drawIcon("bolt", mark, Z.black)
Label({ Text = "ZEX", Font = F_HEAD, TextSize = 16, TextColor3 = Z.text, Size = UDim2.new(0, 46, 1, 0),
    Position = UDim2.new(0, 46, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4, Parent = topbar })
local verChip = Frame({ Size = UDim2.fromOffset(50, 18), Position = UDim2.new(0, 90, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
    BackgroundColor3 = Z.elevated, BorderSizePixel = 0, ZIndex = 4, Parent = topbar })
corner(9).Parent = verChip; stroke(Z.border, 1).Parent = verChip
Label({ Text = "v7.4.1", Font = F_BODY, TextSize = 9, TextColor3 = Z.lime, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = verChip })
local permChip = Frame({ Size = UDim2.fromOffset(58, 18), Position = UDim2.new(0, 148, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
    BackgroundColor3 = Z.elevated, BorderSizePixel = 0, ZIndex = 4, Parent = topbar })
corner(9).Parent = permChip; stroke(Z.border, 1).Parent = permChip
local permChipLbl = Label({ Text = PERM_NAMES[userRank], Font = F_BODY, TextSize = 9, TextColor3 = Z.text2,
    Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = permChip })

local function topBtn(icon: string, xoff: number, hoverCol: Color3): TextButton
    local b = Button({ Text = "", Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, xoff, 0.5, 0),
        AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = Z.elevated, BackgroundTransparency = 1, ZIndex = 4, Parent = topbar })
    corner(7).Parent = b
    local ic = drawIcon(icon, b, Z.text2)
    hoverFx(b, rootMaid, { BackgroundTransparency = 1 }, { BackgroundTransparency = 0 })
    b.MouseEnter:Connect(function() recolorIcon(ic, hoverCol) end)
    b.MouseLeave:Connect(function() recolorIcon(ic, Z.text2) end)
    return b
end
local closeBtn = topBtn("close", -10, Z.danger)
local minBtn   = topBtn("minimize", -46, Z.lime)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 18. SIDEBAR + SLIDING INDICATOR + TOOLTIPS
-- ═══════════════════════════════════════════════════════════════════════════════

local SIDEBAR_W = 64
local sidebar = Frame({ Name = "Sidebar", Size = UDim2.new(0, SIDEBAR_W, 1, -46), Position = UDim2.new(0, 0, 0, 46),
    BackgroundColor3 = Z.card, BorderSizePixel = 0, ZIndex = 3, Parent = window })
Frame({ Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BackgroundColor3 = Z.border, BorderSizePixel = 0, ZIndex = 4, Parent = sidebar })

local TABS = {
    { id = "Dashboard", icon = "dashboard" }, { id = "Player", icon = "player" }, { id = "Combat", icon = "combat" },
    { id = "World", icon = "world" }, { id = "Server", icon = "server" }, { id = "Commands", icon = "commands" },
    { id = "Console", icon = "console" }, { id = "Settings", icon = "settings" },
}
local BTN_SZ, BTN_GAP, BTN_Y0 = 44, 8, 14
local indicator = Frame({ Name = "Indicator", Size = UDim2.fromOffset(3, 24), AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 0, 0, BTN_Y0 + BTN_SZ / 2), BackgroundColor3 = Z.lime, BorderSizePixel = 0, ZIndex = 5, Parent = sidebar })
corner(2).Parent = indicator

local tooltip = Frame({ Name = "Tooltip", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22),
    BackgroundColor3 = Z.elevated, BorderSizePixel = 0, Visible = false, ZIndex = 50, Parent = window })
corner(6).Parent = tooltip; stroke(Z.border, 1).Parent = tooltip
local tooltipLbl = Label({ Text = "", Font = F_BODY, TextSize = 11, TextColor3 = Z.text, AutomaticSize = Enum.AutomaticSize.X,
    Size = UDim2.new(0, 0, 1, 0), ZIndex = 51, Parent = tooltip })
mk("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = tooltipLbl })

local sidebarBtns: { [string]: { btn: TextButton, icon: Frame, y: number } } = {}
for i, t in ipairs(TABS) do
    local y = BTN_Y0 + (i - 1) * (BTN_SZ + BTN_GAP)
    local b = Button({ Text = "", Size = UDim2.fromOffset(BTN_SZ, BTN_SZ), Position = UDim2.new(0.5, 0, 0, y),
        AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Z.elevated, BackgroundTransparency = 1, ZIndex = 4, Parent = sidebar })
    corner(9).Parent = b
    local ic = drawIcon(t.icon, b, Z.text3)
    sidebarBtns[t.id] = { btn = b, icon = ic, y = y + BTN_SZ / 2 }
    b.MouseEnter:Connect(function()
        tooltipLbl.Text = t.id
        tooltip.Position = UDim2.new(0, SIDEBAR_W + 8, 0, 46 + y + (BTN_SZ - 22) / 2)
        tooltip.Visible = true
    end)
    b.MouseLeave:Connect(function() tooltip.Visible = false end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 19. CONTENT AREA + INPUT BAR
-- ═══════════════════════════════════════════════════════════════════════════════

local INPUT_H = 40
local content = Frame({ Name = "Content", Size = UDim2.new(1, -SIDEBAR_W, 1, -46 - INPUT_H),
    Position = UDim2.new(0, SIDEBAR_W, 0, 46), BackgroundColor3 = Z.bg, BorderSizePixel = 0,
    ClipsDescendants = true, ZIndex = 3, Parent = window })
local titleStrip = Frame({ Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, ZIndex = 4, Parent = content })
local tabTitle = Label({ Text = "Dashboard", Font = F_HEAD, TextSize = 18, TextColor3 = Z.text,
    Size = UDim2.new(1, -40, 1, 0), Position = UDim2.new(0, 20, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = titleStrip })

local pageHost = Frame({ Name = "PageHost", Size = UDim2.new(1, 0, 1, -40), Position = UDim2.new(0, 0, 0, 40),
    BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 4, Parent = content })

-- ═══════════════════════════════════════════════════════════════════════════════
-- 20. COMPONENT LIBRARY
-- ═══════════════════════════════════════════════════════════════════════════════

type SectionApi = { body: Frame, layout: UIListLayout }

local Components = {}

function Components.Page(host: Frame): (ScrollingFrame, UIListLayout)
    local s = Scroll({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 4, Parent = host })
    mk("UIPadding", { PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20),
        PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 16), Parent = s })
    local l = mk("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12), Parent = s })
    return s, l
end

function Components.Section(parent: Instance, title: string, order: number): SectionApi
    local card = Frame({ BackgroundColor3 = Z.surface, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 40),
        AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, ZIndex = 4, Parent = parent })
    corner(10).Parent = card; stroke(Z.border, 1).Parent = card
    Label({ Text = title:upper(), Font = F_HEAD, TextSize = 11, TextColor3 = Z.text2, Size = UDim2.new(1, -28, 0, 30),
        Position = UDim2.new(0, 16, 0, 4), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5, Parent = card })
    Frame({ Size = UDim2.fromOffset(20, 3), Position = UDim2.new(0, 16, 0, 28), BackgroundColor3 = Z.lime, BorderSizePixel = 0, ZIndex = 5, Parent = card })
    local body = Frame({ BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 0), Position = UDim2.new(0, 10, 0, 38),
        AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 5, Parent = card })
    local layout = mk("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = body })
    mk("UIPadding", { PaddingBottom = UDim.new(0, 10), Parent = body })
    return { body = body, layout = layout }
end

local function rowBase(parent: Instance, h: number, order: number): Frame
    local row = Frame({ BackgroundColor3 = Z.card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, h),
        LayoutOrder = order, ZIndex = 5, Parent = parent })
    corner(8).Parent = row; stroke(Z.border, 1).Parent = row
    return row
end

function Components.Toggle(parent: Instance, maid: Maid, order: number, cfg: { Title: string, Get: () -> boolean, Toggle: () -> () })
    local row = rowBase(parent, 36, order)
    Label({ Text = cfg.Title, Font = F_BODY, TextSize = 12, TextColor3 = Z.text, Size = UDim2.new(1, -72, 1, 0),
        Position = UDim2.new(0, 14, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6, Parent = row })
    local track = Frame({ Size = UDim2.fromOffset(40, 22), Position = UDim2.new(1, -52, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Z.elevated, BorderSizePixel = 0, ZIndex = 6, Parent = row })
    corner(11).Parent = track; local tStroke = stroke(Z.border, 1); tStroke.Parent = track
    local knob = Frame({ Size = UDim2.fromOffset(16, 16), Position = UDim2.new(0, 3, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Z.text2, BorderSizePixel = 0, ZIndex = 7, Parent = track })
    corner(8).Parent = knob
    local hit = Button({ Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 8, Parent = row })
    local function render(on: boolean)
        tween(knob, { Position = UDim2.new(0, (if on then 21 else 3), 0.5, 0), BackgroundColor3 = if on then Z.black else Z.text2 }, FAST)
        tween(track, { BackgroundColor3 = if on then Z.lime else Z.elevated }, FAST)
        tStroke.Color = if on then Z.lime else Z.border
    end
    render(cfg.Get())
    maid:GiveTask(hit.MouseButton1Click:Connect(function()
        safeCall(cfg.Toggle, "Toggle:" .. cfg.Title); render(cfg.Get())
    end))
    hoverFx(row, maid, { BackgroundColor3 = Z.card }, { BackgroundColor3 = Z.hover })
    return { Set = render }
end

function Components.Slider(parent: Instance, maid: Maid, order: number, cfg: { Title: string, Min: number, Max: number, Default: number, Suffix: string?, Callback: (n: number) -> () })
    local row = rowBase(parent, 52, order)
    Label({ Text = cfg.Title, Font = F_BODY, TextSize = 12, TextColor3 = Z.text, Size = UDim2.new(1, -90, 0, 22),
        Position = UDim2.new(0, 14, 0, 4), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6, Parent = row })
    local valLbl = Label({ Text = "", Font = F_CODE, TextSize = 12, TextColor3 = Z.lime, Size = UDim2.new(0, 70, 0, 22),
        Position = UDim2.new(1, -80, 0, 4), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6, Parent = row })
    local track = Frame({ Size = UDim2.new(1, -28, 0, 6), Position = UDim2.new(0, 14, 1, -16),
        BackgroundColor3 = Z.elevated, BorderSizePixel = 0, ZIndex = 6, Parent = row })
    corner(3).Parent = track
    local fill = Frame({ Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Z.lime, BorderSizePixel = 0, ZIndex = 7, Parent = track })
    corner(3).Parent = fill
    local knob = Frame({ Size = UDim2.fromOffset(14, 14), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Z.text, BorderSizePixel = 0, ZIndex = 8, Parent = track })
    corner(7).Parent = knob; stroke(Z.lime, 2).Parent = knob
    local value = math.clamp(cfg.Default, cfg.Min, cfg.Max)
    local function render(v: number, fire: boolean)
        value = math.clamp(v, cfg.Min, cfg.Max)
        local a = (value - cfg.Min) / math.max(cfg.Max - cfg.Min, 1e-6)
        fill.Size = UDim2.new(a, 0, 1, 0); knob.Position = UDim2.new(a, 0, 0.5, 0)
        valLbl.Text = string.format("%.0f%s", value, cfg.Suffix or "")
        if fire then safeCall(function() cfg.Callback(value) end, "Slider:" .. cfg.Title) end
    end
    render(value, false)
    local dragging = false
    local function setFromX(px: number)
        local a = math.clamp((px - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        render(cfg.Min + a * (cfg.Max - cfg.Min), true)
    end
    maid:GiveTask(track.InputBegan:Connect(function(inp: InputObject)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true; setFromX(inp.Position.X)
        end
    end))
    maid:GiveTask(UserInputService.InputChanged:Connect(function(inp: InputObject)
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            setFromX(inp.Position.X)
        end
    end))
    maid:GiveTask(UserInputService.InputEnded:Connect(function(inp: InputObject)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end))
    return { Set = function(v: number) render(v, false) end }
end

function Components.Button(parent: Instance, maid: Maid, order: number, cfg: { Title: string, Color: Color3?, Callback: () -> () })
    local row = Frame({ BackgroundColor3 = cfg.Color or Z.elevated, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 34),
        LayoutOrder = order, ClipsDescendants = true, ZIndex = 5, Parent = parent })
    corner(8).Parent = row
    local accent = cfg.Color ~= nil
    if not accent then stroke(Z.border, 1).Parent = row end
    local lbl = Label({ Text = cfg.Title, Font = F_BTN, TextSize = 12, TextColor3 = if accent then Z.black else Z.text,
        Size = UDim2.fromScale(1, 1), ZIndex = 6, Parent = row })
    local hit = Button({ Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = row })
    maid:GiveTask(hit.MouseButton1Click:Connect(function()
        ripple(row, if accent then Z.black else Z.lime); safeCall(cfg.Callback, "Btn:" .. cfg.Title)
    end))
    if accent then hoverFx(row, maid, { BackgroundColor3 = cfg.Color :: Color3 }, { BackgroundColor3 = (cfg.Color :: Color3):Lerp(Z.text, 0.12) })
    else hoverFx(row, maid, { BackgroundColor3 = Z.elevated }, { BackgroundColor3 = Z.hover }) end
    return { Label = lbl }
end

function Components.Keybind(parent: Instance, maid: Maid, order: number, cfg: { Title: string, Get: () -> Enum.KeyCode, Set: (k: Enum.KeyCode) -> () })
    local row = rowBase(parent, 36, order)
    Label({ Text = cfg.Title, Font = F_BODY, TextSize = 12, TextColor3 = Z.text, Size = UDim2.new(1, -110, 1, 0),
        Position = UDim2.new(0, 14, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6, Parent = row })
    local keyBtn = Button({ Text = cfg.Get().Name, Font = F_CODE, TextSize = 11, TextColor3 = Z.lime,
        Size = UDim2.fromOffset(84, 24), Position = UDim2.new(1, -96, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Z.elevated, ZIndex = 6, Parent = row })
    corner(6).Parent = keyBtn; stroke(Z.border, 1).Parent = keyBtn
    local capturing = false
    maid:GiveTask(keyBtn.MouseButton1Click:Connect(function()
        capturing = true; keyBtn.Text = "..."; keyBtn.TextColor3 = Z.warn
    end))
    maid:GiveTask(UserInputService.InputBegan:Connect(function(inp: InputObject, gp: boolean)
        if capturing and inp.UserInputType == Enum.UserInputType.Keyboard then
            capturing = false; cfg.Set(inp.KeyCode); keyBtn.Text = inp.KeyCode.Name; keyBtn.TextColor3 = Z.lime
        end
    end))
    hoverFx(row, maid, { BackgroundColor3 = Z.card }, { BackgroundColor3 = Z.hover })
end

function Components.Dropdown(parent: Instance, maid: Maid, order: number, cfg: { Title: string, Options: () -> { string }, Callback: (v: string) -> () })
    local row = rowBase(parent, 36, order)
    Label({ Text = cfg.Title, Font = F_BODY, TextSize = 12, TextColor3 = Z.text, Size = UDim2.new(1, -150, 1, 0),
        Position = UDim2.new(0, 14, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6, Parent = row })
    local sel = Button({ Text = "Select", Font = F_BODY, TextSize = 11, TextColor3 = Z.text2,
        Size = UDim2.fromOffset(124, 24), Position = UDim2.new(1, -136, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Z.elevated, ZIndex = 6, Parent = row })
    corner(6).Parent = sel; stroke(Z.border, 1).Parent = sel
    drawIcon("minimize", Frame({ Size = UDim2.fromOffset(18, 18), Position = UDim2.new(1, -20, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, ZIndex = 7, Parent = sel }), Z.text3)
    local popup: Frame? = nil
    local function close() if popup then popup:Destroy(); popup = nil end end
    maid:GiveTask(function() close() end)
    maid:GiveTask(sel.MouseButton1Click:Connect(function()
        if popup then close(); return end
        local opts = cfg.Options()
        local p = Frame({ BackgroundColor3 = Z.elevated, BorderSizePixel = 0, ZIndex = 60,
            Size = UDim2.fromOffset(sel.AbsoluteSize.X, math.min(#opts, 5) * 26 + 6),
            Position = UDim2.fromOffset(sel.AbsolutePosition.X, sel.AbsolutePosition.Y + sel.AbsoluteSize.Y + 4),
            Parent = screenGui })
        popup = p; corner(8).Parent = p; stroke(Z.borderHi, 1).Parent = p
        local ps = Scroll({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 61, Parent = p })
        mk("UIListLayout", { Padding = UDim.new(0, 2), Parent = ps }); mk("UIPadding", { PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3), Parent = ps })
        if #opts == 0 then Label({ Text = "(none)", TextColor3 = Z.text3, TextSize = 11, Size = UDim2.new(1, 0, 0, 24), ZIndex = 62, Parent = ps }) end
        for _, opt in ipairs(opts) do
            local ob = Button({ Text = opt, Font = F_BODY, TextSize = 11, TextColor3 = Z.text, Size = UDim2.new(1, 0, 0, 24),
                BackgroundColor3 = Z.card, ZIndex = 62, Parent = ps })
            corner(5).Parent = ob
            ob.MouseEnter:Connect(function() ob.BackgroundColor3 = Z.hover end)
            ob.MouseLeave:Connect(function() ob.BackgroundColor3 = Z.card end)
            ob.MouseButton1Click:Connect(function()
                sel.Text = opt; sel.TextColor3 = Z.text; close()
                safeCall(function() cfg.Callback(opt) end, "Dropdown:" .. cfg.Title)
            end)
        end
    end))
    hoverFx(row, maid, { BackgroundColor3 = Z.card }, { BackgroundColor3 = Z.hover })
end

function Components.Stat(parent: Instance, order: number, name: string, color: Color3): TextLabel
    local card = Frame({ BackgroundColor3 = Z.surface, BorderSizePixel = 0, Size = UDim2.new(0.5, -6, 0, 64),
        LayoutOrder = order, ZIndex = 5, Parent = parent })
    corner(10).Parent = card; stroke(Z.border, 1).Parent = card
    Frame({ Size = UDim2.fromOffset(3, 18), Position = UDim2.new(0, 14, 0, 14), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 6, Parent = card })
    Label({ Text = name, Font = F_BODY, TextSize = 10, TextColor3 = Z.text3, Size = UDim2.new(1, -28, 0, 16),
        Position = UDim2.new(0, 24, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6, Parent = card })
    return Label({ Text = "--", Font = F_HEAD, TextSize = 24, TextColor3 = color, Size = UDim2.new(1, -28, 0, 30),
        Position = UDim2.new(0, 22, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6, Parent = card })
end

function Components.Paragraph(parent: Instance, order: number): TextLabel
    local card = Frame({ BackgroundColor3 = Z.surface, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 40),
        AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order, ZIndex = 4, Parent = parent })
    corner(10).Parent = card; stroke(Z.border, 1).Parent = card
    local l = Label({ Text = "", Font = F_CODE, TextSize = 11, TextColor3 = Z.text2, Size = UDim2.new(1, -28, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0, 14, 0, 12), TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 5, Parent = card })
    mk("UIPadding", { PaddingBottom = UDim.new(0, 12), Parent = card })
    return l
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 21. TAB BUILDERS
-- ═══════════════════════════════════════════════════════════════════════════════

local toggleKey = Enum.KeyCode.RightShift

local Pages: { [string]: (host: Frame, maid: Maid) -> () } = {}

Pages.Dashboard = function(host, maid)
    local page, layout = Components.Page(host)
    local grid = Frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 140), LayoutOrder = 1, ZIndex = 4, Parent = page })
    mk("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 64), CellPadding = UDim2.fromOffset(12, 12),
        FillDirectionMaxCells = 2, Parent = grid })
    local fpsV = Components.Stat(grid, 1, "FPS", Z.lime)
    local pingV = Components.Stat(grid, 2, "PING", Z.success)
    local memV = Components.Stat(grid, 3, "MEMORY", Z.info)
    local plrV = Components.Stat(grid, 4, "PLAYERS", Z.warn)
    local para = Components.Paragraph(page, 2)
    local running = true; maid:GiveTask(function() running = false end)
    local fps = 0; local last = os.clock()
    maid:GiveTask(RunService.RenderStepped:Connect(function()
        fps += 1; local now = os.clock(); if now - last >= 1 then fpsV.Text = tostring(fps); fps = 0; last = now end
    end))
    local function refresh()
        pcall(function() memV.Text = string.format("%.0f MB", collectgarbage("count") / 1024) end)
        pcall(function() plrV.Text = tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers) end)
        pcall(function()
            if Services.Stats then
                local sa = Services.Stats :: any
                pingV.Text = math.floor(sa.Network.ServerStatsItem["Data Ping"].Value) .. " ms"
            end
        end)
        if localPlayer then
            local lines = {
                "User      " .. localPlayer.Name .. " (@" .. localPlayer.DisplayName .. ")",
                "UserId    " .. tostring(localPlayer.UserId),
                "Account   " .. tostring(localPlayer.AccountAge) .. " days " .. tostring(localPlayer.MembershipType),
                "Game      " .. game.Name .. " [" .. tostring(game.PlaceId) .. "]",
            }
            local char = localPlayer.Character
            if char then local h = char:FindFirstChildOfClass("Humanoid")
                if h then table.insert(lines, string.format("Vitals    HP %.0f/%.0f  WS %.0f  JP %.0f", h.Health, h.MaxHealth, h.WalkSpeed, h.JumpPower)) end
            end
            para.Text = table.concat(lines, "\n")
        end
    end
    refresh(); task.spawn(function() while running and task.wait(1) do refresh() end end)
end

Pages.Player = function(host, maid)
    local page = Components.Page(host)
    local mv = Components.Section(page, "Movement", 1)
    Components.Toggle(mv.body, maid, 1, { Title = "Fly", Get = function() return CMD_STATE.fly end, Toggle = function() CommandRegistry["fly"].run({}) end })
    Components.Toggle(mv.body, maid, 2, { Title = "Noclip", Get = function() return CMD_STATE.noclip end, Toggle = function() CommandRegistry["noclip"].run({}) end })
    Components.Slider(mv.body, maid, 3, { Title = "Walk Speed", Min = 16, Max = 500, Default = 16, Callback = function(v) CommandRegistry["speed"].run({ tostring(v) }) end })
    Components.Slider(mv.body, maid, 4, { Title = "Jump Power", Min = 50, Max = 500, Default = 50, Callback = function(v) CommandRegistry["jump"].run({ tostring(v) }) end })
    Components.Slider(mv.body, maid, 5, { Title = "Gravity", Min = 0, Max = 400, Default = math.floor(Workspace.Gravity), Callback = function(v) CommandRegistry["gravity"].run({ tostring(v) }) end })
    local cv = Components.Section(page, "Character", 2)
    Components.Toggle(cv.body, maid, 1, { Title = "Godmode", Get = function() return CMD_STATE.godmode end, Toggle = function() CommandRegistry["godmode"].run({}) end })
    Components.Toggle(cv.body, maid, 2, { Title = "Invisible", Get = function() return CMD_STATE.invisible end, Toggle = function() CommandRegistry["invisible"].run({}) end })
    Components.Toggle(cv.body, maid, 3, { Title = "Spin", Get = function() return CMD_STATE.spin end, Toggle = function() CommandRegistry["spin"].run({}) end })
    Components.Toggle(cv.body, maid, 4, { Title = "Anti-Fling", Get = function() return CMD_STATE.antifling end, Toggle = function() CommandRegistry["antifling"].run({}) end })
    Components.Toggle(cv.body, maid, 5, { Title = "Anti-AFK", Get = function() return CMD_STATE.antiafk end, Toggle = function() CommandRegistry["antiafk"].run({}) end })
    local av = Components.Section(page, "Actions", 3)
    Components.Button(av.body, maid, 1, { Title = "Reset Character", Callback = function() CommandRegistry["reset"].run({}) end })
    Components.Button(av.body, maid, 2, { Title = "Refresh (keep position)", Callback = function() CommandRegistry["refresh"].run({}) end })
    Components.Button(av.body, maid, 3, { Title = "Heal", Color = Z.lime, Callback = function() CommandRegistry["heal"].run({}) end })
end

Pages.Combat = function(host, maid)
    local page = Components.Page(host)
    local s = Components.Section(page, "Visuals & Aim", 1)
    Components.Toggle(s.body, maid, 1, { Title = "ESP (box + name + health + distance)", Get = function() return CMD_STATE.esp end, Toggle = function() CommandRegistry["esp"].run({}) end })
    Components.Toggle(s.body, maid, 2, { Title = "Aimbot (nearest, hold)", Get = function() return CMD_STATE.aimbot end, Toggle = function() CommandRegistry["aimbot"].run({}) end })
    Components.Toggle(s.body, maid, 3, { Title = "Click Teleport (Ctrl+Click)", Get = function() return CMD_STATE.clicktp end, Toggle = function() CommandRegistry["clicktp"].run({}) end })
    local p = Components.Paragraph(page, 2)
    p.Text = "ESP and Aimbot run on RenderStepped and clean up fully on toggle-off via a\ndedicated Maid. Combat features are local-render only."
end

Pages.World = function(host, maid)
    local page = Components.Page(host)
    local s = Components.Section(page, "Lighting", 1)
    Components.Toggle(s.body, maid, 1, { Title = "Fullbright", Get = function() return CMD_STATE.fullbright end, Toggle = function() CommandRegistry["fullbright"].run({}) end })
    Components.Slider(s.body, maid, 2, { Title = "Time of Day", Min = 0, Max = 24, Default = math.floor(Lighting.ClockTime), Suffix = "h", Callback = function(v) CommandRegistry["time"].run({ tostring(v) }) end })
    Components.Slider(s.body, maid, 3, { Title = "Fog End", Min = 0, Max = 100000, Default = math.min(Lighting.FogEnd, 100000), Callback = function(v) CommandRegistry["fog"].run({ tostring(v) }) end })
    local d = Components.Section(page, "Danger Zone", 2)
    Components.Button(d.body, maid, 1, { Title = "Clear Terrain", Color = Z.danger, Callback = function() CommandRegistry["clearterrain"].run({}) end })
end

Pages.Server = function(host, maid)
    local page = Components.Page(host)
    local info = Components.Paragraph(page, 1)
    local function refreshInfo()
        info.Text = table.concat({
            "Place     " .. tostring(game.PlaceId),
            "Job       " .. tostring(game.JobId),
            "Players   " .. tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers),
            "Gravity   " .. tostring(Workspace.Gravity),
        }, "\n")
    end
    refreshInfo()
    local s = Components.Section(page, "Session", 2)
    Components.Button(s.body, maid, 1, { Title = "Rejoin", Color = Z.lime, Callback = function() CommandRegistry["rejoin"].run({}) end })
    Components.Button(s.body, maid, 2, { Title = "Server Hop", Callback = function() CommandRegistry["serverhop"].run({}) end })
    local t = Components.Section(page, "Players", 3)
    Components.Dropdown(t.body, maid, 1, { Title = "Teleport to", Options = function()
        local o = {}; for _, p in ipairs(Players:GetPlayers()) do if p ~= localPlayer then table.insert(o, p.Name) end end; return o
    end, Callback = function(v) CommandRegistry["teleport"].run({ v }) end })
    Components.Dropdown(t.body, maid, 2, { Title = "Spectate", Options = function()
        local o = {}; for _, p in ipairs(Players:GetPlayers()) do if p ~= localPlayer then table.insert(o, p.Name) end end; return o
    end, Callback = function(v) CommandRegistry["view"].run({ v }) end })
    Components.Button(t.body, maid, 3, { Title = "Stop Spectating", Callback = function() CommandRegistry["unview"].run({}) end })
end

Pages.Commands = function(host, maid)
    local page, layout = Components.Page(host)
    local searchCard = Frame({ BackgroundColor3 = Z.surface, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 0, ZIndex = 4, Parent = page })
    corner(9).Parent = searchCard; stroke(Z.border, 1).Parent = searchCard
    drawIcon("search", Frame({ Size = UDim2.fromOffset(20, 20), Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, ZIndex = 5, Parent = searchCard }), Z.text3)
    local sorted: { CommandDef } = {}
    for _, cmd in pairs(CommandRegistry) do table.insert(sorted, cmd) end
    table.sort(sorted, function(a, b) return a.name < b.name end)
    local search = TextBox({ PlaceholderText = "Search " .. #sorted .. " commands...", PlaceholderColor3 = Z.text3, Text = "",
        Font = F_BODY, TextSize = 12, TextColor3 = Z.text, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -44, 1, 0), Position = UDim2.new(0, 38, 0, 0), ZIndex = 5, Parent = searchCard })
    local listCard = Frame({ BackgroundColor3 = Z.surface, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -50),
        LayoutOrder = 1, ZIndex = 4, Parent = page })
    corner(10).Parent = listCard; stroke(Z.border, 1).Parent = listCard
    local sc = Scroll({ Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), BackgroundTransparency = 1,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 5, Parent = listCard })
    mk("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.Name, Parent = sc })
    mk("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingTop = UDim.new(0, 4), Parent = sc })
    local rows: { [CommandDef]: Frame } = {}
    local catCol: { [string]: Color3 } = { Player = Z.lime, Combat = Z.danger, World = Z.info, Server = Z.warn, Utility = Z.text2 }
    for _, cmd in ipairs(sorted) do
        local row = Frame({ Name = cmd.name, BackgroundColor3 = Z.card, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 32), ZIndex = 6, Parent = sc })
        corner(6).Parent = row
        Frame({ Size = UDim2.fromOffset(3, 16), Position = UDim2.new(0, 8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = catCol[cmd.category] or Z.lime, BorderSizePixel = 0, ZIndex = 7, Parent = row })
        Label({ Text = cmd.name, Font = F_BTN, TextSize = 11, TextColor3 = Z.text, Size = UDim2.new(0, 120, 1, 0), Position = UDim2.new(0, 18, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7, Parent = row })
        Label({ Text = cmd.desc, Font = F_THIN, TextSize = 10, TextColor3 = Z.text3, Size = UDim2.new(1, -260, 1, 0), Position = UDim2.new(0, 140, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 7, Parent = row })
        local run = Button({ Text = "RUN", Font = F_BTN, TextSize = 10, TextColor3 = Z.black, Size = UDim2.fromOffset(54, 22), Position = UDim2.new(1, -62, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Z.lime, ZIndex = 7, Parent = row })
        corner(5).Parent = run
        maid:GiveTask(run.MouseButton1Click:Connect(function()
            if not canRun(cmd.perm) then notify("No permission: " .. cmd.name, "danger"); return end
            safeCall(function() cmd.run({}) end, "Cmd:" .. cmd.name)
        end))
        hoverFx(row, maid, { BackgroundColor3 = Z.card }, { BackgroundColor3 = Z.hover })
        rows[cmd] = row
    end
    maid:GiveTask(search:GetPropertyChangedSignal("Text"):Connect(function()
        local q = search.Text:lower()
        for cmd, row in pairs(rows) do
            row.Visible = q == "" or cmd.name:lower():find(q, 1, true) ~= nil or cmd.category:lower():find(q, 1, true) ~= nil
        end
    end))
end

Pages.Console = function(host, maid)
    local page = Components.Page(host)
    local card = Frame({ BackgroundColor3 = Z.bg, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -42), LayoutOrder = 1, ZIndex = 4, Parent = page })
    corner(10).Parent = card; stroke(Z.border, 1).Parent = card
    local sc = Scroll({ Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), BackgroundTransparency = 1,
        CanvasSize = UDim2.new(), ZIndex = 5, Parent = card })
    local cl = mk("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = sc })
    mk("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), Parent = sc })
    local lastVer = -1; local rendered = 0; local lastFirst = ""
    local function entry(text: string, order: number)
        local col = Z.text2
        if text:find("%[ERROR%]") then col = Z.danger elseif text:find("%[WARN%]") then col = Z.warn
        elseif text:find("%[OUTPUT%]") then col = Z.success elseif text:find("%[DEBUG%]") then col = Z.info end
        Label({ Text = text, Font = F_CODE, TextSize = 10, TextColor3 = col, Size = UDim2.new(1, -12, 0, 14),
            TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, ZIndex = 6, Parent = sc })
    end
    local running = true; maid:GiveTask(function() running = false end)
    local function upd()
        if logVersion == lastVer then return end; lastVer = logVersion
        local rotated = rendered > 0 and #logs > 0 and logs[1] ~= lastFirst
        if rotated or rendered > #logs then
            for _, ch in ipairs(sc:GetChildren()) do if ch:IsA("TextLabel") then ch:Destroy() end end; rendered = 0
        end
        for i = rendered + 1, #logs do entry(logs[i], i) end
        rendered = #logs; if #logs > 0 then lastFirst = logs[1] end
        sc.CanvasSize = UDim2.new(0, 0, 0, cl.AbsoluteContentSize.Y + 8)
        sc.CanvasPosition = Vector2.new(0, cl.AbsoluteContentSize.Y)
    end
    upd(); task.spawn(function() while running and task.wait(0.3) do upd() end end)
    local bar = Frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 2, ZIndex = 4, Parent = page })
    mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = bar })
    Components.Button(bar, maid, 1, { Title = "Copy logs", Color = Z.lime, Callback = function()
        if Executor.setclipboard then pcall(function() (Executor.setclipboard :: (string) -> boolean)(table.concat(logs, "\n")) end); notify("Logs copied", "success") end
    end })
    for _, ch in ipairs(bar:GetChildren()) do if ch:IsA("Frame") then ch.Size = UDim2.fromOffset(120, 30) end end
    Components.Button(bar, maid, 2, { Title = "Clear", Callback = function()
        table.clear(logs); logVersion += 1
        for _, ch in ipairs(sc:GetChildren()) do if ch:IsA("TextLabel") then ch:Destroy() end end
        sc.CanvasSize = UDim2.new()
    end })
    for _, ch in ipairs(bar:GetChildren()) do if ch:IsA("Frame") then ch.Size = UDim2.fromOffset(120, 30) end end
end

Pages.Settings = function(host, maid)
    local page = Components.Page(host)
    local g = Components.Section(page, "General", 1)
    Components.Keybind(g.body, maid, 1, { Title = "Toggle menu key", Get = function() return toggleKey end, Set = function(k) toggleKey = k; notify("Toggle key: " .. k.Name) end })
    Components.Toggle(g.body, maid, 2, { Title = "Background blur", Get = function() return blurEnabled end, Toggle = function()
        blurEnabled = not blurEnabled; tween(blur, { Size = if blurEnabled then 14 else 0 }, SMOOTH)
    end })
    Components.Slider(g.body, maid, 3, { Title = "UI Scale", Min = 70, Max = 120, Default = 100, Suffix = "%", Callback = function(v) uiScale.Scale = v / 100 end })
    local permBtnApi: any = nil
    permBtnApi = Components.Button(g.body, maid, 4, { Title = "Permission: " .. PERM_NAMES[userRank], Color = Z.lime, Callback = function()
        userRank = (userRank % 4) + 1; permChipLbl.Text = PERM_NAMES[userRank]
        if permBtnApi then permBtnApi.Label.Text = "Permission: " .. PERM_NAMES[userRank] end
    end })
    local w = Components.Section(page, "WebhookPulse", 2)
    local urlRow = rowBase(w.body, 32, 1)
    local urlBox = TextBox({ PlaceholderText = "https://webhookpulse.vercel.app/api/...", PlaceholderColor3 = Z.text3, Text = "",
        Font = F_CODE, TextSize = 10, TextColor3 = Z.text, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 12, 0, 0), ZIndex = 6, Parent = urlRow })
    local secRow = rowBase(w.body, 32, 2)
    local secBox = TextBox({ PlaceholderText = "X-Webhook-Secret (optional)", PlaceholderColor3 = Z.text3, Text = "",
        Font = F_CODE, TextSize = 10, TextColor3 = Z.text, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 12, 0, 0), ZIndex = 6, Parent = secRow })
    Components.Button(w.body, maid, 3, { Title = "Send Test Payload", Color = Z.info, Callback = function()
        local url = urlBox.Text:match("^%s*(.-)%s*$") or ""
        local valid, err = validateUrl(url); if not valid then notify("Invalid URL: " .. err, "danger"); return end
        if not checkRateLimit(url) then notify("Rate limited", "warn"); return end
        notify("Sending test...")
        task.spawn(function()
            local res = httpRequest({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json", ["X-Webhook-Secret"] = secBox.Text:gsub("[%z\r\n]", "") },
                Body = HttpService:JSONEncode({ source = "zex", version = "7.4.1", player = { userid = localPlayer.UserId, username = localPlayer.Name }, test = true }) })
            if res.success then notify("Webhook OK [" .. tostring(res.status) .. "]", "success")
            else notify("Webhook failed: " .. (res.error or "?"), "danger") end
        end)
    end })
    local a = Components.Paragraph(page, 3)
    a.Text = "ZEX v7.4.1 ELITE\nVector-icon component GUI  SSRF-guarded HTTP  Maid lifecycle\nToggle with the configured key. Drag the title bar to move."
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 22. TAB SWITCHING — cross-fade + sliding indicator
-- ═══════════════════════════════════════════════════════════════════════════════

local activePageMaid: Maid? = nil
local activeHost: Frame? = nil
local currentTab = ""

local function setActiveIcon(tabId: string)
    for id, ref in pairs(sidebarBtns) do
        local on = id == tabId
        recolorIcon(ref.icon, if on then Z.lime else Z.text3)
        tween(ref.btn, { BackgroundTransparency = if on then 0 else 1, BackgroundColor3 = Z.elevated }, FAST)
    end
    local ref = sidebarBtns[tabId]
    if ref then tween(indicator, { Position = UDim2.new(0, 0, 0, ref.y) }, SMOOTH) end
end

local function switchTab(tabId: string)
    if tabId == currentTab then return end
    currentTab = tabId
    setActiveIcon(tabId)
    tabTitle.Text = tabId
    local oldMaid = activePageMaid; local oldHost = activeHost
    if oldHost then
        tween(oldHost, { Position = UDim2.new(0, -18, 0, 40) }, FAST)
        task.delay(0.13, function()
            if oldMaid then oldMaid:Destroy() end
            if oldHost then oldHost:Destroy() end
        end)
    end
    local maid = Maid.new(); activePageMaid = maid
    local host = Frame({ Name = "Page_" .. tabId, Size = UDim2.fromScale(1, 1), Position = UDim2.new(0, 18, 0, 40),
        BackgroundTransparency = 1, ZIndex = 4, Parent = pageHost })
    activeHost = host
    local builder = Pages[tabId]
    if builder then safeCall(function() builder(host, maid) end, "Page:" .. tabId) end
    host.Position = UDim2.new(0, 18, 0, 40)
    tween(host, { Position = UDim2.new(0, 0, 0, 40) }, SMOOTH)
end

for id, ref in pairs(sidebarBtns) do
    rootMaid:GiveTask(ref.btn.MouseButton1Click:Connect(function() switchTab(id) end))
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 23. COMMAND INPUT BAR
-- ═══════════════════════════════════════════════════════════════════════════════

local inputBar = Frame({ Name = "InputBar", Size = UDim2.new(1, -SIDEBAR_W, 0, INPUT_H), Position = UDim2.new(0, SIDEBAR_W, 1, -INPUT_H),
    BackgroundColor3 = Z.card, BorderSizePixel = 0, ZIndex = 5, Parent = window })
Frame({ Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Z.border, BorderSizePixel = 0, ZIndex = 6, Parent = inputBar })
local promptLbl = Label({ Text = CMD_PREFIX, Font = F_CODE, TextSize = 14, TextColor3 = Z.lime, Size = UDim2.fromOffset(18, INPUT_H),
    Position = UDim2.new(0, 12, 0, 0), ZIndex = 6, Parent = inputBar })
local inputBox = TextBox({ PlaceholderText = "type a command and press Enter — e.g. fly 80", PlaceholderColor3 = Z.text3, Text = "",
    Font = F_CODE, TextSize = 12, TextColor3 = Z.text, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left,
    Size = UDim2.new(1, -110, 1, 0), Position = UDim2.new(0, 32, 0, 0), ZIndex = 6, Parent = inputBar })
local runCmd = Button({ Text = "RUN", Font = F_BTN, TextSize = 11, TextColor3 = Z.black, Size = UDim2.fromOffset(60, 26),
    Position = UDim2.new(1, -72, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Z.lime, ZIndex = 6, Parent = inputBar })
corner(6).Parent = runCmd
hoverFx(runCmd, rootMaid, { BackgroundColor3 = Z.lime }, { BackgroundColor3 = Z.lime2 })

local function executeInput()
    local raw = inputBox.Text:match("^%s*(.-)%s*$") or ""; if #raw == 0 then return end
    if raw:sub(1, #CMD_PREFIX) == CMD_PREFIX then raw = raw:sub(#CMD_PREFIX + 1) end
    raw = raw:match("^%s*(.-)%s*$") or ""; if #raw == 0 then return end
    local parts: { string } = {}; for tok in raw:gmatch("%S+") do table.insert(parts, tok) end
    if #parts == 0 then return end
    local name = parts[1]:lower(); local args: { string } = {}
    for i = 2, #parts do table.insert(args, parts[i]) end
    local cmd = CommandRegistry[name]
    if not cmd then notify("Unknown command: " .. name, "warn"); return end
    if not canRun(cmd.perm) then notify("No permission: " .. name, "danger"); return end
    safeCall(function() cmd.run(args) end, "Input:" .. name)
    inputBox.Text = ""
end
rootMaid:GiveTask(inputBox.FocusLost:Connect(function(enter) if enter then executeInput() end end))
rootMaid:GiveTask(runCmd.MouseButton1Click:Connect(function() ripple(runCmd, Z.black); executeInput() end))

-- ═══════════════════════════════════════════════════════════════════════════════
-- 24. NOTIFICATIONS v3 — icon · title · body · countdown bar
-- ═══════════════════════════════════════════════════════════════════════════════

local notifHost = Frame({ Name = "Notifs", AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(280, 400),
    Position = UDim2.new(1, -14, 1, -14), BackgroundTransparency = 1, ZIndex = 40, Parent = screenGui })
mk("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom,
    HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8), Parent = notifHost })
local notifSeq = 0
local lvlCol: { [string]: Color3 } = { info = Z.info, warn = Z.warn, success = Z.success, danger = Z.danger }

showNotification = function(title: string, msg: string, level: ToastLevel)
    if not screenGui or not screenGui.Parent then return end
    notifSeq += 1; local col = lvlCol[level] or Z.info
    local card = Frame({ Size = UDim2.new(0, 272, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Z.elevated,
        BorderSizePixel = 0, LayoutOrder = notifSeq, ClipsDescendants = true, ZIndex = 41, Parent = notifHost })
    corner(9).Parent = card; stroke(Z.border, 1).Parent = card
    Frame({ Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = col, BorderSizePixel = 0, ZIndex = 42, Parent = card })
    local dot = Frame({ Size = UDim2.fromOffset(8, 8), Position = UDim2.new(0, 14, 0, 15), BackgroundColor3 = col, BorderSizePixel = 0, ZIndex = 42, Parent = card })
    corner(4).Parent = dot
    Label({ Text = title, Font = F_HEAD, TextSize = 12, TextColor3 = Z.text, Size = UDim2.new(1, -40, 0, 16),
        Position = UDim2.new(0, 30, 0, 10), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 42, Parent = card })
    Label({ Text = msg, Font = F_BODY, TextSize = 11, TextColor3 = Z.text2, Size = UDim2.new(1, -40, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0, 30, 0, 28), TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 42, Parent = card })
    mk("UIPadding", { PaddingBottom = UDim.new(0, 12), Parent = card })
    local prog = Frame({ Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2), BackgroundColor3 = col, BorderSizePixel = 0, ZIndex = 43, Parent = card })
    local nStroke = card:FindFirstChildOfClass("UIStroke"); if nStroke then nStroke.Color = col; nStroke.Transparency = 0; tween(nStroke, { Transparency = 1 }, GENTLE) end
    TweenService:Create(prog, TweenInfo.new(3.4, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) }):Play()
    task.delay(3.5, function()
        if not card or not card.Parent then return end
        tween(card, { BackgroundTransparency = 1 }, FAST)
        local fadeAll = card:GetDescendants()
        for _, d in ipairs(fadeAll) do
            if d:IsA("TextLabel") then tween(d, { TextTransparency = 1 }, FAST)
            elseif d:IsA("Frame") then tween(d, { BackgroundTransparency = 1 }, FAST) end
        end
        task.delay(0.16, function() if card and card.Parent then card:Destroy() end end)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 25. DRAG · MINIMIZE · CLOSE
-- ═══════════════════════════════════════════════════════════════════════════════

local dragMaid: Maid? = nil
rootMaid:GiveTask(function() if dragMaid then dragMaid:Destroy(); dragMaid = nil end end)
rootMaid:GiveTask(topbar.InputBegan:Connect(function(input: InputObject)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
    if dragMaid then dragMaid:Destroy() end; dragMaid = Maid.new()
    local dt = input.UserInputType
    local start = Vector2.new(input.Position.X, input.Position.Y)
    local origin = holder.AbsolutePosition + holder.AbsoluteSize / 2
    dragMaid:GiveTask(UserInputService.InputChanged:Connect(function(i2: InputObject)
        if i2.UserInputType ~= Enum.UserInputType.MouseMovement and i2.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = Vector2.new(i2.Position.X, i2.Position.Y) - start
        local vp = Workspace.CurrentCamera.ViewportSize
        local nx = math.clamp(origin.X + delta.X, holder.AbsoluteSize.X / 2, vp.X - holder.AbsoluteSize.X / 2)
        local ny = math.clamp(origin.Y + delta.Y, holder.AbsoluteSize.Y / 2, vp.Y - holder.AbsoluteSize.Y / 2)
        holder.Position = UDim2.fromOffset(nx, ny)
    end))
    dragMaid:GiveTask(UserInputService.InputEnded:Connect(function(i2: InputObject)
        if i2.UserInputType == dt then if dragMaid then dragMaid:Destroy(); dragMaid = nil end end
    end))
end))

local minimized = false
rootMaid:GiveTask(minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    tween(holder, { Size = UDim2.fromOffset(WIN_W, if minimized then 46 else WIN_H) }, SPRING)
end))

local function closeGui()
    tween(blur, { Size = 0 }, SMOOTH)
    tween(dim, { BackgroundTransparency = 1 }, SMOOTH)
    tween(holder, { Size = UDim2.fromOffset(WIN_W * 0.85, WIN_H * 0.85) }, FAST)
    task.delay(0.18, function()
        if screenGui and screenGui.Parent then screenGui:Destroy() end
        rootMaid:Destroy()
    end)
end
rootMaid:GiveTask(closeBtn.MouseButton1Click:Connect(closeGui))

-- ═══════════════════════════════════════════════════════════════════════════════
-- 26. TOGGLE KEY · ENTRY · TEARDOWN
-- ═══════════════════════════════════════════════════════════════════════════════

local guiVisible = true
local savedPos: UDim2 = UDim2.fromScale(0.5, 0.5)
rootMaid:GiveTask(UserInputService.InputBegan:Connect(function(input: InputObject, gp: boolean)
    if gp then return end
    if input.KeyCode == toggleKey then
        if guiVisible then
            guiVisible = false; savedPos = holder.Position
            tween(holder, { Position = UDim2.new(savedPos.X.Scale, savedPos.X.Offset, 1.6, 0) }, SMOOTH)
            tween(dim, { BackgroundTransparency = 1 }, SMOOTH)
            if blurEnabled then tween(blur, { Size = 0 }, SMOOTH) end
        else
            guiVisible = true
            tween(holder, { Position = savedPos }, SPRING)
            tween(dim, { BackgroundTransparency = 0.55 }, SMOOTH)
            if blurEnabled then tween(blur, { Size = 14 }, SMOOTH) end
        end
    end
end))

rootMaid:GiveTask(screenGui.Destroying:Connect(function()
    if espMaid then espMaid:Destroy(); espMaid = nil end
    if blur then pcall(function() blur:Destroy() end) end
    rootMaid:Destroy()
    log("INFO", "[ZEX] v7.4.1 teardown complete")
end))

-- entry
holder.Size = UDim2.fromOffset(WIN_W * 0.9, WIN_H * 0.9)
dim.BackgroundTransparency = 1
switchTab("Dashboard")
task.delay(0.03, function()
    if not screenGui or not screenGui.Parent then return end
    tween(holder, { Size = UDim2.fromOffset(WIN_W, WIN_H) }, SPRING)
    tween(dim, { BackgroundTransparency = 0.55 }, GENTLE)
    if blurEnabled then tween(blur, { Size = 14 }, GENTLE) end
end)

local cmdCount = 0; for _ in pairs(CommandRegistry) do cmdCount += 1 end
log("INFO", string.format("[ZEX] v7.4.1 ELITE booted — %d commands — rank %s", cmdCount, PERM_NAMES[userRank]))
task.delay(0.6, function() notify("ZEX v7.4.1 ELITE — " .. cmdCount .. " commands loaded", "success") end)
