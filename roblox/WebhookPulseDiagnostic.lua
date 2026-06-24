local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local TextService = game:GetService("TextService")

local Colors = {
  Background = Color3.fromRGB(12, 12, 14),
  Surface = Color3.fromRGB(22, 22, 24),
  Elevated = Color3.fromRGB(28, 28, 30),
  Border = Color3.fromRGB(39, 39, 42),
  TextPrimary = Color3.fromRGB(250, 250, 250),
  TextSecondary = Color3.fromRGB(161, 161, 170),
  Accent = Color3.fromRGB(212, 232, 58),
  Success = Color3.fromRGB(34, 197, 94),
  Danger = Color3.fromRGB(239, 68, 68),
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "WebhookPulseDiagnostic"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

if gethui then
  local ok, hui = pcall(gethui)
  if ok and hui then ScreenGui.Parent = hui end
end
if not ScreenGui.Parent then
  local ok, cg = pcall(function() return game:GetService("CoreGui") end)
  if ok and cg then ScreenGui.Parent = cg end
end
if not ScreenGui.Parent then
  local ok, pg = pcall(function() return LocalPlayer.PlayerGui end)
  if ok and pg then ScreenGui.Parent = pg end
end

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 500, 0, 400)
MainFrame.Position = UDim2.new(0.5, -250, 0.5, -200)
MainFrame.BackgroundColor3 = Colors.Surface
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = MainFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Colors.Border
stroke.Thickness = 1
stroke.Parent = MainFrame

-- TopBar
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.BackgroundColor3 = Colors.Elevated
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 8)
topCorner.Parent = TopBar

local TopBarFix = Instance.new("Frame")
TopBarFix.Size = UDim2.new(1, 0, 0, 8)
TopBarFix.Position = UDim2.new(0, 0, 1, -8)
TopBarFix.BackgroundColor3 = Colors.Elevated
TopBarFix.BorderSizePixel = 0
TopBarFix.Parent = TopBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -40, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Diagnostico WebhookPulse"
Title.TextColor3 = Colors.TextPrimary
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -36, 0, 4)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Colors.TextSecondary
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = TopBar
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

-- Scrolling output
local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -24, 1, -56)
Scroll.Position = UDim2.new(0, 12, 0, 48)
Scroll.BackgroundColor3 = Colors.Background
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 4
Scroll.ScrollBarImageColor3 = Colors.Accent
Scroll.CanvasSize = UDim2.new(0, 0, 0, 300)
Scroll.Parent = MainFrame

local scrollCorner = Instance.new("UICorner")
scrollCorner.CornerRadius = UDim.new(0, 6)
scrollCorner.Parent = Scroll

local scrollStroke = Instance.new("UIStroke")
scrollStroke.Color = Colors.Border
scrollStroke.Thickness = 1
scrollStroke.Parent = Scroll

local Output = Instance.new("TextLabel")
Output.Size = UDim2.new(1, -16, 0, 0)
Output.Position = UDim2.new(0, 8, 0, 8)
Output.BackgroundTransparency = 1
Output.Text = "Ejecutando diagnostico..."
Output.TextColor3 = Colors.TextSecondary
Output.Font = Enum.Font.Gotham
Output.TextSize = 12
Output.TextXAlignment = Enum.TextXAlignment.Left
Output.TextYAlignment = Enum.TextYAlignment.Top
Output.TextWrapped = true
Output.AutomaticSize = Enum.AutomaticSize.Y
Output.Parent = Scroll

local lines = {}

local function addLine(text, color)
  color = color or Colors.TextSecondary
  local colorStr = string.format("<font color=\"#%02x%02x%02x\">", color.R * 255, color.G * 255, color.B * 255)
  table.insert(lines, colorStr .. text .. "</font>")
  Output.Text = table.concat(lines, "\n")
  
  -- Recalculate canvas size
  local bounds = TextService:GetTextSize(
    Output.Text,
    Output.TextSize,
    Output.Font,
    Vector2.new(Scroll.AbsoluteSize.X - 16, 9999)
  )
  local height = math.max(20, bounds.Y + 16)
  Output.Size = UDim2.new(1, -16, 0, height)
  Scroll.CanvasSize = UDim2.new(0, 0, 0, height + 16)
  Scroll.CanvasPosition = Vector2.new(0, math.max(0, Scroll.CanvasSize.Y.Offset - Scroll.AbsoluteSize.Y))
end

local function check(name, fn, expect)
  local ok, result = pcall(fn)
  if ok then
    if expect then
      local pass = expect(result)
      if pass then
        addLine("[OK] " .. name, Colors.Success)
      else
        addLine("[FAIL] " .. name .. " (valor inesperado)", Colors.Danger)
      end
    else
      addLine("[OK] " .. name, Colors.Success)
    end
  else
    addLine("[FAIL] " .. name .. ": " .. tostring(result), Colors.Danger)
  end
end

local function info(name, value)
  addLine("[INFO] " .. name .. ": " .. tostring(value), Colors.TextSecondary)
end

-- Run diagnostics
addLine("=== Diagnostico WebhookPulse ===", Colors.Accent)
addLine("")

check("Script ejecutado", function() return true end)
info("Executor", (function()
  if identifyexecutor then
    local ok, name = pcall(identifyexecutor)
    return ok and tostring(name) or "desconocido"
  end
  return "desconocido"
end)())

check("identifyexecutor() disponible", function() return identifyexecutor ~= nil end)
check("gethui() disponible", function() return gethui ~= nil end)
check("request() disponible", function() return request ~= nil end)
check("syn.request disponible", function() return syn and syn.request ~= nil end)
check("HttpService disponible", function() return HttpService ~= nil end)
check("Players disponible", function() return Players ~= nil end)
check("LocalPlayer disponible", function() return LocalPlayer ~= nil end)
check("LocalPlayer.UserId", function() return LocalPlayer.UserId ~= nil end, function(v) return v > 0 end)
check("LocalPlayer.Name", function() return LocalPlayer.Name ~= nil end, function(v) return v ~= "" end)

info("UserId", LocalPlayer.UserId)
info("Username", LocalPlayer.Name)
info("DisplayName", LocalPlayer.DisplayName)

addLine("")
addLine("=== Prueba HTTP ===", Colors.Accent)
addLine("")

-- Test HTTP request
if request then
  local testReq = {
    Url = "https://httpbin.org/post",
    Method = "POST",
    Headers = { ["Content-Type"] = "application/json" },
    Body = "{\"test\":true}"
  }
  local ok, res = pcall(function() return request(testReq) end)
  if ok and res then
    local code = res.StatusCode or res.statusCode or res.status
    if code and code >= 200 and code < 300 then
      addLine("[OK] HTTP request() funciona (status " .. tostring(code) .. ")", Colors.Success)
    else
      addLine("[WARN] HTTP request() respondio con status " .. tostring(code), Colors.Danger)
    end
  else
    addLine("[FAIL] HTTP request() fallo: " .. tostring(res), Colors.Danger)
  end
else
  addLine("[SKIP] request() no disponible, saltando prueba HTTP", Colors.TextSecondary)
end

addLine("")
addLine("=== Fin del diagnostico ===", Colors.Accent)
addLine("Cierra este panel con la X arriba.")

-- Drag
local dragging, dragStart, startPos = false, nil, nil
TopBar.InputBegan:Connect(function(input)
  if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    dragging = true
    dragStart = input.Position
    startPos = MainFrame.Position
    input.Changed:Connect(function()
      if input.UserInputState == Enum.UserInputState.End then dragging = false end
    end)
  end
end)
TopBar.InputChanged:Connect(function(input)
  if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
    local delta = input.Position - dragStart
    MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
  end
end)

print("[WebhookPulse] Diagnostico cargado. Verifica el panel en pantalla.")
