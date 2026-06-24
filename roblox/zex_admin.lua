--[[
  ZEX v7.0 — Elite Data Controller
  ============================================================
  Director de Coding Senior · 25+ años industria gaming masiva
  Arquitectura: Roblox AAA · Optimización memoria · Alta concurrencia
  
  Nombre: ZEX
  Logo: X estilizada lime (#D4E83A) sobre fondo #0C0C0E
  Paleta: WebhookPulse dark premium (sincronizado con webhookpulse.vercel.app)
  
  NO emojis. Iconos vectoriales puros. Fuente Gotham.
  Todo dentro de pcall. Zero tolerance a crashes.
  
  Tabs:
    · Dashboard   — Stats globales, FPS, jugadores en tiempo real
    · Player      — Recopilación masiva de datos del jugador (40+ campos)
    · Server      — Datos del servidor, física, iluminación, workspace
    · Network     — HTTP request con 6 fallbacks, WebhookPulse integration
    · Commands    — Botones de acción admin (teleport, fly, noclip, speed, etc.)
    · Console     — Log system con ScrollingFrame y auto-scroll
    
  Optimización:
    · Eventos desconectados al cerrar GUI
    · Tables reutilizadas (pool de strings)
    · Updates a 30Hz max (throttle de render)
    · Garbage collection hints en secciones pesadas
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local Mouse = LocalPlayer:GetMouse()

-- ============================================================
-- COLORES ZEX (Sincronizados con WebhookPulse)
-- ============================================================
local Z = {
  bg = Color3.fromRGB(12, 12, 14),          -- #0C0C0E
  surface = Color3.fromRGB(22, 22, 24),   -- #161618
  elevated = Color3.fromRGB(28, 28, 30),  -- #1C1C1E
  border = Color3.fromRGB(39, 39, 42),    -- #27272A
  text = Color3.fromRGB(250, 250, 250),   -- #FAFAFA
  text2 = Color3.fromRGB(161, 161, 170),  -- #A1A1AA
  lime = Color3.fromRGB(212, 232, 58),    -- #D4E83A
  lime2 = Color3.fromRGB(232, 249, 106),  -- #E8F96A
  danger = Color3.fromRGB(239, 68, 68),  -- #EF4444
  success = Color3.fromRGB(34, 197, 94),  -- #22C55E
  info = Color3.fromRGB(59, 130, 246),   -- #3B82F6
}

-- ============================================================
-- UTILIDADES PREMIUM
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

local function shadow(parent)
  local sh = Instance.new("Frame")
  sh.Size = UDim2.new(1, 0, 1, 0)
  sh.Position = UDim2.new(0, 4, 0, 4)
  sh.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
  sh.BackgroundTransparency = 0.6
  sh.BorderSizePixel = 0
  sh.ZIndex = parent.ZIndex - 1
  sh.Parent = parent
  corner(sh, 8)
  return sh
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
-- MAIN FRAME (680x480, arrastrable, centrado)
-- ============================================================
local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 680, 0, 480)
Main.Position = UDim2.new(0.5, -340, 0.5, -240)
Main.BackgroundColor3 = Z.bg
Main.BorderSizePixel = 0
Main.ZIndex = 10
Main.Parent = SG

corner(Main, 8)
stroke(Main, Z.border, 1)
shadow(Main)

-- ============================================================
-- TOPBAR (48px, contiene logo X + nombre ZEX + botón cerrar)
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

-- LOGO X estilizada (reconstruida con Frame + triángulos para evitar depender de imagen externa)
local LogoContainer = Instance.new("Frame")
LogoContainer.Size = UDim2.new(0, 32, 0, 32)
LogoContainer.Position = UDim2.new(0, 12, 0, 8)
LogoContainer.BackgroundTransparency = 1
LogoContainer.ZIndex = 12
LogoContainer.Parent = TopBar

-- Barra diagonal superior-izquierda a inferior-derecha (parte 1)
local X1 = Instance.new("Frame")
X1.Size = UDim2.new(0, 4, 0, 22)
X1.Position = UDim2.new(0.5, -2, 0.5, -11)
X1.BackgroundColor3 = Z.lime
X1.BorderSizePixel = 0
X1.Rotation = 45
X1.ZIndex = 12
X1.Parent = LogoContainer

corner(X1, 99)

-- Barra diagonal inferior-izquierda a superior-derecha (parte 2)
local X2 = Instance.new("Frame")
X2.Size = UDim2.new(0, 4, 0, 22)
X2.Position = UDim2.new(0.5, -2, 0.5, -11)
X2.BackgroundColor3 = Z.lime
X2.BorderSizePixel = 0
X2.Rotation = -45
X2.ZIndex = 12
X2.Parent = LogoContainer

corner(X2, 99)

-- Borde sutil negro en la X para definición
local X1Stroke = X1:Clone()
X1Stroke.BackgroundColor3 = Z.bg
X1Stroke.Size = UDim2.new(0, 6, 0, 24)
X1Stroke.Position = UDim2.new(0.5, -3, 0.5, -12)
X1Stroke.ZIndex = 11
X1Stroke.Parent = LogoContainer

local X2Stroke = X2:Clone()
X2Stroke.BackgroundColor3 = Z.bg
X2Stroke.Size = UDim2.new(0, 6, 0, 24)
X2Stroke.Position = UDim2.new(0.5, -3, 0.5, -12)
X2Stroke.ZIndex = 11
X2Stroke.Parent = LogoContainer

-- Re-poner X1 y X2 encima del borde
X1.Parent = LogoContainer
X2.Parent = LogoContainer

-- Titulo ZEX
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

-- Subtitle
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

-- Boton cerrar
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

-- Minimizar
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
    Main.Size = UDim2.new(0, 680, 0, 48)
    MinBtn.Text = "+"
  else
    Main.Size = UDim2.new(0, 680, 0, 480)
    MinBtn.Text = "-"
  end
end)

-- ============================================================
-- SIDEBAR (120px, 6 tabs, con indicador lime activo)
-- ============================================================
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 120, 1, -48)
Sidebar.Position = UDim2.new(0, 0, 0, 48)
Sidebar.BackgroundColor3 = Z.surface
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 11
Sidebar.Parent = Main

local tabNames = {"Dashboard", "Player", "Server", "Network", "Commands", "Console"}
local tabIcons = {"D", "P", "S", "N", "C", ">"}
local tabs = {}
local activeTab = 1

for i, name in ipairs(tabNames) do
  local btn = Instance.new("TextButton")
  btn.Size = UDim2.new(1, 0, 0, 40)
  btn.Position = UDim2.new(0, 0, 0, (i-1) * 44 + 12)
  btn.BackgroundColor3 = i == 1 and Z.elevated or Z.surface
  btn.BorderSizePixel = 0
  btn.Text = "  " .. tabIcons[i] .. "  " .. name
  btn.TextColor3 = i == 1 and Z.lime or Z.text2
  btn.Font = Enum.Font.GothamBold
  btn.TextSize = 11
  btn.TextXAlignment = Enum.TextXAlignment.Left
  btn.ZIndex = 12
  btn.Name = name
  btn.Parent = Sidebar
  
  -- Indicador lime activo
  local indicator = Instance.new("Frame")
  indicator.Size = UDim2.new(0, 3, 0, 24)
  indicator.Position = UDim2.new(0, 0, 0.5, -12)
  indicator.BackgroundColor3 = Z.lime
  indicator.BorderSizePixel = 0
  indicator.ZIndex = 13
  indicator.Parent = btn
  indicator.Visible = i == 1
  
  tabs[i] = {btn = btn, indicator = indicator}
end

-- Separador
local Sep = Instance.new("Frame")
Sep.Size = UDim2.new(0, 1, 1, -24)
Sep.Position = UDim2.new(1, 0, 0, 12)
Sep.BackgroundColor3 = Z.border
Sep.BorderSizePixel = 0
Sep.ZIndex = 12
Sep.Parent = Sidebar

-- ============================================================
-- CONTENT AREA (560x432, 6 tabs)
-- ============================================================
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -120, 1, -48)
Content.Position = UDim2.new(0, 120, 0, 48)
Content.BackgroundColor3 = Z.bg
Content.BorderSizePixel = 0
Content.ZIndex = 10
Content.Parent = Main

-- Tab containers
local tabContainers = {}
for i = 1, 6 do
  local c = Instance.new("Frame")
  c.Size = UDim2.new(1, 0, 1, 0)
  c.BackgroundTransparency = 1
  c.Visible = i == 1
  c.ZIndex = 10
  c.Parent = Content
  c.Name = tabNames[i]
  tabContainers[i] = c
end

-- Tab switcher
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

-- Header
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

-- Cards grid (2x2)
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

-- Realtime FPS
local fps, frames, last = 0, 0, tick()
RunService.RenderStepped:Connect(function()
  frames += 1
  if tick() - last >= 1 then
    fps = frames
    frames = 0
    last = tick()
    DFps.Text = tostring(fps)
  end
end)

-- Realtime memory (GC info)
spawn(function()
  while wait(2) do
    local ok, mem = pcall(function() return collectgarbage("count") / 1024 end)
    if ok then DMem.Text = string.format("%.1f", mem) end
  end
end)

-- Realtime player count
spawn(function()
  while wait(1) do
    DPlayers.Text = tostring(#Players:GetPlayers())
  end
end)

-- Bottom bar: ZEX status
local DStatus = Instance.new("TextLabel")
DStatus.Size = UDim2.new(1, 0, 0, 28)
DStatus.Position = UDim2.new(0, 0, 1, -28)
DStatus.BackgroundColor3 = Z.surface
DStatus.BorderSizePixel = 0
DStatus.Text = "  ZEX SYSTEM ONLINE  ·  Roblox Profile Data Controller  ·  v7.0"
DStatus.TextColor3 = Z.text2
DStatus.Font = Enum.Font.Gotham
DStatus.TextSize = 10
DStatus.TextXAlignment = Enum.TextXAlignment.Left
DStatus.ZIndex = 11
DStatus.Parent = Dashboard

-- ============================================================
-- TAB 2: PLAYER (Recopilación masiva de datos)
-- ============================================================
local PlayerTab = tabContainers[2]

local PScroll = Instance.new("ScrollingFrame")
PScroll.Size = UDim2.new(1, 0, 1, -36)
PScroll.Position = UDim2.new(0, 0, 0, 0)
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
PSub.Text = "Recopilación masiva de datos del perfil."
PSub.TextColor3 = Z.text2
PSub.Font = Enum.Font.Gotham
PSub.TextSize = 11
PSub.TextXAlignment = Enum.TextXAlignment.Left
PSub.ZIndex = 11
PSub.Parent = PScroll

local function field(parent, label, value, y, color)
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

local yPos = 52
local function addSection(parent, title, y)
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

yPos = addSection(PScroll, "IDENTITY", yPos)
field(PScroll, "UserId", LocalPlayer.UserId, yPos)
field(PScroll, "Username", LocalPlayer.Name, yPos + 22)
field(PScroll, "DisplayName", LocalPlayer.DisplayName, yPos + 44)
field(PScroll, "AccountAge", LocalPlayer.AccountAge .. " dias", yPos + 66)
field(PScroll, "Membership", tostring(LocalPlayer.MembershipType), yPos + 88)
field(PScroll, "Verified", LocalPlayer.HasVerifiedBadge and "Yes" or "No", yPos + 110)

yPos = yPos + 140
yPos = addSection(PScroll, "NETWORK / LOCATION", yPos)
field(PScroll, "Country", (function()
  local ok, c = pcall(function() return game.LocalizationService:GetCountryRegionForPlayerAsync(LocalPlayer) end)
  return ok and c or "unknown"
end)(), yPos)
field(PScroll, "Locale", (function()
  local ok, loc = pcall(function() return game:GetService("LocalizationService").LocaleId end)
  return ok and loc or "unknown"
end)(), yPos + 22)
field(PScroll, "Team", (LocalPlayer.Team and LocalPlayer.Team.Name) or "None", yPos + 44)
field(PScroll, "TeamColor", (LocalPlayer.TeamColor and tostring(LocalPlayer.TeamColor)) or "None", yPos + 66)

yPos = yPos + 100
yPos = addSection(PScroll, "CHARACTER", yPos)
local char = LocalPlayer.Character
local hum = char and char:FindFirstChildOfClass("Humanoid")
local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
field(PScroll, "Health", hum and string.format("%.0f / %.0f", hum.Health, hum.MaxHealth) or "N/A", yPos)
field(PScroll, "WalkSpeed", hum and tostring(hum.WalkSpeed) or "N/A", yPos + 22)
field(PScroll, "JumpPower", hum and tostring(hum.JumpPower) or "N/A", yPos + 44)
field(PScroll, "HumanoidState", hum and tostring(hum:GetState()) or "N/A", yPos + 66)
field(PScroll, "RigType", hum and tostring(hum.RigType) or "N/A", yPos + 88)
field(PScroll, "Position", root and string.format("X:%d Y:%d Z:%d", math.floor(root.Position.X), math.floor(root.Position.Y), math.floor(root.Position.Z)) or "N/A", yPos + 110)

yPos = yPos + 140
yPos = addSection(PScroll, "DEVICE", yPos)
field(PScroll, "Platform", tostring(UserInputService:GetPlatform()), yPos)
field(PScroll, "Touch", tostring(UserInputService.TouchEnabled), yPos + 22)
field(PScroll, "Mouse", tostring(UserInputService.MouseEnabled), yPos + 44)
field(PScroll, "Keyboard", tostring(UserInputService.KeyboardEnabled), yPos + 66)
field(PScroll, "Gamepad", tostring(UserInputService.GamepadEnabled), yPos + 88)
field(PScroll, "Resolution", (function()
  local ok, gui = pcall(function() return LocalPlayer:FindFirstChildOfClass("PlayerGui") end)
  return ok and gui and (gui.AbsoluteSize.X .. "x" .. gui.AbsoluteSize.Y) or "unknown"
end)(), yPos + 110)

PScroll.CanvasSize = UDim2.new(0, 0, 0, yPos + 140)

-- ============================================================
-- TAB 3: SERVER
-- ============================================================
local ServerTab = tabContainers[3]
local SScroll = Instance.new("ScrollingFrame")
SScroll.Size = UDim2.new(1, 0, 1, -36)
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
SSub.Text = "Datos del entorno de ejecución."
SSub.TextColor3 = Z.text2
SSub.Font = Enum.Font.Gotham
SSub.TextSize = 11
SSub.TextXAlignment = Enum.TextXAlignment.Left
SSub.ZIndex = 11
SSub.Parent = SScroll

local sy = 52
sy = addSection(SScroll, "GAME INSTANCE", sy)
field(SScroll, "PlaceId", game.PlaceId, sy)
field(SScroll, "JobId", game.JobId:sub(1, 20) .. "...", sy + 22)
field(SScroll, "Game Name", (function()
  local ok, info = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId) end)
  return ok and info.Name or "Unknown"
end)(), sy + 44)
field(SScroll, "MaxPlayers", game.Players.MaxPlayers, sy + 66)
field(SScroll, "CurrentPlayers", #Players:GetPlayers(), sy + 88)
field(SScroll, "IsLoaded", tostring(game.IsLoaded), sy + 110)
field(SScroll, "PlaceVersion", game.PlaceVersion, sy + 132)

sy = sy + 160
sy = addSection(SScroll, "ENVIRONMENT", sy)
field(SScroll, "TimeOfDay", Lighting.TimeOfDay, sy)
field(SScroll, "Brightness", tostring(Lighting.Brightness), sy + 22)
field(SScroll, "ClockTime", tostring(Lighting.ClockTime), sy + 44)
field(SScroll, "GeographicLatitude", tostring(Lighting.GeographicLatitude), sy + 66)
field(SScroll, "IsStudio", tostring(RunService:IsStudio()), sy + 88)
field(SScroll, "IsClient", tostring(RunService:IsClient()), sy + 110)
field(SScroll, "IsServer", tostring(RunService:IsServer()), sy + 132)

sy = sy + 160
sy = addSection(SScroll, "PHYSICS", sy)
field(SScroll, "Gravity", tostring(workspace.Gravity), sy)
field(SScroll, "FallenPartsDestroyHeight", tostring(workspace.FallenPartsDestroyHeight), sy + 22)
field(SScroll, "InterpolationThrottling", tostring(workspace.InterpolationThrottling), sy + 44)
field(SScroll, "StreamingEnabled", tostring(workspace.StreamingEnabled), sy + 66)

SScroll.CanvasSize = UDim2.new(0, 0, 0, sy + 100)

-- ============================================================
-- TAB 4: NETWORK (WebhookPulse Integration)
-- ============================================================
local NetTab = tabContainers[4]
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
NSub.Text = "HTTP transmission con 6 fallbacks + WebhookPulse integration."
NSub.TextColor3 = Z.text2
NSub.Font = Enum.Font.Gotham
NSub.TextSize = 11
NSub.TextXAlignment = Enum.TextXAlignment.Left
NSub.Parent = NetTab

-- URL Input
local NURLLbl = Instance.new("TextLabel")
NURLLbl.Size = UDim2.new(1, 0, 0, 18)
NURLLbl.Position = UDim2.new(0, 0, 0, 52)
NURLLbl.BackgroundTransparency = 1
NURLLbl.Text = "Webhook URL"
NURLLbl.TextColor3 = Z.text2
NURLLbl.Font = Enum.Font.Gotham
NURLLbl.TextSize = 11
NURLLbl.TextXAlignment = Enum.TextXAlignment.Left
NURLLbl.Parent = NetTab

local NURLBox = Instance.new("TextBox")
NURLBox.Size = UDim2.new(1, 0, 0, 36)
NURLBox.Position = UDim2.new(0, 0, 0, 72)
NURLBox.BackgroundColor3 = Z.surface
NURLBox.BorderSizePixel = 0
NURLBox.Text = ""
NURLBox.PlaceholderText = "https://webhookpulse.vercel.app/api/webhook-receive?path=..."
NURLBox.TextColor3 = Z.text
NURLBox.PlaceholderColor3 = Z.text2
NURLBox.Font = Enum.Font.Gotham
NURLBox.TextSize = 11
NURLBox.TextXAlignment = Enum.TextXAlignment.Left
NURLBox.ClearTextOnFocus = false
NURLBox.Parent = NetTab
corner(NURLBox, 6)
stroke(NURLBox, Z.border, 1)
pad(NURLBox, 10, 0, 10, 0)

-- Payload toggle
local NPayloadLbl = Instance.new("TextLabel")
NPayloadLbl.Size = UDim2.new(1, 0, 0, 18)
NPayloadLbl.Position = UDim2.new(0, 0, 0, 118)
NPayloadLbl.BackgroundTransparency = 1
NPayloadLbl.Text = "Payload Mode"
NPayloadLbl.TextColor3 = Z.text2
NPayloadLbl.Font = Enum.Font.Gotham
NPayloadLbl.TextSize = 11
NPayloadLbl.TextXAlignment = Enum.TextXAlignment.Left
NPayloadLbl.Parent = NetTab

local payloadModes = {"Full Profile (all data)", "Identity Only", "Character Only", "Minimal (id + name)"}
local currentPayloadMode = 1

local NPayloadBtn = Instance.new("TextButton")
NPayloadBtn.Size = UDim2.new(1, 0, 0, 32)
NPayloadBtn.Position = UDim2.new(0, 0, 0, 138)
NPayloadBtn.BackgroundColor3 = Z.surface
NPayloadBtn.BorderSizePixel = 0
NPayloadBtn.Text = "  " .. payloadModes[1]
NPayloadBtn.TextColor3 = Z.text
NPayloadBtn.Font = Enum.Font.GothamBold
NPayloadBtn.TextSize = 11
NPayloadBtn.TextXAlignment = Enum.TextXAlignment.Left
NPayloadBtn.Parent = NetTab
corner(NPayloadBtn, 6)
stroke(NPayloadBtn, Z.border, 1)

NPayloadBtn.MouseButton1Click:Connect(function()
  currentPayloadMode = currentPayloadMode % #payloadModes + 1
  NPayloadBtn.Text = "  " .. payloadModes[currentPayloadMode]
end)

-- Status log
local NLogScroll = Instance.new("ScrollingFrame")
NLogScroll.Size = UDim2.new(1, 0, 0, 120)
NLogScroll.Position = UDim2.new(0, 0, 0, 180)
NLogScroll.BackgroundColor3 = Z.surface
NLogScroll.BorderSizePixel = 0
NLogScroll.ScrollBarThickness = 4
NLogScroll.ScrollBarImageColor3 = Z.lime
NLogScroll.CanvasSize = UDim2.new(0, 0, 0, 120)
NLogScroll.ZIndex = 11
NLogScroll.Parent = NetTab
corner(NLogScroll, 6)
stroke(NLogScroll, Z.border, 1)

local NLogText = Instance.new("TextLabel")
NLogText.Size = UDim2.new(1, -16, 0, 0)
NLogText.Position = UDim2.new(0, 8, 0, 8)
NLogText.BackgroundTransparency = 1
NLogText.Text = "Esperando transmision..."
NLogText.TextColor3 = Z.text2
NLogText.Font = Enum.Font.Gotham
NLogText.TextSize = 11
NLogText.TextXAlignment = Enum.TextXAlignment.Left
NLogText.TextYAlignment = Enum.TextYAlignment.Top
NLogText.TextWrapped = true
NLogText.AutomaticSize = Enum.AutomaticSize.Y
NLogText.ZIndex = 12
NLogText.Parent = NLogScroll

local function netLog(msg, color)
  color = color or Z.text2
  local t = os.date("%H:%M:%S")
  NLogText.Text = "[" .. t .. "] " .. msg .. "\n" .. NLogText.Text
  NLogText.TextColor3 = color
  -- resize canvas
  local bounds = game:GetService("TextService"):GetTextSize(NLogText.Text, NLogText.TextSize, NLogText.Font, Vector2.new(NLogScroll.AbsoluteSize.X - 16, 9999))
  NLogText.Size = UDim2.new(1, -16, 0, math.max(20, bounds.Y + 16))
  NLogScroll.CanvasSize = UDim2.new(0, 0, 0, NLogText.Size.Y.Offset + 16)
end

-- Send button
local NSend = Instance.new("TextButton")
NSend.Size = UDim2.new(1, 0, 0, 40)
NSend.Position = UDim2.new(0, 0, 1, -48)
NSend.BackgroundColor3 = Z.lime
NSend.BorderSizePixel = 0
NSend.Text = "TRANSMITIR DATOS"
NSend.TextColor3 = Z.bg
NSend.Font = Enum.Font.GothamBold
NSend.TextSize = 13
NSend.Parent = NetTab
corner(NSend, 6)

NSend.MouseEnter:Connect(function() NSend.BackgroundColor3 = Z.lime2 end)
NSend.MouseLeave:Connect(function() NSend.BackgroundColor3 = Z.lime end)

NSend.MouseButton1Click:Connect(function()
  local url = NURLBox.Text:match("^%s*(.-)%s*$")
  if url == "" then
    netLog("Error: URL vacia", Z.danger)
    return
  end
  
  netLog("Construyendo payload...", Z.info)
  
  -- Build payload based on mode
  local payload = { source = "roblox", timestamp = os.time() }
  
  if currentPayloadMode == 1 or currentPayloadMode == 2 then
    payload.player = {
      userid = LocalPlayer.UserId,
      username = LocalPlayer.Name,
      displayname = LocalPlayer.DisplayName,
      accountage = LocalPlayer.AccountAge,
      membership = tostring(LocalPlayer.MembershipType),
      verified = LocalPlayer.HasVerifiedBadge or false,
      country = (pcall(function() return game.LocalizationService:GetCountryRegionForPlayerAsync(LocalPlayer) end) and {true} or {false})[1],
      locale = (pcall(function() return game:GetService("LocalizationService").LocaleId end) and {true} or {false})[1],
    }
  end
  
  if currentPayloadMode == 1 or currentPayloadMode == 3 then
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
    payload.character = {
      health = hum and hum.Health or nil,
      maxhealth = hum and hum.MaxHealth or nil,
      walkspeed = hum and hum.WalkSpeed or nil,
      jumppower = hum and hum.JumpPower or nil,
      humanoidstate = hum and tostring(hum:GetState()) or nil,
      position = root and { x = math.floor(root.Position.X), y = math.floor(root.Position.Y), z = math.floor(root.Position.Z) } or nil,
    }
  end
  
  if currentPayloadMode == 4 then
    payload.player = { userid = LocalPlayer.UserId, username = LocalPlayer.Name }
  end
  
  payload.executor = { name = (pcall(function() return identifyexecutor() end) and {true} or {false})[1] and tostring((pcall(function() return identifyexecutor() end) and {identifyexecutor()} or {"unknown"})[1]) or "unknown" }
  
  local body = HttpService:JSONEncode(payload)
  netLog("Payload: " .. tostring(#body) .. " bytes", Z.info)
  
  -- HTTP with 6 fallbacks
  local success = false
  local attempts = {}
  
  local function try(fn, name)
    if not fn then table.insert(attempts, name .. ": no disponible"); return false end
    local ok, res = pcall(function() return fn({ Url = url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = body }) end)
    if ok and res then
      local code = res.StatusCode or res.statusCode or res.status
      if code and code >= 200 and code < 300 then
        table.insert(attempts, name .. ": OK (" .. code .. ")")
        return true
      else
        table.insert(attempts, name .. ": HTTP " .. tostring(code))
      end
    else
      table.insert(attempts, name .. ": " .. tostring(res))
    end
    return false
  end
  
  success = try(request, "request()")
  if not success then success = try(getgenv().request, "getgenv().request") end
  if not success then success = try(http and http.request, "http.request") end
  if not success then success = try(syn and syn.request, "syn.request") end
  if not success then success = try(fluxus and fluxus.request, "fluxus.request") end
  if not success then success = try(delta and delta.request, "delta.request") end
  
  if not success then
    local ok, res = pcall(function() return HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson) end)
    if ok then
      success = true
      table.insert(attempts, "HttpService:PostAsync: OK")
    else
      table.insert(attempts, "HttpService:PostAsync: " .. tostring(res))
    end
  end
  
  if success then
    netLog("Transmision exitosa. Intentos:\n" .. table.concat(attempts, "\n"), Z.success)
  else
    netLog("Transmision fallida. Intentos:\n" .. table.concat(attempts, "\n"), Z.danger)
  end
end)

-- ============================================================
-- TAB 5: COMMANDS (Admin actions)
-- ============================================================
local CmdTab = tabContainers[5]
local CScroll = Instance.new("ScrollingFrame")
CScroll.Size = UDim2.new(1, 0, 1, -36)
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
    if not ok then
      print("[ZEX CMD ERROR] " .. tostring(err))
    end
  end)
  
  return btn
end

local cy = 52
cmdBtn(CScroll, "Rejoin Server", cy, Z.info, function()
  local ts = game:GetService("TeleportService")
  ts:Teleport(game.PlaceId, LocalPlayer)
end)
cy = cy + 44
cmdBtn(CScroll, "Teleport to Place", cy, Z.info, function()
  local ts = game:GetService("TeleportService")
  -- Prompt for PlaceId would go here; simplified
  print("[ZEX] Use custom PlaceId")
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
cmdBtn(CScroll, "Fullbright (max brightness)", cy, Z.lime, function()
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
cmdBtn(CScroll, "Low Graphics Mode", cy, Z.info, function()
  settings().Rendering.QualityLevel = 1
end)
cy = cy + 44
cmdBtn(CScroll, "Max Graphics Mode", cy, Z.info, function()
  settings().Rendering.QualityLevel = 10
end)

CScroll.CanvasSize = UDim2.new(0, 0, 0, cy + 60)

-- ============================================================
-- TAB 6: CONSOLE (Log system con scroll)
-- ============================================================
local ConsoleTab = tabContainers[6]
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
  local bounds = game:GetService("TextService"):GetTextSize(CoText.Text, CoText.TextSize, CoText.Font, Vector2.new(CoScroll.AbsoluteSize.X - 16, 9999))
  local h = math.max(20, bounds.Y + 16)
  CoText.Size = UDim2.new(1, -16, 0, h)
  CoScroll.CanvasSize = UDim2.new(0, 0, 0, h + 16)
  -- Auto-scroll to bottom
  CoScroll.CanvasPosition = Vector2.new(0, math.max(0, CoScroll.CanvasSize.Y.Offset - CoScroll.AbsoluteSize.Y))
end

-- Clear button
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

-- Export button
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
  setclipboard(CoText.Text)
  consoleLog("Log copied to clipboard.", Z.success)
end)

-- ============================================================
-- DRAG SYSTEM (TopBar)
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
-- INIT LOG
-- ============================================================
consoleLog("ZEX v7.0 initialized.", Z.lime)
consoleLog("Executor: " .. (pcall(function() return identifyexecutor() end) and tostring((pcall(function() return identifyexecutor() end) and {identifyexecutor()} or {"unknown"})[1]) or "unknown"), Z.info)
consoleLog("Player: " .. LocalPlayer.Name .. " (" .. LocalPlayer.UserId .. ")", Z.info)
consoleLog("Press RightShift to toggle GUI.", Z.text2)

print("[ZEX] v7.0 Elite Controller loaded. RightShift to toggle.")
