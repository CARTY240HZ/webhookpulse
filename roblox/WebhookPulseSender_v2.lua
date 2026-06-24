--[[
  WebhookPulse Sender v2 — Roblox Script
  Dos pasos: 1) Pegar URL del webhook, 2) Ver datos y enviar.
  Diseño AAA oscuro premium: fondo #0C0C0E, acento lime #D4E83A, sin emojis.
  Compatible con Wave y todos los ejecutores.
--]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Colores exactos
local Colors = {
  Background = Color3.fromRGB(12, 12, 14),      -- #0C0C0E
  Surface = Color3.fromRGB(22, 22, 24),         -- #161618
  Elevated = Color3.fromRGB(28, 28, 30),        -- #1C1C1E
  Border = Color3.fromRGB(39, 39, 42),            -- #27272A
  TextPrimary = Color3.fromRGB(250, 250, 250),    -- #FAFAFA
  TextSecondary = Color3.fromRGB(161, 161, 170),  -- #A1A1AA
  Accent = Color3.fromRGB(212, 232, 58),        -- #D4E83A
  AccentHover = Color3.fromRGB(232, 249, 106),    -- #E8F96A
  Danger = Color3.fromRGB(239, 68, 68),           -- #EF4444
  Success = Color3.fromRGB(34, 197, 94),        -- #22C55E
}

-- ============================================================
-- UTILIDADES
-- ============================================================

local function createCorner(parent, radius)
  local c = Instance.new("UICorner")
  c.CornerRadius = UDim.new(0, radius or 8)
  c.Parent = parent
  return c
end

local function createStroke(parent, color, thickness)
  local s = Instance.new("UIStroke")
  s.Color = color or Colors.Border
  s.Thickness = thickness or 1
  s.Parent = parent
  return s
end

local function createTextLabel(parent, props)
  local lbl = Instance.new("TextLabel")
  for k, v in pairs(props) do lbl[k] = v end
  lbl.Parent = parent
  return lbl
end

local function createTextButton(parent, props)
  local btn = Instance.new("TextButton")
  for k, v in pairs(props) do btn[k] = v end
  btn.Parent = parent
  return btn
end

local function createTextBox(parent, props)
  local box = Instance.new("TextBox")
  for k, v in pairs(props) do box[k] = v end
  box.Parent = parent
  return box
end

-- ============================================================
-- SCREENGUi
-- ============================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "WebhookPulseSender"
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

-- ============================================================
-- CONTENEDOR PRINCIPAL (440x340)
-- ============================================================

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 440, 0, 340)
MainFrame.Position = UDim2.new(0.5, -220, 0.5, -170)
MainFrame.BackgroundColor3 = Colors.Surface
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

createCorner(MainFrame, 8)
createStroke(MainFrame, Colors.Border, 1)

-- ============================================================
-- TOPBAR (arrastrable)
-- ============================================================

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 48)
TopBar.BackgroundColor3 = Colors.Elevated
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

createCorner(TopBar, 8)

local TopBarFix = Instance.new("Frame")
TopBarFix.Size = UDim2.new(1, 0, 0, 8)
TopBarFix.Position = UDim2.new(0, 0, 1, -8)
TopBarFix.BackgroundColor3 = Colors.Elevated
TopBarFix.BorderSizePixel = 0
TopBarFix.Parent = TopBar

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.new(0, 8, 0, 8)
StatusDot.Position = UDim2.new(0, 16, 0, 20)
StatusDot.BackgroundColor3 = Colors.Accent
StatusDot.BorderSizePixel = 0
StatusDot.Parent = TopBar

createCorner(StatusDot, 99)

createTextLabel(TopBar, {
  Name = "Title",
  Size = UDim2.new(1, -60, 1, 0),
  Position = UDim2.new(0, 32, 0, 0),
  BackgroundTransparency = 1,
  Text = "WebhookPulse",
  TextColor3 = Colors.TextPrimary,
  Font = Enum.Font.GothamBold,
  TextSize = 16,
  TextXAlignment = Enum.TextXAlignment.Left,
})

local CloseBtn = createTextButton(TopBar, {
  Size = UDim2.new(0, 32, 0, 32),
  Position = UDim2.new(1, -40, 0, 8),
  BackgroundTransparency = 1,
  Text = "X",
  TextColor3 = Colors.TextSecondary,
  Font = Enum.Font.GothamBold,
  TextSize = 14,
})

CloseBtn.MouseEnter:Connect(function() CloseBtn.TextColor3 = Colors.TextPrimary end)
CloseBtn.MouseLeave:Connect(function() CloseBtn.TextColor3 = Colors.TextSecondary end)
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

-- ============================================================
-- PASO 1: INPUT URL (visible por defecto)
-- ============================================================

local URLFrame = Instance.new("Frame")
URLFrame.Name = "URLFrame"
URLFrame.Size = UDim2.new(1, -32, 1, -64)
URLFrame.Position = UDim2.new(0, 16, 0, 56)
URLFrame.BackgroundTransparency = 1
URLFrame.Visible = true
URLFrame.Parent = MainFrame

createTextLabel(URLFrame, {
  Size = UDim2.new(1, 0, 0, 20),
  BackgroundTransparency = 1,
  Text = "Pega la URL de tu webhook para continuar.",
  TextColor3 = Colors.TextSecondary,
  Font = Enum.Font.Gotham,
  TextSize = 12,
  TextXAlignment = Enum.TextXAlignment.Left,
})

-- Label URL
local URLLabel = createTextLabel(URLFrame, {
  Size = UDim2.new(1, 0, 0, 18),
  Position = UDim2.new(0, 0, 0, 32),
  BackgroundTransparency = 1,
  Text = "URL del Webhook",
  TextColor3 = Colors.TextSecondary,
  Font = Enum.Font.Gotham,
  TextSize = 12,
  TextXAlignment = Enum.TextXAlignment.Left,
})

-- Input URL
local URLInput = createTextBox(URLFrame, {
  Size = UDim2.new(1, 0, 0, 40),
  Position = UDim2.new(0, 0, 0, 54),
  BackgroundColor3 = Colors.Background,
  BorderSizePixel = 0,
  Text = "",
  PlaceholderText = "https://webhookpulse.vercel.app/api/webhook-receive?path=...",
  TextColor3 = Colors.TextPrimary,
  PlaceholderColor3 = Colors.TextSecondary,
  Font = Enum.Font.Gotham,
  TextSize = 11,
  TextXAlignment = Enum.TextXAlignment.Left,
  TextTruncate = Enum.TextTruncate.AtEnd,
  ClearTextOnFocus = false,
})

Instance.new("UIPadding", URLInput).PaddingLeft = UDim.new(0, 12)
createCorner(URLInput, 6)
createStroke(URLInput, Colors.Border, 1)

-- Estado del paso 1
local URLStatus = createTextLabel(URLFrame, {
  Size = UDim2.new(1, 0, 0, 20),
  Position = UDim2.new(0, 0, 0, 102),
  BackgroundTransparency = 1,
  Text = "Esperando URL...",
  TextColor3 = Colors.TextSecondary,
  Font = Enum.Font.Gotham,
  TextSize = 12,
  TextXAlignment = Enum.TextXAlignment.Left,
})

-- Boton Cargar
local LoadBtn = createTextButton(URLFrame, {
  Size = UDim2.new(1, 0, 0, 40),
  Position = UDim2.new(0, 0, 1, -40),
  BackgroundColor3 = Colors.Accent,
  BorderSizePixel = 0,
  Text = "Cargar datos",
  TextColor3 = Colors.Background,
  Font = Enum.Font.GothamBold,
  TextSize = 14,
})

createCorner(LoadBtn, 8)

LoadBtn.MouseEnter:Connect(function() LoadBtn.BackgroundColor3 = Colors.AccentHover end)
LoadBtn.MouseLeave:Connect(function() LoadBtn.BackgroundColor3 = Colors.Accent end)

-- ============================================================
-- PASO 2: DATOS + ENVIAR (oculto por defecto)
-- ============================================================

local DataFrame = Instance.new("Frame")
DataFrame.Name = "DataFrame"
DataFrame.Size = UDim2.new(1, -32, 1, -64)
DataFrame.Position = UDim2.new(0, 16, 0, 56)
DataFrame.BackgroundTransparency = 1
DataFrame.Visible = false
DataFrame.Parent = MainFrame

createTextLabel(DataFrame, {
  Size = UDim2.new(1, 0, 0, 20),
  BackgroundTransparency = 1,
  Text = "Datos del perfil listos para enviar.",
  TextColor3 = Colors.TextSecondary,
  Font = Enum.Font.Gotham,
  TextSize = 12,
  TextXAlignment = Enum.TextXAlignment.Left,
})

-- Campo UserId
local UserIdLabel = createTextLabel(DataFrame, {
  Size = UDim2.new(1, 0, 0, 18),
  Position = UDim2.new(0, 0, 0, 28),
  BackgroundTransparency = 1,
  Text = "UserId",
  TextColor3 = Colors.TextSecondary,
  Font = Enum.Font.Gotham,
  TextSize = 12,
  TextXAlignment = Enum.TextXAlignment.Left,
})

local UserIdValue = createTextLabel(DataFrame, {
  Size = UDim2.new(1, 0, 0, 36),
  Position = UDim2.new(0, 0, 0, 48),
  BackgroundColor3 = Colors.Background,
  BorderSizePixel = 0,
  Text = tostring(LocalPlayer.UserId),
  TextColor3 = Colors.TextPrimary,
  Font = Enum.Font.Gotham,
  TextSize = 14,
  TextXAlignment = Enum.TextXAlignment.Left,
})

Instance.new("UIPadding", UserIdValue).PaddingLeft = UDim.new(0, 12)
createCorner(UserIdValue, 6)
createStroke(UserIdValue, Colors.Border, 1)

-- Campo Username
local UsernameLabel = createTextLabel(DataFrame, {
  Size = UDim2.new(1, 0, 0, 18),
  Position = UDim2.new(0, 0, 0, 92),
  BackgroundTransparency = 1,
  Text = "Username",
  TextColor3 = Colors.TextSecondary,
  Font = Enum.Font.Gotham,
  TextSize = 12,
  TextXAlignment = Enum.TextXAlignment.Left,
})

local UsernameValue = createTextLabel(DataFrame, {
  Size = UDim2.new(1, 0, 0, 36),
  Position = UDim2.new(0, 0, 0, 112),
  BackgroundColor3 = Colors.Background,
  BorderSizePixel = 0,
  Text = LocalPlayer.Name,
  TextColor3 = Colors.TextPrimary,
  Font = Enum.Font.Gotham,
  TextSize = 14,
  TextXAlignment = Enum.TextXAlignment.Left,
})

Instance.new("UIPadding", UsernameValue).PaddingLeft = UDim.new(0, 12)
createCorner(UsernameValue, 6)
createStroke(UsernameValue, Colors.Border, 1)

-- Scrollable debug/status area
local DebugScroll = Instance.new("ScrollingFrame")
DebugScroll.Size = UDim2.new(1, 0, 0, 60)
DebugScroll.Position = UDim2.new(0, 0, 0, 156)
DebugScroll.BackgroundColor3 = Colors.Background
DebugScroll.BorderSizePixel = 0
DebugScroll.ScrollBarThickness = 4
DebugScroll.ScrollBarImageColor3 = Colors.Accent
DebugScroll.CanvasSize = UDim2.new(0, 0, 0, 60)
DebugScroll.Parent = DataFrame

Instance.new("UIPadding", DebugScroll).PaddingLeft = UDim.new(0, 0)
Instance.new("UIPadding", DebugScroll).PaddingRight = UDim.new(0, 0)

createCorner(DebugScroll, 6)
createStroke(DebugScroll, Colors.Border, 1)

local SendStatus = Instance.new("TextLabel")
SendStatus.Size = UDim2.new(1, -16, 0, 0)
SendStatus.Position = UDim2.new(0, 8, 0, 8)
SendStatus.BackgroundTransparency = 1
SendStatus.Text = "Listo para enviar."
SendStatus.TextColor3 = Colors.TextSecondary
SendStatus.Font = Enum.Font.Gotham
SendStatus.TextSize = 12
SendStatus.TextXAlignment = Enum.TextXAlignment.Left
SendStatus.TextYAlignment = Enum.TextYAlignment.Top
SendStatus.TextWrapped = true
SendStatus.AutomaticSize = Enum.AutomaticSize.Y
SendStatus.Parent = DebugScroll

-- Update canvas size when text changes
SendStatus:GetPropertyChangedSignal("TextBounds"):Connect(function()
    local textBounds = SendStatus.TextBounds
    local height = math.max(20, textBounds.Y + 16)
    SendStatus.Size = UDim2.new(1, -16, 0, height)
    DebugScroll.CanvasSize = UDim2.new(0, 0, 0, height + 16)
end)

-- Boton enviar
local SendBtn = createTextButton(DataFrame, {
  Size = UDim2.new(0.48, 0, 0, 40),
  Position = UDim2.new(0, 0, 1, -40),
  BackgroundColor3 = Colors.Accent,
  BorderSizePixel = 0,
  Text = "Enviar datos",
  TextColor3 = Colors.Background,
  Font = Enum.Font.GothamBold,
  TextSize = 14,
})

createCorner(SendBtn, 8)

SendBtn.MouseEnter:Connect(function() SendBtn.BackgroundColor3 = Colors.AccentHover end)
SendBtn.MouseLeave:Connect(function() SendBtn.BackgroundColor3 = Colors.Accent end)

-- Boton volver
local BackBtn = createTextButton(DataFrame, {
  Size = UDim2.new(0.48, 0, 0, 40),
  Position = UDim2.new(0.52, 0, 1, -40),
  BackgroundColor3 = Colors.Elevated,
  BorderSizePixel = 0,
  Text = "Volver",
  TextColor3 = Colors.TextPrimary,
  Font = Enum.Font.GothamBold,
  TextSize = 14,
})

createCorner(BackBtn, 8)
createStroke(BackBtn, Colors.Border, 1)

BackBtn.MouseEnter:Connect(function() BackBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 42) end)
BackBtn.MouseLeave:Connect(function() BackBtn.BackgroundColor3 = Colors.Elevated end)

-- ============================================================
-- LOGICA
-- ============================================================

local currentWebhookURL = ""

-- Paso 1: Cargar datos
LoadBtn.MouseButton1Click:Connect(function()
  local url = URLInput.Text:match("^%s*(.-)%s*$")
  if url == "" then
    URLStatus.Text = "Error: Ingresa una URL valida."
    URLStatus.TextColor3 = Colors.Danger
    return
  end

  if not url:find("api/webhook%-receive") and not url:find("webhook%-receive") then
    URLStatus.Text = "Error: URL no valida de WebhookPulse."
    URLStatus.TextColor3 = Colors.Danger
    return
  end

  currentWebhookURL = url
  URLStatus.Text = "URL valida. Cargando..."
  URLStatus.TextColor3 = Colors.Success

  wait(0.3)

  URLFrame.Visible = false
  DataFrame.Visible = true
  SendStatus.Text = "Listo para enviar."
  SendStatus.TextColor3 = Colors.TextSecondary
  StatusDot.BackgroundColor3 = Colors.Accent
end)

-- Paso 2: Volver
BackBtn.MouseButton1Click:Connect(function()
  DataFrame.Visible = false
  URLFrame.Visible = true
  URLStatus.Text = "Esperando URL..."
  URLStatus.TextColor3 = Colors.TextSecondary
  StatusDot.BackgroundColor3 = Colors.Accent
end)

-- Paso 2: Enviar
SendBtn.MouseButton1Click:Connect(function()
  if currentWebhookURL == "" then
    SendStatus.Text = "Error: No hay URL configurada."
    SendStatus.TextColor3 = Colors.Danger
    return
  end

  SendStatus.Text = "Enviando..."
  SendStatus.TextColor3 = Colors.TextSecondary

  local payload = {
    source = "roblox",
    timestamp = os.time(),
    executor = {
      name = (function()
        if identifyexecutor then
          local ok, name = pcall(identifyexecutor)
          return ok and tostring(name) or "unknown"
        end
        return "unknown"
      end)(),
    },
    player = {
      userid = LocalPlayer.UserId,
      username = LocalPlayer.Name,
      displayname = LocalPlayer.DisplayName,
      accountage = LocalPlayer.AccountAge,
      membership = tostring(LocalPlayer.MembershipType),
      premium = (function()
        local ok, isPremium = pcall(function()
          return LocalPlayer:IsInGroup(1) or false
        end)
        return ok and isPremium or false
      end)(),
      verified = LocalPlayer.HasVerifiedBadge or false,
      country = (function()
        local ok, c = pcall(function()
          return game.LocalizationService:GetCountryRegionForPlayerAsync(LocalPlayer)
        end)
        return ok and c or "unknown"
      end)(),
      team = (LocalPlayer.Team and LocalPlayer.Team.Name) or nil,
      teamcolor = (LocalPlayer.TeamColor and tostring(LocalPlayer.TeamColor)) or nil,
      neutral = LocalPlayer.Neutral,
      characterappearanceid = LocalPlayer.CharacterAppearanceId or nil,
      avatarheadshot = (function()
        local ok, url = pcall(function()
          return "https://www.roblox.com/headshot-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=420&height=420&format=png"
        end)
        return ok and url or nil
      end)(),
      friends = (function()
        local friends = {}
        local ok = pcall(function()
          for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and LocalPlayer:IsFriendsWith(plr.UserId) then
              table.insert(friends, plr.Name)
            end
          end
        end)
        return ok and #friends > 0 and friends or nil
      end)(),
      locale = (function()
        local ok, loc = pcall(function()
          return game:GetService("LocalizationService").LocaleId
        end)
        return ok and loc or nil
      end)(),
    },
    character = (function()
      local char = LocalPlayer.Character
      if not char then return nil end
      local hum = char:FindFirstChildOfClass("Humanoid")
      local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
      local pos = root and { x = math.floor(root.Position.X), y = math.floor(root.Position.Y), z = math.floor(root.Position.Z) } or nil
      local velocity = root and { x = math.floor(root.Velocity.X), y = math.floor(root.Velocity.Y), z = math.floor(root.Velocity.Z) } or nil
      return {
        health = hum and hum.Health or nil,
        maxhealth = hum and hum.MaxHealth or nil,
        walkspeed = hum and hum.WalkSpeed or nil,
        jumppower = hum and hum.JumpPower or nil,
        humanoidstate = hum and tostring(hum:GetState()) or nil,
        rigtype = hum and tostring(hum.RigType) or nil,
        position = pos,
        velocity = velocity,
      }
    end)(),
    game = {
      placeid = game.PlaceId,
      jobid = game.JobId,
      gameid = game.GameId or nil,
      creatorid = game.CreatorId or nil,
      creatortype = game.CreatorType and tostring(game.CreatorType) or nil,
      placeversion = game.PlaceVersion or nil,
      gamename = (function()
        local ok, info = pcall(function()
          return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
        end)
        return ok and info.Name or "Unknown"
      end)(),
      maxplayers = game.Players.MaxPlayers,
      numplayers = #game.Players:GetPlayers(),
      isloaded = game.IsLoaded,
      privateserverid = game.PrivateServerId or nil,
      privateserverownerid = game.PrivateServerOwnerId or nil,
      vipserverid = game.VIPServerId or nil,
      vipserverownerid = game.VIPServerOwnerId or nil,
      genre = (function()
        local ok, info = pcall(function()
          return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
        end)
        return ok and info.Genre and tostring(info.Genre) or nil
      end)(),
    },
    environment = {
      timeofday = game:GetService("Lighting").TimeOfDay,
      brightness = game:GetService("Lighting").Brightness,
      clocktime = game:GetService("Lighting").ClockTime,
      geographiclatitude = game:GetService("Lighting").GeographicLatitude,
      ambient = (function()
        local ok, amb = pcall(function()
          return tostring(game:GetService("Lighting").Ambient)
        end)
        return ok and amb or nil
      end)(),
      outdoorambient = (function()
        local ok, amb = pcall(function()
          return tostring(game:GetService("Lighting").OutdoorAmbient)
        end)
        return ok and amb or nil
      end)(),
      camerapos = (function()
        local cam = workspace.CurrentCamera
        if cam then
          return {
            x = math.floor(cam.CFrame.Position.X),
            y = math.floor(cam.CFrame.Position.Y),
            z = math.floor(cam.CFrame.Position.Z),
          }
        end
        return nil
      end)(),
      camerafov = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or nil,
      isstudio = game:GetService("RunService"):IsStudio(),
      isclient = game:GetService("RunService"):IsClient(),
      isserver = game:GetService("RunService"):IsServer(),
    },
    device = {
      os = tostring(game:GetService("UserInputService"):GetPlatform()),
      touchenabled = game:GetService("UserInputService").TouchEnabled,
      mouseenabled = game:GetService("UserInputService").MouseEnabled,
      keyboardenabled = game:GetService("UserInputService").KeyboardEnabled,
      gamepadenabled = game:GetService("UserInputService").GamepadEnabled,
      accelerometerenabled = game:GetService("UserInputService").AccelerometerEnabled,
      gyroscopeenabled = game:GetService("UserInputService").GyroscopeEnabled,
      screenresolution = (function()
        local ok, res = pcall(function()
          local gui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
          if gui then
            return gui.AbsoluteSize.X .. "x" .. gui.AbsoluteSize.Y
          end
          return nil
        end)
        return ok and res or nil
      end)(),
    },
  }

  local body = HttpService:JSONEncode(payload)
  local success = false
  local responseCode = nil
  local errorMsg = nil
  local attempts = {}

  local function tryHttp(fn, name, reqTable)
    if not fn then
      table.insert(attempts, name .. ": no disponible")
      return false
    end
    local ok, res = pcall(function()
      return fn(reqTable)
    end)
    if ok then
      if res then
        local code = res.StatusCode or res.statusCode or res.status
        if code then
          if code >= 200 and code < 300 then
            success = true
            responseCode = code
            return true
          else
            table.insert(attempts, name .. ": HTTP " .. tostring(code))
            errorMsg = name .. " HTTP " .. tostring(code)
          end
        else
          table.insert(attempts, name .. ": respuesta sin status")
          errorMsg = name .. ": respuesta sin status"
        end
      else
        table.insert(attempts, name .. ": respuesta vacia")
        errorMsg = name .. ": respuesta vacia"
      end
    else
      table.insert(attempts, name .. ": " .. tostring(res))
      errorMsg = name .. ": " .. tostring(res)
    end
    return false
  end

  local reqTable = {
    Url = currentWebhookURL,
    Method = "POST",
    Headers = { ["Content-Type"] = "application/json" },
    Body = body
  }

  tryHttp(request, "request()", reqTable)
  if not success then tryHttp(getgenv().request, "getgenv().request", reqTable) end
  if not success then tryHttp(http and http.request, "http.request", reqTable) end
  if not success then tryHttp(syn and syn.request, "syn.request", reqTable) end
  if not success then tryHttp(fluxus and fluxus.request, "fluxus.request", reqTable) end
  if not success then tryHttp(delta and delta.request, "delta.request", reqTable) end

  if not success then
    local ok, res = pcall(function()
      return HttpService:PostAsync(currentWebhookURL, body, Enum.HttpContentType.ApplicationJson)
    end)
    if ok then
      success = true
      responseCode = 200
    else
      table.insert(attempts, "HttpService: " .. tostring(res))
      errorMsg = "HttpService: " .. tostring(res)
    end
  end

  if success then
    SendStatus.Text = "Enviado correctamente. (" .. tostring(responseCode) .. ")"
    SendStatus.TextColor3 = Colors.Success
    StatusDot.BackgroundColor3 = Colors.Success
  else
    SendStatus.Text = "Error: " .. (errorMsg or "desconocido") .. "\n\nIntentos:\n" .. table.concat(attempts, "\n")
    SendStatus.TextColor3 = Colors.Danger
    StatusDot.BackgroundColor3 = Colors.Danger
  end
end)

-- ============================================================
-- DRAG (arrastrar ventana)
-- ============================================================

local dragging, dragStart, startPos = false, nil, nil

TopBar.InputBegan:Connect(function(input)
  if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
    dragging = true
    dragStart = input.Position
    startPos = MainFrame.Position
    input.Changed:Connect(function()
      if input.UserInputState == Enum.UserInputState.End then
        dragging = false
      end
    end)
  end
end)

TopBar.InputChanged:Connect(function(input)
  if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
    local delta = input.Position - dragStart
    MainFrame.Position = UDim2.new(
      startPos.X.Scale, startPos.X.Offset + delta.X,
      startPos.Y.Scale, startPos.Y.Offset + delta.Y
    )
  end
end)

print("[WebhookPulse] GUI cargada. Paso 1: Ingresa la URL del webhook.")
