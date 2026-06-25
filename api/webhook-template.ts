import { setCorsHeaders } from './_lib/cors.js'
import { getUserFromJWT } from './_lib/auth.js'
import { apiError } from './_lib/errors.js'
import { captureException } from './_lib/sentry.js'

const VALID_TEMPLATES = new Set(['player_join', 'server_stats', 'error_logger', 'admin_command'])

function generateLuaScript(templateId: string, webhookUrl: string, type: 'native' | 'discord'): string {
  const isDiscord = type === 'discord' || webhookUrl.includes('discord.com/api/webhooks')

  const baseScript = `--[[
  WebhookPulse Template: ${templateId}
  Auto-generated for ${isDiscord ? 'Discord' : 'Native'} webhooks
  Paste this into your Roblox game (ServerScriptService)
--]]

local WEBHOOK_URL = "${webhookUrl.replace(/"/g, '\\"')}"

-- Universal HTTP request fallback
local function sendRequest(payload)
  local HttpService = game:GetService("HttpService")
  local body = HttpService:JSONEncode(payload)
  local headers = { ["Content-Type"] = "application/json" }

  local requestFunc = (syn and syn.request) or (fluxus and fluxus.request) or (getgenv and getgenv().request) or request or http_request
  if requestFunc then
    local ok, res = pcall(function()
      return requestFunc({
        Url = WEBHOOK_URL,
        Method = "POST",
        Headers = headers,
        Body = body
      })
    end)
    if ok and res then return res end
  end

  -- Fallback to Roblox HttpService
  local ok, res = pcall(function()
    return HttpService:PostAsync(WEBHOOK_URL, body, Enum.HttpContentType.ApplicationJson, false)
  end)
  if ok then return res end

  -- Final fallback: HttpRequest (some executors)
  if http and http.request then
    local ok2, res2 = pcall(function()
      return http.request({
        url = WEBHOOK_URL,
        method = "POST",
        headers = headers,
        data = body
      })
    end)
    if ok2 then return res2 end
  end

  warn("[WebhookPulse] Failed to send request to " .. WEBHOOK_URL)
  return nil
end

local IS_DISCORD = WEBHOOK_URL:find("discord.com/api/webhooks") ~= nil
`

  const playerJoinScript = baseScript + `
-- Player Join Event
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

Players.PlayerAdded:Connect(function(player)
  local character = player.Character or player.CharacterAdded:Wait()
  local hrp = character:WaitForChild("HumanoidRootPart")
  local humanoid = character:WaitForChild("Humanoid")

  local payload
  if IS_DISCORD then
    payload = {
      embeds = {{
        title = "Player Joined",
        color = 65280,
        fields = {
          { name = "Username", value = player.Name, inline = true },
          { name = "Display Name", value = player.DisplayName, inline = true },
          { name = "User ID", value = tostring(player.UserId), inline = true },
          { name = "Account Age", value = tostring(player.AccountAge) .. " days", inline = true },
          { name = "Membership", value = tostring(player.MembershipType), inline = true },
          { name = "Position", value = tostring(hrp.Position), inline = false },
          { name = "Health", value = tostring(math.floor(humanoid.Health)) .. "/" .. tostring(math.floor(humanoid.MaxHealth)), inline = true },
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        footer = { text = "WebhookPulse" }
      }}
    }
  else
    payload = {
      event = "player_join",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
      player = {
        userId = player.UserId,
        username = player.Name,
        displayName = player.DisplayName,
        accountAge = player.AccountAge,
        membershipType = tostring(player.MembershipType),
        position = { x = hrp.Position.X, y = hrp.Position.Y, z = hrp.Position.Z },
        health = humanoid.Health,
        maxHealth = humanoid.MaxHealth,
        placeId = game.PlaceId,
        jobId = game.JobId
      }
    }
  end

  sendRequest(payload)
end)

print("[WebhookPulse] Player Join template active")
`

  const serverStatsScript = baseScript + `
-- Server Stats Monitor (every 60 seconds)
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local StatsService = game:GetService("Stats")

local lastSend = 0
local INTERVAL = 60

RunService.Heartbeat:Connect(function()
  local now = tick()
  if now - lastSend < INTERVAL then return end
  lastSend = now

  local fps = math.floor(1 / RunService.Heartbeat:Wait())
  local mem = math.floor(StatsService:GetTotalMemoryUsageMb() or 0)
  local ping = 0
  pcall(function()
    ping = math.floor(StatsService.Network.ServerStatsItem["Data Ping"]:GetValue() or 0)
  end)

  local payload
  if IS_DISCORD then
    payload = {
      embeds = {{
        title = "Server Stats",
        color = 3447003,
        fields = {
          { name = "Players", value = tostring(#Players:GetPlayers()) .. "/" .. tostring(Players.MaxPlayers), inline = true },
          { name = "FPS", value = tostring(fps), inline = true },
          { name = "Ping", value = tostring(ping) .. " ms", inline = true },
          { name = "Memory", value = tostring(mem) .. " MB", inline = true },
          { name = "Place ID", value = tostring(game.PlaceId), inline = true },
          { name = "Job ID", value = tostring(game.JobId):sub(1, 16) .. "...", inline = true },
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        footer = { text = "WebhookPulse" }
      }}
    }
  else
    payload = {
      event = "server_stats",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
      server = {
        players = #Players:GetPlayers(),
        maxPlayers = Players.MaxPlayers,
        fps = fps,
        ping = ping,
        memory = mem,
        placeId = game.PlaceId,
        jobId = game.JobId
      }
    }
  end

  sendRequest(payload)
end)

print("[WebhookPulse] Server Stats template active (60s interval)")
`

  const errorLoggerScript = baseScript + `
-- Error Logger
local ScriptContext = game:GetService("ScriptContext")

ScriptContext.Error:Connect(function(message, stack, scriptRef)
  local scriptName = "Unknown"
  local lineNumber = 0

  if scriptRef then
    pcall(function()
      scriptName = scriptRef.Name or tostring(scriptRef)
    end)
  end

  -- Try to extract line number from stack trace
  local firstLine = stack:match("Line (%d+)") or stack:match(":(%d+):") or "0"
  lineNumber = tonumber(firstLine) or 0

  local payload
  if IS_DISCORD then
    payload = {
      embeds = {{
        title = "Script Error",
        color = 16711680,
        fields = {
          { name = "Message", value = message:sub(1, 1000), inline = false },
          { name = "Script", value = scriptName:sub(1, 256), inline = true },
          { name = "Line", value = tostring(lineNumber), inline = true },
          { name = "Stack Trace", value = "\`\`\`\n" .. stack:sub(1, 1000) .. "\n\`\`\`", inline = false },
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        footer = { text = "WebhookPulse" }
      }}
    }
  else
    payload = {
      event = "error",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
      error = {
        message = message,
        script = scriptName,
        line = lineNumber,
        stack = stack,
        placeId = game.PlaceId,
        jobId = game.JobId
      }
    }
  end

  sendRequest(payload)
end)

print("[WebhookPulse] Error Logger template active")
`

  const adminCommandScript = baseScript + `
-- Admin Command Logger
-- Integrate with your admin system by calling logAdminCommand(executor, command, args, target)

local function logAdminCommand(executor, command, args, target)
  local payload
  if IS_DISCORD then
    payload = {
      embeds = {{
        title = "Admin Command Executed",
        color = 16776960,
        fields = {
          { name = "Executor", value = tostring(executor), inline = true },
          { name = "Command", value = tostring(command), inline = true },
          { name = "Args", value = tostring(args):sub(1, 1024), inline = false },
          { name = "Target", value = target and tostring(target) or "None", inline = true },
          { name = "Place ID", value = tostring(game.PlaceId), inline = true },
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        footer = { text = "WebhookPulse" }
      }}
    }
  else
    payload = {
      event = "admin_command",
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
      command = {
        executor = tostring(executor),
        command = tostring(command),
        args = args,
        target = target and tostring(target) or nil,
        placeId = game.PlaceId,
        jobId = game.JobId
      }
    }
  end

  sendRequest(payload)
end

-- Example: hook into your admin system
-- Replace this with your actual command handler integration
-- logAdminCommand(game.Players.LocalPlayer.Name, "kick", "spam", "TargetPlayer")

-- Expose globally so your admin system can call it
if getgenv then
  getgenv().WebhookPulseLogAdminCommand = logAdminCommand
end

print("[WebhookPulse] Admin Command template active")
print("[WebhookPulse] Use WebhookPulseLogAdminCommand(executor, command, args, target) to log commands")
`

  switch (templateId) {
    case 'player_join': return playerJoinScript
    case 'server_stats': return serverStatsScript
    case 'error_logger': return errorLoggerScript
    case 'admin_command': return adminCommandScript
    default: return '-- Unknown template'
  }
}

export default async function handler(req: any, res: any) {
  if (req.method === 'OPTIONS') {
    setCorsHeaders(res, 'private')
    return res.status(204).end()
  }

  if (req.method !== 'POST') {
    return apiError(res, 405, 'METHOD_NOT_ALLOWED')
  }

  try {
    const authHeader = req.headers.authorization || ''
    const user = await getUserFromJWT(authHeader)
    if (!user) {
      return apiError(res, 401, 'UNAUTHORIZED')
    }

    const body = req.body || {}
    const templateId = (body.templateId as string) || ''
    const webhookUrl = (body.webhookUrl as string) || ''
    const type = (body.type as 'native' | 'discord') || 'native'

    if (!VALID_TEMPLATES.has(templateId)) {
      return apiError(res, 400, 'INVALID_TEMPLATE_ID')
    }

    if (!webhookUrl || !webhookUrl.startsWith('http')) {
      return apiError(res, 400, 'INVALID_WEBHOOK_URL')
    }

    if (type !== 'native' && type !== 'discord') {
      return apiError(res, 400, 'INVALID_TYPE')
    }

    const luaScript = generateLuaScript(templateId, webhookUrl, type)

    return res.status(200).json({ luaScript })
  } catch (err) {
    captureException(err as Error)
    return apiError(res, 500, 'INTERNAL_ERROR')
  }
}
