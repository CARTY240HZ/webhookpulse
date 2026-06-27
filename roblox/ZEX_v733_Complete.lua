--[[
  ZEX v8.0 PRIME — AAA EXECUTOR SUITE · 11 TABS · 45+ COMMANDS · PERSISTENT
  ─────────────────────────────────────────────────────────────────────────────
  v8.0 PRIME — system-tier upgrade (merges the v7.0 intelligence/webhook core
  with the v7.4.1 component GUI, plus four elite subsystems):
    · NEW  Config persistence — writefile/readfile flag store (ZEX/config.json),
           debounced autosave; every toggle/slider/keybind survives re-execution.
    · NEW  Drawing-API ESP — box + name + healthbar + distance + tracer, team and
           max-distance filters; graceful Highlight fallback when no Drawing API.
    · NEW  Aimbot PRO — FOV circle, screen-space target, visibility raycast,
           smoothing, team filter, hold-RMB, selectable target part.
    · NEW  Watermark (FPS·ping·players·clock, draggable) + floating keybind list
           + mobile FAB toggle (touch) + protect_gui anti-detection.
    · MERGE Intel tab (full identity/character/server/device dump), Webhooks tab
           (WebhookPulse transmitter, 4 payload modes), Network tab (raw HTTP).
    · KEEP Command Palette (Ctrl+K), profile card, vector icons, spring motion.
  ─────────────────────────────────────────────────────────────────────────────
  v7.4.1 base audit (carried): executor detection genv→fenv→_G (was _G-only and
  silently nil on Wave/KRNL/Synapse/Fluxus); dropdown outside-click dismiss;
  keybind picker no longer double-fires the menu toggle, Esc cancels.
  ─────────────────────────────────────────────────────────────────────────────
  Director-grade rewrite of the presentation layer (Rayfield / Fluent tier):
    · Vector icons drawn from Frames — zero asset dependency, always render
    · Drop-shadow (9-slice) + optional background BlurEffect on open
    · Real interactive components: animated Toggle, draggable Slider, popup
      Dropdown, configurable Keybind picker, ripple-on-click Buttons
    · Sliding sidebar selection indicator + per-icon hover tooltips
    · Spring motion system, content cross-fade on tab switch
    · Notifications v3: icon + title + body + countdown progress bar
  Palette: #0C0C0E bg · #D4E83A lime · Gotham · solid colours (no gradients) · no emojis
  Backend (services, executor detection, SSRF-guarded HTTP, Maid, permissions,
  command registry) carried over verbatim from the audited v7.3.4 core.
]]

--!strict

-- ═══════════════════════════════════════════════════════════════════════════════
-- 0. TYPE DECLARATIONS
-- ═══════════════════════════════════════════════════════════════════════════════

type ServicesTable = {
    Players:Players?, RunService:RunService?, TweenService:TweenService?,
    UserInputService:UserInputService?, HttpService:HttpService?,
    TeleportService:TeleportService?, Lighting:Lighting?, Workspace:Workspace?,
    ReplicatedStorage:ReplicatedStorage?, TextService:TextService?,
    StarterGui:StarterGui?, SoundService:SoundService?, Stats:Stats?,
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. SERVICES — individual pcall per service
-- ═══════════════════════════════════════════════════════════════════════════════

local function getService(name: string): Instance?
    local ok, svc = pcall(function(): Instance return game:GetService(name) end)
    return if ok then svc else nil
end

local Services: ServicesTable = {}
Services.Players          = getService("Players")           :: Players?
Services.RunService       = getService("RunService")        :: RunService?
Services.TweenService     = getService("TweenService")      :: TweenService?
Services.UserInputService = getService("UserInputService")  :: UserInputService?
Services.HttpService      = getService("HttpService")       :: HttpService?
Services.TeleportService  = getService("TeleportService")   :: TeleportService?
Services.Lighting         = getService("Lighting")          :: Lighting?
Services.Workspace        = getService("Workspace")         :: Workspace?
Services.ReplicatedStorage= getService("ReplicatedStorage") :: ReplicatedStorage?
Services.TextService      = getService("TextService")       :: TextService?
Services.StarterGui       = getService("StarterGui")        :: StarterGui?
Services.SoundService     = getService("SoundService")      :: SoundService?
Services.Stats            = getService("Stats")             :: Stats?

assert(Services.Players,          "[ZEX] Players required")
assert(Services.RunService,       "[ZEX] RunService required")
assert(Services.TweenService,     "[ZEX] TweenService required")
assert(Services.UserInputService, "[ZEX] UserInputService required")
assert(Services.HttpService,      "[ZEX] HttpService required")
assert(Services.TeleportService,  "[ZEX] TeleportService required")
assert(Services.Lighting,         "[ZEX] Lighting required")
assert(Services.Workspace,        "[ZEX] Workspace required")

local Players          = Services.Players          :: Players
local RunService       = Services.RunService       :: RunService
local TweenService     = Services.TweenService     :: TweenService
local UserInputService = Services.UserInputService :: UserInputService
local HttpService      = Services.HttpService      :: HttpService
local TeleportService  = Services.TeleportService  :: TeleportService
local Lighting         = Services.Lighting         :: Lighting
local Workspace        = Services.Workspace        :: Workspace
local localPlayer      = Players.LocalPlayer

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. EXECUTOR FEATURE DETECTION
-- ═══════════════════════════════════════════════════════════════════════════════

export type ExecutorApi = {
    getgenv:           (()->{ [string]:any })?,
    gethui:            (()->Instance)?,
    request:           ((opts:{[string]:any})->{[string]:any})?,
    setclipboard:      ((text:string)->boolean)?,
    sethiddenproperty: ((inst:Instance,prop:string,val:any)->boolean)?,
    cloneref:          ((inst:Instance)->Instance)?,
    loadstring:        ((src:string)->(...any)->...any)?,
    hookmetamethod:    ((obj:any,meta:string,hook:(...any)->...any)->any)?,
    getrawmetatable:   ((obj:any)->{[string]:any})?,
    getnamecallmethod: (()->string)?,
}

local Executor: ExecutorApi = {
    getgenv=nil, gethui=nil, request=nil, setclipboard=nil,
    sethiddenproperty=nil, cloneref=nil, loadstring=nil,
    hookmetamethod=nil, getrawmetatable=nil, getnamecallmethod=nil,
}

-- Executor capability functions (gethui, setclipboard, request, …) live in the
-- executor's SHARED global env (getgenv()) or in the running script's function
-- environment — they are frequently ABSENT from the game's _G table. Probing
-- only _G silently disabled every executor feature on most executors (clipboard,
-- gethui parenting, HTTP). Resolve in priority order: genv → fenv → _G.
local _genv: any = nil; pcall(function() _genv = (getgenv :: any)() end)
local _fenv: any = nil; pcall(function() _fenv = (getfenv :: any)() end)

local function resolveGlobal(key: string): any
    local v: any = nil
    if type(_genv) == "table" then local ok, r = pcall(function() return (_genv :: any)[key] end); if ok and r ~= nil then v = r end end
    if v == nil and type(_fenv) == "table" then local ok, r = pcall(function() return (_fenv :: any)[key] end); if ok and r ~= nil then v = r end end
    if v == nil then local ok, r = pcall(function() return (_G :: any)[key] end); if ok then v = r end end
    return v
end

local function detectFn<T>(key: string): T?
    local v = resolveGlobal(key)
    return if type(v) == "function" then v :: T else nil
end

local function detectTbl(key: string): {[string]:any}?
    local v = resolveGlobal(key)
    return if type(v) == "table" then v :: {[string]:any} else nil
end

Executor.getgenv           = detectFn("getgenv")
Executor.gethui            = detectFn("gethui")
Executor.setclipboard      = detectFn("setclipboard")
Executor.sethiddenproperty = detectFn("sethiddenproperty")
Executor.cloneref          = detectFn("cloneref")
Executor.loadstring        = detectFn("loadstring")
Executor.hookmetamethod    = detectFn("hookmetamethod")
Executor.getrawmetatable   = detectFn("getrawmetatable")
Executor.getnamecallmethod = detectFn("getnamecallmethod")

-- HTTP request: bare `request`/`http_request`, else syn.request / fluxus.request
Executor.request = detectFn("request") or detectFn("http_request")
if not Executor.request then
    local syn = detectTbl("syn")
    if syn and type(syn.request) == "function" then Executor.request = syn.request :: any end
end
if not Executor.request then
    local fluxus = detectTbl("fluxus")
    if fluxus and type(fluxus.request) == "function" then Executor.request = fluxus.request :: any end
end
if not Executor.request then
    local delta = detectTbl("delta")
    if delta and type(delta.request) == "function" then Executor.request = delta.request :: any end
end

-- Filesystem (config persistence) — optional, executor-provided
local FS = {
    write      = detectFn("writefile")  :: ((path:string,data:string)->())?,
    read       = detectFn("readfile")   :: ((path:string)->string)?,
    isfile     = detectFn("isfile")     :: ((path:string)->boolean)?,
    isfolder   = detectFn("isfolder")   :: ((path:string)->boolean)?,
    makefolder = detectFn("makefolder") :: ((path:string)->())?,
}
local hasFS = FS.write ~= nil and FS.read ~= nil

-- Drawing API (high-perf ESP) — optional, executor-provided
local DrawingNew: ((kind:string)->any)? = nil
do
    local d = resolveGlobal("Drawing")
    if type(d) == "table" or type(d) == "userdata" then
        local ok, fn = pcall(function() return (d :: any).new end)
        if ok and type(fn) == "function" then DrawingNew = function(kind) return (d :: any).new(kind) end end
    end
end
local hasDrawing = DrawingNew ~= nil

-- GUI protection (anti-detection) — hides the ScreenGui from game scripts
local protectGui = detectFn("protect_gui") or detectFn("protectgui")
local function applyGuiProtection(gui: Instance)
    if protectGui then pcall(function() (protectGui :: any)(gui) end) end
    local syn = detectTbl("syn")
    if syn and type(syn.protect_gui) == "function" then pcall(function() syn.protect_gui(gui) end) end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. TYPES
-- ═══════════════════════════════════════════════════════════════════════════════

export type Palette = {
    bg:Color3, surface:Color3, elevated:Color3, card:Color3, hover:Color3,
    border:Color3, borderHi:Color3, text:Color3, text2:Color3, text3:Color3,
    lime:Color3, lime2:Color3, limeDim:Color3,
    danger:Color3, success:Color3, info:Color3, warn:Color3, black:Color3,
}
export type MaidTask    = RBXScriptConnection|Instance|Tween|thread|(()->())
export type Maid        = { _tasks:{MaidTask}, GiveTask:(self:Maid,t:MaidTask)->(), Destroy:(self:Maid)->() }
export type CommandDef  = { name:string, desc:string, category:string, perm:number, run:(args:{string})->() }
export type HttpResponse = { success:boolean, status:number?, body:string?, error:string? }
export type ToastLevel  = "info"|"warn"|"success"|"danger"

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. MAID
-- ═══════════════════════════════════════════════════════════════════════════════

local Maid = {}; Maid.__index = Maid
function Maid.new(): Maid
    return setmetatable({ _tasks={} :: {MaidTask} }, Maid)
end
function Maid:GiveTask(t: MaidTask)
    table.insert(self._tasks, t)
end
function Maid:Destroy()
    local tasks = self._tasks
    self._tasks = {}
    for _, t in tasks do
        if typeof(t)=="RBXScriptConnection" then pcall(function()(t::RBXScriptConnection):Disconnect()end)
        elseif typeof(t)=="Instance"         then pcall(function()(t::Instance):Destroy()end)
        elseif typeof(t)=="Tween"            then pcall(function()(t::Tween):Cancel()end);pcall(function()(t::Tween):Destroy()end)
        elseif typeof(t)=="thread"           then pcall(function()task.cancel(t::thread)end)
        elseif type(t)  =="function"         then pcall(t)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. CONSTANTS & PALETTE
-- ═══════════════════════════════════════════════════════════════════════════════

local Z: Palette = {
    bg=Color3.fromRGB(12,12,14),       surface=Color3.fromRGB(18,18,21),
    elevated=Color3.fromRGB(26,26,30), card=Color3.fromRGB(22,22,26),
    hover=Color3.fromRGB(34,34,40),
    border=Color3.fromRGB(38,38,44),   borderHi=Color3.fromRGB(58,58,66),
    text=Color3.fromRGB(250,250,252),  text2=Color3.fromRGB(158,158,170),
    text3=Color3.fromRGB(98,98,110),
    lime=Color3.fromRGB(212,232,58),   lime2=Color3.fromRGB(232,249,106),
    limeDim=Color3.fromRGB(150,168,40),
    danger=Color3.fromRGB(239,68,68),  success=Color3.fromRGB(46,204,113),
    info=Color3.fromRGB(59,130,246),   warn=Color3.fromRGB(245,170,30),
    black=Color3.fromRGB(0,0,0),
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
local capturingKeybind = false   -- true while a Keybind picker awaits a key (suppresses menu toggle)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. LOGGING + CAPTURE
-- ═══════════════════════════════════════════════════════════════════════════════

local logs: {string} = {}
local logVersion     = 0

local function log(level: "INFO"|"WARN"|"ERROR"|"DEBUG"|"OUTPUT", message: string)
    local entry = string.format("[%s] [%s] %s", os.date("%H:%M:%S"), level, message)
    table.insert(logs, entry)
    if #logs > LOG_MAX then table.remove(logs, 1) end
    logVersion += 1
end

local function safeCall<T>(fn: ()->T, ctx: string): (boolean, T?)
    return xpcall(fn, function(err)
        log("ERROR", ctx .. ": " .. tostring(err) .. "\n" .. debug.traceback())
    end)
end

-- value-returning guarded call: returns fn() on success, else fallback (no logging)
local function tryGet<T>(fn: ()->T, fallback: T): T
    local ok, r = pcall(fn)
    if ok and r ~= nil then return r :: T end
    return fallback
end

pcall(function()
    if not _G["ZEX_ORIG_PRINT"] then
        _G["ZEX_ORIG_PRINT"] = print
        _G["ZEX_ORIG_WARN"]  = warn
    end
    local op = _G["ZEX_ORIG_PRINT"] :: (...any)->()
    local ow = _G["ZEX_ORIG_WARN"]  :: (...any)->()
    _G.print = function(...) log("OUTPUT","[print] "..table.concat({...}," ")); op(...) end
    _G.warn  = function(...) log("WARN",  "[warn] " ..table.concat({...}," ")); ow(...) end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 7. HTTP ENGINE — SSRF-protected, rate-limited, whitelisted
-- ═══════════════════════════════════════════════════════════════════════════════

local WHITELIST: {string} = {
    "webhookpulse.vercel.app","discord.com","discordapp.com","hooks.slack.com",
}
local rateBuckets: {[string]:{tokens:number,last:number}} = {}
local RATE_MAX = 5; local RATE_WINDOW = 10

local function checkRateLimit(endpoint: string): boolean
    local now  = os.clock()
    local host = endpoint:match("^https://([^/]+)")
    if not host then return false end
    host = host:gsub(":%d+$","")
    local b = rateBuckets[host]
    if not b then rateBuckets[host]={tokens=RATE_MAX-1,last=now}; return true end
    local elapsed = math.max(0, now-b.last)
    b.tokens = math.min(RATE_MAX, b.tokens+elapsed*(RATE_MAX/RATE_WINDOW))
    b.last = now
    if b.tokens >= 1 then b.tokens -= 1; return true end
    return false
end

local function isDomainAllowed(host: string): boolean
    for _, domain in ipairs(WHITELIST) do
        if host == domain or host:sub(-(#domain+1)) == "."..domain then return true end
    end
    return false
end

local function validateUrl(url: string): (boolean, string)
    if type(url)~="string"                      then return false,"URL must be string" end
    if not url:match("^https://")               then return false,"HTTPS required" end
    if url:match("^https://%d+%.%d+%.%d+%.%d+") then return false,"Direct IP not allowed" end
    if url:lower():match("^https://localhost")  then return false,"localhost blocked" end
    if url:lower():match("^https://0%.0%.0%.0") then return false,"0.0.0.0 blocked" end
    local host = url:match("^https://([^/?#]+)")
    if not host then return false,"Invalid URL" end
    host = host:gsub(":%d+$",""):lower()
    if not isDomainAllowed(host)                then return false,"Not whitelisted: "..host end
    return true,""
end

local function httpRequest(options: {[string]:any}): HttpResponse
    local result: HttpResponse = {success=false,status=nil,body=nil,error=nil}
    local layers: {()->{[string]:any}?} = {
        function()
            if not Executor.request then return nil end
            local ok,res = pcall(function() return (Executor.request::(any)->any)(options) end)
            return if ok then res else nil
        end,
        function()
            if not Services.HttpService then return nil end
            local ok,body = pcall(function()
                return (Services.HttpService::HttpService):PostAsync(options.Url,options.Body or "",
                    Enum.HttpContentType.ApplicationJson,false,options.Headers or {})
            end)
            return if ok then {success=true,body=body,StatusCode=200} else nil
        end,
        function()
            local hs = Services.HttpService :: any
            if not hs or not hs.RequestAsync then return nil end
            local ok,res = pcall(function()
                return hs:RequestAsync({Url=options.Url,Method=options.Method or "POST",
                    Headers=options.Headers or {},Body=options.Body})
            end)
            return if ok then res else nil
        end,
    }
    for _, layer in layers do
        local res = layer()
        if res then
            local code = (res.StatusCode or res.status) :: number?
            if code and code >= 300 and code < 400 then result.error="Redirect blocked (SSRF)"; return result end
            if (code and code >= 200 and code < 300) or res.success == true then
                result.success=true; result.status=code or 200
                result.body=(res.Body or res.body or "") :: string; return result
            end
        end
    end
    result.error="All HTTP layers failed"; return result
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 8. PERMISSION SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

local PERM       = {USER=1,MOD=2,ADMIN=3,OWNER=4}
local PERM_NAMES: {[number]:string} = {[1]="USER",[2]="MOD",[3]="ADMIN",[4]="OWNER"}
local userRank   = PERM.OWNER
local function canRun(p: number): boolean return userRank >= p end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 8b. FLAGS + CONFIG PERSISTENCE — survives re-execution (writefile/readfile)
-- ═══════════════════════════════════════════════════════════════════════════════

local Flags: {[string]:any} = {}
local CONFIG_DIR  = "ZEX"
local CONFIG_PATH = "ZEX/config.json"

local function saveConfig()
    if not hasFS then return end
    pcall(function()
        if FS.isfolder and FS.makefolder and not (FS.isfolder :: any)(CONFIG_DIR) then (FS.makefolder :: any)(CONFIG_DIR) end
        local json = HttpService:JSONEncode(Flags)
        local writeFn = FS.write :: any
        writeFn(CONFIG_PATH, json)
    end)
end

local saveQueued = false
local function queueSave()  -- debounce: coalesce rapid writes (slider drag, etc.)
    if saveQueued or not hasFS then return end
    saveQueued = true
    task.delay(0.6, function() saveQueued = false; saveConfig() end)
end

local function setFlag(key: string, value: any)
    Flags[key] = value
    queueSave()
end
local function getFlag(key: string, default: any): any
    local v = Flags[key]
    if v == nil then return default end
    return v
end

local function loadConfig()
    if not hasFS then return end
    pcall(function()
        if FS.isfile and not (FS.isfile :: any)(CONFIG_PATH) then return end
        local raw = (FS.read :: any)(CONFIG_PATH)
        if type(raw) ~= "string" or #raw == 0 then return end
        local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
        if ok and type(decoded) == "table" then
            for k, v in pairs(decoded) do Flags[k] = v end
        end
    end)
end
loadConfig()

-- ═══════════════════════════════════════════════════════════════════════════════
-- 9. COMMAND STATE
-- ═══════════════════════════════════════════════════════════════════════════════

type CmdState = {
    fly:boolean, noclip:boolean, godmode:boolean, invisible:boolean,
    esp:boolean, aimbot:boolean, clicktp:boolean, spin:boolean,
    antifling:boolean, antiafk:boolean, fullbright:boolean,
    flyConn:RBXScriptConnection?,       noclipConn:RBXScriptConnection?,
    spinConn:RBXScriptConnection?,      espConn:RBXScriptConnection?,
    aimbotConn:RBXScriptConnection?,    clicktpConn:RBXScriptConnection?,
    antiflingConn:RBXScriptConnection?, antiafkConn:RBXScriptConnection?,
    godmodeConn:RBXScriptConnection?,
    espInstances:{Instance},
}

local CMD_STATE: CmdState = {
    fly=false, noclip=false, godmode=false, invisible=false,
    esp=false, aimbot=false, clicktp=false, spin=false,
    antifling=false, antiafk=false, fullbright=false,
    flyConn=nil, noclipConn=nil, spinConn=nil, espConn=nil,
    aimbotConn=nil, clicktpConn=nil, antiflingConn=nil, antiafkConn=nil,
    godmodeConn=nil, espInstances={},
}

local espMaid: Maid? = nil

-- ═══════════════════════════════════════════════════════════════════════════════
-- 10. CHARACTER HELPERS
-- ═══════════════════════════════════════════════════════════════════════════════

local function getCharacter(): Model?     return localPlayer and localPlayer.Character end
local function getHumanoid():  Humanoid?  local c=getCharacter(); return c and c:FindFirstChildOfClass("Humanoid")::Humanoid? end
local function getRootPart():  Part?      local c=getCharacter(); return c and c:FindFirstChild("HumanoidRootPart")::Part? end
local function getAnimator():  Animator?  local h=getHumanoid(); return h and h:FindFirstChildOfClass("Animator")::Animator? end

local function getPlayerByName(name: string): Player?
    local lo = name:lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():find(lo,1,true) or p.DisplayName:lower():find(lo,1,true) then return p end
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 11. NOTIFICATION BRIDGE
-- ═══════════════════════════════════════════════════════════════════════════════

local showNotification: ((title:string,msg:string,level:ToastLevel)->())? = nil

local function notify(msg: string, level: ToastLevel?)
    local lv: ToastLevel = level or "info"
    log(if lv=="danger" then "ERROR" elseif lv=="warn" then "WARN" else "INFO", msg)
    if showNotification then
        local title = if lv=="danger" then "Error" elseif lv=="warn" then "Warning"
                      elseif lv=="success" then "Success" else "ZEX"
        showNotification(title,msg,lv)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 12. COMMAND REGISTRY
-- ═══════════════════════════════════════════════════════════════════════════════

local CommandRegistry: {[string]:CommandDef} = {}

local function reg(name:string,desc:string,cat:string,perm:number,run:(args:{string})->())
    CommandRegistry[name:lower()] = {name=name,desc=desc,category=cat,perm=perm,run=run}
end

-- ── PLAYER ───────────────────────────────────────────────────────────────────
reg("fly","Toggle fly","Player",PERM.USER,function(args)
    CMD_STATE.fly = not CMD_STATE.fly
    local char=getCharacter(); if not char then notify("No character","warn"); CMD_STATE.fly=false; return end
    local hum=getHumanoid();   if not hum  then notify("No humanoid","warn");  CMD_STATE.fly=false; return end
    local root=getRootPart();  if not root  then notify("No HRP","warn");       CMD_STATE.fly=false; return end
    if CMD_STATE.fly then
        hum.PlatformStand = true
        local bv = Instance.new("BodyVelocity")
        bv.Name="ZEX_Fly"; bv.MaxForce=Vector3.new(9e9,9e9,9e9); bv.Velocity=Vector3.zero; bv.Parent=root
        CMD_STATE.flyConn = RunService.RenderStepped:Connect(function()
            if not CMD_STATE.fly then return end
            local cam=Workspace.CurrentCamera; local dir=Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W)         then dir+=cam.CFrame.LookVector  end
            if UserInputService:IsKeyDown(Enum.KeyCode.S)         then dir-=cam.CFrame.LookVector  end
            if UserInputService:IsKeyDown(Enum.KeyCode.A)         then dir-=cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D)         then dir+=cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space)     then dir+=Vector3.yAxis           end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir-=Vector3.yAxis           end
            bv.Velocity = if dir.Magnitude>0 then dir.Unit*(tonumber(args[1]) or 50) else Vector3.zero
        end)
        notify("Fly ON","success")
    else
        hum.PlatformStand = false
        if CMD_STATE.flyConn then CMD_STATE.flyConn:Disconnect(); CMD_STATE.flyConn=nil end
        local bv=root:FindFirstChild("ZEX_Fly"); if bv then bv:Destroy() end
        notify("Fly OFF")
    end
end)
reg("unfly","Disable fly","Player",PERM.USER,function(_) if CMD_STATE.fly then CommandRegistry["fly"].run({}) end end)

reg("noclip","Toggle noclip","Player",PERM.USER,function(_)
    CMD_STATE.noclip = not CMD_STATE.noclip
    local char=getCharacter(); if not char then CMD_STATE.noclip=false; return end
    if CMD_STATE.noclip then
        CMD_STATE.noclipConn = RunService.Stepped:Connect(function()
            if not CMD_STATE.noclip then return end
            local c=getCharacter(); if not c then return end
            for _,v in ipairs(c:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide=false end end
        end)
        notify("Noclip ON","success")
    else
        if CMD_STATE.noclipConn then CMD_STATE.noclipConn:Disconnect(); CMD_STATE.noclipConn=nil end
        for _,v in ipairs(char:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide=true end end
        notify("Noclip OFF")
    end
end)
reg("clip","Disable noclip","Player",PERM.USER,function(_) if CMD_STATE.noclip then CommandRegistry["noclip"].run({}) end end)

reg("speed","Set walkspeed","Player",PERM.USER,function(args)
    local v=math.clamp(tonumber(args[1]) or 50,0,9999)
    local h=getHumanoid(); if h then h.WalkSpeed=v; notify("WalkSpeed = "..v) end
end)
reg("ws","WalkSpeed alias","Player",PERM.USER,function(a) CommandRegistry["speed"].run(a) end)

reg("jump","Set jumppower","Player",PERM.USER,function(args)
    local v=math.clamp(tonumber(args[1]) or 75,0,9999)
    local h=getHumanoid(); if h then h.JumpPower=v; h.UseJumpPower=true; notify("JumpPower = "..v) end
end)
reg("jp","JumpPower alias","Player",PERM.USER,function(a) CommandRegistry["jump"].run(a) end)

reg("gravity","Set gravity","World",PERM.USER,function(args)
    local v=tonumber(args[1]) or 196.2; Workspace.Gravity=v; notify("Gravity = "..v)
end)
reg("heal","Restore health","Player",PERM.USER,function(_)
    local h=getHumanoid(); if h then h.Health=h.MaxHealth; notify("Healed","success") end
end)
reg("kill","Kill self","Player",PERM.USER,function(_)
    local h=getHumanoid(); if h then h.Health=0; notify("Killed") end
end)

reg("godmode","Toggle godmode","Player",PERM.MOD,function(_)
    CMD_STATE.godmode = not CMD_STATE.godmode
    if CMD_STATE.godmode then
        local hum=getHumanoid(); if not hum then notify("No humanoid","warn"); CMD_STATE.godmode=false; return end
        hum.Health = hum.MaxHealth
        CMD_STATE.godmodeConn = hum:GetPropertyChangedSignal("Health"):Connect(function()
            if CMD_STATE.godmode and hum.Health < hum.MaxHealth then hum.Health=hum.MaxHealth end
        end)
        notify("Godmode ON","success")
    else
        if CMD_STATE.godmodeConn then CMD_STATE.godmodeConn:Disconnect(); CMD_STATE.godmodeConn=nil end
        notify("Godmode OFF")
    end
end)
reg("ungodmode","Disable godmode","Player",PERM.MOD,function(_) if CMD_STATE.godmode then CommandRegistry["godmode"].run({}) end end)

reg("invisible","Toggle invisibility","Player",PERM.MOD,function(_)
    CMD_STATE.invisible = not CMD_STATE.invisible
    local char=getCharacter(); if not char then CMD_STATE.invisible=false; return end
    for _,v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") or v:IsA("Decal") or v:IsA("Texture") then
            v.Transparency = if CMD_STATE.invisible then 1 else 0
        end
        if v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled=not CMD_STATE.invisible end
    end
    notify(if CMD_STATE.invisible then "Invisible ON" else "Visible", if CMD_STATE.invisible then "success" else nil)
end)
reg("visible","Disable invisibility","Player",PERM.MOD,function(_) if CMD_STATE.invisible then CommandRegistry["invisible"].run({}) end end)

reg("sit",  "Force sit",  "Player",PERM.USER,function(_) local h=getHumanoid(); if h then h.Sit=true  end end)
reg("unsit","Force stand","Player",PERM.USER,function(_) local h=getHumanoid(); if h then h.Sit=false end end)

reg("freeze","Freeze character","Player",PERM.MOD,function(_)
    local c=getCharacter(); if not c then return end
    for _,v in ipairs(c:GetDescendants()) do if v:IsA("BasePart") then v.Anchored=true end end
    notify("Frozen","warn")
end)
reg("thaw","Unfreeze","Player",PERM.MOD,function(_)
    local c=getCharacter(); if not c then return end
    for _,v in ipairs(c:GetDescendants()) do if v:IsA("BasePart") then v.Anchored=false end end
    notify("Thawed")
end)

reg("spin","Toggle spin","Player",PERM.USER,function(_)
    CMD_STATE.spin = not CMD_STATE.spin
    local root=getRootPart(); if not root then CMD_STATE.spin=false; return end
    if CMD_STATE.spin then
        CMD_STATE.spinConn = RunService.RenderStepped:Connect(function()
            if not CMD_STATE.spin then return end
            local r=getRootPart(); if r then r.CFrame=r.CFrame*CFrame.Angles(0,math.rad(10),0) end
        end)
        notify("Spin ON")
    else
        if CMD_STATE.spinConn then CMD_STATE.spinConn:Disconnect(); CMD_STATE.spinConn=nil end
        notify("Spin OFF")
    end
end)

reg("dance","Play dance emote","Player",PERM.USER,function(_)
    local anim=getAnimator()
    if anim then
        local a=Instance.new("Animation"); a.AnimationId="rbxassetid://507771019"
        anim:LoadAnimation(a):Play(); notify("Dancing","success")
    else notify("No animator","warn") end
end)
reg("reset","Reset character","Player",PERM.USER,function(_)
    pcall(function() localPlayer:LoadCharacter() end); notify("Reset")
end)
reg("refresh","Respawn in place","Player",PERM.USER,function(_)
    local root=getRootPart(); if not root then return end
    local pos=root.CFrame
    pcall(function() localPlayer:LoadCharacter() end)
    task.delay(0.5,function()
        local nc=localPlayer and localPlayer.Character; if not nc then return end
        local nr=nc:WaitForChild("HumanoidRootPart",3)::Part?; if nr then nr.CFrame=pos end
    end)
    notify("Refresh")
end)

reg("antiafk","Toggle anti-AFK","Utility",PERM.USER,function(_)
    CMD_STATE.antiafk = not CMD_STATE.antiafk
    if CMD_STATE.antiafk then
        notify("Anti-AFK ON","success")
        task.spawn(function()
            while CMD_STATE.antiafk do
                local h=getHumanoid()
                if h then pcall(function() h:ChangeState(Enum.HumanoidStateType.RunningNoPhysics) end) end
                task.wait(55)
            end
        end)
    else notify("Anti-AFK OFF") end
end)

reg("antifling","Toggle anti-fling","Player",PERM.USER,function(_)
    CMD_STATE.antifling = not CMD_STATE.antifling
    if CMD_STATE.antifling then
        CMD_STATE.antiflingConn = RunService.Heartbeat:Connect(function()
            if not CMD_STATE.antifling then return end
            local char=getCharacter(); if not char then return end
            for _,v in ipairs(char:GetDescendants()) do
                if v:IsA("BasePart") and v.Name~="HumanoidRootPart" then
                    v.Velocity=Vector3.zero; v.RotVelocity=Vector3.zero
                end
            end
        end)
        notify("Anti-Fling ON","success")
    else
        if CMD_STATE.antiflingConn then CMD_STATE.antiflingConn:Disconnect(); CMD_STATE.antiflingConn=nil end
        notify("Anti-Fling OFF")
    end
end)

-- ── COMBAT ───────────────────────────────────────────────────────────────────
-- Shared targeting helpers
local function isTeammate(p: Player): boolean
    return p.Team ~= nil and localPlayer.Team ~= nil and p.Team == localPlayer.Team and not p.Neutral
end
local function isVisible(targetPart: BasePart): boolean
    local cam=Workspace.CurrentCamera; if not cam then return true end
    local char=localPlayer.Character
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances={char,cam}
    local origin=cam.CFrame.Position
    local dir=targetPart.Position-origin
    local hit=Workspace:Raycast(origin,dir,params)
    return hit==nil or hit.Instance:IsDescendantOf(targetPart.Parent)
end

-- Drawing-based ESP: box + name + healthbar + distance + tracer (high-perf)
local function startDrawingESP(maid: Maid)
    local cache: {[Player]:{[string]:any}} = {}
    local function removeP(p: Player)
        local d=cache[p]; if not d then return end
        for _,o in pairs(d) do pcall(function() o.Visible=false; o:Remove() end) end
        cache[p]=nil
    end
    maid:GiveTask(function() for p in pairs(cache) do removeP(p) end end)
    maid:GiveTask(Players.PlayerRemoving:Connect(removeP))
    local function ensure(p: Player)
        if cache[p] then return cache[p] end
        local d={box=(DrawingNew::any)("Square"),name=(DrawingNew::any)("Text"),dist=(DrawingNew::any)("Text"),
                 hpBg=(DrawingNew::any)("Line"),hp=(DrawingNew::any)("Line"),tracer=(DrawingNew::any)("Line")}
        d.box.Thickness=1; d.box.Filled=false; d.box.Color=Z.lime
        d.name.Size=13; d.name.Center=true; d.name.Outline=true; d.name.Color=Color3.new(1,1,1)
        d.dist.Size=12; d.dist.Center=true; d.dist.Outline=true; d.dist.Color=Color3.fromRGB(200,200,200)
        d.hpBg.Thickness=3; d.hpBg.Color=Color3.new(0,0,0)
        d.hp.Thickness=1;   d.hp.Color=Z.success
        d.tracer.Thickness=1; d.tracer.Color=Z.lime
        cache[p]=d; return d
    end
    maid:GiveTask(RunService.RenderStepped:Connect(function()
        local cam=Workspace.CurrentCamera; if not cam then return end
        local sBox,sName=getFlag("esp_box",true),getFlag("esp_name",true)
        local sHp,sDist=getFlag("esp_health",true),getFlag("esp_distance",true)
        local sTracer,sTeam=getFlag("esp_tracer",false),getFlag("esp_team",false)
        local maxDist=tonumber(getFlag("esp_maxdist",0)) or 0
        local mc=localPlayer.Character
        local myHrp=mc and mc:FindFirstChild("HumanoidRootPart")
        for _,p in ipairs(Players:GetPlayers()) do
            if p==localPlayer then continue end
            local char=p.Character
            local hrp=char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
            local hum=char and char:FindFirstChildOfClass("Humanoid") :: Humanoid?
            local ok = char~=nil and hrp~=nil and hum~=nil and hum.Health>0 and (sTeam or not isTeammate(p))
            local dist = (ok and myHrp) and (hrp.Position-myHrp.Position).Magnitude or 0
            if ok and maxDist>0 and dist>maxDist then ok=false end
            local d=cache[p]
            if not ok then if d then for _,o in pairs(d) do o.Visible=false end end; continue end
            d=ensure(p)
            local rootPos,onScreen=cam:WorldToViewportPoint(hrp.Position)
            if not onScreen then for _,o in pairs(d) do o.Visible=false end; continue end
            local topV=cam:WorldToViewportPoint(hrp.Position+Vector3.new(0,3,0))
            local botV=cam:WorldToViewportPoint(hrp.Position-Vector3.new(0,3.5,0))
            local h=math.abs(topV.Y-botV.Y); local w=h*0.5
            local x,y=rootPos.X-w/2, topV.Y
            d.box.Visible=sBox; if sBox then d.box.Size=Vector2.new(w,h); d.box.Position=Vector2.new(x,y) end
            d.name.Visible=sName; if sName then d.name.Text=p.Name; d.name.Position=Vector2.new(rootPos.X,y-16) end
            d.dist.Visible=sDist; if sDist then d.dist.Text=tostring(math.floor(dist)).."m"; d.dist.Position=Vector2.new(rootPos.X,y+h+2) end
            local frac=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
            local hbx=x-4
            d.hpBg.Visible=sHp; d.hp.Visible=sHp
            if sHp then
                d.hpBg.From=Vector2.new(hbx,y); d.hpBg.To=Vector2.new(hbx,y+h)
                d.hp.From=Vector2.new(hbx,y+h*(1-frac)); d.hp.To=Vector2.new(hbx,y+h)
                d.hp.Color = if frac>0.5 then Z.success elseif frac>0.25 then Z.warn else Z.danger
            end
            d.tracer.Visible=sTracer
            if sTracer then local vp=cam.ViewportSize; d.tracer.From=Vector2.new(vp.X/2,vp.Y); d.tracer.To=Vector2.new(rootPos.X,y+h) end
        end
    end))
end

-- Highlight fallback ESP (no Drawing API)
local function startHighlightESP(em: Maid)
    local function attachChar(p: Player, char: Model)
        local pMaid=Maid.new(); em:GiveTask(function() pMaid:Destroy() end)
        local head=char:FindFirstChild("Head")::BasePart?; if not head then return end
        local hl=Instance.new("Highlight"); hl.Name="ZEX_ESP"
        hl.FillColor=Z.danger; hl.OutlineColor=Z.lime
        hl.FillTransparency=0.72; hl.OutlineTransparency=0.25; hl.Parent=char; pMaid:GiveTask(hl)
        local bg=Instance.new("BillboardGui"); bg.Name="ZEX_ESP"; bg.AlwaysOnTop=true
        bg.Size=UDim2.new(0,120,0,40); bg.StudsOffset=Vector3.new(0,2.8,0); bg.Parent=head; pMaid:GiveTask(bg)
        local nameL=Instance.new("TextLabel"); nameL.Size=UDim2.new(1,0,0,16); nameL.BackgroundTransparency=1
        nameL.TextColor3=Z.lime; nameL.Font=F_BODY; nameL.TextSize=12; nameL.Text=p.Name
        nameL.TextStrokeTransparency=0.5; nameL.Parent=bg
        local distL=Instance.new("TextLabel"); distL.Size=UDim2.new(1,0,0,14); distL.Position=UDim2.new(0,0,0,16)
        distL.BackgroundTransparency=1; distL.TextColor3=Z.text2; distL.Font=F_THIN; distL.TextSize=10
        distL.Text="? studs"; distL.TextStrokeTransparency=0.6; distL.Parent=bg
        local hpBg=Instance.new("Frame"); hpBg.Size=UDim2.new(1,0,0,4); hpBg.Position=UDim2.new(0,0,0,32)
        hpBg.BackgroundColor3=Z.elevated; hpBg.BorderSizePixel=0; hpBg.Parent=bg
        local cc1=Instance.new("UICorner"); cc1.CornerRadius=UDim.new(0,2); cc1.Parent=hpBg
        local hpFill=Instance.new("Frame"); hpFill.Size=UDim2.new(1,0,1,0); hpFill.BackgroundColor3=Z.success
        hpFill.BorderSizePixel=0; hpFill.Parent=hpBg
        local cc2=Instance.new("UICorner"); cc2.CornerRadius=UDim.new(0,2); cc2.Parent=hpFill
        local hum=char:FindFirstChildOfClass("Humanoid")
        local hrp=char:FindFirstChild("HumanoidRootPart")::BasePart?
        pMaid:GiveTask(RunService.RenderStepped:Connect(function()
            if not hum or not hum.Parent then return end
            local hp=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
            hpFill.Size=UDim2.new(hp,0,1,0)
            hpFill.BackgroundColor3=if hp>0.5 then Z.success elseif hp>0.25 then Z.warn else Z.danger
            local mc=localPlayer.Character
            if hrp and mc then
                local myHrp=mc:FindFirstChild("HumanoidRootPart")::BasePart?
                if myHrp then distL.Text=math.floor((hrp.Position-myHrp.Position).Magnitude).." studs" end
            end
        end))
    end
    local function addESP(p: Player)
        if p==localPlayer then return end
        if p.Character then attachChar(p,p.Character) end
        em:GiveTask(p.CharacterAdded:Connect(function(char) task.wait(0.3); attachChar(p,char) end))
    end
    for _,p in ipairs(Players:GetPlayers()) do addESP(p) end
    local conn=Players.PlayerAdded:Connect(addESP)
    em:GiveTask(function() conn:Disconnect() end)
end

reg("esp","Toggle ESP","Combat",PERM.MOD,function(_)
    CMD_STATE.esp = not CMD_STATE.esp
    if CMD_STATE.esp then
        if espMaid then espMaid:Destroy() end
        local em = Maid.new(); espMaid = em
        if hasDrawing then startDrawingESP(em) else startHighlightESP(em) end
        notify(if hasDrawing then "ESP ON (Drawing)" else "ESP ON (Highlight)","success")
    else
        if espMaid then espMaid:Destroy(); espMaid=nil end
        notify("ESP OFF")
    end
end)
reg("unesp","Disable ESP","Combat",PERM.MOD,function(_) if CMD_STATE.esp then CommandRegistry["esp"].run({}) end end)

local aimFovCircle: any = nil
local function getAimTarget(fovPx:number, needVisible:boolean, allowTeam:boolean, partName:string): BasePart?
    local cam=Workspace.CurrentCamera; if not cam then return nil end
    local center=cam.ViewportSize/2
    local best=fovPx; local target:BasePart?=nil
    for _,p in ipairs(Players:GetPlayers()) do
        if p==localPlayer then continue end
        if not allowTeam and isTeammate(p) then continue end
        local char=p.Character; if not char then continue end
        local hum=char:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health<=0 then continue end
        local part=(char:FindFirstChild(partName) or char:FindFirstChild("HumanoidRootPart")) :: BasePart?
        if not part then continue end
        local sp,on=cam:WorldToViewportPoint(part.Position)
        if not on then continue end
        local d=(Vector2.new(sp.X,sp.Y)-center).Magnitude
        if d<best then
            if needVisible and not isVisible(part) then continue end
            best=d; target=part
        end
    end
    return target
end

reg("aimbot","Aimbot — FOV·visibility·smoothing","Combat",PERM.MOD,function(_)
    CMD_STATE.aimbot = not CMD_STATE.aimbot
    if CMD_STATE.aimbot then
        if hasDrawing and getFlag("aim_fovcircle",true) then
            aimFovCircle=(DrawingNew::any)("Circle")
            aimFovCircle.Thickness=1; aimFovCircle.NumSides=64; aimFovCircle.Color=Z.lime
            aimFovCircle.Filled=false; aimFovCircle.Transparency=0.55
        end
        CMD_STATE.aimbotConn = RunService.RenderStepped:Connect(function()
            if not CMD_STATE.aimbot then return end
            local cam=Workspace.CurrentCamera; if not cam then return end
            local fov=tonumber(getFlag("aim_fov",120)) or 120
            if aimFovCircle then aimFovCircle.Visible=true; aimFovCircle.Radius=fov; aimFovCircle.Position=cam.ViewportSize/2 end
            if getFlag("aim_hold",true) and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
            local part=getAimTarget(fov, getFlag("aim_visible",true)==true, getFlag("aim_team",false)==true, tostring(getFlag("aim_part","Head")))
            if not part then return end
            local smooth=math.clamp(tonumber(getFlag("aim_smooth",0.5)) or 0.5, 0, 0.95)
            local goal=CFrame.new(cam.CFrame.Position, part.Position)
            cam.CFrame=cam.CFrame:Lerp(goal, 1-smooth)
        end)
        notify("Aimbot ON (hold RMB)","success")
    else
        if CMD_STATE.aimbotConn then CMD_STATE.aimbotConn:Disconnect(); CMD_STATE.aimbotConn=nil end
        if aimFovCircle then pcall(function() aimFovCircle.Visible=false; aimFovCircle:Remove() end); aimFovCircle=nil end
        notify("Aimbot OFF")
    end
end)
reg("unaimbot","Disable aimbot","Combat",PERM.MOD,function(_) if CMD_STATE.aimbot then CommandRegistry["aimbot"].run({}) end end)

reg("clicktp","Toggle click-TP (Ctrl+Click)","Combat",PERM.USER,function(_)
    CMD_STATE.clicktp = not CMD_STATE.clicktp
    if CMD_STATE.clicktp then
        CMD_STATE.clicktpConn = UserInputService.InputBegan:Connect(function(input,gp)
            if gp then return end
            if input.UserInputType==Enum.UserInputType.MouseButton1
                and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                local mouse=localPlayer:GetMouse(); local root=getRootPart()
                if root then root.CFrame=CFrame.new(mouse.Hit.Position+Vector3.new(0,3,0)) end
            end
        end)
        notify("ClickTP ON")
    else
        if CMD_STATE.clicktpConn then CMD_STATE.clicktpConn:Disconnect(); CMD_STATE.clicktpConn=nil end
        notify("ClickTP OFF")
    end
end)

-- ── WORLD ────────────────────────────────────────────────────────────────────
reg("fullbright","Toggle fullbright","World",PERM.USER,function(_)
    CMD_STATE.fullbright = not CMD_STATE.fullbright
    if CMD_STATE.fullbright then
        Lighting.Brightness=2; Lighting.GlobalShadows=false; Lighting.ClockTime=12; Lighting.FogEnd=1e6
        notify("Fullbright ON","success")
    else notify("Fullbright OFF") end
end)
reg("time","Set lighting time","World",PERM.USER,function(args)
    local v=tonumber(args[1]) or 12; Lighting.ClockTime=v; notify("Time = "..v)
end)
reg("fog","Set fog end","World",PERM.USER,function(args)
    local v=tonumber(args[1]) or 100000; Lighting.FogEnd=v; notify("Fog = "..v)
end)
reg("clearterrain","Clear terrain","World",PERM.ADMIN,function(_)
    local t=Workspace:FindFirstChildOfClass("Terrain"); if t then t:Clear(); notify("Terrain cleared","warn") end
end)

-- ── SERVER ───────────────────────────────────────────────────────────────────
reg("rejoin","Rejoin server","Server",PERM.USER,function(_)
    notify("Rejoining..."); TeleportService:Teleport(game.PlaceId,localPlayer)
end)
reg("serverhop","Hop to different server","Server",PERM.USER,function(_)
    if not Executor.request then notify("Executor HTTP unavailable","danger"); return end
    notify("Server hopping...")
    task.spawn(function()
        local url="https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
        local res=httpRequest({Url=url,Method="GET",Headers={}})
        if not res.success or not res.body then notify("Serverhop failed","warn"); return end
        local ok,data=pcall(function() return HttpService:JSONDecode(res.body::string) end)
        if ok and data and data.data then
            for _,server in ipairs(data.data) do
                if server.id~=game.JobId and server.playing<server.maxPlayers then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId,server.id,localPlayer); return
                end
            end
        end
        notify("No available servers","warn")
    end)
end)
reg("teleport","Teleport to player","Server",PERM.MOD,function(args)
    local t=getPlayerByName(args[1] or ""); if not t then notify("Not found","warn"); return end
    local tr=t.Character and t.Character:FindFirstChild("HumanoidRootPart")::Part?
    local r=getRootPart()
    if tr and r then r.CFrame=tr.CFrame; notify("Teleported to "..t.Name,"success") end
end)
reg("tp","Teleport alias","Server",PERM.MOD,function(a) CommandRegistry["teleport"].run(a) end)
reg("bring","Bring player [local]","Server",PERM.ADMIN,function(args)
    local t=getPlayerByName(args[1] or ""); if not t or not t.Character then return end
    local tr=t.Character:FindFirstChild("HumanoidRootPart")::Part?; local r=getRootPart()
    if tr and r then tr.CFrame=r.CFrame; notify("Brought "..t.Name.." [local]","warn") end
end)
reg("fling","Fling player [local]","Server",PERM.ADMIN,function(args)
    local t=getPlayerByName(args[1] or ""); if not t or not t.Character then return end
    local tr=t.Character:FindFirstChild("HumanoidRootPart")::Part?
    if tr then
        local bv=Instance.new("BodyVelocity"); bv.MaxForce=Vector3.new(9e9,9e9,9e9)
        bv.Velocity=Vector3.new(0,500,0); bv.Parent=tr; task.delay(0.5,function() bv:Destroy() end)
        notify("Flung "..t.Name.." [local]","warn")
    end
end)
reg("killall","Kill all [local]","Server",PERM.OWNER,function(_)
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=localPlayer and p.Character then
            local h=p.Character:FindFirstChildOfClass("Humanoid")::Humanoid?
            if h then pcall(function() h.Health=0 end) end
        end
    end
    notify("Killed all [local]","warn")
end)

-- ── UTILITY ──────────────────────────────────────────────────────────────────
reg("btools","Give build tool","Utility",PERM.MOD,function(_)
    local bp=localPlayer:FindFirstChildOfClass("Backpack"); if not bp then return end
    local t=Instance.new("Tool"); t.RequiresHandle=false; t.ToolTip="ZEX Build"; t.Parent=bp; notify("BTools given")
end)
reg("removetools","Remove all tools","Utility",PERM.MOD,function(_)
    local bp=localPlayer:FindFirstChildOfClass("Backpack")
    if bp then for _,v in ipairs(bp:GetChildren()) do if v:IsA("Tool") then v:Destroy() end end end
    local char=getCharacter()
    if char then for _,v in ipairs(char:GetChildren()) do if v:IsA("Tool") then v:Destroy() end end end
    notify("Tools removed")
end)
reg("view","View player camera","Utility",PERM.MOD,function(args)
    local t=getPlayerByName(args[1] or "")
    if t and t.Character then
        local h=t.Character:FindFirstChildOfClass("Humanoid")::Humanoid?
        Workspace.CurrentCamera.CameraSubject=h or t.Character; notify("Viewing "..t.Name)
    end
end)
reg("unview","Reset camera","Utility",PERM.MOD,function(_)
    local h=getHumanoid(); if h then Workspace.CurrentCamera.CameraSubject=h; notify("Camera reset") end
end)
reg("copypos","Copy position to clipboard","Utility",PERM.USER,function(_)
    local root=getRootPart(); if not root then notify("No HRP","warn"); return end
    local p=root.Position; local s=string.format("%.2f, %.2f, %.2f",p.X,p.Y,p.Z)
    if Executor.setclipboard then pcall(function()(Executor.setclipboard::(string)->boolean)(s)end); notify("Copied: "..s,"success")
    else notify("Pos: "..s) end
end)

-- ── GRAPHICS (merged from v7.0) ────────────────────────────────────────────────
reg("lowgraphics","Min render quality","World",PERM.USER,function(_)
    pcall(function() (settings() :: any).Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    pcall(function() Lighting.GlobalShadows=false; Lighting.FogEnd=1e6 end)
    notify("Low graphics","success")
end)
reg("maxgraphics","Max render quality","World",PERM.USER,function(_)
    pcall(function() (settings() :: any).Rendering.QualityLevel = Enum.QualityLevel.Level21 end)
    notify("Max graphics","success")
end)
reg("restorelight","Restore default lighting","World",PERM.USER,function(_)
    pcall(function()
        Lighting.Brightness=2; Lighting.GlobalShadows=true
        Lighting.Ambient=Color3.fromRGB(127,127,127); Lighting.OutdoorAmbient=Color3.fromRGB(127,127,127)
        Lighting.FogEnd=100000
    end)
    CMD_STATE.fullbright=false; notify("Lighting restored")
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 13. MOTION ENGINE — tween · ripple · hover
-- ═══════════════════════════════════════════════════════════════════════════════

local activeTweens: {[Instance]:Tween} = {}

local function tween(obj:Instance,props:{[string]:any},info:TweenInfo?,maid:Maid?): Tween?
    if not obj or not obj.Parent then return nil end
    if activeTweens[obj] then
        pcall(function() activeTweens[obj]:Cancel() end); pcall(function() activeTweens[obj]:Destroy() end)
        activeTweens[obj]=nil
    end
    local ok,tw=pcall(function() return TweenService:Create(obj,info or SMOOTH,props) end)
    if not ok or not tw then return nil end
    activeTweens[obj]=tw
    local conn=(tw::Tween).Completed:Connect(function()
        if activeTweens[obj]==tw then activeTweens[obj]=nil end
        pcall(function()(tw::Tween):Destroy()end)
    end)
    if maid then maid:GiveTask(function()
        if activeTweens[obj]==tw then activeTweens[obj]=nil end
        pcall(function() conn:Disconnect() end)
        pcall(function()(tw::Tween):Cancel()end); pcall(function()(tw::Tween):Destroy()end)
    end) end
    (tw::Tween):Play(); return tw
end

local function hoverFx(inst:GuiObject,maid:Maid,normal:{[string]:any},hover:{[string]:any})
    maid:GiveTask(inst.MouseEnter:Connect(function() tween(inst,hover,FAST,maid) end))
    maid:GiveTask(inst.MouseLeave:Connect(function() tween(inst,normal,FAST,maid) end))
end

local function ripple(btn:GuiObject,color:Color3?)
    if not btn or not btn.Parent then return end
    local r=Instance.new("Frame")
    r.BackgroundColor3=color or Z.lime; r.BackgroundTransparency=0.78; r.BorderSizePixel=0
    r.AnchorPoint=Vector2.new(0.5,0.5); r.ZIndex=btn.ZIndex+5
    local cc=Instance.new("UICorner"); cc.CornerRadius=UDim.new(1,0); cc.Parent=r
    local mp=UserInputService:GetMouseLocation()
    local rel=Vector2.new(mp.X,mp.Y)-btn.AbsolutePosition
    r.Position=UDim2.fromOffset(rel.X,rel.Y); r.Size=UDim2.fromOffset(0,0); r.Parent=btn
    local big=math.max(btn.AbsoluteSize.X,btn.AbsoluteSize.Y)*2.2
    TweenService:Create(r,TweenInfo.new(0.5,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
        {Size=UDim2.fromOffset(big,big),BackgroundTransparency=1}):Play()
    task.delay(0.52,function() if r then r:Destroy() end end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 14. UI PRIMITIVES
-- ═══════════════════════════════════════════════════════════════════════════════

local function corner(r:number): UICorner local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r); return c end
local function stroke(col:Color3,t:number): UIStroke local s=Instance.new("UIStroke"); s.Color=col; s.Thickness=t; s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; return s end
local function pad(all:number): UIPadding
    local p=Instance.new("UIPadding")
    p.PaddingTop=UDim.new(0,all); p.PaddingBottom=UDim.new(0,all); p.PaddingLeft=UDim.new(0,all); p.PaddingRight=UDim.new(0,all); return p
end
local function mk<T>(class:string, props:{[string]:any}): T
    local o=Instance.new(class)
    for k,v in pairs(props) do if k~="Parent" then (o::any)[k]=v end end
    if props.Parent then o.Parent=props.Parent end
    return o::any
end
local function Frame(p:{[string]:any}): Frame return mk("Frame",p) end
local function Label(p:{[string]:any}): TextLabel
    p.BackgroundTransparency=p.BackgroundTransparency or 1; p.Font=p.Font or F_BODY
    p.TextColor3=p.TextColor3 or Z.text; p.TextSize=p.TextSize or 12
    return mk("TextLabel",p)
end
local function Button(p:{[string]:any}): TextButton
    p.AutoButtonColor=false; p.BorderSizePixel=0; p.Font=p.Font or F_BTN
    return mk("TextButton",p)
end
local function TextBox(p:{[string]:any}): TextBox
    p.BorderSizePixel=0; p.Font=p.Font or F_CODE; p.ClearTextOnFocus=p.ClearTextOnFocus or false
    return mk("TextBox",p)
end
local function Scroll(p:{[string]:any}): ScrollingFrame
    p.BorderSizePixel=0; p.ScrollBarThickness=p.ScrollBarThickness or 3
    p.ScrollBarImageColor3=p.ScrollBarImageColor3 or Z.border; p.ScrollBarImageTransparency=0.3
    return mk("ScrollingFrame",p)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 15. VECTOR ICON SYSTEM — drawn from Frames, no asset dependency
-- ═══════════════════════════════════════════════════════════════════════════════

local function drawIcon(name:string, parent:GuiObject, color:Color3): Frame
    local c=Frame({Name="Icon",BackgroundTransparency=1,Size=UDim2.fromOffset(20,20),
        AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Parent=parent})
    local function bit(w:number,h:number,x:number,y:number,rot:number?,round:number?): Frame
        local f=Frame({BackgroundColor3=color,BorderSizePixel=0,AnchorPoint=Vector2.new(0.5,0.5),
            Size=UDim2.fromOffset(w,h),Position=UDim2.new(0.5,x,0.5,y),Rotation=rot or 0,Parent=c})
        local cc=Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,round or 1); cc.Parent=f; return f
    end
    local function ring(d:number,th:number,x:number,y:number)
        local f=Frame({BackgroundTransparency=1,AnchorPoint=Vector2.new(0.5,0.5),
            Size=UDim2.fromOffset(d,d),Position=UDim2.new(0.5,x,0.5,y),Parent=c})
        local cc=Instance.new("UICorner"); cc.CornerRadius=UDim.new(1,0); cc.Parent=f
        local s=stroke(color,th); s.Parent=f
    end
    if name=="dashboard" then
        for _,o in {{-4,-4},{4,-4},{-4,4},{4,4}} do bit(7,7,o[1],o[2],0,2) end
    elseif name=="commands" then
        bit(14,2.5,0,-5,0,1); bit(14,2.5,0,0,0,1); bit(10,2.5,-2,5,0,1)
    elseif name=="player" then
        local h=bit(7,7,0,-5); h:FindFirstChildOfClass("UICorner").CornerRadius=UDim.new(1,0)
        bit(13,7,0,5,0,3)
    elseif name=="combat" then
        ring(16,2,0,0); bit(3,3,0,0,0,1); bit(2,5,0,-9,0,1); bit(2,5,0,9,0,1); bit(5,2,-9,0,0,1); bit(5,2,9,0,0,1)
    elseif name=="world" then
        bit(13,2,0,-5,0,1); bit(13,2,0,0,0,1); bit(13,2,0,5,0,1)
        bit(2,16,-6,0,0,1)
    elseif name=="server" then
        for _,y in {-6,0,6} do bit(15,4,0,y,0,2) end
    elseif name=="editor" then
        bit(7,2,-4,-3,55,1); bit(7,2,-4,3,-55,1)
        bit(7,2,4,-3,-55,1); bit(7,2,4,3,55,1)
    elseif name=="console" then
        bit(6,2,-3,-2,40,1); bit(6,2,-3,2,-40,1); bit(7,2,3,5,0,1)
    elseif name=="settings" then
        ring(13,2,0,0); bit(4,4,0,0,0,1)
        for _,o in {{0,-9},{9,0},{0,9},{-9,0}} do bit(4,4,o[1],o[2],0,1) end
    elseif name=="close" then
        bit(16,2,0,0,45,1); bit(16,2,0,0,-45,1)
    elseif name=="minimize" then
        bit(14,2,0,6,0,1)
    elseif name=="search" then
        ring(11,2,-2,-2); bit(6,2,5,5,45,1)
    elseif name=="bolt" then
        bit(4,8,-1,-3,18,1); bit(4,8,1,3,18,1)
    elseif name=="webhook" then
        ring(7,2,-3,-4); ring(7,2,4,-2); ring(7,2,0,5); bit(2,6,-1,0,30,1); bit(2,6,2,1,-30,1)
    elseif name=="network" then
        bit(12,2,0,-4,20,1); bit(12,2,0,4,-20,1); bit(4,4,-6,-4,0,2); bit(4,4,6,4,0,2)
    elseif name=="intel" then
        bit(13,16,0,0,0,2); bit(8,2,0,-4,0,1); bit(8,2,0,0,0,1); bit(5,2,-1,4,0,1)
    else
        bit(10,10,0,0,0,2)
    end
    return c
end
local function recolorIcon(iconC:Frame, color:Color3)
    for _,ch in ipairs(iconC:GetChildren()) do
        if ch:IsA("Frame") then
            if ch.BackgroundTransparency<1 then ch.BackgroundColor3=color end
            local s=ch:FindFirstChildOfClass("UIStroke"); if s then s.Color=color end
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
    if Executor.gethui then local ok,hui=pcall(Executor.gethui::()->Instance); if ok and hui then parent=hui end end
    if not parent and Executor.cloneref then
        local ok,ref=pcall(function() return (Executor.cloneref::(Instance)->Instance)(game.CoreGui) end)
        if ok and ref then parent=ref end
    end
    if not parent then parent=game.CoreGui end
    screenGui=mk("ScreenGui",{Name="ZEX_v800",ResetOnSpawn=false,IgnoreGuiInset=true,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=999,Parent=parent})
    applyGuiProtection(screenGui)   -- anti-detection: hide from game scripts where supported
    rootMaid:GiveTask(screenGui)
end)
if not screenGui then log("ERROR","[ZEX] ScreenGui failed"); return end

local WIN_W, WIN_H = 760, 500

-- background blur (executor-side BlurEffect on Lighting)
local blurEnabled = getFlag("blur",true)==true
local blur: BlurEffect = mk("BlurEffect",{Name="ZEX_Blur",Size=0,Parent=Lighting})
rootMaid:GiveTask(blur)

-- dim layer
local dim=Frame({Name="Dim",Size=UDim2.fromScale(1,1),BackgroundColor3=Z.black,
    BackgroundTransparency=1,BorderSizePixel=0,ZIndex=1,Parent=screenGui})
rootMaid:GiveTask(dim)

-- holder (draggable, unclipped — carries shadow + window)
local holder=Frame({Name="Holder",Size=UDim2.fromOffset(WIN_W,WIN_H),
    AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),
    BackgroundTransparency=1,ZIndex=2,Parent=screenGui})

-- drop shadow (9-slice). Graceful if the asset fails to load.
mk("ImageLabel",{Name="Shadow",BackgroundTransparency=1,Image="rbxassetid://6015897843",
    ImageColor3=Z.black,ImageTransparency=0.35,ScaleType=Enum.ScaleType.Slice,
    SliceCenter=Rect.new(49,49,450,450),Size=UDim2.new(1,90,1,90),
    Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),ZIndex=1,Parent=holder})

-- window
local window=Frame({Name="Window",Size=UDim2.fromScale(1,1),BackgroundColor3=Z.surface,
    BorderSizePixel=0,ClipsDescendants=true,ZIndex=2,Parent=holder})
corner(12).Parent=window
stroke(Z.border,1).Parent=window
-- premium top inner-highlight (1px) for AAA depth
Frame({Name="TopHighlight",Size=UDim2.new(1,-24,0,1),Position=UDim2.new(0,12,0,0),
    BackgroundColor3=Z.text,BackgroundTransparency=0.9,BorderSizePixel=0,ZIndex=10,Parent=window})
local uiScale=mk("UIScale",{Scale=(tonumber(getFlag("uiscale",100)) or 100)/100,Parent=window})

-- ═══════════════════════════════════════════════════════════════════════════════
-- 17. TITLE BAR
-- ═══════════════════════════════════════════════════════════════════════════════

local topbar=Frame({Name="TopBar",Size=UDim2.new(1,0,0,46),BackgroundColor3=Z.card,
    BorderSizePixel=0,ZIndex=3,Parent=window})
Frame({Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=Z.border,
    BorderSizePixel=0,ZIndex=4,Parent=topbar})
-- brand mark
local mark=Frame({Size=UDim2.fromOffset(22,22),Position=UDim2.new(0,16,0.5,0),
    AnchorPoint=Vector2.new(0,0.5),BackgroundColor3=Z.lime,BorderSizePixel=0,ZIndex=4,Parent=topbar})
corner(6).Parent=mark
drawIcon("bolt",mark,Z.black)
Label({Text="ZEX",Font=F_HEAD,TextSize=16,TextColor3=Z.text,Size=UDim2.new(0,46,1,0),
    Position=UDim2.new(0,46,0,0),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=4,Parent=topbar})
local verChip=Frame({Size=UDim2.fromOffset(50,18),Position=UDim2.new(0,90,0.5,0),AnchorPoint=Vector2.new(0,0.5),
    BackgroundColor3=Z.elevated,BorderSizePixel=0,ZIndex=4,Parent=topbar})
corner(9).Parent=verChip; stroke(Z.border,1).Parent=verChip
Label({Text="v8.0",Font=F_BODY,TextSize=9,TextColor3=Z.lime,Size=UDim2.fromScale(1,1),ZIndex=5,Parent=verChip})
local permChip=Frame({Size=UDim2.fromOffset(58,18),Position=UDim2.new(0,148,0.5,0),AnchorPoint=Vector2.new(0,0.5),
    BackgroundColor3=Z.elevated,BorderSizePixel=0,ZIndex=4,Parent=topbar})
corner(9).Parent=permChip; stroke(Z.border,1).Parent=permChip
local permChipLbl=Label({Text=PERM_NAMES[userRank],Font=F_BODY,TextSize=9,TextColor3=Z.text2,
    Size=UDim2.fromScale(1,1),ZIndex=5,Parent=permChip})

local function topBtn(icon:string,xoff:number,hoverCol:Color3): TextButton
    local b=Button({Text="",Size=UDim2.fromOffset(30,30),Position=UDim2.new(1,xoff,0.5,0),
        AnchorPoint=Vector2.new(1,0.5),BackgroundColor3=Z.elevated,BackgroundTransparency=1,ZIndex=4,Parent=topbar})
    corner(7).Parent=b
    local ic=drawIcon(icon,b,Z.text2)
    hoverFx(b,rootMaid,{BackgroundTransparency=1},{BackgroundTransparency=0})
    b.MouseEnter:Connect(function() recolorIcon(ic,hoverCol) end)
    b.MouseLeave:Connect(function() recolorIcon(ic,Z.text2) end)
    return b
end
local closeBtn=topBtn("close",-10,Z.danger)
local minBtn  =topBtn("minimize",-46,Z.lime)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 18. SIDEBAR + SLIDING INDICATOR + TOOLTIPS
-- ═══════════════════════════════════════════════════════════════════════════════

local SIDEBAR_W = 64
local sidebar=Scroll({Name="Sidebar",Size=UDim2.new(0,SIDEBAR_W,1,-46),Position=UDim2.new(0,0,0,46),
    BackgroundColor3=Z.card,ScrollBarThickness=0,ScrollingDirection=Enum.ScrollingDirection.Y,
    CanvasSize=UDim2.new(),ZIndex=3,Parent=window})
Frame({Size=UDim2.new(0,1,1,0),Position=UDim2.new(0,SIDEBAR_W-1,0,46),BackgroundColor3=Z.border,BorderSizePixel=0,ZIndex=4,Parent=window})

local TABS = {
    {id="Dashboard",icon="dashboard"},{id="Player",icon="player"},{id="Combat",icon="combat"},
    {id="World",icon="world"},{id="Server",icon="server"},{id="Webhooks",icon="webhook"},
    {id="Network",icon="network"},{id="Intel",icon="intel"},{id="Commands",icon="commands"},
    {id="Console",icon="console"},{id="Settings",icon="settings"},
}
local BTN_SZ, BTN_GAP, BTN_Y0 = 44, 8, 12
local indicator=Frame({Name="Indicator",Size=UDim2.fromOffset(3,24),AnchorPoint=Vector2.new(0,0.5),
    Position=UDim2.new(0,0,0,BTN_Y0+BTN_SZ/2),BackgroundColor3=Z.lime,BorderSizePixel=0,ZIndex=5,Parent=sidebar})
corner(2).Parent=indicator

local tooltip=Frame({Name="Tooltip",AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.fromOffset(0,22),
    BackgroundColor3=Z.elevated,BorderSizePixel=0,Visible=false,ZIndex=50,Parent=window})
corner(6).Parent=tooltip; stroke(Z.border,1).Parent=tooltip
local tooltipLbl=Label({Text="",Font=F_BODY,TextSize=11,TextColor3=Z.text,AutomaticSize=Enum.AutomaticSize.X,
    Size=UDim2.new(0,0,1,0),ZIndex=51,Parent=tooltip})
mk("UIPadding",{PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10),Parent=tooltipLbl})

local sidebarBtns: {[string]:{btn:TextButton,icon:Frame,y:number}} = {}
for i,t in ipairs(TABS) do
    local y=BTN_Y0+(i-1)*(BTN_SZ+BTN_GAP)
    local b=Button({Text="",Size=UDim2.fromOffset(BTN_SZ,BTN_SZ),Position=UDim2.new(0.5,0,0,y),
        AnchorPoint=Vector2.new(0.5,0),BackgroundColor3=Z.elevated,BackgroundTransparency=1,ZIndex=4,Parent=sidebar})
    corner(9).Parent=b
    local ic=drawIcon(t.icon,b,Z.text3)
    sidebarBtns[t.id]={btn=b,icon=ic,y=y+BTN_SZ/2}
    b.MouseEnter:Connect(function()
        tooltipLbl.Text=t.id
        tooltip.Position=UDim2.fromOffset(SIDEBAR_W+8, (b.AbsolutePosition.Y-window.AbsolutePosition.Y)+(BTN_SZ-22)/2)
        tooltip.Visible=true
    end)
    b.MouseLeave:Connect(function() tooltip.Visible=false end)
end
sidebar.CanvasSize=UDim2.new(0,0,0,BTN_Y0+#TABS*(BTN_SZ+BTN_GAP)+12)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 19. CONTENT AREA + INPUT BAR
-- ═══════════════════════════════════════════════════════════════════════════════

local INPUT_H = 40
local content=Frame({Name="Content",Size=UDim2.new(1,-SIDEBAR_W,1,-46-INPUT_H),
    Position=UDim2.new(0,SIDEBAR_W,0,46),BackgroundColor3=Z.bg,BorderSizePixel=0,
    ClipsDescendants=true,ZIndex=3,Parent=window})
local titleStrip=Frame({Size=UDim2.new(1,0,0,40),BackgroundTransparency=1,ZIndex=4,Parent=content})
local tabTitle=Label({Text="Dashboard",Font=F_HEAD,TextSize=18,TextColor3=Z.text,
    Size=UDim2.new(1,-40,1,0),Position=UDim2.new(0,20,0,0),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=5,Parent=titleStrip})

local pageHost=Frame({Name="PageHost",Size=UDim2.new(1,0,1,-40),Position=UDim2.new(0,0,0,40),
    BackgroundTransparency=1,ClipsDescendants=true,ZIndex=4,Parent=content})

-- ═══════════════════════════════════════════════════════════════════════════════
-- 20. COMPONENT LIBRARY
-- ═══════════════════════════════════════════════════════════════════════════════

type SectionApi = { body:Frame, layout:UIListLayout }

local Components = {}

function Components.Page(host:Frame): (ScrollingFrame, UIListLayout)
    local s=Scroll({Size=UDim2.fromScale(1,1),BackgroundTransparency=1,
        CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ZIndex=4,Parent=host})
    mk("UIPadding",{PaddingLeft=UDim.new(0,20),PaddingRight=UDim.new(0,20),
        PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,16),Parent=s})
    local l=mk("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,12),Parent=s})
    return s, l
end

function Components.Section(parent:Instance, title:string, order:number): SectionApi
    local card=Frame({BackgroundColor3=Z.surface,BorderSizePixel=0,Size=UDim2.new(1,0,0,40),
        AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=order,ZIndex=4,Parent=parent})
    corner(10).Parent=card; stroke(Z.border,1).Parent=card
    Label({Text=title:upper(),Font=F_HEAD,TextSize=11,TextColor3=Z.text2,Size=UDim2.new(1,-28,0,30),
        Position=UDim2.new(0,16,0,4),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=5,Parent=card})
    Frame({Size=UDim2.fromOffset(20,3),Position=UDim2.new(0,16,0,28),BackgroundColor3=Z.lime,BorderSizePixel=0,ZIndex=5,Parent=card})
    local body=Frame({BackgroundTransparency=1,Size=UDim2.new(1,-20,0,0),Position=UDim2.new(0,10,0,38),
        AutomaticSize=Enum.AutomaticSize.Y,ZIndex=5,Parent=card})
    local layout=mk("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,6),Parent=body})
    mk("UIPadding",{PaddingBottom=UDim.new(0,10),Parent=body})
    return { body=body, layout=layout }
end

local function rowBase(parent:Instance, h:number, order:number): Frame
    local row=Frame({BackgroundColor3=Z.card,BorderSizePixel=0,Size=UDim2.new(1,0,0,h),
        LayoutOrder=order,ZIndex=5,Parent=parent})
    corner(8).Parent=row; stroke(Z.border,1).Parent=row
    return row
end

function Components.Toggle(parent:Instance, maid:Maid, order:number, cfg:{Title:string,Get:()->boolean,Toggle:()->()})
    local row=rowBase(parent,36,order)
    Label({Text=cfg.Title,Font=F_BODY,TextSize=12,TextColor3=Z.text,Size=UDim2.new(1,-72,1,0),
        Position=UDim2.new(0,14,0,0),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=6,Parent=row})
    local track=Frame({Size=UDim2.fromOffset(40,22),Position=UDim2.new(1,-52,0.5,0),AnchorPoint=Vector2.new(0,0.5),
        BackgroundColor3=Z.elevated,BorderSizePixel=0,ZIndex=6,Parent=row})
    corner(11).Parent=track; local tStroke=stroke(Z.border,1); tStroke.Parent=track
    local knob=Frame({Size=UDim2.fromOffset(16,16),Position=UDim2.new(0,3,0.5,0),AnchorPoint=Vector2.new(0,0.5),
        BackgroundColor3=Z.text2,BorderSizePixel=0,ZIndex=7,Parent=track})
    corner(8).Parent=knob
    local hit=Button({Text="",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=8,Parent=row})
    local function render(on:boolean)
        tween(knob,{Position=UDim2.new(0,(if on then 21 else 3),0.5,0),BackgroundColor3=if on then Z.black else Z.text2},FAST)
        tween(track,{BackgroundColor3=if on then Z.lime else Z.elevated},FAST)
        tStroke.Color=if on then Z.lime else Z.border
    end
    render(cfg.Get())
    maid:GiveTask(hit.MouseButton1Click:Connect(function()
        safeCall(cfg.Toggle,"Toggle:"..cfg.Title); render(cfg.Get())
    end))
    hoverFx(row,maid,{BackgroundColor3=Z.card},{BackgroundColor3=Z.hover})
    return { Set=render }
end

function Components.Slider(parent:Instance, maid:Maid, order:number, cfg:{Title:string,Min:number,Max:number,Default:number,Suffix:string?,Callback:(n:number)->()})
    local row=rowBase(parent,52,order)
    Label({Text=cfg.Title,Font=F_BODY,TextSize=12,TextColor3=Z.text,Size=UDim2.new(1,-90,0,22),
        Position=UDim2.new(0,14,0,4),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=6,Parent=row})
    local valLbl=Label({Text="",Font=F_CODE,TextSize=12,TextColor3=Z.lime,Size=UDim2.new(0,70,0,22),
        Position=UDim2.new(1,-80,0,4),TextXAlignment=Enum.TextXAlignment.Right,ZIndex=6,Parent=row})
    local track=Frame({Size=UDim2.new(1,-28,0,6),Position=UDim2.new(0,14,1,-16),
        BackgroundColor3=Z.elevated,BorderSizePixel=0,ZIndex=6,Parent=row})
    corner(3).Parent=track
    local fill=Frame({Size=UDim2.new(0,0,1,0),BackgroundColor3=Z.lime,BorderSizePixel=0,ZIndex=7,Parent=track})
    corner(3).Parent=fill
    local knob=Frame({Size=UDim2.fromOffset(14,14),Position=UDim2.new(0,0,0.5,0),AnchorPoint=Vector2.new(0.5,0.5),
        BackgroundColor3=Z.text,BorderSizePixel=0,ZIndex=8,Parent=track})
    corner(7).Parent=knob; stroke(Z.lime,2).Parent=knob
    local value=math.clamp(cfg.Default,cfg.Min,cfg.Max)
    local function render(v:number, fire:boolean)
        value=math.clamp(v,cfg.Min,cfg.Max)
        local a=(value-cfg.Min)/math.max(cfg.Max-cfg.Min,1e-6)
        fill.Size=UDim2.new(a,0,1,0); knob.Position=UDim2.new(a,0,0.5,0)
        valLbl.Text=string.format("%.0f%s",value,cfg.Suffix or "")
        if fire then safeCall(function() cfg.Callback(value) end,"Slider:"..cfg.Title) end
    end
    render(value,false)
    local dragging=false
    local function setFromX(px:number)
        local a=math.clamp((px-track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1),0,1)
        render(cfg.Min+a*(cfg.Max-cfg.Min),true)
    end
    maid:GiveTask(track.InputBegan:Connect(function(inp:InputObject)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
            dragging=true; setFromX(inp.Position.X)
        end
    end))
    maid:GiveTask(UserInputService.InputChanged:Connect(function(inp:InputObject)
        if dragging and (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) then
            setFromX(inp.Position.X)
        end
    end))
    maid:GiveTask(UserInputService.InputEnded:Connect(function(inp:InputObject)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then dragging=false end
    end))
    return { Set=function(v:number) render(v,false) end }
end

function Components.Button(parent:Instance, maid:Maid, order:number, cfg:{Title:string,Color:Color3?,Callback:()->()})
    local row=Frame({BackgroundColor3=cfg.Color or Z.elevated,BorderSizePixel=0,Size=UDim2.new(1,0,0,34),
        LayoutOrder=order,ClipsDescendants=true,ZIndex=5,Parent=parent})
    corner(8).Parent=row
    local accent = cfg.Color~=nil
    if not accent then stroke(Z.border,1).Parent=row end
    local lbl=Label({Text=cfg.Title,Font=F_BTN,TextSize=12,TextColor3=if accent then Z.black else Z.text,
        Size=UDim2.fromScale(1,1),ZIndex=6,Parent=row})
    local hit=Button({Text="",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=7,Parent=row})
    maid:GiveTask(hit.MouseButton1Click:Connect(function()
        ripple(row, if accent then Z.black else Z.lime); safeCall(cfg.Callback,"Btn:"..cfg.Title)
    end))
    if accent then hoverFx(row,maid,{BackgroundColor3=cfg.Color::Color3},{BackgroundColor3=(cfg.Color::Color3):Lerp(Z.text,0.12)})
    else hoverFx(row,maid,{BackgroundColor3=Z.elevated},{BackgroundColor3=Z.hover}) end
    return { Label=lbl }
end

function Components.Keybind(parent:Instance, maid:Maid, order:number, cfg:{Title:string,Get:()->Enum.KeyCode,Set:(k:Enum.KeyCode)->()})
    local row=rowBase(parent,36,order)
    Label({Text=cfg.Title,Font=F_BODY,TextSize=12,TextColor3=Z.text,Size=UDim2.new(1,-110,1,0),
        Position=UDim2.new(0,14,0,0),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=6,Parent=row})
    local keyBtn=Button({Text=cfg.Get().Name,Font=F_CODE,TextSize=11,TextColor3=Z.lime,
        Size=UDim2.fromOffset(84,24),Position=UDim2.new(1,-96,0.5,0),AnchorPoint=Vector2.new(0,0.5),
        BackgroundColor3=Z.elevated,ZIndex=6,Parent=row})
    corner(6).Parent=keyBtn; stroke(Z.border,1).Parent=keyBtn
    local capturing=false
    maid:GiveTask(keyBtn.MouseButton1Click:Connect(function()
        capturing=true; capturingKeybind=true; keyBtn.Text="..."; keyBtn.TextColor3=Z.warn
    end))
    maid:GiveTask(UserInputService.InputBegan:Connect(function(inp:InputObject,gp:boolean)
        if not capturing or inp.UserInputType~=Enum.UserInputType.Keyboard then return end
        capturing=false; task.defer(function() capturingKeybind=false end)  -- clear next frame so menu toggle ignores this press
        if inp.KeyCode==Enum.KeyCode.Escape then keyBtn.Text=cfg.Get().Name; keyBtn.TextColor3=Z.lime; return end  -- Esc cancels
        cfg.Set(inp.KeyCode); keyBtn.Text=inp.KeyCode.Name; keyBtn.TextColor3=Z.lime
    end))
    hoverFx(row,maid,{BackgroundColor3=Z.card},{BackgroundColor3=Z.hover})
end

function Components.Dropdown(parent:Instance, maid:Maid, order:number, cfg:{Title:string,Options:()->{string},Callback:(v:string)->()})
    local row=rowBase(parent,36,order)
    Label({Text=cfg.Title,Font=F_BODY,TextSize=12,TextColor3=Z.text,Size=UDim2.new(1,-150,1,0),
        Position=UDim2.new(0,14,0,0),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=6,Parent=row})
    local sel=Button({Text="Select",Font=F_BODY,TextSize=11,TextColor3=Z.text2,
        Size=UDim2.fromOffset(124,24),Position=UDim2.new(1,-136,0.5,0),AnchorPoint=Vector2.new(0,0.5),
        BackgroundColor3=Z.elevated,ZIndex=6,Parent=row})
    corner(6).Parent=sel; stroke(Z.border,1).Parent=sel
    drawIcon("minimize",Frame({Size=UDim2.fromOffset(18,18),Position=UDim2.new(1,-20,0.5,0),
        AnchorPoint=Vector2.new(0,0.5),BackgroundTransparency=1,ZIndex=7,Parent=sel}),Z.text3)
    local popup: Frame? = nil
    local closeConn: RBXScriptConnection? = nil
    local function close()
        if closeConn then closeConn:Disconnect(); closeConn=nil end
        if popup then popup:Destroy(); popup=nil end
    end
    maid:GiveTask(function() close() end)
    maid:GiveTask(sel.MouseButton1Click:Connect(function()
        if popup then close(); return end
        local opts=cfg.Options()
        local p=Frame({BackgroundColor3=Z.elevated,BorderSizePixel=0,ZIndex=60,
            Size=UDim2.fromOffset(sel.AbsoluteSize.X, math.min(#opts,5)*26+6),
            Position=UDim2.fromOffset(sel.AbsolutePosition.X, sel.AbsolutePosition.Y+sel.AbsoluteSize.Y+4),
            Parent=screenGui})
        popup=p; corner(8).Parent=p; stroke(Z.borderHi,1).Parent=p
        -- dismiss when clicking anywhere outside the popup or its trigger button
        closeConn=UserInputService.InputBegan:Connect(function(inp:InputObject)
            if inp.UserInputType~=Enum.UserInputType.MouseButton1 and inp.UserInputType~=Enum.UserInputType.Touch then return end
            local m=UserInputService:GetMouseLocation()
            local function inside(g:GuiObject): boolean
                local ap,sz=g.AbsolutePosition,g.AbsoluteSize
                return m.X>=ap.X and m.X<=ap.X+sz.X and m.Y>=ap.Y and m.Y<=ap.Y+sz.Y
            end
            if not inside(p) and not inside(sel) then close() end
        end)
        local ps=Scroll({Size=UDim2.fromScale(1,1),BackgroundTransparency=1,CanvasSize=UDim2.new(),
            AutomaticCanvasSize=Enum.AutomaticSize.Y,ZIndex=61,Parent=p})
        mk("UIListLayout",{Padding=UDim.new(0,2),Parent=ps}); mk("UIPadding",{PaddingTop=UDim.new(0,3),PaddingLeft=UDim.new(0,3),PaddingRight=UDim.new(0,3),Parent=ps})
        if #opts==0 then Label({Text="(none)",TextColor3=Z.text3,TextSize=11,Size=UDim2.new(1,0,0,24),ZIndex=62,Parent=ps}) end
        for _,opt in ipairs(opts) do
            local ob=Button({Text=opt,Font=F_BODY,TextSize=11,TextColor3=Z.text,Size=UDim2.new(1,0,0,24),
                BackgroundColor3=Z.card,ZIndex=62,Parent=ps})
            corner(5).Parent=ob
            ob.MouseEnter:Connect(function() ob.BackgroundColor3=Z.hover end)
            ob.MouseLeave:Connect(function() ob.BackgroundColor3=Z.card end)
            ob.MouseButton1Click:Connect(function()
                sel.Text=opt; sel.TextColor3=Z.text; close()
                safeCall(function() cfg.Callback(opt) end,"Dropdown:"..cfg.Title)
            end)
        end
    end))
    hoverFx(row,maid,{BackgroundColor3=Z.card},{BackgroundColor3=Z.hover})
end

function Components.Stat(parent:Instance, order:number, name:string, color:Color3): TextLabel
    local card=Frame({BackgroundColor3=Z.surface,BorderSizePixel=0,Size=UDim2.new(0.5,-6,0,64),
        LayoutOrder=order,ZIndex=5,Parent=parent})
    corner(10).Parent=card; stroke(Z.border,1).Parent=card
    Frame({Size=UDim2.fromOffset(3,18),Position=UDim2.new(0,14,0,14),BackgroundColor3=color,BorderSizePixel=0,ZIndex=6,Parent=card})
    Label({Text=name,Font=F_BODY,TextSize=10,TextColor3=Z.text3,Size=UDim2.new(1,-28,0,16),
        Position=UDim2.new(0,24,0,14),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=6,Parent=card})
    return Label({Text="--",Font=F_HEAD,TextSize=24,TextColor3=color,Size=UDim2.new(1,-28,0,30),
        Position=UDim2.new(0,22,0,30),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=6,Parent=card})
end

function Components.Paragraph(parent:Instance, order:number): TextLabel
    local card=Frame({BackgroundColor3=Z.surface,BorderSizePixel=0,Size=UDim2.new(1,0,0,40),
        AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=order,ZIndex=4,Parent=parent})
    corner(10).Parent=card; stroke(Z.border,1).Parent=card
    local l=Label({Text="",Font=F_CODE,TextSize=11,TextColor3=Z.text2,Size=UDim2.new(1,-28,0,0),
        AutomaticSize=Enum.AutomaticSize.Y,Position=UDim2.new(0,14,0,12),TextWrapped=true,
        TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,ZIndex=5,Parent=card})
    mk("UIPadding",{PaddingBottom=UDim.new(0,12),Parent=card})
    return l
end

-- Hero profile card: circular avatar headshot + identity + live rank chip.
function Components.Profile(parent:Instance, maid:Maid, order:number)
    local card=Frame({BackgroundColor3=Z.surface,BorderSizePixel=0,Size=UDim2.new(1,0,0,84),
        LayoutOrder=order,ZIndex=4,Parent=parent})
    corner(12).Parent=card; stroke(Z.border,1).Parent=card
    -- accent rail
    Frame({Size=UDim2.fromOffset(3,52),Position=UDim2.new(0,0,0.5,0),AnchorPoint=Vector2.new(0,0.5),
        BackgroundColor3=Z.lime,BorderSizePixel=0,ZIndex=5,Parent=card})
    -- avatar ring + headshot
    local ring=Frame({Size=UDim2.fromOffset(60,60),Position=UDim2.new(0,16,0.5,0),AnchorPoint=Vector2.new(0,0.5),
        BackgroundColor3=Z.elevated,BorderSizePixel=0,ZIndex=5,Parent=card})
    corner(30).Parent=ring; stroke(Z.lime,2).Parent=ring
    local avatar=mk("ImageLabel",{Name="Avatar",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),
        ScaleType=Enum.ScaleType.Crop,ZIndex=6,Parent=ring}) :: ImageLabel
    mk("UICorner",{CornerRadius=UDim.new(1,0),Parent=avatar})
    task.spawn(function()
        if not localPlayer then return end
        local ok,url=pcall(function()
            return Players:GetUserThumbnailAsync(localPlayer.UserId,
                Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
        end)
        if ok and url and avatar and avatar.Parent then avatar.Image=url end
    end)
    -- identity
    local nameL=Label({Text=if localPlayer then localPlayer.DisplayName else "Player",
        Font=F_HEAD,TextSize=16,TextColor3=Z.text,Size=UDim2.new(1,-200,0,18),
        Position=UDim2.new(0,90,0,18),TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=6,Parent=card})
    Label({Text=if localPlayer then "@"..localPlayer.Name.."  ·  uid "..tostring(localPlayer.UserId) else "",
        Font=F_BODY,TextSize=11,TextColor3=Z.text2,Size=UDim2.new(1,-200,0,14),
        Position=UDim2.new(0,90,0,38),TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=6,Parent=card})
    Label({Text=if localPlayer then tostring(localPlayer.AccountAge).." days  ·  "..tostring(localPlayer.MembershipType) else "",
        Font=F_THIN,TextSize=10,TextColor3=Z.text3,Size=UDim2.new(1,-200,0,14),
        Position=UDim2.new(0,90,0,54),TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=6,Parent=card})
    -- rank chip (top-right)
    local rankChip=Frame({Size=UDim2.fromOffset(70,22),Position=UDim2.new(1,-16,0,16),AnchorPoint=Vector2.new(1,0),
        BackgroundColor3=Z.elevated,BorderSizePixel=0,ZIndex=6,Parent=card})
    corner(11).Parent=rankChip; stroke(Z.lime,1).Parent=rankChip
    Label({Text=PERM_NAMES[userRank],Font=F_BTN,TextSize=10,TextColor3=Z.lime,Size=UDim2.fromScale(1,1),ZIndex=7,Parent=rankChip})
end

-- Section header strip (lightweight, for data pages)
function Components.Header(parent:Instance, order:number, title:string)
    local h=Frame({BackgroundTransparency=1,Size=UDim2.new(1,0,0,22),LayoutOrder=order,ZIndex=4,Parent=parent})
    Frame({Size=UDim2.fromOffset(3,14),Position=UDim2.new(0,0,0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundColor3=Z.lime,BorderSizePixel=0,ZIndex=5,Parent=h})
    Label({Text=title:upper(),Font=F_HEAD,TextSize=11,TextColor3=Z.text2,Size=UDim2.new(1,-12,1,0),
        Position=UDim2.new(0,12,0,0),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=5,Parent=h})
end

-- Read-only label : value row (intelligence dump)
function Components.Field(parent:Instance, order:number, label:string, value:any): TextLabel
    local row=Frame({BackgroundColor3=Z.card,BorderSizePixel=0,Size=UDim2.new(1,0,0,28),LayoutOrder=order,ZIndex=5,Parent=parent})
    corner(6).Parent=row; stroke(Z.border,1).Parent=row
    Label({Text=label,Font=F_BODY,TextSize=11,TextColor3=Z.text2,Size=UDim2.new(0.4,-12,1,0),
        Position=UDim2.new(0,12,0,0),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=6,Parent=row})
    return Label({Text=tostring(value),Font=F_CODE,TextSize=11,TextColor3=Z.text,Size=UDim2.new(0.6,-12,1,0),
        Position=UDim2.new(0.4,0,0,0),TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=6,Parent=row})
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 21. TAB BUILDERS
-- ═══════════════════════════════════════════════════════════════════════════════

local toggleKey = Enum.KeyCode.RightShift
do  -- restore saved toggle key
    local n=getFlag("toggle_key",nil)
    if type(n)=="string" then local ok,kc=pcall(function() return (Enum.KeyCode::any)[n] end); if ok and kc then toggleKey=kc end end
end

-- forward declares for overlays created in the entry section (referenced by Settings)
local watermark: Frame? = nil
local keybindList: Frame? = nil

local Pages: {[string]:(host:Frame,maid:Maid)->()} = {}

Pages.Dashboard=function(host,maid)
    local page,layout=Components.Page(host)
    Components.Profile(page,maid,0)
    local grid=Frame({BackgroundTransparency=1,Size=UDim2.new(1,0,0,140),LayoutOrder=1,ZIndex=4,Parent=page})
    mk("UIGridLayout",{CellSize=UDim2.new(0.5,-6,0,64),CellPadding=UDim2.fromOffset(12,12),
        FillDirectionMaxCells=2,Parent=grid})
    local fpsV=Components.Stat(grid,1,"FPS",Z.lime)
    local pingV=Components.Stat(grid,2,"PING",Z.success)
    local memV=Components.Stat(grid,3,"MEMORY",Z.info)
    local plrV=Components.Stat(grid,4,"PLAYERS",Z.warn)
    local para=Components.Paragraph(page,2)
    local running=true; maid:GiveTask(function() running=false end)
    local fps=0; local last=os.clock()
    maid:GiveTask(RunService.RenderStepped:Connect(function()
        fps+=1; local now=os.clock(); if now-last>=1 then fpsV.Text=tostring(fps); fps=0; last=now end
    end))
    local function refresh()
        pcall(function() memV.Text=string.format("%.0f MB",collectgarbage("count")/1024) end)
        pcall(function() plrV.Text=tostring(#Players:GetPlayers()).." / "..tostring(Players.MaxPlayers) end)
        pcall(function()
            if Services.Stats then
                local sa=Services.Stats::any
                pingV.Text=math.floor(sa.Network.ServerStatsItem["Data Ping"].Value).." ms"
            end
        end)
        if localPlayer then
            local lines={
                "User      "..localPlayer.Name.." (@"..localPlayer.DisplayName..")",
                "UserId    "..tostring(localPlayer.UserId),
                "Account   "..tostring(localPlayer.AccountAge).." days · "..tostring(localPlayer.MembershipType),
                "Game      "..game.Name.." ["..tostring(game.PlaceId).."]",
            }
            local char=localPlayer.Character
            if char then local h=char:FindFirstChildOfClass("Humanoid")
                if h then table.insert(lines,string.format("Vitals    HP %.0f/%.0f · WS %.0f · JP %.0f",h.Health,h.MaxHealth,h.WalkSpeed,h.JumpPower)) end
            end
            para.Text=table.concat(lines,"\n")
        end
    end
    refresh(); task.spawn(function() while running and task.wait(1) do refresh() end end)
end

Pages.Player=function(host,maid)
    local page=Components.Page(host)
    local mv=Components.Section(page,"Movement",1)
    Components.Toggle(mv.body,maid,1,{Title="Fly",Get=function() return CMD_STATE.fly end,Toggle=function() CommandRegistry["fly"].run({}) end})
    Components.Toggle(mv.body,maid,2,{Title="Noclip",Get=function() return CMD_STATE.noclip end,Toggle=function() CommandRegistry["noclip"].run({}) end})
    Components.Slider(mv.body,maid,3,{Title="Walk Speed",Min=16,Max=500,Default=16,Callback=function(v) CommandRegistry["speed"].run({tostring(v)}) end})
    Components.Slider(mv.body,maid,4,{Title="Jump Power",Min=50,Max=500,Default=50,Callback=function(v) CommandRegistry["jump"].run({tostring(v)}) end})
    Components.Slider(mv.body,maid,5,{Title="Gravity",Min=0,Max=400,Default=math.floor(Workspace.Gravity),Callback=function(v) CommandRegistry["gravity"].run({tostring(v)}) end})
    local cv=Components.Section(page,"Character",2)
    Components.Toggle(cv.body,maid,1,{Title="Godmode",Get=function() return CMD_STATE.godmode end,Toggle=function() CommandRegistry["godmode"].run({}) end})
    Components.Toggle(cv.body,maid,2,{Title="Invisible",Get=function() return CMD_STATE.invisible end,Toggle=function() CommandRegistry["invisible"].run({}) end})
    Components.Toggle(cv.body,maid,3,{Title="Spin",Get=function() return CMD_STATE.spin end,Toggle=function() CommandRegistry["spin"].run({}) end})
    Components.Toggle(cv.body,maid,4,{Title="Anti-Fling",Get=function() return CMD_STATE.antifling end,Toggle=function() CommandRegistry["antifling"].run({}) end})
    Components.Toggle(cv.body,maid,5,{Title="Anti-AFK",Get=function() return CMD_STATE.antiafk end,Toggle=function() CommandRegistry["antiafk"].run({}) end})
    local av=Components.Section(page,"Actions",3)
    Components.Button(av.body,maid,1,{Title="Reset Character",Callback=function() CommandRegistry["reset"].run({}) end})
    Components.Button(av.body,maid,2,{Title="Refresh (keep position)",Callback=function() CommandRegistry["refresh"].run({}) end})
    Components.Button(av.body,maid,3,{Title="Heal",Color=Z.lime,Callback=function() CommandRegistry["heal"].run({}) end})
end

local function flagToggle(flag:string, def:boolean): {Get:()->boolean,Toggle:()->()}
    return {
        Get=function() return getFlag(flag,def)==true end,
        Toggle=function() setFlag(flag, not (getFlag(flag,def)==true)) end,
    }
end

Pages.Combat=function(host,maid)
    local page=Components.Page(host)
    local s=Components.Section(page,"Master Toggles",1)
    Components.Toggle(s.body,maid,1,{Title="ESP",Get=function() return CMD_STATE.esp end,Toggle=function() CommandRegistry["esp"].run({}) end})
    Components.Toggle(s.body,maid,2,{Title="Aimbot (hold RMB)",Get=function() return CMD_STATE.aimbot end,Toggle=function() CommandRegistry["aimbot"].run({}) end})
    Components.Toggle(s.body,maid,3,{Title="Click Teleport (Ctrl+Click)",Get=function() return CMD_STATE.clicktp end,Toggle=function() CommandRegistry["clicktp"].run({}) end})

    local e=Components.Section(page,"ESP Options",2)
    local fb
    fb=flagToggle("esp_box",true);      Components.Toggle(e.body,maid,1,{Title="Box",Get=fb.Get,Toggle=fb.Toggle})
    fb=flagToggle("esp_name",true);     Components.Toggle(e.body,maid,2,{Title="Name",Get=fb.Get,Toggle=fb.Toggle})
    fb=flagToggle("esp_health",true);   Components.Toggle(e.body,maid,3,{Title="Health bar",Get=fb.Get,Toggle=fb.Toggle})
    fb=flagToggle("esp_distance",true); Components.Toggle(e.body,maid,4,{Title="Distance",Get=fb.Get,Toggle=fb.Toggle})
    fb=flagToggle("esp_tracer",false);  Components.Toggle(e.body,maid,5,{Title="Tracers",Get=fb.Get,Toggle=fb.Toggle})
    fb=flagToggle("esp_team",false);    Components.Toggle(e.body,maid,6,{Title="Show teammates",Get=fb.Get,Toggle=fb.Toggle})
    Components.Slider(e.body,maid,7,{Title="Max distance (0 = unlimited)",Min=0,Max=2000,Default=tonumber(getFlag("esp_maxdist",0)) or 0,Suffix="m",Callback=function(v) setFlag("esp_maxdist",v) end})

    local a=Components.Section(page,"Aimbot Options",3)
    fb=flagToggle("aim_visible",true);  Components.Toggle(a.body,maid,1,{Title="Visibility check (raycast)",Get=fb.Get,Toggle=fb.Toggle})
    fb=flagToggle("aim_team",false);    Components.Toggle(a.body,maid,2,{Title="Target teammates",Get=fb.Get,Toggle=fb.Toggle})
    fb=flagToggle("aim_hold",true);     Components.Toggle(a.body,maid,3,{Title="Hold RMB to aim",Get=fb.Get,Toggle=fb.Toggle})
    fb=flagToggle("aim_fovcircle",true);Components.Toggle(a.body,maid,4,{Title="Show FOV circle",Get=fb.Get,Toggle=fb.Toggle})
    Components.Slider(a.body,maid,5,{Title="FOV radius",Min=20,Max=400,Default=tonumber(getFlag("aim_fov",120)) or 120,Suffix="px",Callback=function(v) setFlag("aim_fov",v) end})
    Components.Slider(a.body,maid,6,{Title="Smoothing",Min=0,Max=95,Default=math.floor((tonumber(getFlag("aim_smooth",0.5)) or 0.5)*100),Suffix="%",Callback=function(v) setFlag("aim_smooth",v/100) end})
    Components.Dropdown(a.body,maid,7,{Title="Target part",Options=function() return {"Head","HumanoidRootPart","Torso"} end,Callback=function(v) setFlag("aim_part",v) end})

    local p=Components.Paragraph(page,4)
    p.Text=(if hasDrawing then "Drawing API detected — full box/tracer/FOV-circle ESP active." else "No Drawing API on this executor — ESP uses Highlight fallback.").."\nAll options persist to "..CONFIG_PATH.." and survive re-execution."
end

Pages.World=function(host,maid)
    local page=Components.Page(host)
    local s=Components.Section(page,"Lighting",1)
    Components.Toggle(s.body,maid,1,{Title="Fullbright",Get=function() return CMD_STATE.fullbright end,Toggle=function() CommandRegistry["fullbright"].run({}) end})
    Components.Slider(s.body,maid,2,{Title="Time of Day",Min=0,Max=24,Default=math.floor(Lighting.ClockTime),Suffix="h",Callback=function(v) CommandRegistry["time"].run({tostring(v)}) end})
    Components.Slider(s.body,maid,3,{Title="Fog End",Min=0,Max=100000,Default=math.min(Lighting.FogEnd,100000),Callback=function(v) CommandRegistry["fog"].run({tostring(v)}) end})
    local d=Components.Section(page,"Danger Zone",2)
    Components.Button(d.body,maid,1,{Title="Clear Terrain",Color=Z.danger,Callback=function() CommandRegistry["clearterrain"].run({}) end})
end

Pages.Server=function(host,maid)
    local page=Components.Page(host)
    local info=Components.Paragraph(page,1)
    local function refreshInfo()
        info.Text=table.concat({
            "Place     "..tostring(game.PlaceId),
            "Job       "..tostring(game.JobId),
            "Players   "..tostring(#Players:GetPlayers()).." / "..tostring(Players.MaxPlayers),
            "Gravity   "..tostring(Workspace.Gravity),
        },"\n")
    end
    refreshInfo()
    local s=Components.Section(page,"Session",2)
    Components.Button(s.body,maid,1,{Title="Rejoin",Color=Z.lime,Callback=function() CommandRegistry["rejoin"].run({}) end})
    Components.Button(s.body,maid,2,{Title="Server Hop",Callback=function() CommandRegistry["serverhop"].run({}) end})
    local t=Components.Section(page,"Players",3)
    Components.Dropdown(t.body,maid,1,{Title="Teleport to",Options=function()
        local o={}; for _,p in ipairs(Players:GetPlayers()) do if p~=localPlayer then table.insert(o,p.Name) end end; return o
    end,Callback=function(v) CommandRegistry["teleport"].run({v}) end})
    Components.Dropdown(t.body,maid,2,{Title="Spectate",Options=function()
        local o={}; for _,p in ipairs(Players:GetPlayers()) do if p~=localPlayer then table.insert(o,p.Name) end end; return o
    end,Callback=function(v) CommandRegistry["view"].run({v}) end})
    Components.Button(t.body,maid,3,{Title="Stop Spectating",Callback=function() CommandRegistry["unview"].run({}) end})
end

-- INTEL — full profile/server/device intelligence dump (merged from v7.0)
Pages.Intel=function(host,maid)
    local page=Components.Page(host)
    Components.Header(page,1,"Identity")
    Components.Field(page,2,"UserId",localPlayer.UserId)
    Components.Field(page,3,"Username",localPlayer.Name)
    Components.Field(page,4,"DisplayName",localPlayer.DisplayName)
    Components.Field(page,5,"AccountAge",localPlayer.AccountAge.." days")
    Components.Field(page,6,"Membership",tostring(localPlayer.MembershipType))
    Components.Field(page,7,"Verified",localPlayer.HasVerifiedBadge and "Yes" or "No")
    Components.Header(page,10,"Network / Locale")
    Components.Field(page,11,"Country",tryGet(function() return (game:GetService("LocalizationService")::any):GetCountryRegionForPlayerAsync(localPlayer) end,"unknown"))
    Components.Field(page,12,"Locale",tryGet(function() return (game:GetService("LocalizationService")::any).LocaleId end,"unknown"))
    Components.Field(page,13,"Team",(localPlayer.Team and localPlayer.Team.Name) or "None")
    Components.Header(page,20,"Character")
    local hpF=Components.Field(page,21,"Health","--")
    local wsF=Components.Field(page,22,"WalkSpeed","--")
    local jpF=Components.Field(page,23,"JumpPower","--")
    local stF=Components.Field(page,24,"State","--")
    local poF=Components.Field(page,25,"Position","--")
    Components.Header(page,30,"Server")
    Components.Field(page,31,"PlaceId",game.PlaceId)
    Components.Field(page,32,"JobId",tostring(game.JobId):sub(1,18).."…")
    Components.Field(page,33,"GameName",tryGet(function() return (game:GetService("MarketplaceService")::any):GetProductInfo(game.PlaceId).Name end,"Unknown"))
    Components.Field(page,34,"PlaceVersion",game.PlaceVersion)
    local plF=Components.Field(page,35,"Players","--")
    Components.Header(page,40,"Environment / Device")
    Components.Field(page,41,"Platform",tostring(UserInputService:GetPlatform()))
    Components.Field(page,42,"Touch",tostring(UserInputService.TouchEnabled))
    Components.Field(page,43,"Gravity",tostring(Workspace.Gravity))
    Components.Field(page,44,"IsStudio",tostring(RunService:IsStudio()))
    local reF=Components.Field(page,45,"Resolution","--")
    local running=true; maid:GiveTask(function() running=false end)
    local function refresh()
        local char=localPlayer.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local root=char and char:FindFirstChild("HumanoidRootPart")
        hpF.Text=hum and string.format("%.0f / %.0f",hum.Health,hum.MaxHealth) or "N/A"
        wsF.Text=hum and tostring(hum.WalkSpeed) or "N/A"
        jpF.Text=hum and tostring(hum.JumpPower) or "N/A"
        stF.Text=hum and tostring(hum:GetState()) or "N/A"
        poF.Text=root and string.format("%d, %d, %d",root.Position.X,root.Position.Y,root.Position.Z) or "N/A"
        plF.Text=tostring(#Players:GetPlayers()).." / "..tostring(Players.MaxPlayers)
        local cam=Workspace.CurrentCamera
        reF.Text=cam and (math.floor(cam.ViewportSize.X).."x"..math.floor(cam.ViewportSize.Y)) or "unknown"
    end
    refresh(); task.spawn(function() while running and task.wait(1) do refresh() end end)
end

-- WEBHOOKS — WebhookPulse transmitter, 4 payload modes (merged from v7.0)
Pages.Webhooks=function(host,maid)
    local page=Components.Page(host)
    local s=Components.Section(page,"WebhookPulse Transmitter",1)
    local urlRow=rowBase(s.body,32,1)
    local urlBox=TextBox({PlaceholderText="https://webhookpulse.vercel.app/api/webhook-receive?path=…",PlaceholderColor3=Z.text3,
        Text=tostring(getFlag("wh_url","")),Font=F_CODE,TextSize=10,TextColor3=Z.text,BackgroundTransparency=1,
        TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,-20,1,0),Position=UDim2.new(0,12,0,0),ZIndex=6,Parent=urlRow})
    maid:GiveTask(urlBox.FocusLost:Connect(function() setFlag("wh_url",urlBox.Text) end))
    local secRow=rowBase(s.body,32,2)
    local secBox=TextBox({PlaceholderText="X-Webhook-Secret (optional)",PlaceholderColor3=Z.text3,
        Text=tostring(getFlag("wh_secret","")),Font=F_CODE,TextSize=10,TextColor3=Z.text,BackgroundTransparency=1,
        TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,-20,1,0),Position=UDim2.new(0,12,0,0),ZIndex=6,Parent=secRow})
    maid:GiveTask(secBox.FocusLost:Connect(function() setFlag("wh_secret",secBox.Text) end))
    local modes={"FULL (all fields)","IDENTITY only","CHARACTER only","MINIMAL (id+name)"}
    Components.Dropdown(s.body,maid,3,{Title="Payload mode",Options=function() return modes end,Callback=function(v)
        for i,m in ipairs(modes) do if m==v then setFlag("wh_mode",i) end end
    end})
    local logPara=Components.Paragraph(page,2); logPara.Text="Waiting for transmission…"
    local function logLine(msg:string) logPara.Text=os.date("%H:%M:%S").."  "..msg.."\n"..logPara.Text end
    local function buildPayload(mode:number): {[string]:any}
        local p:{[string]:any}={source="roblox",timestamp=os.time(),version="8.0",
            executor={name=tryGet(function() local f=resolveGlobal("identifyexecutor"); return (f and (f::any)()) or "unknown" end,"unknown")}}
        if mode==1 or mode==2 or mode==4 then
            p.player={userid=localPlayer.UserId,username=localPlayer.Name,displayname=localPlayer.DisplayName,
                accountage=localPlayer.AccountAge,membership=tostring(localPlayer.MembershipType),
                verified=localPlayer.HasVerifiedBadge or false,
                country=tryGet(function() return (game:GetService("LocalizationService")::any):GetCountryRegionForPlayerAsync(localPlayer) end,"unknown"),
                team=(localPlayer.Team and localPlayer.Team.Name) or nil}
        end
        if mode==1 or mode==3 then
            local char=localPlayer.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
            local root=char and char:FindFirstChild("HumanoidRootPart")
            p.character={health=hum and hum.Health or nil,maxhealth=hum and hum.MaxHealth or nil,
                walkspeed=hum and hum.WalkSpeed or nil,jumppower=hum and hum.JumpPower or nil,
                position=root and {x=math.floor(root.Position.X),y=math.floor(root.Position.Y),z=math.floor(root.Position.Z)} or nil}
        end
        if mode==1 then
            p.game={placeid=game.PlaceId,jobid=game.JobId,numplayers=#Players:GetPlayers(),maxplayers=Players.MaxPlayers,isloaded=game.IsLoaded}
            p.device={os=tostring(UserInputService:GetPlatform()),touchenabled=UserInputService.TouchEnabled,
                mouseenabled=UserInputService.MouseEnabled,keyboardenabled=UserInputService.KeyboardEnabled}
        end
        if mode==4 then p={source="roblox",timestamp=os.time(),player={userid=localPlayer.UserId,username=localPlayer.Name}} end
        return p
    end
    Components.Button(s.body,maid,4,{Title="TRANSMIT TO WEBHOOKPULSE",Color=Z.lime,Callback=function()
        local url=urlBox.Text:match("^%s*(.-)%s*$") or ""
        local valid,err=validateUrl(url); if not valid then logLine("Invalid URL: "..err); notify("Invalid URL: "..err,"danger"); return end
        if not checkRateLimit(url) then logLine("Rate limited"); notify("Rate limited","warn"); return end
        local mode=tonumber(getFlag("wh_mode",1)) or 1
        logLine("Building payload (mode "..mode..")…")
        task.spawn(function()
            local body=HttpService:JSONEncode(buildPayload(mode))
            logLine("Payload "..#body.." bytes — sending…")
            local headers:{[string]:string}={["Content-Type"]="application/json"}
            local sec=secBox.Text:gsub("[%z\r\n]",""); if #sec>0 then headers["X-Webhook-Secret"]=sec end
            local res=httpRequest({Url=url,Method="POST",Headers=headers,Body=body})
            if res.success then logLine("OK ["..tostring(res.status).."] — stored in WebhookPulse."); notify("Webhook OK ["..tostring(res.status).."]","success")
            else logLine("FAILED: "..(res.error or "?")); notify("Webhook failed: "..(res.error or "?"),"danger") end
        end)
    end})
end

-- NETWORK — raw HTTP tester with multi-fallback transport (merged from v7.0)
Pages.Network=function(host,maid)
    local page=Components.Page(host)
    local s=Components.Section(page,"Raw HTTP Tester",1)
    local urlRow=rowBase(s.body,32,1)
    local urlBox=TextBox({PlaceholderText="https://httpbin.org/post",PlaceholderColor3=Z.text3,Text="",
        Font=F_CODE,TextSize=10,TextColor3=Z.text,BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,
        Size=UDim2.new(1,-20,1,0),Position=UDim2.new(0,12,0,0),ZIndex=6,Parent=urlRow})
    local bodyRow=rowBase(s.body,64,2)
    local bodyBox=TextBox({PlaceholderText='{"test":true}',PlaceholderColor3=Z.text3,Text='{"test":true}',
        Font=F_CODE,TextSize=10,TextColor3=Z.text,BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,
        TextYAlignment=Enum.TextYAlignment.Top,MultiLine=true,ClearTextOnFocus=false,
        Size=UDim2.new(1,-20,1,-8),Position=UDim2.new(0,12,0,4),ZIndex=6,Parent=bodyRow})
    local methods={"POST","GET","PUT","DELETE"}; local methodIdx=1
    Components.Dropdown(s.body,maid,3,{Title="Method",Options=function() return methods end,Callback=function(v)
        for i,m in ipairs(methods) do if m==v then methodIdx=i end end
    end})
    local logPara=Components.Paragraph(page,2); logPara.Text="Waiting…"
    local function logLine(msg:string) logPara.Text=os.date("%H:%M:%S").."  "..msg.."\n"..logPara.Text end
    Components.Button(s.body,maid,4,{Title="SEND RAW HTTP",Color=Z.info,Callback=function()
        local url=urlBox.Text:match("^%s*(.-)%s*$") or ""
        if not url:match("^https://") then logLine("HTTPS required"); return end
        if url:match("^https://%d+%.%d+%.%d+%.%d+") or url:lower():match("^https://localhost") then logLine("IP/localhost blocked (SSRF)"); return end
        logLine("Sending "..methods[methodIdx].." → "..url)
        task.spawn(function()
            local res=httpRequest({Url=url,Method=methods[methodIdx],Headers={["Content-Type"]="application/json"},Body=bodyBox.Text})
            if res.success then logLine("OK ["..tostring(res.status).."]: "..tostring(res.body):sub(1,120))
            else logLine("FAILED: "..(res.error or "?")) end
        end)
    end})
end

Pages.Commands=function(host,maid)
    local page,layout=Components.Page(host)
    local searchCard=Frame({BackgroundColor3=Z.surface,BorderSizePixel=0,Size=UDim2.new(1,0,0,38),LayoutOrder=0,ZIndex=4,Parent=page})
    corner(9).Parent=searchCard; stroke(Z.border,1).Parent=searchCard
    drawIcon("search",Frame({Size=UDim2.fromOffset(20,20),Position=UDim2.new(0,12,0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundTransparency=1,ZIndex=5,Parent=searchCard}),Z.text3)
    local search=TextBox({PlaceholderText="Search "..0 .." commands...",PlaceholderColor3=Z.text3,Text="",
        Font=F_BODY,TextSize=12,TextColor3=Z.text,BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,
        Size=UDim2.new(1,-44,1,0),Position=UDim2.new(0,38,0,0),ZIndex=5,Parent=searchCard})
    local listCard=Frame({BackgroundColor3=Z.surface,BorderSizePixel=0,Size=UDim2.new(1,0,1,-50),
        AutomaticSize=Enum.AutomaticSize.None,LayoutOrder=1,ZIndex=4,Parent=page})
    corner(10).Parent=listCard; stroke(Z.border,1).Parent=listCard
    local sc=Scroll({Size=UDim2.new(1,-8,1,-8),Position=UDim2.fromOffset(4,4),BackgroundTransparency=1,
        CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ZIndex=5,Parent=listCard})
    mk("UIListLayout",{Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.Name,Parent=sc})
    mk("UIPadding",{PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,4),PaddingTop=UDim.new(0,4),Parent=sc})
    -- page height fix: make listCard fill remaining space
    page.Size=UDim2.fromScale(1,1)
    listCard.Size=UDim2.new(1,0,1,-50)
    local sorted: {CommandDef}={}
    for _,cmd in pairs(CommandRegistry) do table.insert(sorted,cmd) end
    table.sort(sorted,function(a,b) return a.name<b.name end)
    search.PlaceholderText="Search "..#sorted.." commands..."
    local rows: {[CommandDef]:Frame}={}
    local catCol:{[string]:Color3}={Player=Z.lime,Combat=Z.danger,World=Z.info,Server=Z.warn,Utility=Z.text2}
    for _,cmd in ipairs(sorted) do
        local row=Frame({Name=cmd.name,BackgroundColor3=Z.card,BorderSizePixel=0,Size=UDim2.new(1,0,0,32),ZIndex=6,Parent=sc})
        corner(6).Parent=row
        Frame({Size=UDim2.fromOffset(3,16),Position=UDim2.new(0,8,0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundColor3=catCol[cmd.category] or Z.lime,BorderSizePixel=0,ZIndex=7,Parent=row})
        Label({Text=cmd.name,Font=F_BTN,TextSize=11,TextColor3=Z.text,Size=UDim2.new(0,120,1,0),Position=UDim2.new(0,18,0,0),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=7,Parent=row})
        Label({Text=cmd.desc,Font=F_THIN,TextSize=10,TextColor3=Z.text3,Size=UDim2.new(1,-260,1,0),Position=UDim2.new(0,140,0,0),TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=7,Parent=row})
        local run=Button({Text="RUN",Font=F_BTN,TextSize=10,TextColor3=Z.black,Size=UDim2.fromOffset(54,22),Position=UDim2.new(1,-62,0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundColor3=Z.lime,ZIndex=7,Parent=row})
        corner(5).Parent=run
        maid:GiveTask(run.MouseButton1Click:Connect(function()
            if not canRun(cmd.perm) then notify("No permission: "..cmd.name,"danger"); return end
            safeCall(function() cmd.run({}) end,"Cmd:"..cmd.name)
        end))
        hoverFx(row,maid,{BackgroundColor3=Z.card},{BackgroundColor3=Z.hover})
        rows[cmd]=row
    end
    maid:GiveTask(search:GetPropertyChangedSignal("Text"):Connect(function()
        local q=search.Text:lower()
        for cmd,row in pairs(rows) do
            row.Visible = q=="" or cmd.name:lower():find(q,1,true)~=nil or cmd.category:lower():find(q,1,true)~=nil
        end
    end))
end

Pages.Console=function(host,maid)
    local page=Components.Page(host)
    page.Size=UDim2.fromScale(1,1)
    local card=Frame({BackgroundColor3=Z.bg,BorderSizePixel=0,Size=UDim2.new(1,0,1,-42),LayoutOrder=1,ZIndex=4,Parent=page})
    corner(10).Parent=card; stroke(Z.border,1).Parent=card
    local sc=Scroll({Size=UDim2.new(1,-8,1,-8),Position=UDim2.fromOffset(4,4),BackgroundTransparency=1,
        CanvasSize=UDim2.new(),ZIndex=5,Parent=card})
    local cl=mk("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Parent=sc})
    mk("UIPadding",{PaddingLeft=UDim.new(0,6),PaddingTop=UDim.new(0,4),Parent=sc})
    local lastVer=-1; local rendered=0; local lastFirst=""
    local function entry(text:string,order:number)
        local col=Z.text2
        if text:find("%[ERROR%]") then col=Z.danger elseif text:find("%[WARN%]") then col=Z.warn
        elseif text:find("%[OUTPUT%]") then col=Z.success elseif text:find("%[DEBUG%]") then col=Z.info end
        Label({Text=text,Font=F_CODE,TextSize=10,TextColor3=col,Size=UDim2.new(1,-12,0,14),
            TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=order,ZIndex=6,Parent=sc})
    end
    local running=true; maid:GiveTask(function() running=false end)
    local function upd()
        if logVersion==lastVer then return end; lastVer=logVersion
        local rotated=rendered>0 and #logs>0 and logs[1]~=lastFirst
        if rotated or rendered>#logs then
            for _,ch in ipairs(sc:GetChildren()) do if ch:IsA("TextLabel") then ch:Destroy() end end; rendered=0
        end
        for i=rendered+1,#logs do entry(logs[i],i) end
        rendered=#logs; if #logs>0 then lastFirst=logs[1] end
        sc.CanvasSize=UDim2.new(0,0,0,cl.AbsoluteContentSize.Y+8)
        sc.CanvasPosition=Vector2.new(0,cl.AbsoluteContentSize.Y)
    end
    upd(); task.spawn(function() while running and task.wait(0.3) do upd() end end)
    local bar=Frame({BackgroundTransparency=1,Size=UDim2.new(1,0,0,30),LayoutOrder=2,ZIndex=4,Parent=page})
    mk("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8),Parent=bar})
    Components.Button(bar,maid,1,{Title="Copy logs",Color=Z.lime,Callback=function()
        if Executor.setclipboard then pcall(function()(Executor.setclipboard::(string)->boolean)(table.concat(logs,"\n"))end); notify("Logs copied","success") end
    end})
    -- Button uses full width; constrain inside horizontal bar
    for _,ch in ipairs(bar:GetChildren()) do if ch:IsA("Frame") then ch.Size=UDim2.fromOffset(120,30) end end
    Components.Button(bar,maid,2,{Title="Clear",Callback=function()
        table.clear(logs); logVersion+=1
        for _,ch in ipairs(sc:GetChildren()) do if ch:IsA("TextLabel") then ch:Destroy() end end
        sc.CanvasSize=UDim2.new()
    end})
    for _,ch in ipairs(bar:GetChildren()) do if ch:IsA("Frame") then ch.Size=UDim2.fromOffset(120,30) end end
end

Pages.Settings=function(host,maid)
    local page=Components.Page(host)
    local g=Components.Section(page,"General",1)
    Components.Keybind(g.body,maid,1,{Title="Toggle menu key",Get=function() return toggleKey end,Set=function(k) toggleKey=k; setFlag("toggle_key",k.Name); notify("Toggle key: "..k.Name) end})
    Components.Toggle(g.body,maid,2,{Title="Background blur",Get=function() return blurEnabled end,Toggle=function()
        blurEnabled=not blurEnabled; setFlag("blur",blurEnabled); tween(blur,{Size=if blurEnabled then 14 else 0},SMOOTH)
    end})
    Components.Slider(g.body,maid,3,{Title="UI Scale",Min=70,Max=120,Default=tonumber(getFlag("uiscale",100)) or 100,Suffix="%",Callback=function(v) uiScale.Scale=v/100; setFlag("uiscale",v) end})
    Components.Toggle(g.body,maid,4,{Title="Watermark (FPS/ping/clock)",Get=function() return getFlag("watermark",true)==true end,Toggle=function()
        local on=not (getFlag("watermark",true)==true); setFlag("watermark",on); if watermark then watermark.Visible=on end
    end})
    Components.Toggle(g.body,maid,5,{Title="Keybind list",Get=function() return getFlag("keybindlist",true)==true end,Toggle=function()
        local on=not (getFlag("keybindlist",true)==true); setFlag("keybindlist",on); if keybindList then keybindList.Visible=on end
    end})
    local permBtnApi: any = nil
    permBtnApi = Components.Button(g.body,maid,6,{Title="Permission: "..PERM_NAMES[userRank],Color=Z.lime,Callback=function()
        userRank=(userRank%4)+1; permChipLbl.Text=PERM_NAMES[userRank]
        if permBtnApi then permBtnApi.Label.Text="Permission: "..PERM_NAMES[userRank] end
    end})
    local c=Components.Section(page,"Configuration",2)
    Components.Button(c.body,maid,1,{Title="Save config now",Color=Z.lime,Callback=function()
        if not hasFS then notify("No filesystem on this executor","warn"); return end
        saveConfig(); notify("Saved to "..CONFIG_PATH,"success")
    end})
    Components.Button(c.body,maid,2,{Title="Reset config (clear all)",Color=Z.danger,Callback=function()
        for k in pairs(Flags) do Flags[k]=nil end; saveConfig(); notify("Config reset — re-execute to apply","warn")
    end})
    Components.Paragraph(page,3).Text= if hasFS
        then "Persistence active. All toggles, sliders and keybinds auto-save to "..CONFIG_PATH.." (debounced) and reload on next execution."
        else "Filesystem API not available on this executor — settings persist only for this session."
    local a=Components.Paragraph(page,4)
    a.Text="ZEX v8.0 PRIME\nDrawing ESP/aimbot · config persistence · watermark · protect_gui · WebhookPulse transmitter\nCtrl+K command palette · drag title bar to move · toggle with the configured key."
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 22. TAB SWITCHING — cross-fade + sliding indicator
-- ═══════════════════════════════════════════════════════════════════════════════

local activePageMaid: Maid? = nil
local activeHost: Frame? = nil
local currentTab = ""

local function setActiveIcon(tabId:string)
    for id,ref in pairs(sidebarBtns) do
        local on = id==tabId
        recolorIcon(ref.icon, if on then Z.lime else Z.text3)
        tween(ref.btn,{BackgroundTransparency=if on then 0 else 1, BackgroundColor3=Z.elevated},FAST)
    end
    local ref=sidebarBtns[tabId]
    if ref then tween(indicator,{Position=UDim2.new(0,0,0,ref.y)},SMOOTH) end
end

local function switchTab(tabId:string)
    if tabId==currentTab then return end
    currentTab=tabId
    setActiveIcon(tabId)
    tabTitle.Text=tabId
    local oldMaid=activePageMaid; local oldHost=activeHost
    if oldHost then
        tween(oldHost,{Position=UDim2.new(0,-18,0,40)},FAST)
        task.delay(0.13,function()
            if oldMaid then oldMaid:Destroy() end
            if oldHost then oldHost:Destroy() end
        end)
    end
    local maid=Maid.new(); activePageMaid=maid
    local host=Frame({Name="Page_"..tabId,Size=UDim2.fromScale(1,1),Position=UDim2.new(0,18,0,40),
        BackgroundTransparency=1,ZIndex=4,Parent=pageHost})
    activeHost=host
    local builder=Pages[tabId]
    if builder then safeCall(function() builder(host,maid) end,"Page:"..tabId) end
    host.Position=UDim2.new(0,18,0,40)
    tween(host,{Position=UDim2.new(0,0,0,40)},SMOOTH)
end

for id,ref in pairs(sidebarBtns) do
    rootMaid:GiveTask(ref.btn.MouseButton1Click:Connect(function() switchTab(id) end))
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 23. COMMAND INPUT BAR
-- ═══════════════════════════════════════════════════════════════════════════════

local inputBar=Frame({Name="InputBar",Size=UDim2.new(1,-SIDEBAR_W,0,INPUT_H),Position=UDim2.new(0,SIDEBAR_W,1,-INPUT_H),
    BackgroundColor3=Z.card,BorderSizePixel=0,ZIndex=5,Parent=window})
Frame({Size=UDim2.new(1,0,0,1),BackgroundColor3=Z.border,BorderSizePixel=0,ZIndex=6,Parent=inputBar})
local promptLbl=Label({Text=CMD_PREFIX,Font=F_CODE,TextSize=14,TextColor3=Z.lime,Size=UDim2.fromOffset(18,INPUT_H),
    Position=UDim2.new(0,12,0,0),ZIndex=6,Parent=inputBar})
local inputBox=TextBox({PlaceholderText="type a command and press Enter — e.g. fly 80",PlaceholderColor3=Z.text3,Text="",
    Font=F_CODE,TextSize=12,TextColor3=Z.text,BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,
    Size=UDim2.new(1,-110,1,0),Position=UDim2.new(0,32,0,0),ZIndex=6,Parent=inputBar})
local runCmd=Button({Text="RUN",Font=F_BTN,TextSize=11,TextColor3=Z.black,Size=UDim2.fromOffset(60,26),
    Position=UDim2.new(1,-72,0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundColor3=Z.lime,ZIndex=6,Parent=inputBar})
corner(6).Parent=runCmd
hoverFx(runCmd,rootMaid,{BackgroundColor3=Z.lime},{BackgroundColor3=Z.lime2})

local function executeInput()
    local raw=inputBox.Text:match("^%s*(.-)%s*$") or ""; if #raw==0 then return end
    if raw:sub(1,#CMD_PREFIX)==CMD_PREFIX then raw=raw:sub(#CMD_PREFIX+1) end
    raw=raw:match("^%s*(.-)%s*$") or ""; if #raw==0 then return end
    local parts: {string}={}; for tok in raw:gmatch("%S+") do table.insert(parts,tok) end
    if #parts==0 then return end
    local name=parts[1]:lower(); local args: {string}={}
    for i=2,#parts do table.insert(args,parts[i]) end
    local cmd=CommandRegistry[name]
    if not cmd then notify("Unknown command: "..name,"warn"); return end
    if not canRun(cmd.perm) then notify("No permission: "..name,"danger"); return end
    safeCall(function() cmd.run(args) end,"Input:"..name)
    inputBox.Text=""
end
rootMaid:GiveTask(inputBox.FocusLost:Connect(function(enter) if enter then executeInput() end end))
rootMaid:GiveTask(runCmd.MouseButton1Click:Connect(function() ripple(runCmd,Z.black); executeInput() end))

-- ═══════════════════════════════════════════════════════════════════════════════
-- 24. NOTIFICATIONS v3 — icon · title · body · countdown bar
-- ═══════════════════════════════════════════════════════════════════════════════

local notifHost=Frame({Name="Notifs",AnchorPoint=Vector2.new(1,1),Size=UDim2.fromOffset(280,400),
    Position=UDim2.new(1,-14,1,-14),BackgroundTransparency=1,ZIndex=40,Parent=screenGui})
mk("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,VerticalAlignment=Enum.VerticalAlignment.Bottom,
    HorizontalAlignment=Enum.HorizontalAlignment.Right,Padding=UDim.new(0,8),Parent=notifHost})
local notifSeq=0
local lvlCol:{[string]:Color3}={info=Z.info,warn=Z.warn,success=Z.success,danger=Z.danger}

showNotification=function(title:string,msg:string,level:ToastLevel)
    if not screenGui or not screenGui.Parent then return end
    notifSeq+=1; local col=lvlCol[level] or Z.info
    local card=Frame({Size=UDim2.new(0,272,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=Z.elevated,
        BorderSizePixel=0,LayoutOrder=notifSeq,ClipsDescendants=true,ZIndex=41,Parent=notifHost})
    corner(9).Parent=card; stroke(Z.border,1).Parent=card
    Frame({Size=UDim2.new(0,3,1,0),BackgroundColor3=col,BorderSizePixel=0,ZIndex=42,Parent=card})
    local dot=Frame({Size=UDim2.fromOffset(8,8),Position=UDim2.new(0,14,0,15),BackgroundColor3=col,BorderSizePixel=0,ZIndex=42,Parent=card})
    corner(4).Parent=dot
    Label({Text=title,Font=F_HEAD,TextSize=12,TextColor3=Z.text,Size=UDim2.new(1,-40,0,16),
        Position=UDim2.new(0,30,0,10),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=42,Parent=card})
    Label({Text=msg,Font=F_BODY,TextSize=11,TextColor3=Z.text2,Size=UDim2.new(1,-40,0,0),
        AutomaticSize=Enum.AutomaticSize.Y,Position=UDim2.new(0,30,0,28),TextWrapped=true,
        TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,ZIndex=42,Parent=card})
    mk("UIPadding",{PaddingBottom=UDim.new(0,12),Parent=card})
    local prog=Frame({Size=UDim2.new(1,0,0,2),Position=UDim2.new(0,0,1,-2),BackgroundColor3=col,BorderSizePixel=0,ZIndex=43,Parent=card})
    -- entry: grow-in width (UIListLayout controls Position, so we animate Size + a stroke flash instead of fighting it)
    local nStroke=card:FindFirstChildOfClass("UIStroke"); if nStroke then nStroke.Color=col; nStroke.Transparency=0; tween(nStroke,{Transparency=1},GENTLE) end
    TweenService:Create(prog,TweenInfo.new(3.4,Enum.EasingStyle.Linear),{Size=UDim2.new(0,0,0,2)}):Play()
    task.delay(3.5,function()
        if not card or not card.Parent then return end
        tween(card,{BackgroundTransparency=1},FAST)
        local fadeAll=card:GetDescendants()
        for _,d in ipairs(fadeAll) do
            if d:IsA("TextLabel") then tween(d,{TextTransparency=1},FAST)
            elseif d:IsA("Frame") then tween(d,{BackgroundTransparency=1},FAST) end
        end
        task.delay(0.16,function() if card and card.Parent then card:Destroy() end end)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 24b. COMMAND PALETTE — Ctrl+K fuzzy launcher · full keyboard nav
-- ═══════════════════════════════════════════════════════════════════════════════

local paletteOpen = false

local function openPalette()
    if paletteOpen then return end
    paletteOpen = true
    local pm = Maid.new()

    local overlay=Frame({Name="Palette",Active=true,Size=UDim2.fromScale(1,1),BackgroundColor3=Z.black,
        BackgroundTransparency=1,BorderSizePixel=0,ZIndex=80,Parent=screenGui})
    pm:GiveTask(overlay)
    tween(overlay,{BackgroundTransparency=0.5},SMOOTH)

    local panel=Frame({Size=UDim2.fromOffset(520,56),AnchorPoint=Vector2.new(0.5,0),
        Position=UDim2.new(0.5,0,0,86),BackgroundColor3=Z.surface,BorderSizePixel=0,
        ClipsDescendants=true,ZIndex=81,Parent=overlay})
    corner(14).Parent=panel; stroke(Z.borderHi,1).Parent=panel
    -- top inner highlight (premium edge)
    Frame({Size=UDim2.new(1,0,0,1),BackgroundColor3=Z.text,BackgroundTransparency=0.92,BorderSizePixel=0,ZIndex=85,Parent=panel})

    local head=Frame({Size=UDim2.new(1,0,0,48),BackgroundColor3=Z.card,BorderSizePixel=0,ZIndex=82,Parent=panel})
    Frame({Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=Z.border,BorderSizePixel=0,ZIndex=83,Parent=head})
    drawIcon("search",Frame({Size=UDim2.fromOffset(20,20),Position=UDim2.new(0,16,0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundTransparency=1,ZIndex=83,Parent=head}),Z.lime)
    local box=TextBox({PlaceholderText="Run a command…",PlaceholderColor3=Z.text3,Text="",
        Font=F_BODY,TextSize=14,TextColor3=Z.text,BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,
        Size=UDim2.new(1,-110,1,0),Position=UDim2.new(0,44,0,0),ClearTextOnFocus=false,ZIndex=83,Parent=head})
    local hint=Label({Text="ESC",Font=F_CODE,TextSize=10,TextColor3=Z.text3,Size=UDim2.fromOffset(40,18),
        Position=UDim2.new(1,-54,0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundColor3=Z.elevated,ZIndex=83,Parent=head})
    corner(5).Parent=hint

    local list=Scroll({Size=UDim2.new(1,-8,1,-56),Position=UDim2.fromOffset(4,52),BackgroundTransparency=1,
        CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ZIndex=82,Parent=panel})
    mk("UIListLayout",{Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder,Parent=list})
    mk("UIPadding",{PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,4),PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,4),Parent=list})
    local catCol:{[string]:Color3}={Player=Z.lime,Combat=Z.danger,World=Z.info,Server=Z.warn,Utility=Z.text2}

    local all: {CommandDef}={}
    for _,c in pairs(CommandRegistry) do table.insert(all,c) end
    table.sort(all,function(a,b) return a.name<b.name end)

    local filtered: {CommandDef}={}
    local rows: {TextButton}={}
    local sel=1

    local function runCmd(cmd:CommandDef)
        if not canRun(cmd.perm) then notify("No permission: "..cmd.name,"danger"); return end
        safeCall(function() cmd.run({}) end,"Palette:"..cmd.name)
    end
    local function closePalette()
        if not paletteOpen then return end
        paletteOpen=false
        tween(overlay,{BackgroundTransparency=1},FAST)
        task.delay(0.14,function() pm:Destroy() end)
    end
    local function highlight()
        for i,b in ipairs(rows) do
            local on=i==sel
            b.BackgroundColor3=if on then Z.hover else Z.card
            local bar=b:FindFirstChild("selbar"); if bar and bar:IsA("Frame") then bar.Visible=on end
        end
        local b=rows[sel]
        if b then
            local top=(b.AbsolutePosition.Y-list.AbsolutePosition.Y)+list.CanvasPosition.Y
            local bottom=top+b.AbsoluteSize.Y
            if top<list.CanvasPosition.Y then list.CanvasPosition=Vector2.new(0,math.max(top-4,0))
            elseif bottom>list.CanvasPosition.Y+list.AbsoluteSize.Y then list.CanvasPosition=Vector2.new(0,bottom-list.AbsoluteSize.Y+4) end
        end
    end
    local function rebuild(q:string)
        for _,b in ipairs(rows) do b:Destroy() end
        table.clear(rows); table.clear(filtered)
        local ql=q:lower()
        for _,cmd in ipairs(all) do
            if ql=="" or cmd.name:lower():find(ql,1,true) or cmd.desc:lower():find(ql,1,true) or cmd.category:lower():find(ql,1,true) then
                table.insert(filtered,cmd)
            end
        end
        if #filtered==0 then
            local e=Button({Text="",BackgroundColor3=Z.card,Size=UDim2.new(1,0,0,38),LayoutOrder=1,ZIndex=83,Parent=list})
            corner(7).Parent=e
            Label({Text="no matching command",Font=F_THIN,TextSize=11,TextColor3=Z.text3,Size=UDim2.fromScale(1,1),ZIndex=84,Parent=e})
        end
        for i,cmd in ipairs(filtered) do
            local b=Button({Text="",BackgroundColor3=Z.card,Size=UDim2.new(1,0,0,38),LayoutOrder=i,ZIndex=83,Parent=list})
            corner(7).Parent=b
            Frame({Name="selbar",Size=UDim2.fromOffset(3,20),Position=UDim2.new(0,6,0.5,0),AnchorPoint=Vector2.new(0,0.5),
                BackgroundColor3=catCol[cmd.category] or Z.lime,BorderSizePixel=0,Visible=false,ZIndex=84,Parent=b})
            Label({Text=cmd.name,Font=F_BTN,TextSize=12,TextColor3=Z.text,Size=UDim2.new(0,150,1,0),
                Position=UDim2.new(0,18,0,0),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=84,Parent=b})
            Label({Text=cmd.desc,Font=F_THIN,TextSize=10,TextColor3=Z.text3,Size=UDim2.new(1,-250,1,0),
                Position=UDim2.new(0,168,0,0),TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=84,Parent=b})
            Label({Text=cmd.category,Font=F_CODE,TextSize=9,TextColor3=catCol[cmd.category] or Z.text2,
                Size=UDim2.new(0,68,1,0),Position=UDim2.new(1,-74,0,0),TextXAlignment=Enum.TextXAlignment.Right,ZIndex=84,Parent=b})
            local idx=i
            b.MouseEnter:Connect(function() sel=idx; highlight() end)
            b.MouseButton1Click:Connect(function() runCmd(cmd); closePalette() end)
            table.insert(rows,b)
        end
        sel=math.clamp(sel,1,math.max(#filtered,1))
        local visible=math.min(math.max(#filtered,1),7)
        tween(panel,{Size=UDim2.fromOffset(520, 56+visible*41+6)},SMOOTH)
        highlight()
    end

    pm:GiveTask(box:GetPropertyChangedSignal("Text"):Connect(function() sel=1; rebuild(box.Text) end))
    pm:GiveTask(box.FocusLost:Connect(function(enter)
        if enter then local cmd=filtered[sel]; if cmd then runCmd(cmd); closePalette() end end
    end))
    pm:GiveTask(UserInputService.InputBegan:Connect(function(inp:InputObject)
        if not paletteOpen then return end
        if inp.KeyCode==Enum.KeyCode.Escape then closePalette()
        elseif inp.KeyCode==Enum.KeyCode.Down then sel=math.clamp(sel+1,1,math.max(#filtered,1)); highlight()
        elseif inp.KeyCode==Enum.KeyCode.Up   then sel=math.clamp(sel-1,1,math.max(#filtered,1)); highlight()
        end
    end))
    pm:GiveTask(overlay.InputBegan:Connect(function(inp:InputObject)
        if inp.UserInputType~=Enum.UserInputType.MouseButton1 and inp.UserInputType~=Enum.UserInputType.Touch then return end
        local m=UserInputService:GetMouseLocation()
        local ap,sz=panel.AbsolutePosition,panel.AbsoluteSize
        if not (m.X>=ap.X and m.X<=ap.X+sz.X and m.Y>=ap.Y and m.Y<=ap.Y+sz.Y) then closePalette() end
    end))

    rebuild("")
    task.defer(function() pcall(function() box:CaptureFocus() end) end)
end

rootMaid:GiveTask(UserInputService.InputBegan:Connect(function(input:InputObject,gp:boolean)
    if gp then return end
    if capturingKeybind then return end
    if input.KeyCode==Enum.KeyCode.K
        and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
        openPalette()
    end
end))

-- ═══════════════════════════════════════════════════════════════════════════════
-- 25. DRAG · MINIMIZE · CLOSE
-- ═══════════════════════════════════════════════════════════════════════════════

local dragMaid: Maid? = nil
rootMaid:GiveTask(function() if dragMaid then dragMaid:Destroy(); dragMaid=nil end end)
rootMaid:GiveTask(topbar.InputBegan:Connect(function(input:InputObject)
    if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
    if dragMaid then dragMaid:Destroy() end; dragMaid=Maid.new()
    local dt=input.UserInputType
    local start=Vector2.new(input.Position.X,input.Position.Y)
    local origin=holder.AbsolutePosition + holder.AbsoluteSize/2  -- center (AnchorPoint .5)
    dragMaid:GiveTask(UserInputService.InputChanged:Connect(function(i2:InputObject)
        if i2.UserInputType~=Enum.UserInputType.MouseMovement and i2.UserInputType~=Enum.UserInputType.Touch then return end
        local delta=Vector2.new(i2.Position.X,i2.Position.Y)-start
        local vp=Workspace.CurrentCamera.ViewportSize
        local nx=math.clamp(origin.X+delta.X, holder.AbsoluteSize.X/2, vp.X-holder.AbsoluteSize.X/2)
        local ny=math.clamp(origin.Y+delta.Y, holder.AbsoluteSize.Y/2, vp.Y-holder.AbsoluteSize.Y/2)
        holder.Position=UDim2.fromOffset(nx,ny)
    end))
    dragMaid:GiveTask(UserInputService.InputEnded:Connect(function(i2:InputObject)
        if i2.UserInputType==dt then if dragMaid then dragMaid:Destroy(); dragMaid=nil end end
    end))
end))

local minimized=false
rootMaid:GiveTask(minBtn.MouseButton1Click:Connect(function()
    minimized=not minimized
    tween(holder,{Size=UDim2.fromOffset(WIN_W, if minimized then 46 else WIN_H)},SPRING)
end))

local function closeGui()
    tween(blur,{Size=0},SMOOTH)
    tween(dim,{BackgroundTransparency=1},SMOOTH)
    tween(holder,{Size=UDim2.fromOffset(WIN_W*0.85,WIN_H*0.85)},FAST)
    task.delay(0.18,function()
        if screenGui and screenGui.Parent then screenGui:Destroy() end
        rootMaid:Destroy()
    end)
end
rootMaid:GiveTask(closeBtn.MouseButton1Click:Connect(closeGui))

-- ═══════════════════════════════════════════════════════════════════════════════
-- 26. TOGGLE KEY · ENTRY · TEARDOWN
-- ═══════════════════════════════════════════════════════════════════════════════

local guiVisible=true
local savedPos: UDim2 = UDim2.fromScale(0.5,0.5)
local function setGuiVisible(visible:boolean)
    if visible==guiVisible then return end
    guiVisible=visible
    if not visible then
        savedPos=holder.Position
        tween(holder,{Position=UDim2.new(savedPos.X.Scale,savedPos.X.Offset,1.6,0)},SMOOTH)
        tween(dim,{BackgroundTransparency=1},SMOOTH)
        if blurEnabled then tween(blur,{Size=0},SMOOTH) end
    else
        tween(holder,{Position=savedPos},SPRING)
        tween(dim,{BackgroundTransparency=0.55},SMOOTH)
        if blurEnabled then tween(blur,{Size=14},SMOOTH) end
    end
end
rootMaid:GiveTask(UserInputService.InputBegan:Connect(function(input:InputObject,gp:boolean)
    if gp then return end
    if capturingKeybind then return end   -- a Keybind picker is consuming this key
    if input.KeyCode==toggleKey then setGuiVisible(not guiVisible) end
end))

-- ── WATERMARK — live FPS · ping · players · clock (draggable) ───────────────────
watermark=Frame({Name="Watermark",Size=UDim2.fromOffset(340,28),Position=UDim2.fromOffset(16,16),
    BackgroundColor3=Z.surface,BorderSizePixel=0,Visible=getFlag("watermark",true)==true,ZIndex=30,Parent=screenGui})
corner(8).Parent=watermark; stroke(Z.border,1).Parent=watermark
Frame({Size=UDim2.fromOffset(3,16),Position=UDim2.new(0,10,0.5,0),AnchorPoint=Vector2.new(0,0.5),BackgroundColor3=Z.lime,BorderSizePixel=0,ZIndex=31,Parent=watermark})
local wmLbl=Label({Text="ZEX v8.0 PRIME",Font=F_BTN,TextSize=11,TextColor3=Z.text,Size=UDim2.new(1,-26,1,0),
    Position=UDim2.new(0,20,0,0),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=31,Parent=watermark})
do
    local wmDrag: Maid? = nil
    rootMaid:GiveTask(watermark.InputBegan:Connect(function(inp:InputObject)
        if inp.UserInputType~=Enum.UserInputType.MouseButton1 and inp.UserInputType~=Enum.UserInputType.Touch then return end
        if wmDrag then wmDrag:Destroy() end; wmDrag=Maid.new()
        local start=Vector2.new(inp.Position.X,inp.Position.Y); local origin=watermark.AbsolutePosition
        wmDrag:GiveTask(UserInputService.InputChanged:Connect(function(i2:InputObject)
            if i2.UserInputType~=Enum.UserInputType.MouseMovement and i2.UserInputType~=Enum.UserInputType.Touch then return end
            local d=Vector2.new(i2.Position.X,i2.Position.Y)-start
            watermark.Position=UDim2.fromOffset(origin.X+d.X,origin.Y+d.Y)
        end))
        wmDrag:GiveTask(UserInputService.InputEnded:Connect(function(i2:InputObject)
            if i2.UserInputType==inp.UserInputType then if wmDrag then wmDrag:Destroy(); wmDrag=nil end end
        end))
    end))
    local fps=0
    rootMaid:GiveTask(RunService.RenderStepped:Connect(function() fps+=1 end))
    task.spawn(function()
        local last=os.clock()
        while screenGui and screenGui.Parent do
            task.wait(1)
            local now=os.clock(); local f=math.floor(fps/math.max(now-last,1e-3)); fps=0; last=now
            local ping="--"
            pcall(function() if Services.Stats then ping=tostring(math.floor((Services.Stats::any).Network.ServerStatsItem["Data Ping"].Value)) end end)
            wmLbl.Text=string.format("ZEX v8.0   ·   %d FPS   ·   %s ms   ·   %d players   ·   %s",
                f, ping, #Players:GetPlayers(), os.date("%H:%M:%S"))
        end
    end)
end

-- ── KEYBIND LIST — active binds (bottom-left) ──────────────────────────────────
keybindList=Frame({Name="Keybinds",Size=UDim2.fromOffset(196,0),AutomaticSize=Enum.AutomaticSize.Y,
    Position=UDim2.new(0,16,1,-16),AnchorPoint=Vector2.new(0,1),BackgroundColor3=Z.surface,BorderSizePixel=0,
    Visible=getFlag("keybindlist",true)==true,ZIndex=30,Parent=screenGui})
corner(8).Parent=keybindList; stroke(Z.border,1).Parent=keybindList
mk("UIListLayout",{Padding=UDim.new(0,3),SortOrder=Enum.SortOrder.LayoutOrder,Parent=keybindList})
mk("UIPadding",{PaddingTop=UDim.new(0,8),PaddingBottom=UDim.new(0,8),PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12),Parent=keybindList})
Label({Text="KEYBINDS",Font=F_HEAD,TextSize=10,TextColor3=Z.lime,Size=UDim2.new(1,0,0,14),LayoutOrder=0,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=31,Parent=keybindList})
local kbToggle=Label({Text="",Font=F_BODY,TextSize=11,TextColor3=Z.text2,Size=UDim2.new(1,0,0,16),LayoutOrder=1,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=31,Parent=keybindList})
Label({Text="Command palette — Ctrl+K",Font=F_BODY,TextSize=11,TextColor3=Z.text2,Size=UDim2.new(1,0,0,16),LayoutOrder=2,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=31,Parent=keybindList})
Label({Text="Aimbot lock — Hold RMB",Font=F_BODY,TextSize=11,TextColor3=Z.text2,Size=UDim2.new(1,0,0,16),LayoutOrder=3,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=31,Parent=keybindList})
task.spawn(function() while screenGui and screenGui.Parent do kbToggle.Text="Toggle GUI — "..toggleKey.Name; task.wait(0.5) end end)

-- ── MOBILE — floating toggle button (touch devices only) ───────────────────────
if UserInputService.TouchEnabled then
    local fab=Button({Text="",Size=UDim2.fromOffset(52,52),Position=UDim2.new(1,-22,1,-92),AnchorPoint=Vector2.new(1,1),
        BackgroundColor3=Z.lime,ZIndex=35,Parent=screenGui})
    corner(26).Parent=fab; drawIcon("bolt",fab,Z.black)
    local fabDrag: Maid? = nil; local moved=false
    rootMaid:GiveTask(fab.InputBegan:Connect(function(inp:InputObject)
        if inp.UserInputType~=Enum.UserInputType.Touch and inp.UserInputType~=Enum.UserInputType.MouseButton1 then return end
        moved=false
        if fabDrag then fabDrag:Destroy() end; fabDrag=Maid.new()
        local start=Vector2.new(inp.Position.X,inp.Position.Y); local origin=fab.AbsolutePosition+fab.AbsoluteSize
        fabDrag:GiveTask(UserInputService.InputChanged:Connect(function(i2:InputObject)
            if i2.UserInputType~=Enum.UserInputType.Touch and i2.UserInputType~=Enum.UserInputType.MouseMovement then return end
            local d=Vector2.new(i2.Position.X,i2.Position.Y)-start
            if d.Magnitude>6 then moved=true end
            fab.Position=UDim2.fromOffset(origin.X+d.X,origin.Y+d.Y)
        end))
        fabDrag:GiveTask(UserInputService.InputEnded:Connect(function(i2:InputObject)
            if i2.UserInputType==inp.UserInputType then
                if fabDrag then fabDrag:Destroy(); fabDrag=nil end
                if not moved then setGuiVisible(not guiVisible) end
            end
        end))
    end))
end

rootMaid:GiveTask(screenGui.Destroying:Connect(function()
    if espMaid then espMaid:Destroy(); espMaid=nil end
    if blur then pcall(function() blur:Destroy() end) end
    saveConfig()
    rootMaid:Destroy()
    log("INFO","[ZEX] v8.0 PRIME teardown complete")
end))

-- entry
holder.Size=UDim2.fromOffset(WIN_W*0.9,WIN_H*0.9)
dim.BackgroundTransparency=1
switchTab("Dashboard")
task.delay(0.03,function()
    if not screenGui or not screenGui.Parent then return end
    tween(holder,{Size=UDim2.fromOffset(WIN_W,WIN_H)},SPRING)
    tween(dim,{BackgroundTransparency=0.55},GENTLE)
    if blurEnabled then tween(blur,{Size=14},GENTLE) end
end)

local cmdCount=0; for _ in pairs(CommandRegistry) do cmdCount+=1 end
log("INFO",string.format("[ZEX] v8.0 PRIME booted — %d commands — Drawing:%s FS:%s — rank %s",
    cmdCount, tostring(hasDrawing), tostring(hasFS), PERM_NAMES[userRank]))
task.delay(0.6,function() notify("ZEX v8.0 PRIME — "..cmdCount.." commands · Ctrl+K palette","success") end)
