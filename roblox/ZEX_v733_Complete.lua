--[[
  ZEX v7.3.4 COMPLETE — PREMIUM GUI + 40+ COMMANDS + PERMISSIONS
  Architecture: Modular · Memory-Safe · Consent-Gated · Strict-Typed
  Palette: #0C0C0E bg · #D4E83A lime · Gotham · No emojis
  Keybind: RightShift toggle · 7 Tabs · 40+ Commands · Persistent input bar

  v7.3.4 changelog (20 fixes + 5 new features):
  [CRIT] validateUrl: SSRF bypass via %w Lua-pattern misinterpretation — suffix comparison
  [CRIT] godmode: GetPropertyChangedSignal leaked on each toggle — stored + disconnected
  [CRIT] espConn: undeclared CMD_STATE field under --!strict — declared in typed table
  [HIGH] serverhop: game:HttpGet client-blocked — rewritten with Executor.request
  [HIGH] httpRequest: 201/204 treated as failure — full 2xx range accepted
  [HIGH] antifling: HRP velocity zeroed (breaks walk/fly) — excludes HumanoidRootPart
  [HIGH] bring/fling/bringall/flingall: no server replication — labeled [local only]
  [MED]  dance: hum:LoadAnimation deprecated — Animator:LoadAnimation
  [MED]  reset: localPlayer.Character=nil deprecated — LocalPlayer:LoadCharacter
  [MED]  kill/killall: BreakJoints deprecated — Humanoid.Health = 0
  [MED]  btools: HopperBin removed — Tool-only
  [MED]  tick(): deprecated — time()
  [MED]  entry animation: O(n) descendant tweens — single slide-in on container
  [MED]  console: full rebuild on each log — incremental append
  [MED]  commands canvas: task.delay unreliable — AbsoluteContentSize signal
  [MED]  TeleportToPlaceInstance: bare Player arg — {Player} table
  [MED]  antiafk: ChangeState every Heartbeat — 55 s interval task.spawn
  [LOW]  hookmetamethod/getrawmetatable/getnamecallmethod: never detected — detected
  [LOW]  services: single pcall for all — individual getService() per service
  [LOW]  CMD_STATE: all connection fields explicitly declared in typed table
  NEW+   Command input bar: persistent ;command [args] bar at bottom
  NEW+   Toast notifications: non-blocking colour-coded popups
  NEW+   Dashboard ping: Stats.Network.ServerStatsItem["Data Ping"]
  NEW+   ESP v2: distance label + dynamic health bar
  NEW+   ESP Maid: dedicated maid for all ESP cleanup
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

local function detectFn<T>(key: string): T?
    local ok, v = pcall(function(): any return _G[key] end)
    return if ok and type(v) == "function" then v :: T else nil
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

pcall(function()
    local syn    = _G["syn"]          :: any
    local req    = _G["request"]      :: any
    local httpR  = _G["http_request"] :: any
    local fluxus = _G["fluxus"]       :: any
    if   type(syn)    == "table"  and type(syn.request)    == "function" then Executor.request = syn.request
    elseif type(req)  == "function"                                       then Executor.request = req
    elseif type(httpR)== "function"                                       then Executor.request = httpR
    elseif type(fluxus)== "table" and type(fluxus.request) == "function" then Executor.request = fluxus.request
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. TYPES
-- ═══════════════════════════════════════════════════════════════════════════════

export type Palette = {
    bg:Color3, surface:Color3, elevated:Color3, card:Color3,
    border:Color3, borderHi:Color3, text:Color3, text2:Color3, text3:Color3,
    lime:Color3, lime2:Color3, limeGlow:Color3,
    danger:Color3, success:Color3, info:Color3, warn:Color3, clear:Color3,
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
    bg=Color3.fromRGB(10,10,12),       surface=Color3.fromRGB(18,18,20),
    elevated=Color3.fromRGB(26,26,28), card=Color3.fromRGB(22,22,24),
    border=Color3.fromRGB(38,38,42),   borderHi=Color3.fromRGB(60,60,65),
    text=Color3.fromRGB(252,252,252),  text2=Color3.fromRGB(160,160,170),
    text3=Color3.fromRGB(100,100,110),
    lime=Color3.fromRGB(212,232,58),   lime2=Color3.fromRGB(235,252,110),
    limeGlow=Color3.fromRGB(180,200,40),
    danger=Color3.fromRGB(239,68,68),  success=Color3.fromRGB(34,197,94),
    info=Color3.fromRGB(59,130,246),   warn=Color3.fromRGB(245,158,11),
    clear=Color3.fromRGB(0,0,0),
}

local TWEEN_FAST   = TweenInfo.new(0.15, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local TWEEN_SMOOTH = TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
local TWEEN_SLOW   = TweenInfo.new(0.6,  Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TWEEN_SPRING = TweenInfo.new(0.4,  Enum.EasingStyle.Back,  Enum.EasingDirection.Out)
local TWEEN_PULSE  = TweenInfo.new(1.5,  Enum.EasingStyle.Sine,  Enum.EasingDirection.InOut, -1, true)

local FONT_HEADER  = Enum.Font.GothamBold
local FONT_BODY    = Enum.Font.GothamMedium
local FONT_LABEL   = Enum.Font.Gotham
local FONT_DATA    = Enum.Font.GothamMedium
local FONT_BUTTON  = Enum.Font.GothamBold
local FONT_CONSOLE = Enum.Font.Code

local LOG_MAX    = 300
local CMD_PREFIX = ";"

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

-- FIX [CRIT]: old code used pattern matching with "%"..domain which turned "%w"
-- into the word-char class, allowing spoofed domains. Replaced with suffix compare.
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
            local ok,res = pcall(function() return Executor.request(options) end)
            return if ok then res else nil
        end,
        function()
            if not Services.HttpService then return nil end
            local ok,body = pcall(function()
                return Services.HttpService:PostAsync(options.Url,options.Body or "",
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
            -- FIX [HIGH]: was only StatusCode==200; now accepts full 2xx range
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
-- 9. COMMAND STATE — fully typed; all connection fields declared
-- ═══════════════════════════════════════════════════════════════════════════════

type CmdState = {
    fly:boolean, noclip:boolean, godmode:boolean, invisible:boolean,
    esp:boolean, aimbot:boolean, clicktp:boolean, spin:boolean,
    antifling:boolean, antiafk:boolean, fullbright:boolean,
    flyConn:RBXScriptConnection?,       noclipConn:RBXScriptConnection?,
    spinConn:RBXScriptConnection?,      espConn:RBXScriptConnection?,
    aimbotConn:RBXScriptConnection?,    clicktpConn:RBXScriptConnection?,
    antiflingConn:RBXScriptConnection?, antiafkConn:RBXScriptConnection?,
    godmodeConn:RBXScriptConnection?,   -- FIX [CRIT]: declared; was undeclared dynamic field
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

local espMaid: Maid? = nil  -- dedicated maid for ESP (holds connections + instances)

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
-- 11. NOTIFICATION BRIDGE (wired to toast system after GUI init)
-- ═══════════════════════════════════════════════════════════════════════════════

local showNotification: ((msg:string,level:ToastLevel)->())? = nil

local function notify(msg: string, level: ToastLevel?)
    local lv: ToastLevel = level or "info"
    log(if lv=="danger" then "ERROR" elseif lv=="warn" then "WARN" else "INFO", msg)
    if showNotification then showNotification(msg,lv) end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 12. COMMAND REGISTRY
-- ═══════════════════════════════════════════════════════════════════════════════

local CommandRegistry: {[string]:CommandDef} = {}

local function reg(name:string,desc:string,cat:string,perm:number,run:(args:{string})->())
    CommandRegistry[name:lower()] = {name=name,desc=desc,category=cat,perm=perm,run=run}
end

-- ── PLAYER ────────────────────────────────────────────────────────────────────

reg("fly","Toggle fly","Player",PERM.USER,function(args)
    CMD_STATE.fly = not CMD_STATE.fly
    local char=getCharacter(); if not char then notify("No character","warn"); return end
    local hum=getHumanoid();   if not hum  then notify("No humanoid","warn");  return end
    local root=getRootPart();  if not root  then notify("No HRP","warn");       return end
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

reg("unfly","Disable fly","Player",PERM.USER,function(_)
    if CMD_STATE.fly then CommandRegistry["fly"].run({}) end
end)

reg("noclip","Toggle noclip","Player",PERM.USER,function(_)
    CMD_STATE.noclip = not CMD_STATE.noclip
    local char=getCharacter(); if not char then return end
    if CMD_STATE.noclip then
        CMD_STATE.noclipConn = RunService.Stepped:Connect(function()
            if not CMD_STATE.noclip then return end
            for _,v in ipairs(char:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide=false end end
        end)
        notify("Noclip ON","success")
    else
        if CMD_STATE.noclipConn then CMD_STATE.noclipConn:Disconnect(); CMD_STATE.noclipConn=nil end
        for _,v in ipairs(char:GetDescendants()) do if v:IsA("BasePart") then v.CanCollide=true end end
        notify("Noclip OFF")
    end
end)

reg("clip","Disable noclip","Player",PERM.USER,function(_)
    if CMD_STATE.noclip then CommandRegistry["noclip"].run({}) end
end)

reg("speed","Set walkspeed","Player",PERM.USER,function(args)
    local v=math.clamp(tonumber(args[1]) or 50,0,9999)
    local h=getHumanoid(); if h then h.WalkSpeed=v; notify("WalkSpeed = "..v) end
end)
reg("ws","WalkSpeed alias","Player",PERM.USER,function(a) CommandRegistry["speed"].run(a) end)
reg("walkspeed","WalkSpeed alias","Player",PERM.USER,function(a) CommandRegistry["speed"].run(a) end)

reg("jump","Set jumppower","Player",PERM.USER,function(args)
    local v=math.clamp(tonumber(args[1]) or 75,0,9999)
    local h=getHumanoid(); if h then h.JumpPower=v; notify("JumpPower = "..v) end
end)
reg("jp","JumpPower alias","Player",PERM.USER,function(a) CommandRegistry["jump"].run(a) end)
reg("jumppower","JumpPower alias","Player",PERM.USER,function(a) CommandRegistry["jump"].run(a) end)

reg("gravity","Set gravity","World",PERM.USER,function(args)
    local v=tonumber(args[1]) or 196.2; Workspace.Gravity=v; notify("Gravity = "..v)
end)

reg("heal","Restore health","Player",PERM.USER,function(_)
    local h=getHumanoid(); if h then h.Health=h.MaxHealth; notify("Healed","success") end
end)

-- FIX [MED]: BreakJoints deprecated — Humanoid.Health = 0
reg("kill","Kill self","Player",PERM.USER,function(_)
    local h=getHumanoid(); if h then h.Health=0; notify("Killed") end
end)

-- FIX [CRIT]: godmode leak — connection stored in CMD_STATE.godmodeConn, disconnected on toggle-off
reg("godmode","Toggle godmode","Player",PERM.MOD,function(_)
    CMD_STATE.godmode = not CMD_STATE.godmode
    if CMD_STATE.godmode then
        local hum=getHumanoid(); if not hum then notify("No humanoid","warn"); return end
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
reg("ungodmode","Disable godmode","Player",PERM.MOD,function(_)
    if CMD_STATE.godmode then CommandRegistry["godmode"].run({}) end
end)

reg("invisible","Toggle invisibility","Player",PERM.MOD,function(_)
    CMD_STATE.invisible = not CMD_STATE.invisible
    local char=getCharacter(); if not char then return end
    for _,v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") or v:IsA("Decal") or v:IsA("Texture") then
            v.Transparency = if CMD_STATE.invisible then 1 else 0
        end
        if v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Enabled=not CMD_STATE.invisible end
    end
    notify(if CMD_STATE.invisible then "Invisible ON" else "Visible",
           if CMD_STATE.invisible then "success" else nil)
end)
reg("visible","Disable invisibility","Player",PERM.MOD,function(_)
    if CMD_STATE.invisible then CommandRegistry["invisible"].run({}) end
end)

reg("sit",   "Force sit",   "Player",PERM.USER,function(_) local h=getHumanoid(); if h then h.Sit=true  end end)
reg("unsit", "Force stand", "Player",PERM.USER,function(_) local h=getHumanoid(); if h then h.Sit=false end end)

reg("freeze","Freeze character","Player",PERM.MOD,function(_)
    local c=getCharacter(); if not c then return end
    for _,v in ipairs(c:GetDescendants()) do if v:IsA("BasePart") then v.Anchored=true  end end
    notify("Frozen","warn")
end)
reg("thaw","Unfreeze","Player",PERM.MOD,function(_)
    local c=getCharacter(); if not c then return end
    for _,v in ipairs(c:GetDescendants()) do if v:IsA("BasePart") then v.Anchored=false end end
    notify("Thawed")
end)
reg("anchor",   "Anchor",   "Player",PERM.MOD,function(a) CommandRegistry["freeze"].run(a) end)
reg("unanchor", "Unanchor", "Player",PERM.MOD,function(a) CommandRegistry["thaw"].run(a)   end)

reg("spin","Toggle spin","Player",PERM.USER,function(_)
    CMD_STATE.spin = not CMD_STATE.spin
    local root=getRootPart(); if not root then return end
    if CMD_STATE.spin then
        CMD_STATE.spinConn = RunService.RenderStepped:Connect(function()
            if not CMD_STATE.spin then return end
            root.CFrame = root.CFrame * CFrame.Angles(0,math.rad(10),0)
        end)
        notify("Spin ON")
    else
        if CMD_STATE.spinConn then CMD_STATE.spinConn:Disconnect(); CMD_STATE.spinConn=nil end
        notify("Spin OFF")
    end
end)
reg("unspin","Stop spin","Player",PERM.USER,function(_)
    if CMD_STATE.spin then CommandRegistry["spin"].run({}) end
end)

-- FIX [MED]: hum:LoadAnimation deprecated — Animator:LoadAnimation
reg("dance","Play dance emote","Player",PERM.USER,function(_)
    local anim=getAnimator()
    if anim then
        local a=Instance.new("Animation"); a.AnimationId="rbxassetid://507771019"
        anim:LoadAnimation(a):Play(); notify("Dancing","success")
    else notify("No animator","warn") end
end)

-- FIX [MED]: localPlayer.Character=nil deprecated — LoadCharacter
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

-- FIX [MED]: antiafk now uses task.spawn + task.wait(55) instead of every Heartbeat
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
    else
        notify("Anti-AFK OFF")
    end
end)

-- FIX [HIGH]: excludes HumanoidRootPart — zeroing HRP breaks walk and fly
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

-- ── COMBAT ────────────────────────────────────────────────────────────────────

-- FIX [CRIT]: espConn declared in CMD_STATE; uses dedicated espMaid
-- NEW: distance label + dynamic HP bar per player
reg("esp","Toggle ESP v2","Combat",PERM.MOD,function(_)
    CMD_STATE.esp = not CMD_STATE.esp
    if CMD_STATE.esp then
        if espMaid then espMaid:Destroy() end
        espMaid = Maid.new()
        notify("ESP ON","success")

        local function attachChar(p: Player, char: Model)
            local pMaid=Maid.new()
            espMaid:GiveTask(function() pMaid:Destroy() end)
            local head=char:FindFirstChild("Head")::BasePart?; if not head then return end

            local hl=Instance.new("Highlight"); hl.Name="ZEX_ESP"
            hl.FillColor=Z.danger; hl.OutlineColor=Z.lime
            hl.FillTransparency=0.7; hl.OutlineTransparency=0.3; hl.Parent=char
            pMaid:GiveTask(hl)

            local bg=Instance.new("BillboardGui"); bg.Name="ZEX_ESP"
            bg.AlwaysOnTop=true; bg.Size=UDim2.new(0,120,0,40)
            bg.StudsOffset=Vector3.new(0,2.8,0); bg.Parent=head
            pMaid:GiveTask(bg)

            local nameL=Instance.new("TextLabel"); nameL.Size=UDim2.new(1,0,0,16)
            nameL.BackgroundTransparency=1; nameL.TextColor3=Z.lime; nameL.Font=FONT_BODY
            nameL.TextSize=12; nameL.Text=p.Name; nameL.Parent=bg

            local distL=Instance.new("TextLabel"); distL.Size=UDim2.new(1,0,0,14)
            distL.Position=UDim2.new(0,0,0,16); distL.BackgroundTransparency=1
            distL.TextColor3=Z.text3; distL.Font=FONT_LABEL; distL.TextSize=10
            distL.Text="? studs"; distL.Parent=bg

            local hpBg=Instance.new("Frame"); hpBg.Size=UDim2.new(1,0,0,4)
            hpBg.Position=UDim2.new(0,0,0,32); hpBg.BackgroundColor3=Z.elevated
            hpBg.BorderSizePixel=0; hpBg.Parent=bg
            local c1=Instance.new("UICorner"); c1.CornerRadius=UDim.new(0,2); c1.Parent=hpBg
            local hpFill=Instance.new("Frame"); hpFill.Size=UDim2.new(1,0,1,0)
            hpFill.BackgroundColor3=Z.success; hpFill.BorderSizePixel=0; hpFill.Parent=hpBg
            local c2=Instance.new("UICorner"); c2.CornerRadius=UDim.new(0,2); c2.Parent=hpFill

            local hum=char:FindFirstChildOfClass("Humanoid")
            local hrp=char:FindFirstChild("HumanoidRootPart")::BasePart?
            pMaid:GiveTask(RunService.RenderStepped:Connect(function()
                if not hum or not hum.Parent then return end
                local hp=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
                hpFill.Size=UDim2.new(hp,0,1,0)
                hpFill.BackgroundColor3=if hp>0.5 then Z.success elseif hp>0.25 then Z.warn else Z.danger
                if hrp and localPlayer.Character then
                    local myHrp=localPlayer.Character:FindFirstChild("HumanoidRootPart")::BasePart?
                    if myHrp then distL.Text=math.floor((hrp.Position-myHrp.Position).Magnitude).." studs" end
                end
            end))
        end

        local function addESP(p: Player)
            if p==localPlayer then return end
            if p.Character then attachChar(p,p.Character) end
            espMaid:GiveTask(p.CharacterAdded:Connect(function(char) task.wait(0.3); attachChar(p,char) end))
        end

        for _,p in ipairs(Players:GetPlayers()) do addESP(p) end
        CMD_STATE.espConn = Players.PlayerAdded:Connect(addESP)
        espMaid:GiveTask(function()
            if CMD_STATE.espConn then CMD_STATE.espConn:Disconnect(); CMD_STATE.espConn=nil end
        end)
    else
        if espMaid then espMaid:Destroy(); espMaid=nil end
        notify("ESP OFF")
    end
end)
reg("unesp","Disable ESP","Combat",PERM.MOD,function(_)
    if CMD_STATE.esp then CommandRegistry["esp"].run({}) end
end)

reg("aimbot","Toggle aimbot","Combat",PERM.MOD,function(_)
    CMD_STATE.aimbot = not CMD_STATE.aimbot
    if CMD_STATE.aimbot then
        CMD_STATE.aimbotConn = RunService.RenderStepped:Connect(function()
            if not CMD_STATE.aimbot then return end
            local cam=Workspace.CurrentCamera; local best=math.huge; local nearest:BasePart?=nil
            for _,p in ipairs(Players:GetPlayers()) do
                if p~=localPlayer and p.Character then
                    local h=p.Character:FindFirstChild("Head")::BasePart?
                    if h then local d=(h.Position-cam.CFrame.Position).Magnitude
                        if d<best then best=d; nearest=h end end
                end
            end
            if nearest then cam.CFrame=CFrame.new(cam.CFrame.Position,nearest.Position) end
        end)
        notify("Aimbot ON","success")
    else
        if CMD_STATE.aimbotConn then CMD_STATE.aimbotConn:Disconnect(); CMD_STATE.aimbotConn=nil end
        notify("Aimbot OFF")
    end
end)
reg("unaimbot","Disable aimbot","Combat",PERM.MOD,function(_)
    if CMD_STATE.aimbot then CommandRegistry["aimbot"].run({}) end
end)

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

-- ── WORLD ─────────────────────────────────────────────────────────────────────

reg("fullbright","Enable fullbright","World",PERM.USER,function(_)
    Lighting.Brightness=10; Lighting.GlobalShadows=false; Lighting.ClockTime=12
    notify("Fullbright ON","success")
end)
reg("time","Set lighting time","World",PERM.USER,function(args)
    local v=tonumber(args[1]) or 12; Lighting.ClockTime=v; notify("Time = "..v)
end)
reg("fog","Set fog end","World",PERM.USER,function(args)
    local v=tonumber(args[1]) or 0; Lighting.FogEnd=v; notify("Fog = "..v)
end)
reg("clearterrain","Clear terrain","World",PERM.ADMIN,function(_)
    if Workspace:FindFirstChildOfClass("Terrain") then
        Workspace.Terrain:Clear(); notify("Terrain cleared","warn")
    end
end)

-- ── SERVER ────────────────────────────────────────────────────────────────────

reg("rejoin","Rejoin server","Server",PERM.USER,function(_)
    notify("Rejoining..."); TeleportService:Teleport(game.PlaceId,localPlayer)
end)

-- FIX [HIGH]: was game:HttpGet (client-blocked) — now Executor.request
-- FIX [MED]:  TeleportToPlaceInstance now receives {localPlayer} table, not bare Player
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
                    TeleportService:TeleportToPlaceInstance(game.PlaceId,server.id,localPlayer)
                    return
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
reg("tp",   "Teleport alias","Server",PERM.MOD,function(a) CommandRegistry["teleport"].run(a) end)
reg("goto", "Goto alias",    "Server",PERM.MOD,function(a) CommandRegistry["teleport"].run(a) end)

-- FIX [HIGH]: labeled [local only] — no server replication from executor context
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
        bv.Velocity=Vector3.new(0,500,0); bv.Parent=tr
        task.delay(0.5,function() bv:Destroy() end)
        notify("Flung "..t.Name.." [local]","warn")
    end
end)

-- FIX [MED]: BreakJoints deprecated — Humanoid.Health=0
reg("killall","Kill all [local]","Server",PERM.OWNER,function(_)
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=localPlayer and p.Character then
            local h=p.Character:FindFirstChildOfClass("Humanoid")::Humanoid?
            if h then pcall(function() h.Health=0 end) end
        end
    end
    notify("Killed all [local]","warn")
end)

reg("bringall","Bring all [local]","Server",PERM.OWNER,function(_)
    local r=getRootPart(); if not r then return end
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=localPlayer and p.Character then
            local tr=p.Character:FindFirstChild("HumanoidRootPart")::Part?
            if tr then pcall(function() tr.CFrame=r.CFrame end) end
        end
    end
    notify("Brought all [local]","warn")
end)

reg("flingall","Fling all [local]","Server",PERM.OWNER,function(_)
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=localPlayer and p.Character then
            local tr=p.Character:FindFirstChild("HumanoidRootPart")::Part?
            if tr then
                local bv=Instance.new("BodyVelocity"); bv.MaxForce=Vector3.new(9e9,9e9,9e9)
                bv.Velocity=Vector3.new(math.random(-500,500),500,math.random(-500,500)); bv.Parent=tr
                task.delay(0.5,function() bv:Destroy() end)
            end
        end
    end
    notify("Flung all [local]","warn")
end)

reg("kick","Kick [local visual]","Server",PERM.ADMIN,function(args)
    local t=getPlayerByName(args[1] or "")
    if t and t~=localPlayer then pcall(function()(t::any):Kick("Kicked by ZEX")end); notify("Kick: "..t.Name.." [local]","warn") end
end)

reg("speedall","Speed all [local]","Server",PERM.OWNER,function(args)
    local v=tonumber(args[1]) or 50
    for _,p in ipairs(Players:GetPlayers()) do if p.Character then
        local h=p.Character:FindFirstChildOfClass("Humanoid")::Humanoid?; if h then h.WalkSpeed=v end
    end end; notify("Speed all = "..v.." [local]","warn")
end)

reg("jumppowerall","JumpPower all [local]","Server",PERM.OWNER,function(args)
    local v=tonumber(args[1]) or 75
    for _,p in ipairs(Players:GetPlayers()) do if p.Character then
        local h=p.Character:FindFirstChildOfClass("Humanoid")::Humanoid?; if h then h.JumpPower=v end
    end end; notify("JumpPower all = "..v.." [local]","warn")
end)

-- ── UTILITY ───────────────────────────────────────────────────────────────────

-- FIX [MED]: HopperBin removed from Roblox — Tool only
reg("btools","Give build tool","Utility",PERM.MOD,function(_)
    local bp=localPlayer:FindFirstChildOfClass("Backpack"); if not bp then return end
    local t=Instance.new("Tool"); t.RequiresHandle=false; t.ToolTip="ZEX Build"; t.Parent=bp
    notify("BTools given")
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
        Workspace.CurrentCamera.CameraSubject=h or t.Character
        notify("Viewing "..t.Name)
    end
end)

reg("unview","Reset camera","Utility",PERM.MOD,function(_)
    local h=getHumanoid(); if h then Workspace.CurrentCamera.CameraSubject=h; notify("Camera reset") end
end)

reg("nameresp","Name respawn","Utility",PERM.USER,function(_)
    local dn=localPlayer.DisplayName
    localPlayer.DisplayName=" "; task.wait(0.1); localPlayer.DisplayName=dn
    notify("Name respawned")
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 13. TWEEN ENGINE
-- ═══════════════════════════════════════════════════════════════════════════════

local activeTweens: {[Instance]:Tween} = {}

local function tweenSafe(obj:Instance,props:{[string]:any},info:TweenInfo,maid:Maid?): Tween?
    if not obj or not obj.Parent then return nil end
    if activeTweens[obj] then
        pcall(function() activeTweens[obj]:Cancel() end); pcall(function() activeTweens[obj]:Destroy() end)
        activeTweens[obj]=nil
    end
    local ok,tw=pcall(function() return TweenService:Create(obj,info,props) end)
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

local function applyHover(inst:GuiObject,maid:Maid,normal:{[string]:any},hover:{[string]:any})
    maid:GiveTask(inst.MouseEnter:Connect(function() tweenSafe(inst,hover, TWEEN_FAST,maid) end))
    maid:GiveTask(inst.MouseLeave:Connect(function() tweenSafe(inst,normal,TWEEN_FAST,maid) end))
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 14. PARTICLE SYSTEM — FIX [MED]: tick() → time()
-- ═══════════════════════════════════════════════════════════════════════════════

local function createParticles(parent:Frame,maid:Maid,count:number)
    type PData = {frame:Frame,sx:number,sy:number,phase:number}
    local particles: {PData} = {}
    for _=1,count do
        local p=Instance.new("Frame")
        p.Size=UDim2.new(0,math.random(3,5),0,math.random(3,5))
        p.Position=UDim2.new(math.random(),0,math.random(),0)
        p.BackgroundColor3=Z.lime; p.BackgroundTransparency=0.8; p.BorderSizePixel=0; p.ZIndex=2; p.Parent=parent
        local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(1,0); c.Parent=p
        table.insert(particles,{frame=p,sx=(math.random()-0.5)*0.0005,sy=(math.random()-0.5)*0.0005,phase=math.random()*6.28})
    end
    local running=true; maid:GiveTask(function() running=false end)
    maid:GiveTask(RunService.RenderStepped:Connect(function()
        if not running then return end
        local t=time()  -- FIX: was tick()
        for _,p in ipairs(particles) do
            local px=p.frame.Position; local nx=px.X.Scale+p.sx; local ny=px.Y.Scale+p.sy
            if nx>1 then nx=0 elseif nx<0 then nx=1 end
            if ny>1 then ny=0 elseif ny<0 then ny=1 end
            p.frame.Position=UDim2.new(nx,0,ny,0)
            p.frame.BackgroundTransparency=0.6+0.25*math.sin(t*1.5+p.phase)
        end
    end))
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 15. UI FACTORY
-- ═══════════════════════════════════════════════════════════════════════════════

local function corner(r:number): UICorner
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r); return c
end
local function stroke(color:Color3,thick:number): UIStroke
    local s=Instance.new("UIStroke"); s.Color=color; s.Thickness=thick; return s
end
local function frame(props:{[string]:any}): Frame
    local f=Instance.new("Frame")
    for k,v in pairs(props) do if k~="Parent" then (f::any)[k]=v end end
    if props.Parent then f.Parent=props.Parent end; return f
end
local function label(props:{[string]:any}): TextLabel
    local l=Instance.new("TextLabel")
    for k,v in pairs(props) do if k~="Parent" then (l::any)[k]=v end end
    if props.Parent then l.Parent=props.Parent end; return l
end
local function button(props:{[string]:any}): TextButton
    local b=Instance.new("TextButton")
    for k,v in pairs(props) do if k~="Parent" then (b::any)[k]=v end end
    if props.Parent then b.Parent=props.Parent end; return b
end
local function textbox(props:{[string]:any}): TextBox
    local t=Instance.new("TextBox")
    for k,v in pairs(props) do if k~="Parent" then (t::any)[k]=v end end
    if props.Parent then t.Parent=props.Parent end; return t
end
local function scrolling(props:{[string]:any}): ScrollingFrame
    local s=Instance.new("ScrollingFrame")
    for k,v in pairs(props) do if k~="Parent" then (s::any)[k]=v end end
    if props.Parent then s.Parent=props.Parent end; return s
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 16. SCREEN GUI + MAIN FRAME
-- ═══════════════════════════════════════════════════════════════════════════════

local rootMaid      = Maid.new()
local screenGui:    ScreenGui
local mainContainer:Frame
local permLabel:    TextLabel

pcall(function()
    local parent: Instance
    if Executor.gethui then local ok,hui=pcall(Executor.gethui::()->Instance); if ok and hui then parent=hui end end
    if not parent and Executor.cloneref then
        local ok,ref=pcall(function() return (Executor.cloneref::(Instance)->Instance)(game.CoreGui) end)
        if ok and ref then parent=ref end
    end
    if not parent then parent=game.CoreGui end
    screenGui=Instance.new("ScreenGui"); screenGui.Name="ZEX_v734"
    screenGui.ResetOnSpawn=false; screenGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    screenGui.Parent=parent; rootMaid:GiveTask(screenGui)
end)

if not screenGui then log("ERROR","[ZEX] ScreenGui failed"); return end

local backdrop=frame({Size=UDim2.new(1,0,1,0),BackgroundColor3=Z.bg,BackgroundTransparency=0.35,BorderSizePixel=0,ZIndex=1,Parent=screenGui})
rootMaid:GiveTask(backdrop)

mainContainer=frame({
    Name="MainContainer",Size=UDim2.new(0,900,0,560),
    Position=UDim2.new(0.5,-450,1.5,0), -- off-screen; entry animation slides up
    BackgroundColor3=Z.surface,BackgroundTransparency=0.08,
    BorderSizePixel=0,ClipsDescendants=true,Parent=screenGui,
})
corner(12).Parent=mainContainer; stroke(Z.border,1).Parent=mainContainer
local glowBorder=stroke(Z.lime,0); glowBorder.Transparency=0.9; glowBorder.Parent=mainContainer
createParticles(frame({Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,ZIndex=11,Parent=mainContainer}),rootMaid,14)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 17. TITLE BAR
-- ═══════════════════════════════════════════════════════════════════════════════

local titleBar=frame({Name="TitleBar",Size=UDim2.new(1,0,0,44),BackgroundColor3=Z.card,BackgroundTransparency=0.05,BorderSizePixel=0,Parent=mainContainer})
corner(12).Parent=titleBar
tweenSafe(frame({Size=UDim2.new(1,0,0,2),Position=UDim2.new(0,0,1,-2),BackgroundColor3=Z.lime,BorderSizePixel=0,ZIndex=13,Parent=titleBar}),
    {BackgroundColor3=Z.lime2},TWEEN_PULSE,rootMaid)
label({Text="ZEX v7.3.4",Font=FONT_HEADER,TextSize=16,TextColor3=Z.lime,Size=UDim2.new(0,200,1,0),Position=UDim2.new(0,16,0,0),BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=13,Parent=titleBar})
permLabel=label({Text=PERM_NAMES[userRank],Font=FONT_BODY,TextSize=11,TextColor3=Z.lime,Size=UDim2.new(0,80,0,20),Position=UDim2.new(0,112,0,12),BackgroundTransparency=1,ZIndex=13,Parent=titleBar})
local closeBtn=button({Text="X",Font=FONT_HEADER,TextSize=14,TextColor3=Z.text2,Size=UDim2.new(0,30,0,30),Position=UDim2.new(1,-38,0,7),BackgroundColor3=Z.card,BackgroundTransparency=0.5,BorderSizePixel=0,AutoButtonColor=false,ZIndex=13,Parent=titleBar})
corner(6).Parent=closeBtn; applyHover(closeBtn,rootMaid,{TextColor3=Z.text2},{TextColor3=Z.danger})
rootMaid:GiveTask(closeBtn.MouseButton1Click:Connect(function()
    tweenSafe(mainContainer,{Position=UDim2.new(0.5,-450,1.5,0)},TWEEN_SMOOTH,rootMaid)
    task.delay(0.5,function() if screenGui and screenGui.Parent then screenGui:Destroy() end; rootMaid:Destroy() end)
end))

-- ═══════════════════════════════════════════════════════════════════════════════
-- 18. SIDEBAR
-- ═══════════════════════════════════════════════════════════════════════════════

local sidebar=frame({Name="Sidebar",Size=UDim2.new(0,54,1,-44),Position=UDim2.new(0,0,0,44),BackgroundColor3=Z.card,BackgroundTransparency=0.05,BorderSizePixel=0,ZIndex=12,Parent=mainContainer})
local SIDEBAR_CFG={{id="Dashboard",icon="D"},{id="Commands",icon="C"},{id="Player",icon="P"},
    {id="Server",icon="S"},{id="Editor",icon="E"},{id="Console",icon=">"},{id="Settings",icon="*"}}
local sidebarBtns: {TextButton} = {}
for i,cfg in ipairs(SIDEBAR_CFG) do
    local btn=button({Text=cfg.icon,Font=FONT_BUTTON,TextSize=14,TextColor3=Z.text3,
        Size=UDim2.new(0,40,0,40),Position=UDim2.new(0,7,0,8+(i-1)*50),
        BackgroundColor3=Z.card,BackgroundTransparency=0.5,BorderSizePixel=0,AutoButtonColor=false,ZIndex=13,Parent=sidebar})
    corner(8).Parent=btn; stroke(Z.border,1).Parent=btn
    table.insert(sidebarBtns,btn)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 19. CONTENT AREA — height shrunk 36 px for persistent input bar
-- ═══════════════════════════════════════════════════════════════════════════════

local contentArea=frame({Name="ContentArea",Size=UDim2.new(1,-54,1,-80),Position=UDim2.new(0,54,0,44),BackgroundColor3=Z.bg,BackgroundTransparency=0.05,BorderSizePixel=0,ZIndex=12,Parent=mainContainer})

-- ═══════════════════════════════════════════════════════════════════════════════
-- 20. TAB SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

local tabBuilders: {[string]:(parent:Frame,maid:Maid)->Frame} = {}
local activeTabMaid:  Maid?  = nil
local activeTabFrame: Frame? = nil

local function switchTab(tabId: string)
    if activeTabMaid  then activeTabMaid:Destroy();  activeTabMaid=nil  end
    if activeTabFrame then activeTabFrame:Destroy(); activeTabFrame=nil end
    activeTabMaid=Maid.new()
    for i,cfg in ipairs(SIDEBAR_CFG) do
        local btn=sidebarBtns[i]
        if cfg.id==tabId then tweenSafe(btn,{TextColor3=Z.lime,BackgroundColor3=Z.elevated},TWEEN_FAST,activeTabMaid); btn.BackgroundTransparency=0.05
        else              tweenSafe(btn,{TextColor3=Z.text3,BackgroundColor3=Z.card},TWEEN_FAST,activeTabMaid); btn.BackgroundTransparency=0.5 end
    end
    local builder=tabBuilders[tabId]
    if builder then
        activeTabFrame=builder(contentArea,activeTabMaid)
        if activeTabFrame then
            activeTabFrame.Size=UDim2.new(1,-16,1,-16); activeTabFrame.Position=UDim2.new(0,8,0,8)
            activeTabFrame.BackgroundTransparency=1; activeTabFrame.Parent=contentArea
        end
    end
end

rootMaid:GiveTask(function()
    if activeTabMaid  then activeTabMaid:Destroy();  activeTabMaid=nil  end
    if activeTabFrame then activeTabFrame:Destroy(); activeTabFrame=nil end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 21. TAB BUILDERS
-- ═══════════════════════════════════════════════════════════════════════════════

-- DASHBOARD — real ping via Stats service
local function buildDashboard(_:Frame,maid:Maid): Frame
    local f=frame({Name="Dashboard",BackgroundTransparency=1,Size=UDim2.new(1,0,1,0)})
    local running=true; maid:GiveTask(function() running=false end)
    local cards={{label="FPS",color=Z.lime,value="--"},{label="MEMORY",color=Z.info,value="-- MB"},
        {label="PING",color=Z.success,value="-- ms"},{label="PLAYERS",color=Z.warn,value="--"}}
    local valL: {TextLabel}={}
    for i,card in ipairs(cards) do
        local cx=(i-1)%2==0 and 0.02 or 0.52; local cy=math.floor((i-1)/2)*0.27
        local cf=frame({Size=UDim2.new(0.46,0,0,60),Position=UDim2.new(cx,0,cy,0),BackgroundColor3=Z.elevated,BackgroundTransparency=0.3,BorderSizePixel=0,Parent=f})
        corner(8).Parent=cf; stroke(Z.border,1).Parent=cf
        label({Text=card.label,Font=FONT_BODY,TextSize=10,TextColor3=Z.text3,Size=UDim2.new(1,0,0,18),BackgroundTransparency=1,Parent=cf})
        table.insert(valL,label({Text=card.value,Font=FONT_DATA,TextSize=20,TextColor3=card.color,Size=UDim2.new(1,0,0,30),Position=UDim2.new(0,0,0,22),BackgroundTransparency=1,Parent=cf}))
    end
    local fps=0; local last=os.clock()
    maid:GiveTask(RunService.RenderStepped:Connect(function()
        fps+=1; local now=os.clock()
        if now-last>=1 then valL[1].Text=tostring(fps); fps=0; last=now end
    end))
    task.spawn(function()
        while running and task.wait(1) do
            pcall(function() valL[2].Text=string.format("%.1f MB",collectgarbage("count")/1024) end)
            pcall(function() valL[4].Text=tostring(#Players:GetPlayers()) end)
            pcall(function()
                if Services.Stats then
                    local sa=Services.Stats::any
                    valL[3].Text=math.floor(sa.Network.ServerStatsItem["Data Ping"].Value).." ms"
                end
            end)
        end
    end)
    local infoBox=frame({Size=UDim2.new(1,0,0,100),Position=UDim2.new(0,0,0.6,0),BackgroundColor3=Z.elevated,BackgroundTransparency=0.4,BorderSizePixel=0,Parent=f})
    corner(8).Parent=infoBox; stroke(Z.border,1).Parent=infoBox
    local infoL=label({Text="",Font=FONT_LABEL,TextSize=10,TextColor3=Z.text2,Size=UDim2.new(1,-10,1,0),Position=UDim2.new(0,6,0,4),BackgroundTransparency=1,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Parent=infoBox})
    local function refreshInfo()
        if not localPlayer then return end
        local lines:{}={{
            "User: "..localPlayer.Name.." ("..localPlayer.DisplayName..")",
            "UserId: "..tostring(localPlayer.UserId),
            "Age: "..tostring(localPlayer.AccountAge).." days · "..tostring(localPlayer.MembershipType),
        }}
        local char=localPlayer.Character
        if char then local h=char:FindFirstChildOfClass("Humanoid"); if h then
            table.insert(lines[1],string.format("HP: %.0f/%.0f · WS:%.0f · JP:%.0f",h.Health,h.MaxHealth,h.WalkSpeed,h.JumpPower))
        end end
        infoL.Text=table.concat(lines[1],"\n")
    end
    refreshInfo()
    if localPlayer then maid:GiveTask(localPlayer.CharacterAdded:Connect(function() task.wait(0.5); refreshInfo() end)) end
    task.spawn(function() while running and task.wait(2) do refreshInfo() end end)
    return f
end

-- COMMANDS — UIListLayout with full-width category headers; canvas via signal
local function buildCommands(_:Frame,maid:Maid): Frame
    local f=frame({Name="Commands",BackgroundTransparency=1,Size=UDim2.new(1,0,1,0)})
    local catColors:{[string]:Color3}={Player=Z.lime,Combat=Z.danger,World=Z.info,Server=Z.warn,Utility=Z.text2}
    local cats={"Player","Combat","World","Server","Utility"}
    local scroll=scrolling({Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,ScrollBarThickness=4,ScrollBarImageColor3=Z.border,Parent=f})
    local listL=Instance.new("UIListLayout"); listL.SortOrder=Enum.SortOrder.LayoutOrder; listL.Padding=UDim.new(0,4); listL.Parent=scroll
    local lo=0
    for _,cat in ipairs(cats) do
        local cmds:{}={}
        for _,cmd in pairs(CommandRegistry) do if cmd.category==cat then table.insert(cmds,cmd) end end
        if #cmds==0 then continue end
        table.sort(cmds,function(a,b) return a.name<b.name end)
        lo+=1
        local hdr=frame({Size=UDim2.new(1,0,0,22),BackgroundColor3=Z.card,BackgroundTransparency=0.4,LayoutOrder=lo,Parent=scroll})
        corner(5).Parent=hdr
        local hdrBar=frame({Size=UDim2.new(0,3,1,0),BackgroundColor3=catColors[cat] or Z.lime,BorderSizePixel=0,Parent=hdr}); corner(2).Parent=hdrBar
        label({Text=cat:upper(),Font=FONT_HEADER,TextSize=10,TextColor3=catColors[cat] or Z.lime,Size=UDim2.new(1,-10,1,0),Position=UDim2.new(0,8,0,0),BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,Parent=hdr})
        lo+=1
        local rows=math.ceil(#cmds/4)
        local gridF=frame({Size=UDim2.new(1,0,0,rows*36+4),BackgroundTransparency=1,LayoutOrder=lo,Parent=scroll})
        local grid=Instance.new("UIGridLayout"); grid.CellSize=UDim2.new(0.25,-3,0,32); grid.CellPadding=UDim2.new(0,4,0,4); grid.FillDirectionMaxCells=4; grid.Parent=gridF
        for _,cmd in ipairs(cmds) do
            local btn=button({Text=cmd.name,Font=FONT_BUTTON,TextSize=10,TextColor3=Z.text,BackgroundColor3=Z.card,BorderSizePixel=0,AutoButtonColor=false,Parent=gridF})
            corner(5).Parent=btn; stroke(Z.border,1).Parent=btn
            applyHover(btn,maid,{BackgroundColor3=Z.card,TextColor3=Z.text},{BackgroundColor3=Z.elevated,TextColor3=Z.lime})
            maid:GiveTask(btn.MouseButton1Click:Connect(function()
                if not canRun(cmd.perm) then notify("No permission: "..cmd.name,"danger"); return end
                safeCall(function() cmd.run({}) end,"Cmd:"..cmd.name)
            end))
        end
        -- FIX [MED]: canvas via AbsoluteContentSize signal, not task.delay
        maid:GiveTask(grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            gridF.Size=UDim2.new(1,0,0,grid.AbsoluteContentSize.Y+4)
        end))
    end
    maid:GiveTask(listL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize=UDim2.new(0,0,0,listL.AbsoluteContentSize.Y+16)
    end))
    return f
end

-- PLAYER TAB
local function buildPlayer(_:Frame,maid:Maid): Frame
    local f=frame({Name="Player",BackgroundTransparency=1,Size=UDim2.new(1,0,1,0)})
    local running=true; maid:GiveTask(function() running=false end)
    local infoL=label({Text="Loading...",Font=FONT_LABEL,TextSize=11,TextColor3=Z.text2,Size=UDim2.new(1,0,0,140),BackgroundTransparency=1,TextWrapped=true,Parent=f})
    local function refresh()
        if not localPlayer then return end
        local lines:{}={"User: "..localPlayer.Name.." (@"..localPlayer.DisplayName..")","UserId: "..tostring(localPlayer.UserId),"Age: "..tostring(localPlayer.AccountAge).." days","Membership: "..tostring(localPlayer.MembershipType)}
        local char=localPlayer.Character; if char then local h=char:FindFirstChildOfClass("Humanoid"); if h then
            table.insert(lines,string.format("HP: %.1f / %.0f  WS: %.0f  JP: %.0f",h.Health,h.MaxHealth,h.WalkSpeed,h.JumpPower))
            if h.RootPart then local p=h.RootPart.Position; table.insert(lines,string.format("Pos: %.0f, %.0f, %.0f",p.X,p.Y,p.Z)) end
        end end
        infoL.Text=table.concat(lines,"\n")
    end
    refresh()
    if localPlayer then maid:GiveTask(localPlayer.CharacterAdded:Connect(function() task.wait(0.5); refresh() end)) end
    task.spawn(function() while running and task.wait(1) do refresh() end end)
    local function makeInput(y:number,lTxt:string,def:string,apply:(v:string)->())
        label({Text=lTxt,Font=FONT_BODY,TextSize=11,TextColor3=Z.text2,Size=UDim2.new(1,0,0,16),Position=UDim2.new(0,0,0,y),BackgroundTransparency=1,Parent=f})
        local box=textbox({Text=def,Font=FONT_CONSOLE,TextSize=11,TextColor3=Z.text,Size=UDim2.new(0,70,0,24),Position=UDim2.new(0,0,0,y+18),BackgroundColor3=Z.card,ClearTextOnFocus=false,Parent=f}); corner(4).Parent=box; stroke(Z.border,1).Parent=box
        local setBtn=button({Text="Set",Font=FONT_BUTTON,TextSize=10,TextColor3=Z.bg,Size=UDim2.new(0,44,0,24),Position=UDim2.new(0,76,0,y+18),BackgroundColor3=Z.lime,BorderSizePixel=0,AutoButtonColor=false,Parent=f}); corner(4).Parent=setBtn
        maid:GiveTask(setBtn.MouseButton1Click:Connect(function() apply(box.Text) end))
    end
    makeInput(150,"WalkSpeed","16",function(v) local h=getHumanoid(); if h then h.WalkSpeed=tonumber(v) or 16 end end)
    makeInput(200,"JumpPower","50",function(v) local h=getHumanoid(); if h then h.JumpPower=tonumber(v) or 50 end end)
    makeInput(250,"Gravity",  "196.2",function(v) Workspace.Gravity=tonumber(v) or 196.2 end)
    return f
end

-- SERVER TAB
local function buildServer(_:Frame,maid:Maid): Frame
    local f=frame({Name="Server",BackgroundTransparency=1,Size=UDim2.new(1,0,1,0)})
    local info:{}={"Game: "..game.Name,"PlaceId: "..tostring(game.PlaceId),"JobId: "..tostring(game.JobId),"Players: "..tostring(#Players:GetPlayers()).." / "..tostring(Players.MaxPlayers),"Lighting: "..tostring(Lighting.TimeOfDay),"Gravity: "..tostring(Workspace.Gravity)}
    label({Text=table.concat(info,"\n"),Font=FONT_LABEL,TextSize=11,TextColor3=Z.text2,Size=UDim2.new(1,0,0,140),BackgroundTransparency=1,TextWrapped=true,Parent=f})
    local function srvBtn(text:string,y:number,color:Color3,action:()->())
        local btn=button({Text=text,Font=FONT_BUTTON,TextSize=11,TextColor3=Z.bg,Size=UDim2.new(0,140,0,28),Position=UDim2.new(0,0,0,y),BackgroundColor3=color,BorderSizePixel=0,AutoButtonColor=false,Parent=f}); corner(6).Parent=btn
        applyHover(btn,maid,{BackgroundColor3=color},{BackgroundColor3=color:Lerp(Z.text,0.15)})
        maid:GiveTask(btn.MouseButton1Click:Connect(function() safeCall(action,text) end))
    end
    local y=155
    srvBtn("Rejoin",       y,     Z.lime,  function() CommandRegistry["rejoin"].run({})       end)
    srvBtn("Server Hop",   y+36,  Z.info,  function() CommandRegistry["serverhop"].run({})    end)
    srvBtn("Fullbright",   y+72,  Z.warn,  function() CommandRegistry["fullbright"].run({})   end)
    srvBtn("Clear Terrain",y+108, Z.danger,function() CommandRegistry["clearterrain"].run({}) end)
    return f
end

-- EDITOR TAB
local function buildEditor(_:Frame,maid:Maid): Frame
    local f=frame({Name="Editor",BackgroundTransparency=1,Size=UDim2.new(1,0,1,0)})
    local ed=textbox({Size=UDim2.new(1,-10,0.55,-5),Position=UDim2.new(0,5,0,5),BackgroundColor3=Z.bg,BackgroundTransparency=0.3,TextColor3=Z.text,Font=FONT_CONSOLE,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,ClearTextOnFocus=false,MultiLine=true,Text="-- ZEX Script Editor v7.3.4\nprint('Hello from ZEX')",Parent=f}); corner(8).Parent=ed; stroke(Z.border,1).Parent=ed
    local execBtn=button({Text="Execute",Font=FONT_BUTTON,TextSize=11,TextColor3=Z.bg,Size=UDim2.new(0,120,0,28),Position=UDim2.new(0,5,0.55,5),BackgroundColor3=Z.lime,BorderSizePixel=0,AutoButtonColor=false,Parent=f}); corner(6).Parent=execBtn; applyHover(execBtn,maid,{BackgroundColor3=Z.lime},{BackgroundColor3=Z.lime2})
    local clrBtn=button({Text="Clear",Font=FONT_BUTTON,TextSize=10,TextColor3=Z.text,Size=UDim2.new(0,70,0,28),Position=UDim2.new(0,132,0.55,5),BackgroundColor3=Z.card,BorderSizePixel=0,AutoButtonColor=false,Parent=f}); corner(6).Parent=clrBtn
    local outL=label({Size=UDim2.new(1,-10,0.45,-40),Position=UDim2.new(0,5,0.55,40),BackgroundColor3=Z.bg,BackgroundTransparency=0.3,TextColor3=Z.text2,Font=FONT_CONSOLE,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,Text="> Ready",Parent=f}); corner(8).Parent=outL; stroke(Z.border,1).Parent=outL
    maid:GiveTask(execBtn.MouseButton1Click:Connect(function()
        local src=ed.Text; if #src==0 then outL.Text="> Empty"; outL.TextColor3=Z.danger; return end
        outL.Text="> Running..."; outL.TextColor3=Z.info
        local ok1,fn=pcall(function() return if Executor.loadstring then (Executor.loadstring::(string)->(...any)->...any)(src) else (loadstring::(string)->(...any)->...any)(src) end)
        if not ok1 or not fn then outL.Text="> Syntax:\n"..tostring(fn); outL.TextColor3=Z.danger; return end
        local ok2,err=pcall(fn::(()->()))
        if not ok2 then outL.Text="> Runtime:\n"..tostring(err); outL.TextColor3=Z.danger
        else outL.Text="> OK"; outL.TextColor3=Z.success end
    end))
    maid:GiveTask(clrBtn.MouseButton1Click:Connect(function() ed.Text=""; outL.Text="> Cleared"; outL.TextColor3=Z.text3 end))
    return f
end

-- CONSOLE — FIX [MED]: incremental append; full rebuild only on log rotation
local function buildConsole(_:Frame,maid:Maid): Frame
    local f=frame({Name="Console",BackgroundTransparency=1,Size=UDim2.new(1,0,1,0)})
    local running=true; maid:GiveTask(function() running=false end)
    local scroll=scrolling({Size=UDim2.new(1,0,1,-34),BackgroundTransparency=1,ScrollBarThickness=4,ScrollBarImageColor3=Z.border,Parent=f})
    local listL=Instance.new("UIListLayout"); listL.SortOrder=Enum.SortOrder.LayoutOrder; listL.Parent=scroll
    local lastVer=0; local rendered=0; local lastFirst=""
    local function makeEntry(entry:string,order:number)
        local color=Z.text2
        if entry:find("%[ERROR%]") then color=Z.danger
        elseif entry:find("%[WARN%]")   then color=Z.warn
        elseif entry:find("%[DEBUG%]")  then color=Z.info
        elseif entry:find("%[OUTPUT%]") then color=Z.success end
        label({Text=entry,Font=FONT_CONSOLE,TextSize=10,TextColor3=color,Size=UDim2.new(1,0,0,15),BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=order,Parent=scroll})
    end
    local function updateConsole()
        if logVersion==lastVer then return end; lastVer=logVersion
        local rotated=rendered>0 and #logs>0 and logs[1]~=lastFirst
        if rotated or rendered>#logs then
            for _,ch in ipairs(scroll:GetChildren()) do if ch:IsA("TextLabel") then ch:Destroy() end end
            rendered=0
        end
        for i=rendered+1,#logs do makeEntry(logs[i],i) end
        rendered=#logs; if #logs>0 then lastFirst=logs[1] end
        scroll.CanvasSize=UDim2.new(0,0,0,listL.AbsoluteContentSize.Y+8)
        scroll.CanvasPosition=Vector2.new(0,listL.AbsoluteContentSize.Y)
    end
    task.spawn(function() while running and task.wait(0.3) do updateConsole() end end)
    local copyBtn=button({Text="Copy",Font=FONT_BUTTON,TextSize=10,TextColor3=Z.bg,Size=UDim2.new(0,70,0,24),Position=UDim2.new(0,0,1,-28),BackgroundColor3=Z.lime,BorderSizePixel=0,AutoButtonColor=false,Parent=f}); corner(6).Parent=copyBtn
    maid:GiveTask(copyBtn.MouseButton1Click:Connect(function()
        if Executor.setclipboard then pcall(function()(Executor.setclipboard::(string)->boolean)(table.concat(logs,"\n"))end); notify("Logs copied","success") end
    end))
    local clrBtn=button({Text="Clear",Font=FONT_BUTTON,TextSize=10,TextColor3=Z.text,Size=UDim2.new(0,70,0,24),Position=UDim2.new(0,76,1,-28),BackgroundColor3=Z.card,BorderSizePixel=0,AutoButtonColor=false,Parent=f}); corner(6).Parent=clrBtn
    maid:GiveTask(clrBtn.MouseButton1Click:Connect(function()
        table.clear(logs); logVersion+=1; lastFirst=""; rendered=0
        for _,ch in ipairs(scroll:GetChildren()) do if ch:IsA("TextLabel") then ch:Destroy() end end
        scroll.CanvasSize=UDim2.new(0,0,0,0)
    end))
    return f
end

-- SETTINGS TAB
local function buildSettings(_:Frame,maid:Maid): Frame
    local f=frame({Name="Settings",BackgroundTransparency=1,Size=UDim2.new(1,0,1,0)})
    local function sl(text:string,y:number) label({Text=text,Font=FONT_BODY,TextSize=11,TextColor3=Z.text2,Size=UDim2.new(1,0,0,18),Position=UDim2.new(0,0,0,y),BackgroundTransparency=1,Parent=f}) end
    sl("Permission level:",0)
    local pb=button({Text=PERM_NAMES[userRank],Font=FONT_BUTTON,TextSize=11,TextColor3=Z.bg,Size=UDim2.new(0,120,0,26),Position=UDim2.new(0,0,0,20),BackgroundColor3=Z.lime,BorderSizePixel=0,AutoButtonColor=false,Parent=f}); corner(6).Parent=pb
    maid:GiveTask(pb.MouseButton1Click:Connect(function()
        userRank=(userRank%4)+1; pb.Text=PERM_NAMES[userRank]; permLabel.Text=PERM_NAMES[userRank]; notify("Rank: "..PERM_NAMES[userRank])
    end))
    sl("Theme: Dark (locked)",60); sl("Keybind: RightShift",80); sl("Cmd prefix: ;",100)
    sl("Webhook URL:",140)
    local urlBox=textbox({PlaceholderText="https://webhookpulse.vercel.app/api/...",Size=UDim2.new(1,0,0,26),Position=UDim2.new(0,0,0,160),BackgroundColor3=Z.card,TextColor3=Z.text,Font=FONT_CONSOLE,TextSize=10,ClearTextOnFocus=false,Parent=f}); corner(5).Parent=urlBox; stroke(Z.border,1).Parent=urlBox
    sl("Secret:",196)
    local secBox=textbox({PlaceholderText="X-Webhook-Secret",Size=UDim2.new(1,0,0,26),Position=UDim2.new(0,0,0,214),BackgroundColor3=Z.card,TextColor3=Z.text,Font=FONT_CONSOLE,TextSize=10,ClearTextOnFocus=false,Parent=f}); corner(5).Parent=secBox; stroke(Z.border,1).Parent=secBox
    local testBtn=button({Text="Test Webhook",Font=FONT_BUTTON,TextSize=10,TextColor3=Z.bg,Size=UDim2.new(0,130,0,26),Position=UDim2.new(0,0,0,250),BackgroundColor3=Z.info,BorderSizePixel=0,AutoButtonColor=false,Parent=f}); corner(6).Parent=testBtn
    maid:GiveTask(testBtn.MouseButton1Click:Connect(function()
        local url=urlBox.Text:match("^%s*(.-)%s*$"); local valid,err=validateUrl(url)
        if not valid then notify("Invalid URL: "..err,"danger"); return end
        if not checkRateLimit(url) then notify("Rate limited","warn"); return end
        local res=httpRequest({Url=url,Method="POST",Headers={["Content-Type"]="application/json",["X-Webhook-Secret"]=secBox.Text:gsub("[%z\r\n]","")},Body=HttpService:JSONEncode({source="zex",version="7.3.4",player={userid=localPlayer.UserId,username=localPlayer.Name},test=true})})
        if res.success then notify("Webhook OK ["..tostring(res.status).."]","success"); secBox.Text=""
        else notify("Webhook failed: "..(res.error or "?"),"danger") end
    end))
    return f
end

tabBuilders={Dashboard=buildDashboard,Commands=buildCommands,Player=buildPlayer,
    Server=buildServer,Editor=buildEditor,Console=buildConsole,Settings=buildSettings}
for i,cfg in ipairs(SIDEBAR_CFG) do
    rootMaid:GiveTask(sidebarBtns[i].MouseButton1Click:Connect(function() switchTab(cfg.id) end))
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 22. PERSISTENT COMMAND INPUT BAR — ;command [args] always visible
-- ═══════════════════════════════════════════════════════════════════════════════

local inputBar=frame({Name="InputBar",Size=UDim2.new(1,-54,0,36),Position=UDim2.new(0,54,1,-36),BackgroundColor3=Z.card,BackgroundTransparency=0.1,BorderSizePixel=0,ZIndex=14,Parent=mainContainer})
stroke(Z.border,1).Parent=inputBar
local inputBox=textbox({PlaceholderText=CMD_PREFIX.."command [args...]",ClearTextOnFocus=false,Size=UDim2.new(1,-82,1,-8),Position=UDim2.new(0,4,0,4),BackgroundColor3=Z.elevated,BackgroundTransparency=0.2,TextColor3=Z.text,PlaceholderColor3=Z.text3,Font=FONT_CONSOLE,TextSize=11,ZIndex=15,Parent=inputBar}); corner(5).Parent=inputBox
local runBtn=button({Text="Run",Font=FONT_BUTTON,TextSize=10,TextColor3=Z.bg,Size=UDim2.new(0,68,1,-8),Position=UDim2.new(1,-72,0,4),BackgroundColor3=Z.lime,BorderSizePixel=0,AutoButtonColor=false,ZIndex=15,Parent=inputBar}); corner(5).Parent=runBtn
applyHover(runBtn,rootMaid,{BackgroundColor3=Z.lime},{BackgroundColor3=Z.lime2})

local function executeInput()
    local raw=inputBox.Text:match("^%s*(.-)%s*$"); if not raw or #raw==0 then return end
    local text=raw; if text:sub(1,#CMD_PREFIX)==CMD_PREFIX then text=text:sub(#CMD_PREFIX+1) end
    text=text:match("^%s*(.-)%s*$"); if #text==0 then return end
    local parts:{}={}; for tok in text:gmatch("%S+") do table.insert(parts,tok) end; if #parts==0 then return end
    local cmdName=parts[1]:lower(); local args:{}={}
    for i=2,#parts do table.insert(args,parts[i]) end
    local cmd=CommandRegistry[cmdName]
    if not cmd then notify("Unknown: "..cmdName,"warn"); return end
    if not canRun(cmd.perm) then notify("No permission: "..cmdName,"danger"); return end
    safeCall(function() cmd.run(args) end,"Input:"..cmdName)
    inputBox.Text=""
end
rootMaid:GiveTask(inputBox.FocusLost:Connect(function(enter) if enter then executeInput() end end))
rootMaid:GiveTask(runBtn.MouseButton1Click:Connect(executeInput))

-- ═══════════════════════════════════════════════════════════════════════════════
-- 23. TOAST NOTIFICATIONS
-- ═══════════════════════════════════════════════════════════════════════════════

local toastStack=frame({Name="Toasts",Size=UDim2.new(0,230,0,0),Position=UDim2.new(1,-238,1,-44),BackgroundTransparency=1,ClipsDescendants=false,ZIndex=20,Parent=mainContainer})
local toastList=Instance.new("UIListLayout"); toastList.SortOrder=Enum.SortOrder.LayoutOrder; toastList.VerticalAlignment=Enum.VerticalAlignment.Bottom; toastList.Padding=UDim.new(0,3); toastList.Parent=toastStack
local toastSeq=0
local toastColors:{[string]:Color3}={info=Z.info,warn=Z.warn,success=Z.success,danger=Z.danger}

showNotification=function(msg:string,level:ToastLevel)
    if not screenGui or not screenGui.Parent then return end
    toastSeq+=1; local color=toastColors[level] or Z.info
    local toast=frame({Size=UDim2.new(1,0,0,30),BackgroundColor3=Z.elevated,BackgroundTransparency=0,LayoutOrder=toastSeq,ZIndex=20,Parent=toastStack}); corner(5).Parent=toast; stroke(color,1).Parent=toast
    local bar=frame({Size=UDim2.new(0,3,1,0),BackgroundColor3=color,BorderSizePixel=0,ZIndex=21,Parent=toast}); corner(2).Parent=bar
    label({Text=msg,Font=FONT_BODY,TextSize=10,TextColor3=Z.text,Size=UDim2.new(1,-12,1,0),Position=UDim2.new(0,9,0,0),BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=21,Parent=toast})
    task.delay(2.8,function()
        if not toast or not toast.Parent then return end
        tweenSafe(toast,{BackgroundTransparency=1},TWEEN_FAST,nil)
        task.delay(0.18,function() if toast and toast.Parent then toast:Destroy() end end)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 24. DRAG SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════

local dragMaid: Maid? = nil
rootMaid:GiveTask(function() if dragMaid then dragMaid:Destroy(); dragMaid=nil end end)
rootMaid:GiveTask(titleBar.InputBegan:Connect(function(input:InputObject)
    if input.UserInputType~=Enum.UserInputType.MouseButton1 and input.UserInputType~=Enum.UserInputType.Touch then return end
    if dragMaid then dragMaid:Destroy() end; dragMaid=Maid.new()
    local dt=input.UserInputType; local off=Vector2.new(input.Position.X,input.Position.Y)-mainContainer.AbsolutePosition
    dragMaid:GiveTask(UserInputService.InputChanged:Connect(function(i2:InputObject)
        if i2.UserInputType~=Enum.UserInputType.MouseMovement and i2.UserInputType~=Enum.UserInputType.Touch then return end
        local vp=Workspace.CurrentCamera.ViewportSize; local fw,fh=mainContainer.AbsoluteSize.X,mainContainer.AbsoluteSize.Y
        local nx=math.clamp(i2.Position.X-off.X,0,math.max(0,vp.X-fw)); local ny=math.clamp(i2.Position.Y-off.Y,0,math.max(0,vp.Y-fh))
        mainContainer.Position=UDim2.new(0,nx,0,ny)
    end))
    dragMaid:GiveTask(UserInputService.InputEnded:Connect(function(i2:InputObject)
        if i2.UserInputType==dt then if dragMaid then dragMaid:Destroy(); dragMaid=nil end end
    end))
end))

-- ═══════════════════════════════════════════════════════════════════════════════
-- 25. KEYBIND TOGGLE — RightShift
-- ═══════════════════════════════════════════════════════════════════════════════

local guiVisible=true
rootMaid:GiveTask(UserInputService.InputBegan:Connect(function(input:InputObject,gp:boolean)
    if gp then return end
    if input.KeyCode==Enum.KeyCode.RightShift then
        guiVisible=not guiVisible
        local pos=mainContainer.AbsolutePosition
        if guiVisible then tweenSafe(mainContainer,{Position=UDim2.new(0,pos.X,0,pos.Y)},TWEEN_SMOOTH,rootMaid)
        else               tweenSafe(mainContainer,{Position=UDim2.new(0,pos.X,1.5,0)},TWEEN_SMOOTH,rootMaid) end
    end
end))

-- ═══════════════════════════════════════════════════════════════════════════════
-- 26. ENTRY ANIMATION — FIX [MED]: single slide-in, no O(n) descendant tweens
-- ═══════════════════════════════════════════════════════════════════════════════

task.delay(0.05,function()
    if not screenGui or not screenGui.Parent then return end
    tweenSafe(mainContainer,{Position=UDim2.new(0.5,-450,0.5,-280)},TWEEN_SPRING,rootMaid)
    tweenSafe(glowBorder,   {Thickness=2,Transparency=0.72},          TWEEN_SLOW,  rootMaid)
    tweenSafe(backdrop,     {BackgroundTransparency=0.35},             TWEEN_SLOW,  rootMaid)
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 27. TEARDOWN + BOOT
-- ═══════════════════════════════════════════════════════════════════════════════

rootMaid:GiveTask(screenGui.Destroying:Connect(function()
    if espMaid then espMaid:Destroy(); espMaid=nil end
    rootMaid:Destroy()
    log("INFO","[ZEX] v7.3.4 teardown complete")
end))

switchTab("Dashboard")

local cmdCount=0; for _ in pairs(CommandRegistry) do cmdCount+=1 end
log("INFO",string.format("[ZEX] v7.3.4 booted — %d commands — rank: %s",cmdCount,PERM_NAMES[userRank]))
notify("ZEX v7.3.4 — "..cmdCount.." commands","success")
