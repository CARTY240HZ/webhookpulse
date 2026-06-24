--[[
  ZEX v7.0 ELITE — Roblox Admin Controller
  ============================================================
  Arquitectura AAA · 25+ años industria gaming · Optimizada memoria
  Nombre: ZEX | Logo: X estilizada lime | Paleta: WebhookPulse dark
  NO emojis. Iconos vectoriales puros. Fuente Gotham. Todo en pcall.
  
  Tabs: Dashboard, Player, Server, Webhooks, Network, Commands, Console
  Keybind: RightShift para toggle
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- ============================================================
-- PALETA ZEX
-- ============================================================
local Z = {
  bg = Color3.fromRGB(12, 12, 14),
  surface = Color3.fromRGB(22, 22, 24),
  elevated = Color3.fromRGB(28, 28, 30),
  border = Color3.fromRGB(39, 39, 42),
  text = Color3.fromRGB(250, 250, 250),
  text2 = Color3.fromRGB(161, 161, 170),
  lime = Color3.fromRGB(212, 232, 58),
  lime2 = Color3.fromRGB(232, 249, 106),
  danger = Color3.fromRGB(239, 68, 68),
  success = Color3.fromRGB(34, 197, 94),
  info = Color3.fromRGB(59, 130, 246),
}

-- ============================================================
-- UTILIDADES
-- ============================================================
local function corner(parent, r)
  local c = Instance.new("UICorner")
  c.CornerRadius = UDim.new(0, r or 6)
  c.Parent = parent
  return c
end

local function stroke(parent, col, th)
  local s = Instance.new("UIStroke")
  s.Color = col or Z.border
  s.Thickness = th or 1
  s.Parent = parent
  return s
end

local function pad(parent, l, t, r, b)
  local p = Instance.new("UIPadding")
  p.PaddingLeft = UDim.new(0, l or 0)
  p.PaddingTop = UDim.new(0, t or 0)
  p.PaddingRight = UDim.new(0, r or 0)
  p.PaddingBottom = UDim.new(0, b or 0)
  p.Parent = parent
  return p
end

local function safeCall(fn, fallback)
  local ok, res = pcall(fn)
  if ok then return res end
  return fallback
end

local function parseResponse(res)
  if not res then return { status = 0, isSuccess = false, isHoneypot = false, body = "no response" } end
  local code = res.StatusCode or res.statusCode or res.status or 0
  local bodyStr = res.Body or res.body or ""
  local isSuccess = false
  local isHoneypot = false
  local bodyData = nil
  local ok, decoded = pcall(function() return HttpService:JSONDecode(bodyStr) end)
  if ok and decoded then
    bodyData = decoded
    if decoded.success == true or decoded.logId then
      isSuccess = true
    elseif decoded.received == true then
      isHoneypot = true
    end
  end
  return { status = code, isSuccess = isSuccess, isHoneypot = isHoneypot, body = bodyStr, data = bodyData }
end

-- ============================================================
-- SCREEN GUI
-- ============================================================
local SG = Instance.new("ScreenGui")
SG.Name = "ZEX_Controller"
SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

if gethui then
  local ok, hui = pcall(gethui)
  if ok and hui then SG.Parent = hui end
end
if not SG.Parent then
  local ok, cg = pcall(function() return game:GetService("CoreGui") end)
  if ok and cg then SG.Parent = cg end
end
if not SG.Parent then
  SG.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- ============================================================
-- MAIN FRAME
-- ============================================================
local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 720, 0, 520)
Main.Position = UDim2.new(0.5, -360, 0.5, -260)
Main.BackgroundColor3 = Z.bg
Main.BorderSizePixel = 0
Main.ZIndex = 10
Main.Parent = SG

corner(Main, 8)
stroke(Main, Z.border, 1)

-- Shadow
local Shadow = Instance.new("Frame")
Shadow.Size = UDim2.new(1, 0, 1, 0)
Shadow.Position = UDim2.new(0, 4, 0, 4)
Shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Shadow.BackgroundTransparency = 0.6
Shadow.BorderSizePixel = 0
Shadow.ZIndex = 9
Shadow.Parent = Main
corner(Shadow, 8)

-- ============================================================
-- TOPBAR
-- ============================================================
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 48)
TopBar.BackgroundColor3 = Z.surface
TopBar.BorderSizePixel = 0
TopBar.ZIndex = 11
TopBar.Parent = Main

corner(TopBar, 8)

local TopBarFix = Instance.new("Frame")
TopBarFix.Size = UDim2.new(1, 0, 0, 8)
TopBarFix.Position = UDim2.new(0, 0, 1, -8)
TopBarFix.BackgroundColor3 = Z.surface
TopBarFix.BorderSizePixel = 0
TopBarFix.ZIndex = 11
TopBarFix.Parent = TopBar

-- LOGO X
local LogoX = Instance.new("Frame")
LogoX.Size = UDim2.new(0, 32, 0, 32)
LogoX.Position = UDim2.new(0, 12, 0, 8)
LogoX.BackgroundTransparency = 1
LogoX.ZIndex = 12
LogoX.Parent = TopBar

local X1 = Instance.new("Frame")
X1.Size = UDim2.new(0, 4, 0, 22)
X1.Position = UDim2.new(0.5, -2, 0.5, -11)
X1.BackgroundColor3 = Z.lime
X1.BorderSizePixel = 0
X1.Rotation = 45
X1.ZIndex = 12
X1.Parent = LogoX
corner(X1, 99)

local X2 = Instance.new("Frame")
X2.Size = UDim2.new(0, 4, 0, 22)
X2.Position = UDim2.new(0.5, -2, 0.5, -11)
X2.BackgroundColor3 = Z.lime
X2.BorderSizePixel = 0
X2.Rotation = -45
X2.ZIndex = 12
X2.Parent = LogoX
corner(X2, 99)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0, 120, 1, 0)
Title.Position = UDim2.new(0, 52, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "ZEX"
Title.TextColor3 = Z.lime
Title.Font = Enum.Font.GothamBold
Title.TextSize = 20
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 12
Title.Parent = TopBar

local SubTitle = Instance.new("TextLabel")
SubTitle.Size = UDim2.new(0, 200, 0, 16)
SubTitle.Position = UDim2.new(0, 52, 0, 28)
SubTitle.BackgroundTransparency = 1
SubTitle.Text = "v7.0 ELITE"
SubTitle.TextColor3 = Z.text2
SubTitle.Font = Enum.Font.Gotham
SubTitle.TextSize = 10
SubTitle.TextXAlignment = Enum.TextXAlignment.Left
SubTitle.ZIndex = 12
SubTitle.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -40, 0, 8)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Z.text2
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.ZIndex = 12
CloseBtn.Parent = TopBar
CloseBtn.MouseEnter:Connect(function() CloseBtn.TextColor3 = Z.danger end)
CloseBtn.MouseLeave:Connect(function() CloseBtn.TextColor3 = Z.text2 end)
CloseBtn.MouseButton1Click:Connect(function() SG:Destroy() end)

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 32, 0, 32)
MinBtn.Position = UDim2.new(1, -72, 0, 8)
MinBtn.BackgroundTransparency = 1
MinBtn.Text = "-"
MinBtn.TextColor3 = Z.text2
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 18
MinBtn.ZIndex = 12
MinBtn.Parent = TopBar

local minimized = false
MinBtn.MouseEnter:Connect(function() MinBtn.TextColor3 = Z.text end)
MinBtn.MouseLeave:Connect(function() MinBtn.TextColor3 = Z.text2 end)
MinBtn.MouseButton1Click:Connect(function()
  minimized = not minimized
  if minimized then
    Main.Size = UDim2.new(0, 720, 0, 48)
    MinBtn.Text = "+"
  else
    Main.Size = UDim2.new(0, 720, 0, 520)
    MinBtn.Text = "-"
  end
end)

-- ============================================================
-- SIDEBAR (7 tabs)
-- ============================================================
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 120, 1, -48)
Sidebar.Position = UDim2.new(0, 0, 0, 48)
Sidebar.BackgroundColor3 = Z.surface
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 11
Sidebar.Parent = Main

local tabNames = {"Dashboard", "Player", "Server", "Webhooks", "Network", "Commands", "Console"}
local tabs = {}
local activeTab = 1

for i, name in ipairs(tabNames) do
  local btn = Instance.new("TextButton")
  btn.Size = UDim2.new(1, 0, 0, 36)
  btn.Position = UDim2.new(0, 0, 0, (i-1) * 40 + 12)
  btn.BackgroundColor3 = i == 1 and Z.elevated or Z.surface
  btn.BorderSizePixel = 0
  btn.Text = "  " .. name
  btn.TextColor3 = i == 1 and Z.lime or Z.text2
  btn.Font = Enum.Font.GothamBold
  btn.TextSize = 11
  btn.TextXAlignment = Enum.TextXAlignment.Left
  btn.ZIndex = 12
  btn.Name = name
  btn.Parent = Sidebar
  
  local indicator = Instance.new("Frame")
  indicator.Size = UDim2.new(0, 3, 0, 20)
  indicator.Position = UDim2.new(0, 0, 0.5, -10)
  indicator.BackgroundColor3 = Z.lime
  indicator.BorderSizePixel = 0
  indicator.ZIndex = 13
  indicator.Parent = btn
  indicator.Visible = i == 1
  
  tabs[i] = {btn = btn, indicator = indicator}
end

local Sep = Instance.new("Frame")
Sep.Size = UDim2.new(0, 1, 1, -24)
Sep.Position = UDim2.new(1, 0, 0, 12)
Sep.BackgroundColor3 = Z.border
Sep.BorderSizePixel = 0
Sep.ZIndex = 12
Sep.Parent = Sidebar

-- ============================================================
-- CONTENT AREA
-- ============================================================
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -120, 1, -48)
Content.Position = UDim2.new(0, 120, 0, 48)
Content.BackgroundColor3 = Z.bg
Content.BorderSizePixel = 0
Content.ZIndex = 10
Content.Parent = Main

local tabContainers = {}
for i = 1, 7 do
  local c = Instance.new("Frame")
  c.Size = UDim2.new(1, 0, 1, 0)
  c.BackgroundTransparency = 1
  c.Visible = i == 1
  c.ZIndex = 10
  c.Parent = Content
  c.Name = tabNames[i]
  tabContainers[i] = c
end

for i, t in ipairs(tabs) do
  t.btn.MouseButton1Click:Connect(function()
    activeTab = i
    for j, ot in ipairs(tabs) do
      ot.btn.BackgroundColor3 = Z.surface
      ot.btn.TextColor3 = Z.text2
      ot.indicator.Visible = false
      tabContainers[j].Visible = false
    end
    t.btn.BackgroundColor3 = Z.elevated
    t.btn.TextColor3 = Z.lime
    t.indicator.Visible = true
    tabContainers[i].Visible = true
  end)
end

-- ============================================================
-- TAB 1: DASHBOARD
-- ============================================================
local Dashboard = tabContainers[1]
pad(Dashboard, 16, 16, 16, 16)

local DHeader = Instance.new("TextLabel")
DHeader.Size = UDim2.new(1, 0, 0, 22)
DHeader.BackgroundTransparency = 1
DHeader.Text = "Dashboard"
DHeader.TextColor3 = Z.text
DHeader.Font = Enum.Font.GothamBold
DHeader.TextSize = 16
DHeader.TextXAlignment = Enum.TextXAlignment.Left
DHeader.Parent = Dashboard

local DSub = Instance.new("TextLabel")
DSub.Size = UDim2.new(1, 0, 0, 18)
DSub.Position = UDim2.new(0, 0, 0, 24)
DSub.BackgroundTransparency = 1
DSub.Text = "Estado global del sistema en tiempo real."
DSub.TextColor3 = Z.text2
DSub.Font = Enum.Font.Gotham
DSub.TextSize = 11
DSub.TextXAlignment = Enum.TextXAlignment.Left
DSub.Parent = Dashboard

local function createCard(parent, icon, label, value, row, col, color)
  color = color or Z.lime
  local card = Instance.new("Frame")
  card.Size = UDim2.new(0.5, -6, 0, 80)
  card.Position = UDim2.new(col == 1 and 0 or 0.5, col == 1 and 0 or 6, 0, 56 + (row-1) * 86)
  card.BackgroundColor3 = Z.surface
  card.BorderSizePixel = 0
  card.ZIndex = 11
  card.Parent = parent
  corner(card, 6)
  stroke(card, Z.border, 1)
  
  local ico = Instance.new("TextLabel")
  ico.Size = UDim2.new(0, 28, 0, 28)
  ico.Position = UDim2.new(0, 12, 0, 12)
  ico.BackgroundColor3 = Z.bg
  ico.BorderSizePixel = 0
  ico.Text = icon
  ico.TextColor3 = color
  ico.Font = Enum.Font.GothamBold
  ico.TextSize = 14
  ico.ZIndex = 12
  ico.Parent = card
  corner(ico, 6)
  
  local lbl = Instance.new("TextLabel")
  lbl.Size = UDim2.new(1, -52, 0, 16)
  lbl.Position = UDim2.new(0, 52, 0, 14)
  lbl.BackgroundTransparency = 1
  lbl.Text = label
  lbl.TextColor3 = Z.text2
  lbl.Font = Enum.Font.Gotham
  lbl.TextSize = 10
  lbl.TextXAlignment = Enum.TextXAlignment.Left
  lbl.ZIndex = 12
  lbl.Parent = card
  
  local val = Instance.new("TextLabel")
  val.Size = UDim2.new(1, -52, 0, 22)
  val.Position = UDim2.new(0, 52, 0, 32)
  val.BackgroundTransparency = 1
  val.Text = value
  val.TextColor3 = Z.text
  val.Font = Enum.Font.GothamBold
  val.TextSize = 18
  val.TextXAlignment = Enum.TextXAlignment.Left
  val.ZIndex = 12
  val.Parent = card
  val.Name = "Value"
  
  return val
end

local DPlayers = createCard(Dashboard, "P", "Jugadores en servidor", tostring(#Players:GetPlayers()), 1, 1, Z.info)
local DPlace = createCard(Dashboard, "#", "PlaceId", tostring(game.PlaceId), 1, 2, Z.lime)
local DFps = createCard(Dashboard, "F", "FPS", "--", 2, 1, Z.success)
local DMem = createCard(Dashboard, "M", "Memoria (MB)", "--", 2, 2, Z.info)

local fpsCount, lastFpsTick = 0, tick()
RunService.RenderStepped:Connect(function()
  fpsCount += 1
  if tick() - lastFpsTick >= 1 then
    DFps.Text = tostring(fpsCount)
    fpsCount = 0
    lastFpsTick = tick()
  end
end)

spawn(function()
  while wait(2) do
    local mem = safeCall(function() return collectgarbage("count") / 1024 end, 0)
    DMem.Text = string.format("%.1f", mem)
  end
end)

spawn(function()
  while wait(1) do
    DPlayers.Text = tostring(#Players:GetPlayers())
  end
end)

local DStatus = Instance.new("TextLabel")
DStatus.Size = UDim2.new(1, 0, 0, 28)
DStatus.Position = UDim2.new(0, 0, 1, -28)
DStatus.BackgroundColor3 = Z.surface
DStatus.BorderSizePixel = 0
DStatus.Text = "  ZEX SYSTEM ONLINE  v7.0  |  Roblox Profile Data Controller"
DStatus.TextColor3 = Z.text2
DStatus.Font = Enum.Font.Gotham
DStatus.TextSize = 10
DStatus.TextXAlignment = Enum.TextXAlignment.Left
DStatus.ZIndex = 11
DStatus.Parent = Dashboard

-- ============================================================
-- TAB 2: PLAYER
-- ============================================================
local PlayerTab = tabContainers[2]

local PScroll = Instance.new("ScrollingFrame")
PScroll.Size = UDim2.new(1, 0, 1, 0)
PScroll.BackgroundTransparency = 1
PScroll.ScrollBarThickness = 4
PScroll.ScrollBarImageColor3 = Z.lime
PScroll.CanvasSize = UDim2.new(0, 0, 0, 800)
PScroll.ZIndex = 10
PScroll.Parent = PlayerTab
pad(PScroll, 16, 16, 16, 0)

local PHeader = Instance.new("TextLabel")
PHeader.Size = UDim2.new(1, 0, 0, 22)
PHeader.BackgroundTransparency = 1
PHeader.Text = "Player Intelligence"
PHeader.TextColor3 = Z.text
PHeader.Font = Enum.Font.GothamBold
PHeader.TextSize = 16
PHeader.TextXAlignment = Enum.TextXAlignment.Left
PHeader.ZIndex = 11
PHeader.Parent = PScroll

local PSub = Instance.new("TextLabel")
PSub.Size = UDim2.new(1, 0, 0, 18)
PSub.Position = UDim2.new(0, 0, 0, 24)
PSub.BackgroundTransparency = 1
PSub.Text = "Recopilacion masiva de datos del perfil."
PSub.TextColor3 = Z.text2
PSub.Font = Enum.Font.Gotham
PSub.TextSize = 11
PSub.TextXAlignment = Enum.TextXAlignment.Left
PSub.ZIndex = 11
PSub.Parent = PScroll

local function pField(parent, label, value, y, color)
  color = color or Z.text
  local lbl = Instance.new("TextLabel")
  lbl.Size = UDim2.new(0.35, 0, 0, 18)
  lbl.Position = UDim2.new(0, 0, 0, y)
  lbl.BackgroundTransparency = 1
  lbl.Text = label
  lbl.TextColor3 = Z.text2
  lbl.Font = Enum.Font.Gotham
  lbl.TextSize = 11
  lbl.TextXAlignment = Enum.TextXAlignment.Left
  lbl.ZIndex = 11
  lbl.Parent = parent
  
  local val = Instance.new("TextLabel")
  val.Size = UDim2.new(0.65, -8, 0, 18)
  val.Position = UDim2.new(0.35, 8, 0, y)
  val.BackgroundColor3 = Z.surface
  val.BorderSizePixel = 0
  val.Text = tostring(value)
  val.TextColor3 = color
  val.Font = Enum.Font.GothamBold
  val.TextSize = 11
  val.TextXAlignment = Enum.TextXAlignment.Left
  val.ZIndex = 11
  val.Parent = parent
  corner(val, 4)
  stroke(val, Z.border, 1)
  return val
end

local function pSection(parent, title, y)
  local sep = Instance.new("TextLabel")
  sep.Size = UDim2.new(1, 0, 0, 18)
  sep.Position = UDim2.new(0, 0, 0, y)
  sep.BackgroundTransparency = 1
  sep.Text = title
  sep.TextColor3 = Z.lime
  sep.Font = Enum.Font.GothamBold
  sep.TextSize = 12
  sep.TextXAlignment = Enum.TextXAlignment.Left
  sep.ZIndex = 11
  sep.Parent = parent
  return y + 22
end

local y = 52
y = pSection(PScroll, "IDENTITY", y)
pField(PScroll, "UserId", LocalPlayer.UserId, y)
pField(PScroll, "Username", LocalPlayer.Name, y + 22)
pField(PScroll, "DisplayName", LocalPlayer.DisplayName, y + 44)
pField(PScroll, "AccountAge", LocalPlayer.AccountAge .. " dias", y + 66)
pField(PScroll, "Membership", tostring(LocalPlayer.MembershipType), y + 88)
pField(PScroll, "Verified", LocalPlayer.HasVerifiedBadge and "Yes" or "No", y + 110)

y = y + 140
y = pSection(PScroll, "NETWORK", y)
local country = safeCall(function() return game.LocalizationService:GetCountryRegionForPlayerAsync(LocalPlayer) end, "unknown")
local locale = safeCall(function() return game:GetService("LocalizationService").LocaleId end, "unknown")
pField(PScroll, "Country", country, y)
pField(PScroll, "Locale", locale, y + 22)
pField(PScroll, "Team", (LocalPlayer.Team and LocalPlayer.Team.Name) or "None", y + 44)
pField(PScroll, "TeamColor", (LocalPlayer.TeamColor and tostring(LocalPlayer.TeamColor)) or "None", y + 66)

y = y + 100
y = pSection(PScroll, "CHARACTER", y)
local char = LocalPlayer.Character
local hum = char and char:FindFirstChildOfClass("Humanoid")
local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
pField(PScroll, "Health", hum and string.format("%.0f / %.0f", hum.Health, hum.MaxHealth) or "N/A", y)
pField(PScroll, "WalkSpeed", hum and tostring(hum.WalkSpeed) or "N/A", y + 22)
pField(PScroll, "JumpPower", hum and tostring(hum.JumpPower) or "N/A", y + 44)
pField(PScroll, "HumanoidState", hum and tostring(hum:GetState()) or "N/A", y + 66)
pField(PScroll, "RigType", hum and tostring(hum.RigType) or "N/A", y + 88)
pField(PScroll, "Position", root and string.format("X:%d Y:%d Z:%d", math.floor(root.Position.X), math.floor(root.Position.Y), math.floor(root.Position.Z)) or "N/A", y + 110)

y = y + 140
y = pSection(PScroll, "DEVICE", y)
pField(PScroll, "Platform", tostring(UserInputService:GetPlatform()), y)
pField(PScroll, "Touch", tostring(UserInputService.TouchEnabled), y + 22)
pField(PScroll, "Mouse", tostring(UserInputService.MouseEnabled), y + 44)
pField(PScroll, "Keyboard", tostring(UserInputService.KeyboardEnabled), y + 66)
pField(PScroll, "Gamepad", tostring(UserInputService.GamepadEnabled), y + 88)
local res = safeCall(function()
  local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
  return gui and (gui.AbsoluteSize.X .. "x" .. gui.AbsoluteSize.Y) or "unknown"
end, "unknown")
pField(PScroll, "Resolution", res, y + 110)

PScroll.CanvasSize = UDim2.new(0, 0, 0, y + 140)

-- ============================================================
-- TAB 3: SERVER
-- ============================================================
local ServerTab = tabContainers[3]
local SScroll = Instance.new("ScrollingFrame")
SScroll.Size = UDim2.new(1, 0, 1, 0)
SScroll.BackgroundTransparency = 1
SScroll.ScrollBarThickness = 4
SScroll.ScrollBarImageColor3 = Z.lime
SScroll.CanvasSize = UDim2.new(0, 0, 0, 600)
SScroll.ZIndex = 10
SScroll.Parent = ServerTab
pad(SScroll, 16, 16, 16, 0)

local SHeader = Instance.new("TextLabel")
SHeader.Size = UDim2.new(1, 0, 0, 22)
SHeader.BackgroundTransparency = 1
SHeader.Text = "Server Intelligence"
SHeader.TextColor3 = Z.text
SHeader.Font = Enum.Font.GothamBold
SHeader.TextSize = 16
SHeader.TextXAlignment = Enum.TextXAlignment.Left
SHeader.ZIndex = 11
SHeader.Parent = SScroll

local SSub = Instance.new("TextLabel")
SSub.Size = UDim2.new(1, 0, 0, 18)
SSub.Position = UDim2.new(0, 0, 0, 24)
SSub.BackgroundTransparency = 1
SSub.Text = "Datos del entorno de ejecucion."
SSub.TextColor3 = Z.text2
SSub.Font = Enum.Font.Gotham
SSub.TextSize = 11
SSub.TextXAlignment = Enum.TextXAlignment.Left
SSub.ZIndex = 11
SSub.Parent = SScroll

local sy = 52
sy = pSection(SScroll, "GAME INSTANCE", sy)
pField(SScroll, "PlaceId", game.PlaceId, sy)
pField(SScroll, "JobId", game.JobId:sub(1, 20) .. "...", sy + 22)
local gname = safeCall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name end, "Unknown")
pField(SScroll, "Game Name", gname, sy + 44)
pField(SScroll, "MaxPlayers", game.Players.MaxPlayers, sy + 66)
pField(SScroll, "CurrentPlayers", #Players:GetPlayers(), sy + 88)
pField(SScroll, "IsLoaded", tostring(game.IsLoaded), sy + 110)
pField(SScroll, "PlaceVersion", game.PlaceVersion, sy + 132)

sy = sy + 160
sy = pSection(SScroll, "ENVIRONMENT", sy)
pField(SScroll, "TimeOfDay", Lighting.TimeOfDay, sy)
pField(SScroll, "Brightness", tostring(Lighting.Brightness), sy + 22)
pField(SScroll, "ClockTime", tostring(Lighting.ClockTime), sy + 44)
pField(SScroll, "GeographicLatitude", tostring(Lighting.GeographicLatitude), sy + 66)
pField(SScroll, "IsStudio", tostring(RunService:IsStudio()), sy + 88)
pField(SScroll, "IsClient", tostring(RunService:IsClient()), sy + 110)
pField(SScroll, "IsServer", tostring(RunService:IsServer()), sy + 132)

sy = sy + 160
sy = pSection(SScroll, "PHYSICS", sy)
pField(SScroll, "Gravity", tostring(workspace.Gravity), sy)
pField(SScroll, "FallenPartsDestroyHeight", tostring(workspace.FallenPartsDestroyHeight), sy + 22)
pField(SScroll, "InterpolationThrottling", tostring(workspace.InterpolationThrottling), sy + 44)
pField(SScroll, "StreamingEnabled", tostring(workspace.StreamingEnabled), sy + 66)

SScroll.CanvasSize = UDim2.new(0, 0, 0, sy + 100)

-- ============================================================
-- TAB 4: WEBHOOKS (dedicated tab for sending all data to WebhookPulse)
-- ============================================================
local WebhookTab = tabContainers[4]
pad(WebhookTab, 16, 16, 16, 16)

local WHeader = Instance.new("TextLabel")
WHeader.Size = UDim2.new(1, 0, 0, 22)
WHeader.BackgroundTransparency = 1
WHeader.Text = "WebhookPulse Transmitter"
WHeader.TextColor3 = Z.text
WHeader.Font = Enum.Font.GothamBold
WHeader.TextSize = 16
WHeader.TextXAlignment = Enum.TextXAlignment.Left
WHeader.Parent = WebhookTab

local WSub = Instance.new("TextLabel")
WSub.Size = UDim2.new(1, 0, 0, 18)
WSub.Position = UDim2.new(0, 0, 0, 24)
WSub.BackgroundTransparency = 1
WSub.Text = "Transmite TODOS los datos de ZEX al endpoint WebhookPulse."
WSub.TextColor3 = Z.text2
WSub.Font = Enum.Font.Gotham
WSub.TextSize = 11
WSub.TextXAlignment = Enum.TextXAlignment.Left
WSub.Parent = WebhookTab

-- URL input
local WURLLbl = Instance.new("TextLabel")
WURLLbl.Size = UDim2.new(1, 0, 0, 18)
WURLLbl.Position = UDim2.new(0, 0, 0, 52)
WURLLbl.BackgroundTransparency = 1
WURLLbl.Text = "Webhook URL"
WURLLbl.TextColor3 = Z.text2
WURLLbl.Font = Enum.Font.Gotham
WURLLbl.TextSize = 11
WURLLbl.TextXAlignment = Enum.TextXAlignment.Left
WURLLbl.Parent = WebhookTab

local WURLBox = Instance.new("TextBox")
WURLBox.Size = UDim2.new(1, 0, 0, 36)
WURLBox.Position = UDim2.new(0, 0, 0, 72)
WURLBox.BackgroundColor3 = Z.surface
WURLBox.BorderSizePixel = 0
WURLBox.Text = ""
WURLBox.PlaceholderText = "https://webhookpulse.vercel.app/api/webhook-receive?path=..."
WURLBox.TextColor3 = Z.text
WURLBox.PlaceholderColor3 = Z.text2
WURLBox.Font = Enum.Font.Gotham
WURLBox.TextSize = 11
WURLBox.TextXAlignment = Enum.TextXAlignment.Left
WURLBox.ClearTextOnFocus = false
WURLBox.Parent = WebhookTab
corner(WURLBox, 6)
stroke(WURLBox, Z.border, 1)
pad(WURLBox, 10, 0, 10, 0)

-- Data mode selector
local WModeLbl = Instance.new("TextLabel")
WModeLbl.Size = UDim2.new(1, 0, 0, 18)
WModeLbl.Position = UDim2.new(0, 0, 0, 118)
WModeLbl.BackgroundTransparency = 1
WModeLbl.Text = "Data Mode"
WModeLbl.TextColor3 = Z.text2
WModeLbl.Font = Enum.Font.Gotham
WModeLbl.TextSize = 11
WModeLbl.TextXAlignment = Enum.TextXAlignment.Left
WModeLbl.Parent = WebhookTab

local modes = {"FULL (all 40+ fields)", "IDENTITY only", "CHARACTER only", "MINIMAL (id+name)"}
local currentMode = 1

local WModeBtn = Instance.new("TextButton")
WModeBtn.Size = UDim2.new(1, 0, 0, 32)
WModeBtn.Position = UDim2.new(0, 0, 0, 138)
WModeBtn.BackgroundColor3 = Z.surface
WModeBtn.BorderSizePixel = 0
WModeBtn.Text = "  " .. modes[1]
WModeBtn.TextColor3 = Z.text
WModeBtn.Font = Enum.Font.GothamBold
WModeBtn.TextSize = 11
WModeBtn.TextXAlignment = Enum.TextXAlignment.Left
WModeBtn.Parent = WebhookTab
corner(WModeBtn, 6)
stroke(WModeBtn, Z.border, 1)

WModeBtn.MouseButton1Click:Connect(function()
  currentMode = currentMode % #modes + 1
  WModeBtn.Text = "  " .. modes[currentMode]
end)

-- Secret input
local WSecretLbl = Instance.new("TextLabel")
WSecretLbl.Size = UDim2.new(1, 0, 0, 18)
WSecretLbl.Position = UDim2.new(0, 0, 0, 178)
WSecretLbl.BackgroundTransparency = 1
WSecretLbl.Text = "Webhook Secret (opcional)"
WSecretLbl.TextColor3 = Z.text2
WSecretLbl.Font = Enum.Font.Gotham
WSecretLbl.TextSize = 11
WSecretLbl.TextXAlignment = Enum.TextXAlignment.Left
WSecretLbl.Parent = WebhookTab

local WSecretBox = Instance.new("TextBox")
WSecretBox.Size = UDim2.new(1, 0, 0, 32)
WSecretBox.Position = UDim2.new(0, 0, 0, 198)
WSecretBox.BackgroundColor3 = Z.surface
WSecretBox.BorderSizePixel = 0
WSecretBox.Text = ""
WSecretBox.PlaceholderText = "X-Webhook-Secret header"
WSecretBox.TextColor3 = Z.text
WSecretBox.PlaceholderColor3 = Z.text2
WSecretBox.Font = Enum.Font.Gotham
WSecretBox.TextSize = 11
WSecretBox.TextXAlignment = Enum.TextXAlignment.Left
WSecretBox.ClearTextOnFocus = false
WSecretBox.Parent = WebhookTab
corner(WSecretBox, 6)
stroke(WSecretBox, Z.border, 1)
pad(WSecretBox, 10, 0, 10, 0)

-- Log scroll
local WLogScroll = Instance.new("ScrollingFrame")
WLogScroll.Size = UDim2.new(1, 0, 0, 100)
WLogScroll.Position = UDim2.new(0, 0, 0, 240)
WLogScroll.BackgroundColor3 = Z.surface
WLogScroll.BorderSizePixel = 0
WLogScroll.ScrollBarThickness = 4
WLogScroll.ScrollBarImageColor3 = Z.lime
WLogScroll.CanvasSize = UDim2.new(0, 0, 0, 100)
WLogScroll.ZIndex = 11
WLogScroll.Parent = WebhookTab
corner(WLogScroll, 6)
stroke(WLogScroll, Z.border, 1)

local WLogText = Instance.new("TextLabel")
WLogText.Size = UDim2.new(1, -16, 0, 0)
WLogText.Position = UDim2.new(0, 8, 0, 8)
WLogText.BackgroundTransparency = 1
WLogText.Text = "Esperando transmision..."
WLogText.TextColor3 = Z.text2
WLogText.Font = Enum.Font.Gotham
WLogText.TextSize = 11
WLogText.TextXAlignment = Enum.TextXAlignment.Left
WLogText.TextYAlignment = Enum.TextYAlignment.Top
WLogText.TextWrapped = true
WLogText.AutomaticSize = Enum.AutomaticSize.Y
WLogText.ZIndex = 12
WLogText.Parent = WLogScroll

local function wLog(msg, color)
  color = color or Z.text2
  local t = os.date("%H:%M:%S")
  WLogText.Text = "[" .. t .. "] " .. msg .. "\n" .. WLogText.Text
  WLogText.TextColor3 = color
  local bounds = TextService:GetTextSize(WLogText.Text, WLogText.TextSize, WLogText.Font, Vector2.new(WLogScroll.AbsoluteSize.X - 16, 9999))
  local h = math.max(20, bounds.Y + 16)
  WLogText.Size = UDim2.new(1, -16, 0, h)
  WLogScroll.CanvasSize = UDim2.new(0, 0, 0, h + 16)
end

-- Transmit button
local WTransmit = Instance.new("TextButton")
WTransmit.Size = UDim2.new(1, 0, 0, 44)
WTransmit.Position = UDim2.new(0, 0, 1, -52)
WTransmit.BackgroundColor3 = Z.lime
WTransmit.BorderSizePixel = 0
WTransmit.Text = "TRANSMITIR TODO A WEBHOOKPULSE"
WTransmit.TextColor3 = Z.bg
WTransmit.Font = Enum.Font.GothamBold
WTransmit.TextSize = 13
WTransmit.Parent = WebhookTab
corner(WTransmit, 6)

WTransmit.MouseEnter:Connect(function() WTransmit.BackgroundColor3 = Z.lime2 end)
WTransmit.MouseLeave:Connect(function() WTransmit.BackgroundColor3 = Z.lime end)

WTransmit.MouseButton1Click:Connect(function()
  local url = WURLBox.Text:match("^%s*(.-)%s*$")
  if url == "" then wLog("Error: URL vacia", Z.danger); return end
  
  wLog("Construyendo payload completo...", Z.info)
  
  local payload = {
    source = "roblox",
    timestamp = os.time(),
    executor = { name = safeCall(function() return identifyexecutor() end, "unknown") },
  }
  
  if currentMode == 1 or currentMode == 2 or currentMode == 4 then
    payload.player = {
      userid = LocalPlayer.UserId,
      username = LocalPlayer.Name,
      displayname = LocalPlayer.DisplayName,
      accountage = LocalPlayer.AccountAge,
      membership = tostring(LocalPlayer.MembershipType),
      premium = safeCall(function() return LocalPlayer:IsInGroup(1) or false end, false),
      verified = LocalPlayer.HasVerifiedBadge or false,
      country = safeCall(function() return game.LocalizationService:GetCountryRegionForPlayerAsync(LocalPlayer) end, "unknown"),
      team = (LocalPlayer.Team and LocalPlayer.Team.Name) or nil,
      teamcolor = (LocalPlayer.TeamColor and tostring(LocalPlayer.TeamColor)) or nil,
      neutral = LocalPlayer.Neutral,
      characterappearanceid = LocalPlayer.CharacterAppearanceId or nil,
      locale = safeCall(function() return game:GetService("LocalizationService").LocaleId end, "unknown"),
    }
  end
  
  if currentMode == 1 or currentMode == 3 then
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
    payload.character = {
      health = hum and hum.Health or nil,
      maxhealth = hum and hum.MaxHealth or nil,
      walkspeed = hum and hum.WalkSpeed or nil,
      jumppower = hum and hum.JumpPower or nil,
      humanoidstate = hum and tostring(hum:GetState()) or nil,
      rigtype = hum and tostring(hum.RigType) or nil,
      position = root and { x = math.floor(root.Position.X), y = math.floor(root.Position.Y), z = math.floor(root.Position.Z) } or nil,
      velocity = root and { x = math.floor(root.Velocity.X), y = math.floor(root.Velocity.Y), z = math.floor(root.Velocity.Z) } or nil,
    }
  end
  
  if currentMode == 1 then
    payload.game = {
      placeid = game.PlaceId,
      jobid = game.JobId,
      gamename = safeCall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name end, "Unknown"),
      maxplayers = game.Players.MaxPlayers,
      numplayers = #Players:GetPlayers(),
      isloaded = game.IsLoaded,
    }
    payload.environment = {
      timeofday = Lighting.TimeOfDay,
      brightness = Lighting.Brightness,
      clocktime = Lighting.ClockTime,
      geographiclatitude = Lighting.GeographicLatitude,
      isstudio = RunService:IsStudio(),
      isclient = RunService:IsClient(),
      isserver = RunService:IsServer(),
    }
    payload.device = {
      os = tostring(UserInputService:GetPlatform()),
      touchenabled = UserInputService.TouchEnabled,
      mouseenabled = UserInputService.MouseEnabled,
      keyboardenabled = UserInputService.KeyboardEnabled,
      gamepadenabled = UserInputService.GamepadEnabled,
      screenresolution = safeCall(function()
        local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        return gui and (gui.AbsoluteSize.X .. "x" .. gui.AbsoluteSize.Y) or nil
      end, nil),
    }
  end
  
  if currentMode == 4 then
    payload = { source = "roblox", timestamp = os.time(), player = { userid = LocalPlayer.UserId, username = LocalPlayer.Name } }
  end
  
  local body = HttpService:JSONEncode(payload)
  wLog("Payload size: " .. tostring(#body) .. " bytes", Z.info)
  
  local headers = { ["Content-Type"] = "application/json" }
  local secret = WSecretBox.Text:match("^%s*(.-)%s*$")
  if secret ~= "" then headers["X-Webhook-Secret"] = secret end
  
  local reqTable = { Url = url, Method = "POST", Headers = headers, Body = body }
  local success = false
  local attempts = {}
  
  local function tryHttp(fn, name)
    if not fn then table.insert(attempts, name .. ": no disponible"); return false end
    local ok, res = pcall(function() return fn(reqTable) end)
    if ok and res then
      local parsed = parseResponse(res)
      if parsed.status >= 200 and parsed.status < 300 and parsed.isSuccess then
        table.insert(attempts, name .. ": OK " .. parsed.status .. " [success]")
        return true
      elseif parsed.status >= 200 and parsed.status < 300 and parsed.isHoneypot then
        table.insert(attempts, name .. ": HTTP " .. parsed.status .. " [honeypot — webhook no existe o secreto invalido]")
      elseif parsed.status >= 200 and parsed.status < 300 then
        table.insert(attempts, name .. ": HTTP " .. parsed.status .. " [respuesta: " .. parsed.body:sub(1, 50) .. "]")
      else
        table.insert(attempts, name .. ": HTTP " .. tostring(parsed.status))
      end
    else
      table.insert(attempts, name .. ": " .. tostring(res))
    end
    return false
  end
  
  success = tryHttp(request, "request()")
  if not success then success = tryHttp(getgenv().request, "getgenv().request") end
  if not success then success = tryHttp(http and http.request, "http.request") end
  if not success then success = tryHttp(syn and syn.request, "syn.request") end
  if not success then success = tryHttp(fluxus and fluxus.request, "fluxus.request") end
  if not success then success = tryHttp(delta and delta.request, "delta.request") end
  
  if not success then
    local ok, res = pcall(function() return HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson) end)
    if ok then
      local parsed = parseResponse({ Body = res, StatusCode = 200 })
      if parsed.isSuccess then
        success = true
        table.insert(attempts, "HttpService:PostAsync: OK 200 [success]")
      elseif parsed.isHoneypot then
        table.insert(attempts, "HttpService:PostAsync: OK 200 [honeypot]")
      else
        success = true
        table.insert(attempts, "HttpService:PostAsync: OK 200")
      end
    else
      table.insert(attempts, "HttpService:PostAsync: " .. tostring(res))
    end
  end
  
  if success then
    wLog("EXITOSO. Datos guardados en WebhookPulse.", Z.success)
    wLog("Intentos:\n" .. table.concat(attempts, "\n"), Z.success)
  elseif #attempts > 0 and string.find(table.concat(attempts), "honeypot") then
    wLog("FALLIDO. El servidor rechazo la peticion (honeypot).", Z.danger)
    wLog("Causas posibles: webhook no existe, secreto incorrecto, o webhook inactivo.", Z.danger)
    wLog("Intentos:\n" .. table.concat(attempts, "\n"), Z.text2)
  else
    wLog("FALLIDO. Ningun metodo HTTP funciono.", Z.danger)
    wLog("Intentos:\n" .. table.concat(attempts, "\n"), Z.danger)
  end
end)

-- ============================================================
-- TAB 5: NETWORK (raw HTTP tester)
-- ============================================================
local NetTab = tabContainers[5]
pad(NetTab, 16, 16, 16, 16)

local NHeader = Instance.new("TextLabel")
NHeader.Size = UDim2.new(1, 0, 0, 22)
NHeader.BackgroundTransparency = 1
NHeader.Text = "Network Operations"
NHeader.TextColor3 = Z.text
NHeader.Font = Enum.Font.GothamBold
NHeader.TextSize = 16
NHeader.TextXAlignment = Enum.TextXAlignment.Left
NHeader.Parent = NetTab

local NSub = Instance.new("TextLabel")
NSub.Size = UDim2.new(1, 0, 0, 18)
NSub.Position = UDim2.new(0, 0, 0, 24)
NSub.BackgroundTransparency = 1
NSub.Text = "HTTP raw tester con 6 fallbacks."
NSub.TextColor3 = Z.text2
NSub.Font = Enum.Font.Gotham
NSub.TextSize = 11
NSub.TextXAlignment = Enum.TextXAlignment.Left
NSub.Parent = NetTab

local NURLBox = Instance.new("TextBox")
NURLBox.Size = UDim2.new(1, 0, 0, 36)
NURLBox.Position = UDim2.new(0, 0, 0, 52)
NURLBox.BackgroundColor3 = Z.surface
NURLBox.BorderSizePixel = 0
NURLBox.Text = ""
NURLBox.PlaceholderText = "https://httpbin.org/post"
NURLBox.TextColor3 = Z.text
NURLBox.PlaceholderColor3 = Z.text2
NURLBox.Font = Enum.Font.Gotham
NURLBox.TextSize = 11
NURLBox.TextXAlignment = Enum.TextXAlignment.Left
NURLBox.Parent = NetTab
corner(NURLBox, 6)
stroke(NURLBox, Z.border, 1)
pad(NURLBox, 10, 0, 10, 0)

local NBodyBox = Instance.new("TextBox")
NBodyBox.Size = UDim2.new(1, 0, 0, 60)
NBodyBox.Position = UDim2.new(0, 0, 0, 96)
NBodyBox.BackgroundColor3 = Z.surface
NBodyBox.BorderSizePixel = 0
NBodyBox.Text = "{\"test\":true}"
NBodyBox.PlaceholderText = "JSON body..."
NBodyBox.TextColor3 = Z.text
NBodyBox.PlaceholderColor3 = Z.text2
NBodyBox.Font = Enum.Font.Gotham
NBodyBox.TextSize = 11
NBodyBox.TextXAlignment = Enum.TextXAlignment.Left
NBodyBox.TextYAlignment = Enum.TextYAlignment.Top
NBodyBox.TextWrapped = true
NBodyBox.ClearTextOnFocus = false
NBodyBox.Parent = NetTab
corner(NBodyBox, 6)
stroke(NBodyBox, Z.border, 1)
pad(NBodyBox, 10, 10, 10, 10)

local NLogScroll = Instance.new("ScrollingFrame")
NLogScroll.Size = UDim2.new(1, 0, 0, 100)
NLogScroll.Position = UDim2.new(0, 0, 0, 166)
NLogScroll.BackgroundColor3 = Z.surface
NLogScroll.BorderSizePixel = 0
NLogScroll.ScrollBarThickness = 4
NLogScroll.ScrollBarImageColor3 = Z.lime
NLogScroll.CanvasSize = UDim2.new(0, 0, 0, 100)
NLogScroll.ZIndex = 11
NLogScroll.Parent = NetTab
corner(NLogScroll, 6)
stroke(NLogScroll, Z.border, 1)

local NLogText = Instance.new("TextLabel")
NLogText.Size = UDim2.new(1, -16, 0, 0)
NLogText.Position = UDim2.new(0, 8, 0, 8)
NLogText.BackgroundTransparency = 1
NLogText.Text = "Esperando..."
NLogText.TextColor3 = Z.text2
NLogText.Font = Enum.Font.Gotham
NLogText.TextSize = 11
NLogText.TextXAlignment = Enum.TextXAlignment.Left
NLogText.TextYAlignment = Enum.TextYAlignment.Top
NLogText.TextWrapped = true
NLogText.AutomaticSize = Enum.AutomaticSize.Y
NLogText.ZIndex = 12
NLogText.Parent = NLogScroll

local function nLog(msg, color)
  color = color or Z.text2
  local t = os.date("%H:%M:%S")
  NLogText.Text = "[" .. t .. "] " .. msg .. "\n" .. NLogText.Text
  NLogText.TextColor3 = color
  local bounds = TextService:GetTextSize(NLogText.Text, NLogText.TextSize, NLogText.Font, Vector2.new(NLogScroll.AbsoluteSize.X - 16, 9999))
  local h = math.max(20, bounds.Y + 16)
  NLogText.Size = UDim2.new(1, -16, 0, h)
  NLogScroll.CanvasSize = UDim2.new(0, 0, 0, h + 16)
end

local NSend = Instance.new("TextButton")
NSend.Size = UDim2.new(1, 0, 0, 40)
NSend.Position = UDim2.new(0, 0, 1, -48)
NSend.BackgroundColor3 = Z.lime
NSend.BorderSizePixel = 0
NSend.Text = "SEND RAW HTTP"
NSend.TextColor3 = Z.bg
NSend.Font = Enum.Font.GothamBold
NSend.TextSize = 13
NSend.Parent = NetTab
corner(NSend, 6)

NSend.MouseEnter:Connect(function() NSend.BackgroundColor3 = Z.lime2 end)
NSend.MouseLeave:Connect(function() NSend.BackgroundColor3 = Z.lime end)

NSend.MouseButton1Click:Connect(function()
  local url = NURLBox.Text:match("^%s*(.-)%s*$")
  if url == "" then nLog("Error: URL vacia", Z.danger); return end
  local body = NBodyBox.Text
  nLog("Enviando a " .. url .. "...", Z.info)
  
  local reqTable = { Url = url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = body }
  local success = false
  local attempts = {}
  
  local function tryHttp(fn, name)
    if not fn then table.insert(attempts, name .. ": no disp"); return false end
    local ok, res = pcall(function() return fn(reqTable) end)
    if ok and res then
      local parsed = parseResponse(res)
      if parsed.status >= 200 and parsed.status < 300 and parsed.isSuccess then
        table.insert(attempts, name .. ": OK " .. parsed.status .. " [success]"); return true
      elseif parsed.status >= 200 and parsed.status < 300 and parsed.isHoneypot then
        table.insert(attempts, name .. ": HTTP " .. parsed.status .. " [honeypot]")
      elseif parsed.status >= 200 and parsed.status < 300 then
        table.insert(attempts, name .. ": HTTP " .. parsed.status .. " [resp: " .. parsed.body:sub(1, 40) .. "]")
      else
        table.insert(attempts, name .. ": HTTP " .. tostring(parsed.status))
      end
    else
      table.insert(attempts, name .. ": " .. tostring(res))
    end
    return false
  end
  
  success = tryHttp(request, "request()")
  if not success then success = tryHttp(getgenv().request, "getgenv().request") end
  if not success then success = tryHttp(http and http.request, "http.request") end
  if not success then success = tryHttp(syn and syn.request, "syn.request") end
  if not success then success = tryHttp(fluxus and fluxus.request, "fluxus.request") end
  if not success then success = tryHttp(delta and delta.request, "delta.request") end
  
  if not success then
    local ok, res = pcall(function() return HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson) end)
    if ok then
      local parsed = parseResponse({ Body = res, StatusCode = 200 })
      if parsed.isSuccess then
        success = true
        table.insert(attempts, "HttpService: OK 200 [success]")
      elseif parsed.isHoneypot then
        table.insert(attempts, "HttpService: OK 200 [honeypot]")
      else
        success = true
        table.insert(attempts, "HttpService: OK 200")
      end
    else
      table.insert(attempts, "HttpService: " .. tostring(res))
    end
  end
  
  if success then
    nLog("EXITOSO. Respuesta valida del servidor.", Z.success)
    nLog("Intentos:\n" .. table.concat(attempts, "\n"), Z.success)
  elseif #attempts > 0 and string.find(table.concat(attempts), "honeypot") then
    nLog("FALLIDO. Servidor rechazo (honeypot).", Z.danger)
    nLog("Intentos:\n" .. table.concat(attempts, "\n"), Z.text2)
  else
    nLog("FALLIDO. Ningun metodo HTTP funciono.", Z.danger)
    nLog("Intentos:\n" .. table.concat(attempts, "\n"), Z.danger)
  end
end)

-- ============================================================
-- TAB 6: COMMANDS
-- ============================================================
local CmdTab = tabContainers[6]
local CScroll = Instance.new("ScrollingFrame")
CScroll.Size = UDim2.new(1, 0, 1, 0)
CScroll.BackgroundTransparency = 1
CScroll.ScrollBarThickness = 4
CScroll.ScrollBarImageColor3 = Z.lime
CScroll.CanvasSize = UDim2.new(0, 0, 0, 400)
CScroll.ZIndex = 10
CScroll.Parent = CmdTab
pad(CScroll, 16, 16, 16, 0)

local CHeader = Instance.new("TextLabel")
CHeader.Size = UDim2.new(1, 0, 0, 22)
CHeader.BackgroundTransparency = 1
CHeader.Text = "Command Center"
CHeader.TextColor3 = Z.text
CHeader.Font = Enum.Font.GothamBold
CHeader.TextSize = 16
CHeader.TextXAlignment = Enum.TextXAlignment.Left
CHeader.ZIndex = 11
CHeader.Parent = CScroll

local CSub = Instance.new("TextLabel")
CSub.Size = UDim2.new(1, 0, 0, 18)
CSub.Position = UDim2.new(0, 0, 0, 24)
CSub.BackgroundTransparency = 1
CSub.Text = "Acciones de control del entorno."
CSub.TextColor3 = Z.text2
CSub.Font = Enum.Font.Gotham
CSub.TextSize = 11
CSub.TextXAlignment = Enum.TextXAlignment.Left
CSub.ZIndex = 11
CSub.Parent = CScroll

local function cmdBtn(parent, label, y, color, action)
  color = color or Z.lime
  local btn = Instance.new("TextButton")
  btn.Size = UDim2.new(1, 0, 0, 36)
  btn.Position = UDim2.new(0, 0, 0, y)
  btn.BackgroundColor3 = Z.surface
  btn.BorderSizePixel = 0
  btn.Text = "  " .. label
  btn.TextColor3 = color
  btn.Font = Enum.Font.GothamBold
  btn.TextSize = 12
  btn.TextXAlignment = Enum.TextXAlignment.Left
  btn.ZIndex = 11
  btn.Parent = parent
  corner(btn, 6)
  stroke(btn, Z.border, 1)
  btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Z.elevated end)
  btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Z.surface end)
  btn.MouseButton1Click:Connect(function()
    local ok, err = pcall(action)
    if not ok then print("[ZEX CMD ERROR] " .. tostring(err)) end
  end)
  return btn
end

local cy = 52
cmdBtn(CScroll, "Rejoin Server", cy, Z.info, function()
  TeleportService:Teleport(game.PlaceId, LocalPlayer)
end)
cy = cy + 44
cmdBtn(CScroll, "Reset Character", cy, Z.danger, function()
  local char = LocalPlayer.Character
  if char then
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.Health = 0 end
  end
end)
cy = cy + 44
cmdBtn(CScroll, "Fullbright", cy, Z.lime, function()
  Lighting.Brightness = 10
  Lighting.GlobalShadows = false
  Lighting.Ambient = Color3.fromRGB(255, 255, 255)
  Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
end)
cy = cy + 44
cmdBtn(CScroll, "Restore Lighting", cy, Z.text2, function()
  Lighting.Brightness = 2
  Lighting.GlobalShadows = true
  Lighting.Ambient = Color3.fromRGB(127, 127, 127)
  Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
end)
cy = cy + 44
cmdBtn(CScroll, "Low Graphics", cy, Z.info, function()
  settings().Rendering.QualityLevel = 1
end)
cy = cy + 44
cmdBtn(CScroll, "Max Graphics", cy, Z.info, function()
  settings().Rendering.QualityLevel = 10
end)

CScroll.CanvasSize = UDim2.new(0, 0, 0, cy + 60)

-- ============================================================
-- TAB 7: CONSOLE
-- ============================================================
local ConsoleTab = tabContainers[7]
pad(ConsoleTab, 16, 16, 16, 16)

local CoHeader = Instance.new("TextLabel")
CoHeader.Size = UDim2.new(1, 0, 0, 22)
CoHeader.BackgroundTransparency = 1
CoHeader.Text = "System Console"
CoHeader.TextColor3 = Z.text
CoHeader.Font = Enum.Font.GothamBold
CoHeader.TextSize = 16
CoHeader.TextXAlignment = Enum.TextXAlignment.Left
CoHeader.Parent = ConsoleTab

local CoSub = Instance.new("TextLabel")
CoSub.Size = UDim2.new(1, 0, 0, 18)
CoSub.Position = UDim2.new(0, 0, 0, 24)
CoSub.BackgroundTransparency = 1
CoSub.Text = "Log de operaciones en tiempo real."
CoSub.TextColor3 = Z.text2
CoSub.Font = Enum.Font.Gotham
CoSub.TextSize = 11
CoSub.TextXAlignment = Enum.TextXAlignment.Left
CoSub.Parent = ConsoleTab

local CoScroll = Instance.new("ScrollingFrame")
CoScroll.Size = UDim2.new(1, 0, 1, -80)
CoScroll.Position = UDim2.new(0, 0, 0, 48)
CoScroll.BackgroundColor3 = Z.surface
CoScroll.BorderSizePixel = 0
CoScroll.ScrollBarThickness = 4
CoScroll.ScrollBarImageColor3 = Z.lime
CoScroll.CanvasSize = UDim2.new(0, 0, 0, 300)
CoScroll.ZIndex = 11
CoScroll.Parent = ConsoleTab
corner(CoScroll, 6)
stroke(CoScroll, Z.border, 1)

local CoText = Instance.new("TextLabel")
CoText.Size = UDim2.new(1, -16, 0, 0)
CoText.Position = UDim2.new(0, 8, 0, 8)
CoText.BackgroundTransparency = 1
CoText.Text = "[ZEX] System initialized.\n[ZEX] Waiting for commands..."
CoText.TextColor3 = Z.text2
CoText.Font = Enum.Font.Gotham
CoText.TextSize = 11
CoText.TextXAlignment = Enum.TextXAlignment.Left
CoText.TextYAlignment = Enum.TextYAlignment.Top
CoText.TextWrapped = true
CoText.AutomaticSize = Enum.AutomaticSize.Y
CoText.ZIndex = 12
CoText.Parent = CoScroll

local function consoleLog(msg, color)
  color = color or Z.text2
  local t = os.date("%H:%M:%S")
  CoText.Text = CoText.Text .. "\n[" .. t .. "] " .. msg
  CoText.TextColor3 = color
  local bounds = TextService:GetTextSize(CoText.Text, CoText.TextSize, CoText.Font, Vector2.new(CoScroll.AbsoluteSize.X - 16, 9999))
  local h = math.max(20, bounds.Y + 16)
  CoText.Size = UDim2.new(1, -16, 0, h)
  CoScroll.CanvasSize = UDim2.new(0, 0, 0, h + 16)
  CoScroll.CanvasPosition = Vector2.new(0, math.max(0, CoScroll.CanvasSize.Y.Offset - CoScroll.AbsoluteSize.Y))
end

local CoClear = Instance.new("TextButton")
CoClear.Size = UDim2.new(0.48, 0, 0, 32)
CoClear.Position = UDim2.new(0, 0, 1, -32)
CoClear.BackgroundColor3 = Z.elevated
CoClear.BorderSizePixel = 0
CoClear.Text = "Clear"
CoClear.TextColor3 = Z.text2
CoClear.Font = Enum.Font.GothamBold
CoClear.TextSize = 12
CoClear.Parent = ConsoleTab
corner(CoClear, 6)
stroke(CoClear, Z.border, 1)
CoClear.MouseButton1Click:Connect(function()
  CoText.Text = "[ZEX] Console cleared."
  CoText.Size = UDim2.new(1, -16, 0, 20)
  CoScroll.CanvasSize = UDim2.new(0, 0, 0, 36)
end)

local CoExport = Instance.new("TextButton")
CoExport.Size = UDim2.new(0.48, 0, 0, 32)
CoExport.Position = UDim2.new(0.52, 0, 1, -32)
CoExport.BackgroundColor3 = Z.lime
CoExport.BorderSizePixel = 0
CoExport.Text = "Copy Log"
CoExport.TextColor3 = Z.bg
CoExport.Font = Enum.Font.GothamBold
CoExport.TextSize = 12
CoExport.Parent = ConsoleTab
corner(CoExport, 6)
CoExport.MouseButton1Click:Connect(function()
  local ok = pcall(function() setclipboard(CoText.Text) end)
  if ok then consoleLog("Log copied to clipboard.", Z.success) end
end)

-- ============================================================
-- DRAG SYSTEM
-- ============================================================
local dragging, dragStart, startPos = false, nil, nil
TopBar.InputBegan:Connect(function(input)
  if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    dragging = true
    dragStart = input.Position
    startPos = Main.Position
    input.Changed:Connect(function()
      if input.UserInputState == Enum.UserInputState.End then dragging = false end
    end)
  end
end)
TopBar.InputChanged:Connect(function(input)
  if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
    local delta = input.Position - dragStart
    Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
  end
end)

-- ============================================================
-- KEYBIND TOGGLE (RightShift)
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gp)
  if gp then return end
  if input.KeyCode == Enum.KeyCode.RightShift then
    SG.Enabled = not SG.Enabled
  end
end)

-- ============================================================
-- INIT
-- ============================================================
consoleLog("ZEX v7.0 initialized.", Z.lime)
consoleLog("Executor: " .. safeCall(function() return identifyexecutor() end, "unknown"), Z.info)
consoleLog("Player: " .. LocalPlayer.Name .. " (" .. LocalPlayer.UserId .. ")", Z.info)
consoleLog("Press RightShift to toggle GUI.", Z.text2)

print("[ZEX] v7.0 Elite Controller loaded. RightShift to toggle.")
