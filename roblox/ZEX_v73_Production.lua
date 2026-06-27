--[[
  ZEX v7.3 PRODUCTION
  Architecture: Modular · Memory-Safe · Consent-Gated · Strict-Typed
  Palette: WebhookPulse Dark · Font: Gotham
  Keybind: RightShift toggle · Tabs: 7 panels
  Lifecycle: Maid · TweenPool · ConnectionRegistry
  Author: Principal Luau Engineer — AAA Client Engineering
]]

--!strict

-- ═══════════════════════════════════════════════════════════════════════════════
-- 0. EXECUTOR GLOBAL DECLARATIONS (strict mode compliance)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Executor globals (getgenv, syn, request, etc.) are detected dynamically via
-- pcall() in section 2. Do NOT use "declare" here — it is a Luau type-checker
-- keyword, NOT valid Lua runtime syntax. Executors will error with:
-- "Incomplete statement: expected assignment or a function call"

-- ── SERVICES TYPE ────────────────────────────────────────────────────────
type ServicesTable = {
    Players: Players?,
    RunService: RunService?,
    TweenService: TweenService?,
    UserInputService: UserInputService?,
    HttpService: HttpService?,
    TeleportService: TeleportService?,
    Lighting: Lighting?,
    Workspace: Workspace?,
    ReplicatedStorage: ReplicatedStorage?,
    TextService: TextService?,
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
end)

assert(Services.Players, "Players service required")
assert(Services.RunService, "RunService required")
assert(Services.TweenService, "TweenService required")
assert(Services.UserInputService, "UserInputService required")
assert(Services.HttpService, "HttpService required")
assert(Services.TeleportService, "TeleportService required")
assert(Services.Lighting, "Lighting required")
assert(Services.Workspace, "Workspace required")
assert(Services.ReplicatedStorage, "ReplicatedStorage required")
assert(Services.TextService, "TextService required")

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. EXECUTOR FEATURE DETECTION (pcall-gated, every API)
-- ═══════════════════════════════════════════════════════════════════════════════

export type ExecutorApi = {
    getgenv: (() -> { [string]: any })?,
    gethui: (() -> Instance)?,
    request: ((options: { [string]: any }) -> { [string]: any })?,
    setclipboard: ((text: string) -> boolean)?,
    sethiddenproperty: ((instance: Instance, prop: string, value: any) -> boolean)?,
    cloneref: ((instance: Instance) -> Instance)?,
}

local Executor: ExecutorApi = {
    getgenv = nil,
    gethui = nil,
    request = nil,
    setclipboard = nil,
    sethiddenproperty = nil,
    cloneref = nil,
}

pcall(function()
    local g = _G["getgenv"]
    if type(g) == "function" then Executor.getgenv = g :: any end
end)
pcall(function()
    local g = _G["gethui"]
    if type(g) == "function" then Executor.gethui = g :: any end
end)
pcall(function()
    local syn = _G["syn"]
    local req = _G["request"]
    local httpReq = _G["http_request"]
    local fluxus = _G["fluxus"]
    if type(syn) == "table" and type(syn.request) == "function" then
        Executor.request = syn.request
    elseif type(req) == "function" then
        Executor.request = req
    elseif type(httpReq) == "function" then
        Executor.request = httpReq
    elseif type(fluxus) == "table" and type(fluxus.request) == "function" then
        Executor.request = fluxus.request
    end
end)
pcall(function()
    local g = _G["setclipboard"]
    if type(g) == "function" then Executor.setclipboard = g :: any end
end)
pcall(function()
    local g = _G["sethiddenproperty"]
    if type(g) == "function" then Executor.sethiddenproperty = g :: any end
end)
pcall(function()
    local g = _G["cloneref"]
    if type(g) == "function" then Executor.cloneref = g :: any end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. TYPE ALIASES
-- ═══════════════════════════════════════════════════════════════════════════════

export type Palette = {
    bg: Color3, surface: Color3, elevated: Color3, card: Color3,
    border: Color3, borderHi: Color3, text: Color3, text2: Color3,
    text3: Color3, lime: Color3, lime2: Color3, limeGlow: Color3,
    danger: Color3, success: Color3, info: Color3, warn: Color3, clear: Color3,
}
export type ConsentMode = "MINIMAL" | "IDENTITY" | "CHARACTER" | "FULL"
export type PayloadField = {
    key: string,
    collect: () -> any,
    tier: ConsentMode,
    category: string,
}
export type MaidTask = RBXScriptConnection | Instance | Tween | thread | (() -> ())
export type Maid = {
    _tasks: { MaidTask },
    GiveTask: (self: Maid, task: MaidTask) -> (),
    Destroy: (self: Maid) -> (),
}
export type TabConfig = {
    name: string,
    icon: string,
    build: (parent: Frame, maid: Maid) -> Frame,
}
export type HttpResponse = {
    success: boolean,
    status: number?,
    body: string?,
    error: string?,
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. MAID / LIFECYCLE (canonical)
-- ═══════════════════════════════════════════════════════════════════════════════

local Maid = {}
Maid.__index = Maid

function Maid.new(): Maid
    local self = setmetatable({ _tasks = {} :: { MaidTask } }, Maid)
    return self
end

function Maid:GiveTask(task: MaidTask)
    table.insert(self._tasks, task)
end

function Maid:Destroy()
    for _, t in self._tasks do
        if typeof(t) == "RBXScriptConnection" then
            pcall(function() (t :: RBXScriptConnection):Disconnect() end)
        elseif typeof(t) == "Instance" then
            pcall(function() (t :: Instance):Destroy() end)
        elseif typeof(t) == "Tween" then
            pcall(function() (t :: Tween):Cancel() end)
            pcall(function() (t :: Tween):Destroy() end)
        elseif typeof(t) == "thread" then
            pcall(function() task.cancel(t :: thread) end)
        elseif type(t) == "function" then
            pcall(t)
        end
    end
    table.clear(self._tasks)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. CONSTANTS & PALETTE (immutable)
-- ═══════════════════════════════════════════════════════════════════════════════

local Z: Palette = {
    bg        = Color3.fromRGB(10, 10, 12),
    surface   = Color3.fromRGB(18, 18, 20),
    elevated  = Color3.fromRGB(26, 26, 28),
    card      = Color3.fromRGB(22, 22, 24),
    border    = Color3.fromRGB(38, 38, 42),
    borderHi  = Color3.fromRGB(60, 60, 65),
    text      = Color3.fromRGB(252, 252, 252),
    text2     = Color3.fromRGB(160, 160, 170),
    text3     = Color3.fromRGB(100, 100, 110),
    lime      = Color3.fromRGB(212, 232, 58),
    lime2     = Color3.fromRGB(235, 252, 110),
    limeGlow  = Color3.fromRGB(180, 200, 40),
    danger    = Color3.fromRGB(239, 68, 68),
    success   = Color3.fromRGB(34, 197, 94),
    info      = Color3.fromRGB(59, 130, 246),
    warn      = Color3.fromRGB(245, 158, 11),
    clear     = Color3.fromRGB(0, 0, 0),
}

local TWEEN_INSTANT = TweenInfo.new(0)
local TWEEN_FAST = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_SMOOTH = TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
local TWEEN_SLOW = TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local FONT_HEADER = Enum.Font.GothamBold
local FONT_BODY = Enum.Font.GothamMedium
local FONT_LABEL = Enum.Font.Gotham
local FONT_DATA = Enum.Font.GothamMedium
local FONT_BUTTON = Enum.Font.GothamBold
local FONT_CONSOLE = Enum.Font.Code

local LOG_MAX = 200

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. SAFE EXECUTION ENGINE
-- ═══════════════════════════════════════════════════════════════════════════════

local logs: { string } = {}

local logVersion = 0

local function log(level: "INFO" | "WARN" | "ERROR" | "DEBUG", message: string)
    local timestamp = os.date("%H:%M:%S")
    local entry = string.format("[%s] [%s] %s", timestamp, level, message)
    table.insert(logs, entry)
    if #logs > LOG_MAX then
        table.remove(logs, 1)
    end
    logVersion += 1
end

local function safeCall<T>(fn: () -> T, context: string): (boolean, T?)
    return xpcall(fn, function(err)
        log("ERROR", context .. ": " .. tostring(err) .. "\n" .. debug.traceback())
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 7. HTTP ENGINE (https-only, whitelisted, token-bucket rate-limited)
-- ═══════════════════════════════════════════════════════════════════════════════

local WHITELIST: { string } = {
    "webhookpulse.vercel.app",
    "discord.com",
    "discordapp.com",
    "hooks.slack.com",
}

local rateBuckets: { [string]: { tokens: number, last: number } } = {}
local RATE_MAX = 5
local RATE_WINDOW = 10

local function checkRateLimit(endpoint: string): boolean
    local now = os.clock()
    -- Use hostname as bucket key, not full URL (prevents query-string splitting)
    local host = endpoint:match("^https://([^/]+)")
    if not host then return false end
    host = host:gsub(":%d+$", "")
    local bucket = rateBuckets[host]
    if not bucket then
        rateBuckets[host] = { tokens = RATE_MAX - 1, last = now }
        return true
    end
    local elapsed = math.max(0, now - bucket.last)
    bucket.tokens = math.min(RATE_MAX, bucket.tokens + elapsed * (RATE_MAX / RATE_WINDOW))
    bucket.last = now
    if bucket.tokens >= 1 then
        bucket.tokens -= 1
        return true
    end
    return false
end

local function escapePattern(s: string): string
    return s:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
end

local function validateUrl(url: string): (boolean, string)
    if type(url) ~= "string" then return false, "URL must be a string" end
    if not url:match("^https://") then return false, "HTTPS required" end
    if url:match("^https://%d+%.%d+%.%d+%.%d+") then return false, "IP addresses not allowed" end
    if url:lower():match("^https://localhost") then return false, "localhost not allowed" end
    if url:match("^https://0x") or url:match("^https://0%d%d%d") then return false, "IP addresses not allowed" end
    local host = url:match("^https://([^/]+)")
    if not host then return false, "Invalid URL format" end
    host = host:gsub(":%d+$", "")
    for _, domain in ipairs(WHITELIST) do
        if host == domain or host:match("%" .. escapePattern(domain) .. "$") then
            return true, ""
        end
    end
    return false, "Domain not in whitelist"
end

local function httpRequest(options: { [string]: any }): HttpResponse
    local result: HttpResponse = { success = false, status = nil, body = nil, error = nil }
    local timeout = options.Timeout or 15000
    local completed = false
    local startTime = os.clock()
    
    local function checkTimeout(): boolean
        return (os.clock() - startTime) * 1000 >= timeout
    end
    
    local layers = {
        function()
            if Executor.request then
                local ok, res = pcall(function() return Executor.request(options) end)
                if not ok then
                    log("WARN", "Executor request layer failed: " .. tostring(res))
                end
                if ok then return res end
            end
            return nil
        end,
        function()
            if Services.HttpService then
                local ok, body = pcall(function()
                    return Services.HttpService:PostAsync(options.Url, options.Body or "", Enum.HttpContentType.ApplicationJson, false, options.Headers or {})
                end)
                if not ok then
                    log("WARN", "HttpService PostAsync layer failed: " .. tostring(body))
                end
                if ok then return { success = true, body = body, status = 200 } end
            end
            return nil
        end,
        function()
            if Services.HttpService and Services.HttpService.RequestAsync then
                local ok, res = pcall(function()
                    return Services.HttpService:RequestAsync({
                        Url = options.Url,
                        Method = options.Method or "POST",
                        Headers = options.Headers or {},
                        Body = options.Body,
                    })
                end)
                if not ok then
                    log("WARN", "HttpService RequestAsync layer failed: " .. tostring(res))
                end
                if ok then return res end
            end
            return nil
        end,
    }
    
    for _, layer in ipairs(layers) do
        if checkTimeout() then
            result.error = "HTTP request timeout"
            return result
        end
        local res = layer()
        if res then
            if res.StatusCode and (res.StatusCode >= 300 and res.StatusCode < 400) then
                result.error = "HTTP redirects are not allowed (SSRF protection)"
                return result
            end
            if res.StatusCode == 200 or res.status == 200 or res.success then
                result.success = true
                result.status = res.StatusCode or res.status or 200
                result.body = res.Body or res.body or ""
                return result
            end
        end
    end
    result.error = "All HTTP layers failed"
    return result
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 8. DATA COLLECTOR (mode-based, minimal default, consent-gated)
-- ═══════════════════════════════════════════════════════════════════════════════

local localPlayer = Services.Players and Services.Players.LocalPlayer

local function getCharacter(): Model?
    if not localPlayer then return nil end
    return localPlayer.Character
end

local function getHumanoid(): Humanoid?
    local char = getCharacter()
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum :: Humanoid?
end

local PayloadRegistry: { PayloadField } = {
    -- MINIMAL
    { key = "UserId",      collect = function() return localPlayer and localPlayer.UserId or "N/A" end, tier = "MINIMAL",    category = "Identity" },
    { key = "Username",    collect = function() return localPlayer and localPlayer.Name or "N/A" end, tier = "MINIMAL",    category = "Identity" },
    -- IDENTITY
    { key = "AccountAge",  collect = function() return localPlayer and localPlayer.AccountAge or "N/A" end, tier = "IDENTITY", category = "Identity" },
    { key = "Membership",  collect = function() return localPlayer and tostring(localPlayer.MembershipType) or "N/A" end, tier = "IDENTITY", category = "Identity" },
    { key = "Verified",    collect = function() return localPlayer and tostring(localPlayer.Verified) or "N/A" end, tier = "IDENTITY", category = "Identity" },
    { key = "Country",     collect = function() return "Auto" end, tier = "IDENTITY", category = "Identity" },
    { key = "Locale",      collect = function() return localPlayer and tostring(localPlayer.LocaleId) or "N/A" end, tier = "IDENTITY", category = "Identity" },
    -- CHARACTER
    { key = "Health",      collect = function() local h = getHumanoid() return h and h.Health or "N/A" end, tier = "CHARACTER", category = "Character" },
    { key = "MaxHealth",   collect = function() local h = getHumanoid() return h and h.MaxHealth or "N/A" end, tier = "CHARACTER", category = "Character" },
    { key = "WalkSpeed",   collect = function() local h = getHumanoid() return h and h.WalkSpeed or "N/A" end, tier = "CHARACTER", category = "Character" },
    { key = "JumpPower",   collect = function() local h = getHumanoid() return h and h.JumpPower or "N/A" end, tier = "CHARACTER", category = "Character" },
    { key = "Position",    collect = function() local h = getHumanoid() return h and tostring(h.RootPart and h.RootPart.Position or Vector3.new()) or "N/A" end, tier = "CHARACTER", category = "Character" },
    -- FULL
    { key = "GameName",    collect = function() return game.Name or "N/A" end, tier = "FULL", category = "Game" },
    { key = "PlaceId",     collect = function() return game.PlaceId or "N/A" end, tier = "FULL", category = "Game" },
    { key = "JobId",       collect = function() return game.JobId or "N/A" end, tier = "FULL", category = "Game" },
    { key = "Executor",    collect = function() if Executor.request then return "Detected" else return "None" end end, tier = "FULL", category = "Device" },
    { key = "Device",      collect = function() return tostring(Services.UserInputService:GetPlatform()) end, tier = "FULL", category = "Device" },
}

local function collectPayload(mode: ConsentMode, allowedFields: { [string]: boolean }?): { [string]: any }
    local payload: { [string]: any } = {}
    for _, field in ipairs(PayloadRegistry) do
        local allowed = false
        if mode == "MINIMAL" and field.tier == "MINIMAL" then allowed = true
        elseif mode == "IDENTITY" and (field.tier == "MINIMAL" or field.tier == "IDENTITY") then allowed = true
        elseif mode == "CHARACTER" and (field.tier == "MINIMAL" or field.tier == "IDENTITY" or field.tier == "CHARACTER") then allowed = true
        elseif mode == "FULL" then allowed = true
        end
        if allowedFields and allowedFields[field.key] == false then allowed = false end
        if allowed then
            local ok, val = pcall(field.collect)
            if ok then payload[field.key] = val else payload[field.key] = "Error" end
        end
    end
    return payload
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 9. EMBED BUILDER (Discord-compatible)
-- ═══════════════════════════════════════════════════════════════════════════════

local function buildEmbed(payload: { [string]: any }): { [string]: any }
    local fields = {}
    for k, v in pairs(payload) do
        table.insert(fields, { name = k, value = tostring(v), inline = true })
    end
    return {
        embeds = {{
            title = "ZEX Payload",
            color = 0xD4E83A,
            fields = fields,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }}
    }
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 10. UI FACTORY (parent set LAST, no exceptions)
-- ═══════════════════════════════════════════════════════════════════════════════

local function corner(radius: number): UICorner
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    return c
end

local function stroke(color: Color3, thickness: number): UIStroke
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness
    return s
end

local function frame(props: { [string]: any }): Frame
    local f = Instance.new("Frame")
    for k, v in pairs(props) do if k ~= "Parent" then (f :: any)[k] = v end end
    if props.Parent then f.Parent = props.Parent end
    return f
end

local function label(props: { [string]: any }): TextLabel
    local l = Instance.new("TextLabel")
    for k, v in pairs(props) do if k ~= "Parent" then (l :: any)[k] = v end end
    if props.Parent then l.Parent = props.Parent end
    return l
end

local function button(props: { [string]: any }): TextButton
    local b = Instance.new("TextButton")
    for k, v in pairs(props) do if k ~= "Parent" then (b :: any)[k] = v end end
    if props.Parent then b.Parent = props.Parent end
    return b
end

local function textbox(props: { [string]: any }): TextBox
    local t = Instance.new("TextBox")
    for k, v in pairs(props) do if k ~= "Parent" then (t :: any)[k] = v end end
    if props.Parent then t.Parent = props.Parent end
    return t
end

local function scrolling(props: { [string]: any }): ScrollingFrame
    local s = Instance.new("ScrollingFrame")
    for k, v in pairs(props) do if k ~= "Parent" then (s :: any)[k] = v end end
    if props.Parent then s.Parent = props.Parent end
    return s
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 11. TWEEN ENGINE (pool with cancellation)
-- ═══════════════════════════════════════════════════════════════════════════════

local activeTweens: { [Instance]: Tween } = {}

local function tweenSafe(obj: Instance, props: { [string]: any }, info: TweenInfo, maid: Maid): Tween?
    if activeTweens[obj] then
        pcall(function() activeTweens[obj]:Cancel() end)
        pcall(function() activeTweens[obj]:Destroy() end)
        activeTweens[obj] = nil
    end
    local ok, tw = pcall(function()
        return Services.TweenService:Create(obj, info, props)
    end)
    if not ok or not tw then
        return nil
    end
    activeTweens[obj] = tw
    local conn = tw.Completed:Connect(function()
        if activeTweens[obj] == tw then
            activeTweens[obj] = nil
        end
        pcall(function() tw:Destroy() end)
    end)
    maid:GiveTask(function()
        if activeTweens[obj] == tw then
            activeTweens[obj] = nil
        end
        pcall(function() conn:Disconnect() end)
        pcall(function() tw:Cancel() end)
        pcall(function() tw:Destroy() end)
    end)
    tw:Play()
    return tw
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 12. HOVER ENGINE
-- ═══════════════════════════════════════════════════════════════════════════════

local function applyHoverEffect(instance: GuiObject, maid: Maid, normalProps: { [string]: any }, hoverProps: { [string]: any })
    maid:GiveTask(instance.MouseEnter:Connect(function()
        tweenSafe(instance, hoverProps, TWEEN_FAST, maid)
    end))
    maid:GiveTask(instance.MouseLeave:Connect(function()
        tweenSafe(instance, normalProps, TWEEN_FAST, maid)
    end))
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- 13. SCREEN GUI + MAIN FRAME
-- ═══════════════════════════════════════════════════════════════════════════════

local rootMaid = Maid.new()

local screenGui: ScreenGui
local mainFrame: Frame

pcall(function()
    local parent: Instance
    if Executor.gethui then
        local ok, hui = pcall(Executor.gethui)
        if ok and hui then parent = hui end
    end
    if not parent and Executor.cloneref then
        local ok, ref = pcall(function() return Executor.cloneref(game.CoreGui) end)
        if ok and ref then parent = ref end
    end
    if not parent then
        parent = game.CoreGui
    end
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ZEX_v73"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = parent
    rootMaid:GiveTask(screenGui)
end)

if not screenGui then
    log("ERROR", "Failed to create ScreenGui")
    return
end

mainFrame = frame({
    Name = "MainFrame",
    Size = UDim2.new(0, 720, 0, 460),
    Position = UDim2.new(0.5, -360, 0.5, -230),
    BackgroundColor3 = Z.bg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Parent = screenGui,
})
corner(10).Parent = mainFrame
stroke(Z.border, 1).Parent = mainFrame

-- Note: UIScale removed — dead code (always 1.0). DPI scaling can be added later if needed.

local titleBar = frame({
    Name = "TitleBar",
    Size = UDim2.new(1, 0, 0, 40),
    BackgroundColor3 = Z.surface,
    BorderSizePixel = 0,
    Parent = mainFrame,
})
local titleAccent = frame({
    Name = "TitleAccent",
    Size = UDim2.new(0, 4, 1, 0),
    BackgroundColor3 = Z.lime,
    BorderSizePixel = 0,
    Parent = titleBar,
})
local titleLabel = label({
    Name = "TitleLabel",
    Text = "ZEX v7.3",
    Font = FONT_HEADER,
    TextSize = 16,
    TextColor3 = Z.text,
    Size = UDim2.new(0, 200, 1, 0),
    Position = UDim2.new(0, 16, 0, 0),
    BackgroundTransparency = 1,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = titleBar,
})

-- Close button (AAA standard)
local closeBtn = button({
    Name = "CloseBtn",
    Text = "X",
    Font = FONT_HEADER,
    TextSize = 14,
    TextColor3 = Z.text2,
    Size = UDim2.new(0, 28, 0, 28),
    Position = UDim2.new(1, -36, 0, 6),
    BackgroundColor3 = Z.clear,
    BackgroundTransparency = 1,
    Parent = titleBar,
})
applyHoverEffect(closeBtn, rootMaid, { TextColor3 = Z.text2 }, { TextColor3 = Z.danger })
rootMaid:GiveTask(closeBtn.MouseButton1Click:Connect(function()
    tweenSafe(mainFrame, { Position = UDim2.new(0.5, -360, 1.5, 0) }, TWEEN_SMOOTH, rootMaid)
    task.delay(0.5, function()
        screenGui:Destroy()
    end)
end))

local tabBar = frame({
    Name = "TabBar",
    Size = UDim2.new(0, 160, 1, -40),
    Position = UDim2.new(0, 0, 0, 40),
    BackgroundColor3 = Z.surface,
    BorderSizePixel = 0,
    Parent = mainFrame,
})
local tabAccentBar = frame({
    Name = "TabAccentBar",
    Size = UDim2.new(0, 3, 1, 0),
    Position = UDim2.new(1, -3, 0, 0),
    BackgroundColor3 = Z.border,
    BorderSizePixel = 0,
    Parent = tabBar,
})

local contentArea = frame({
    Name = "ContentArea",
    Size = UDim2.new(1, -160, 1, -40),
    Position = UDim2.new(0, 160, 0, 40),
    BackgroundColor3 = Z.bg,
    BorderSizePixel = 0,
    Parent = mainFrame,
})

-- ═══════════════════════════════════════════════════════════════════════════════
-- 14. TAB SYSTEM (7 tabs, each self-contained with own Maid)
-- ═══════════════════════════════════════════════════════════════════════════════

local tabs: { TabConfig } = {}
local tabButtons: { TextButton } = {}
local activeTabMaid: Maid? = nil
local activeTabFrame: Frame? = nil

-- Cleanup guard: ensure active tab resources are destroyed on UI teardown
rootMaid:GiveTask(function()
    if activeTabMaid then activeTabMaid:Destroy(); activeTabMaid = nil end
    if activeTabFrame then activeTabFrame:Destroy(); activeTabFrame = nil end
end)

local function switchTab(index: number)
    if activeTabMaid then activeTabMaid:Destroy() end
    activeTabMaid = Maid.new()
    if activeTabFrame then activeTabFrame:Destroy() end
    activeTabFrame = nil

    for i, btn in ipairs(tabButtons) do
        if i == index then
            btn.BackgroundColor3 = Z.elevated
            tweenSafe(btn, { BackgroundColor3 = Z.elevated }, TWEEN_FAST, activeTabMaid)
        else
            btn.BackgroundColor3 = Z.surface
            tweenSafe(btn, { BackgroundColor3 = Z.surface }, TWEEN_FAST, activeTabMaid)
        end
    end

    local tab = tabs[index]
    if tab then
        activeTabFrame = tab.build(contentArea, activeTabMaid)
        if activeTabFrame then
            activeTabFrame.Size = UDim2.new(1, -24, 1, -24)
            activeTabFrame.Position = UDim2.new(0, 12, 0, 12)
            activeTabFrame.BackgroundTransparency = 1
            activeTabFrame.Parent = contentArea
        end
    end
end

local function createTabButton(tab: TabConfig, index: number, parent: Frame, maid: Maid): TextButton
    local btn = button({
        Name = tab.name .. "Tab",
        Text = "  " .. tab.name,
        Font = FONT_BUTTON,
        TextSize = 12,
        TextColor3 = Z.text2,
        Size = UDim2.new(1, 0, 0, 36),
        Position = UDim2.new(0, 0, 0, (index - 1) * 36),
        BackgroundColor3 = Z.surface,
        BorderSizePixel = 0,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
        Parent = parent,
    })
    corner(6).Parent = btn

    applyHoverEffect(btn, maid, { BackgroundColor3 = Z.surface }, { BackgroundColor3 = Z.elevated })

    maid:GiveTask(btn.MouseButton1Click:Connect(function()
        switchTab(index)
    end))

    return btn
end

-- Dashboard Tab
local function buildDashboard(parent: Frame, maid: Maid): Frame
    local f = frame({ Name = "Dashboard", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = parent })
    local running = true
    maid:GiveTask(function() running = false end)

    local fpsLabel = label({ Text = "FPS: --", Font = FONT_DATA, TextSize = 14, TextColor3 = Z.lime, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Parent = f })
    local memLabel = label({ Text = "Memory: -- MB", Font = FONT_DATA, TextSize = 14, TextColor3 = Z.info, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0, 28), BackgroundTransparency = 1, Parent = f })
    local pingLabel = label({ Text = "Ping: -- ms", Font = FONT_DATA, TextSize = 14, TextColor3 = Z.success, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0, 56), BackgroundTransparency = 1, Parent = f })
    local playerLabel = label({ Text = "Players: --", Font = FONT_DATA, TextSize = 14, TextColor3 = Z.warn, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0, 84), BackgroundTransparency = 1, Parent = f })

    local fps = 0
    local last = os.clock()
    maid:GiveTask(Services.RunService.RenderStepped:Connect(function()
        fps += 1
        local now = os.clock()
        if now - last >= 1 then
            fpsLabel.Text = string.format("FPS: %d", fps)
            fps = 0
            last = now
        end
    end))

    task.spawn(function()
        while running and task.wait(1) do
            local mem = collectgarbage("count") / 1024
            memLabel.Text = string.format("Memory: %.2f MB", mem)
            local players = #Services.Players:GetPlayers()
            playerLabel.Text = string.format("Players: %d", players)
        end
    end)

    return f
end

-- Player Tab
local function buildPlayer(parent: Frame, maid: Maid): Frame
    local f = frame({ Name = "Player", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = parent })
    local running = true
    maid:GiveTask(function() running = false end)

    local infoLabel = label({ Text = "Loading...", Font = FONT_LABEL, TextSize = 11, TextColor3 = Z.text2, Size = UDim2.new(1, 0, 0, 200), BackgroundTransparency = 1, TextWrapped = true, Parent = f })

    local function update()
        if not localPlayer then return end
        local lines = {}
        table.insert(lines, "UserId: " .. tostring(localPlayer.UserId))
        table.insert(lines, "Username: " .. localPlayer.Name)
        table.insert(lines, "Display: " .. (localPlayer.DisplayName or "N/A"))
        table.insert(lines, "Age: " .. tostring(localPlayer.AccountAge))
        table.insert(lines, "Membership: " .. tostring(localPlayer.MembershipType))
        local char = localPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                table.insert(lines, "Health: " .. tostring(hum.Health) .. " / " .. tostring(hum.MaxHealth))
                table.insert(lines, "WalkSpeed: " .. tostring(hum.WalkSpeed))
                table.insert(lines, "JumpPower: " .. tostring(hum.JumpPower))
                if hum.RootPart then
                    table.insert(lines, "Position: " .. tostring(hum.RootPart.Position))
                end
            end
        end
        infoLabel.Text = table.concat(lines, "\n")
    end

    update()
    if localPlayer then
        maid:GiveTask(localPlayer.CharacterAdded:Connect(function()
            task.wait(0.5)
            update()
        end))
    end
    task.spawn(function()
        while running and task.wait(1) do
            update()
        end
    end)

    return f
end

-- Server Tab
local function buildServer(parent: Frame, maid: Maid): Frame
    local f = frame({ Name = "Server", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = parent })
    local info = {}
    table.insert(info, "Game: " .. game.Name)
    table.insert(info, "PlaceId: " .. tostring(game.PlaceId))
    table.insert(info, "JobId: " .. tostring(game.JobId))
    table.insert(info, "Players: " .. tostring(#Services.Players:GetPlayers()))
    table.insert(info, "Time: " .. tostring(Services.Lighting.TimeOfDay))
    table.insert(info, "Gravity: " .. tostring(Services.Workspace.Gravity))

    label({ Text = table.concat(info, "\n"), Font = FONT_LABEL, TextSize = 11, TextColor3 = Z.text2, Size = UDim2.new(1, 0, 0, 200), BackgroundTransparency = 1, TextWrapped = true, Parent = f })
    return f
end

-- Webhooks Tab
local function buildWebhooks(parent: Frame, maid: Maid): Frame
    local f = frame({ Name = "Webhooks", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = parent })

    local urlBox = textbox({
        Name = "UrlBox",
        PlaceholderText = "https://webhookpulse.vercel.app/api/...",
        Size = UDim2.new(1, -120, 0, 32),
        BackgroundColor3 = Z.card,
        TextColor3 = Z.text,
        Font = FONT_CONSOLE,
        TextSize = 11,
        ClearTextOnFocus = false,
        Parent = f,
    })
    corner(6).Parent = urlBox
    stroke(Z.border, 1).Parent = urlBox

    local secretBox = textbox({
        Name = "SecretBox",
        PlaceholderText = "X-Webhook-Secret",
        Size = UDim2.new(1, -120, 0, 32),
        Position = UDim2.new(0, 0, 0, 40),
        BackgroundColor3 = Z.card,
        TextColor3 = Z.text,
        Font = FONT_CONSOLE,
        TextSize = 11,
        ClearTextOnFocus = false,
        Parent = f,
    })
    corner(6).Parent = secretBox
    stroke(Z.border, 1).Parent = secretBox

    local statusLabel = label({
        Text = "Status: Ready",
        Font = FONT_LABEL,
        TextSize = 11,
        TextColor3 = Z.text3,
        Size = UDim2.new(1, 0, 0, 20),
        Position = UDim2.new(0, 0, 0, 80),
        BackgroundTransparency = 1,
        Parent = f,
    })

    -- Consent checkboxes
    local consentModes: { ConsentMode } = { "MINIMAL", "IDENTITY", "CHARACTER", "FULL" }
    local currentMode: ConsentMode = "MINIMAL"
    local modeButtons: { TextButton } = {}

    for i, mode in ipairs(consentModes) do
        local btn = button({
            Text = mode,
            Font = FONT_BUTTON,
            TextSize = 10,
            TextColor3 = Z.text2,
            Size = UDim2.new(0, 80, 0, 24),
            Position = UDim2.new(0, (i - 1) * 85, 0, 110),
            BackgroundColor3 = Z.card,
            Parent = f,
        })
        corner(6).Parent = btn
        stroke(Z.border, 1).Parent = btn
        table.insert(modeButtons, btn)
        maid:GiveTask(btn.MouseButton1Click:Connect(function()
            currentMode = mode
            for _, b in ipairs(modeButtons) do
                b.BackgroundColor3 = Z.card
            end
            btn.BackgroundColor3 = Z.lime
            btn.TextColor3 = Z.bg
        end))
    end

    local sendBtn = button({
        Text = "Transmit",
        Font = FONT_BUTTON,
        TextSize = 12,
        TextColor3 = Z.bg,
        Size = UDim2.new(0, 120, 0, 32),
        Position = UDim2.new(0, 0, 0, 150),
        BackgroundColor3 = Z.lime,
        Parent = f,
    })
    corner(6).Parent = sendBtn

    maid:GiveTask(sendBtn.MouseButton1Click:Connect(function()
        local url = urlBox.Text
        local valid, err = validateUrl(url)
        if not valid then
            statusLabel.Text = "Status: Invalid URL — " .. err
            statusLabel.TextColor3 = Z.danger
            return
        end
        if not checkRateLimit(url) then
            statusLabel.Text = "Status: Rate limited"
            statusLabel.TextColor3 = Z.danger
            return
        end
        statusLabel.Text = "Status: Collecting..."
        statusLabel.TextColor3 = Z.info
        local payload = collectPayload(currentMode)
        local embed = buildEmbed(payload)
        local body = Services.HttpService:JSONEncode(embed)
        local res = httpRequest({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json", ["X-Webhook-Secret"] = secretBox.Text:gsub("[%z\r\n]", "") },
            Body = body,
        })
        if res.success then
            statusLabel.Text = "Status: Sent successfully"
            statusLabel.TextColor3 = Z.success
            -- Wipe secret from UI (note: true cryptographic memory wipe is not possible in Luau)
            secretBox.Text = ""
            secretBox:ReleaseFocus()
        else
            statusLabel.Text = "Status: Failed — " .. (res.error or "Unknown")
            statusLabel.TextColor3 = Z.danger
        end
    end))

    return f
end

-- Network Tab
local function buildNetwork(parent: Frame, maid: Maid): Frame
    local f = frame({ Name = "Network", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = parent })

    local urlBox = textbox({
        PlaceholderText = "https://example.com/api",
        Size = UDim2.new(1, -80, 0, 32),
        BackgroundColor3 = Z.card,
        TextColor3 = Z.text,
        Font = FONT_CONSOLE,
        TextSize = 11,
        Parent = f,
    })
    corner(6).Parent = urlBox
    stroke(Z.border, 1).Parent = urlBox

    local methodBox = textbox({
        Text = "GET",
        Size = UDim2.new(0, 70, 0, 32),
        Position = UDim2.new(1, -70, 0, 0),
        BackgroundColor3 = Z.card,
        TextColor3 = Z.text,
        Font = FONT_CONSOLE,
        TextSize = 11,
        Parent = f,
    })
    corner(6).Parent = methodBox

    local resultLabel = label({
        Text = "Result will appear here...",
        Font = FONT_CONSOLE,
        TextSize = 10,
        TextColor3 = Z.text3,
        Size = UDim2.new(1, 0, 1, -80),
        Position = UDim2.new(0, 0, 0, 42),
        BackgroundTransparency = 1,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = f,
    })

    local reqBtn = button({
        Text = "Request",
        Font = FONT_BUTTON,
        TextSize = 12,
        TextColor3 = Z.bg,
        Size = UDim2.new(0, 100, 0, 28),
        Position = UDim2.new(0, 0, 0, 42),
        BackgroundColor3 = Z.lime,
        Parent = f,
    })
    corner(6).Parent = reqBtn

    maid:GiveTask(reqBtn.MouseButton1Click:Connect(function()
        local url = urlBox.Text
        local valid, err = validateUrl(url)
        if not valid then
            resultLabel.Text = "Error: " .. err
            resultLabel.TextColor3 = Z.danger
            return
        end
        local method = string.upper(methodBox.Text:gsub("%s", ""))
        local ALLOWED_METHODS: { [string]: boolean } = { GET = true, POST = true, PUT = true, PATCH = true, DELETE = true }
        if not ALLOWED_METHODS[method] then
            resultLabel.Text = "Error: Invalid HTTP method"
            resultLabel.TextColor3 = Z.danger
            return
        end
        resultLabel.Text = "Sending..."
        resultLabel.TextColor3 = Z.info
        local res = httpRequest({
            Url = url,
            Method = method,
            Headers = {},
            Timeout = 10000,
        })
        if res.success then
            local body = res.body or ""
            if #body > 10240 then
                body = string.sub(body, 1, 10240) .. "\n[... truncated at 10KB]"
            end
            resultLabel.Text = string.format("Status: %d\nBody:\n%s", res.status or 0, body)
            resultLabel.TextColor3 = Z.success
        else
            resultLabel.Text = "Error: " .. (res.error or "Failed")
            resultLabel.TextColor3 = Z.danger
        end
    end))

    return f
end

-- Commands Tab
local function buildCommands(parent: Frame, maid: Maid): Frame
    local f = frame({ Name = "Commands", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = parent })
    local cmds = {
        { name = "Rejoin", action = function() Services.TeleportService:Teleport(game.PlaceId, localPlayer) end },
        { name = "Reset", action = function() if localPlayer then localPlayer.Character:BreakJoints() end end },
        { name = "Fullbright", action = function()
            Services.Lighting.Brightness = 10
            Services.Lighting.GlobalShadows = false
            Services.Lighting.ClockTime = 12
        end },
        { name = "Speed +50", action = function()
            local h = getHumanoid()
            if h then h.WalkSpeed = h.WalkSpeed + 50 end
        end },
        { name = "Jump +50", action = function()
            local h = getHumanoid()
            if h then h.JumpPower = h.JumpPower + 50 end
        end },
    }

    for i, cmd in ipairs(cmds) do
        local btn = button({
            Text = cmd.name,
            Font = FONT_BUTTON,
            TextSize = 11,
            TextColor3 = Z.text,
            Size = UDim2.new(0, 120, 0, 28),
            Position = UDim2.new(0, 0, 0, (i - 1) * 34),
            BackgroundColor3 = Z.card,
            Parent = f,
        })
        corner(6).Parent = btn
        stroke(Z.border, 1).Parent = btn
        applyHoverEffect(btn, maid, { BackgroundColor3 = Z.card }, { BackgroundColor3 = Z.elevated })
        maid:GiveTask(btn.MouseButton1Click:Connect(function()
            safeCall(cmd.action, "Command " .. cmd.name)
        end))
    end
    return f
end

-- Console Tab
local function buildConsole(parent: Frame, maid: Maid): Frame
    local f = frame({ Name = "Console", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Parent = parent })
    local running = true
    maid:GiveTask(function() running = false end)

    local scroll = scrolling({
        Size = UDim2.new(1, 0, 1, -40),
        BackgroundTransparency = 1,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Z.border,
        Parent = f,
    })
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = scroll

    local lastLogVersion = 0

    local function appendNewLogs()
        if logVersion == lastLogVersion then return end
        lastLogVersion = logVersion
        -- Full rebuild: O(n) for ≤200 rows, acceptable
        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("TextLabel") then child:Destroy() end
        end
        for _, entry in ipairs(logs) do
            local color = Z.text2
            if entry:find("ERROR") then color = Z.danger
            elseif entry:find("WARN") then color = Z.warn
            elseif entry:find("DEBUG") then color = Z.info end
            local l = label({
                Text = entry,
                Font = FONT_CONSOLE,
                TextSize = 10,
                TextColor3 = color,
                Size = UDim2.new(1, 0, 0, 16),
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = scroll,
            })
        end
        scroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
        scroll.CanvasPosition = Vector2.new(0, listLayout.AbsoluteContentSize.Y)
    end

    local function clearConsole()
        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("TextLabel") then child:Destroy() end
        end
        table.clear(logs)
        lastLogCount = 0
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    end

    task.spawn(function()
        while running and task.wait(0.5) do
            appendNewLogs()
        end
    end)

    local copyBtn = button({
        Text = "Copy Log",
        Font = FONT_BUTTON,
        TextSize = 11,
        TextColor3 = Z.bg,
        Size = UDim2.new(0, 100, 0, 28),
        Position = UDim2.new(0, 0, 1, -32),
        BackgroundColor3 = Z.lime,
        Parent = f,
    })
    corner(6).Parent = copyBtn
    maid:GiveTask(copyBtn.MouseButton1Click:Connect(function()
        if Executor.setclipboard then
            pcall(function() Executor.setclipboard(table.concat(logs, "\n")) end)
        end
    end))

    local clearBtn = button({
        Text = "Clear",
        Font = FONT_BUTTON,
        TextSize = 11,
        TextColor3 = Z.text,
        Size = UDim2.new(0, 80, 0, 28),
        Position = UDim2.new(0, 108, 1, -32),
        BackgroundColor3 = Z.card,
        Parent = f,
    })
    corner(6).Parent = clearBtn
    maid:GiveTask(clearBtn.MouseButton1Click:Connect(function()
        clearConsole()
    end))

    return f
end

-- Register tabs
tabs = {
    { name = "Dashboard", icon = "D", build = buildDashboard },
    { name = "Player", icon = "P", build = buildPlayer },
    { name = "Server", icon = "S", build = buildServer },
    { name = "Webhooks", icon = "W", build = buildWebhooks },
    { name = "Network", icon = "N", build = buildNetwork },
    { name = "Commands", icon = "C", build = buildCommands },
    { name = "Console", icon = ">", build = buildConsole },
}

for i, tab in ipairs(tabs) do
    local btn = createTabButton(tab, i, tabBar, rootMaid)
    table.insert(tabButtons, btn)
end

switchTab(1)

rootMaid:GiveTask(function()
    table.clear(tabButtons)
    table.clear(tabs)
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 15. DRAG SYSTEM (optimized — temporary connections, no per-frame waste)
-- ═══════════════════════════════════════════════════════════════════════════════

local dragMaid: Maid? = nil

-- Cleanup guard: ensure drag resources are destroyed on UI teardown
rootMaid:GiveTask(function()
    if dragMaid then dragMaid:Destroy(); dragMaid = nil end
end)

rootMaid:GiveTask(titleBar.InputBegan:Connect(function(input: InputObject)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if dragMaid then dragMaid:Destroy() end
        dragMaid = Maid.new()
        
        local dragInputType = input.UserInputType
        local dragOffset = Vector2.new(input.Position.X, input.Position.Y) - mainFrame.AbsolutePosition
        
        dragMaid:GiveTask(Services.UserInputService.InputChanged:Connect(function(input2: InputObject)
            if input2.UserInputType == Enum.UserInputType.MouseMovement or input2.UserInputType == Enum.UserInputType.Touch then
                local pos = Vector2.new(input2.Position.X, input2.Position.Y) - dragOffset
                local vp = Services.Workspace.CurrentCamera.ViewportSize
                local fw, fh = mainFrame.AbsoluteSize.X, mainFrame.AbsoluteSize.Y
                pos = Vector2.new(
                    math.clamp(pos.X, 0, math.max(0, vp.X - fw)),
                    math.clamp(pos.Y, 0, math.max(0, vp.Y - fh))
                )
                mainFrame.Position = UDim2.new(0, pos.X, 0, pos.Y)
            end
        end))
        
        dragMaid:GiveTask(Services.UserInputService.InputEnded:Connect(function(input2: InputObject)
            if input2.UserInputType == dragInputType then
                if dragMaid then
                    dragMaid:Destroy()
                    dragMaid = nil
                end
            end
        end))
    end
end))

-- ═══════════════════════════════════════════════════════════════════════════════
-- 16. KEYBIND TOGGLE (RightShift)
-- ═══════════════════════════════════════════════════════════════════════════════

local visible = true
rootMaid:GiveTask(Services.UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        visible = not visible
        if visible then
            tweenSafe(mainFrame, { Position = UDim2.new(0.5, -360, 0.5, -230) }, TWEEN_SMOOTH, rootMaid)
        else
            tweenSafe(mainFrame, { Position = UDim2.new(0.5, -360, 1.5, 0) }, TWEEN_SMOOTH, rootMaid)
        end
    end
end))

-- ═══════════════════════════════════════════════════════════════════════════════
-- 17. ENTRY ANIMATION (staggered fade)
-- ═══════════════════════════════════════════════════════════════════════════════

mainFrame.BackgroundTransparency = 1
for _, child in ipairs(mainFrame:GetDescendants()) do
    if child:IsA("GuiObject") then
        child.BackgroundTransparency = 1
        if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
            child.TextTransparency = 1
        end
    end
end

task.delay(0.1, function()
    if not screenGui or not screenGui.Parent then return end
    tweenSafe(mainFrame, { BackgroundTransparency = 0 }, TWEEN_SLOW, rootMaid)
    for i, child in ipairs(mainFrame:GetDescendants()) do
        if child:IsA("GuiObject") then
            task.delay(i * 0.03, function()
                if not screenGui or not screenGui.Parent then return end
                if not child or not child.Parent then return end
                tweenSafe(child, { BackgroundTransparency = 0 }, TWEEN_FAST, rootMaid)
                if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
                    tweenSafe(child, { TextTransparency = 0 }, TWEEN_FAST, rootMaid)
                end
            end)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- 18. ROOT MAID TEARDOWN (cascade on Destroy)
-- ═══════════════════════════════════════════════════════════════════════════════

rootMaid:GiveTask(screenGui.Destroying:Connect(function()
    rootMaid:Destroy()
    log("INFO", "ZEX v7.3 teardown complete")
end))

-- ═══════════════════════════════════════════════════════════════════════════════
-- 19. BOOT
-- ═══════════════════════════════════════════════════════════════════════════════

log("INFO", "ZEX v7.3 booted — Executor: " .. (Executor.request and "Detected" or "None"))

-- Expose minimal control table for external access (optional)
log("INFO", "ZEX v7.3 ready")
