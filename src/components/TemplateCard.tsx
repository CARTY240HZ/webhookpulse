import { useState } from 'react'
import { User, Activity, AlertTriangle, Shield, Copy, X, Code, ChevronDown, ChevronUp } from 'lucide-react'
import { t, type TranslationKey } from '../i18n'

interface TemplateCardProps {
  templateId: string
  webhookUrl: string
  type: 'native' | 'discord'
}

const TEMPLATE_META: Record<string, { titleKey: TranslationKey; description: string; icon: React.ElementType; preview: Record<string, unknown> }> = {
  player_join: {
    titleKey: 'webhooks.templates.playerJoin',
    description: 'Send player data when someone joins your game. Includes userId, username, displayName, accountAge, position, and health.',
    icon: User,
    preview: {
      event: 'player_join',
      timestamp: '2024-01-15T12:00:00Z',
      player: {
        userId: 123456789,
        username: 'PlayerName',
        displayName: 'DisplayName',
        accountAge: 365,
        membershipType: 'Premium',
        position: { x: 0, y: 10, z: 0 },
        health: 100,
        maxHealth: 100,
        placeId: 1234567890,
        jobId: 'abc-123'
      }
    }
  },
  server_stats: {
    titleKey: 'webhooks.templates.serverStats',
    description: 'Send server statistics every 60 seconds. Includes player count, FPS, ping, memory usage, and place info.',
    icon: Activity,
    preview: {
      event: 'server_stats',
      timestamp: '2024-01-15T12:00:00Z',
      server: {
        players: 12,
        maxPlayers: 20,
        fps: 60,
        ping: 45,
        memory: 512,
        placeId: 1234567890,
        jobId: 'abc-123'
      }
    }
  },
  error_logger: {
    titleKey: 'webhooks.templates.errorLogger',
    description: 'Capture script errors via ScriptContext.Error with full stack trace, script name, and line number.',
    icon: AlertTriangle,
    preview: {
      event: 'error',
      timestamp: '2024-01-15T12:00:00Z',
      error: {
        message: 'attempt to index nil with \'Name\'',
        script: 'ServerScriptService.AdminModule',
        line: 42,
        stack: 'ServerScriptService.AdminModule:42\nServerScriptService.Main:15',
        placeId: 1234567890,
        jobId: 'abc-123'
      }
    }
  },
  admin_command: {
    titleKey: 'webhooks.templates.adminCommand',
    description: 'Log admin commands with executor name, command, arguments, and target player for full audit trails.',
    icon: Shield,
    preview: {
      event: 'admin_command',
      timestamp: '2024-01-15T12:00:00Z',
      command: {
        executor: 'AdminUser',
        command: 'kick',
        args: ['spamming'],
        target: 'TargetPlayer',
        placeId: 1234567890,
        jobId: 'abc-123'
      }
    }
  }
}

function ScriptModal({ script, onClose }: { script: string; onClose: () => void }) {
  const [copied, setCopied] = useState(false)

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(script)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch {
      // ignore
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4">
      <div className="bg-surface border border-border rounded-lg w-full max-w-3xl max-h-[90vh] flex flex-col">
        <div className="flex items-center justify-between p-4 border-b border-border">
          <div className="flex items-center gap-2">
            <Code className="w-5 h-5 text-accent" />
            <h3 className="text-lg font-semibold text-text-primary">{t('webhooks.templates.generate')}</h3>
          </div>
          <button onClick={onClose} className="text-text-secondary hover:text-text-primary transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>
        <div className="flex-1 overflow-auto p-4">
          <pre className="text-xs font-mono text-text-secondary bg-background border border-border rounded p-4 overflow-x-auto whitespace-pre-wrap break-all">
            {script}
          </pre>
        </div>
        <div className="flex items-center justify-end gap-3 p-4 border-t border-border">
          <button
            onClick={onClose}
            className="px-4 py-2 rounded text-sm font-medium bg-surface border border-border text-text-primary hover:bg-elevated transition-colors"
          >
            {t('settings.cancel')}
          </button>
          <button
            onClick={handleCopy}
            className="flex items-center gap-2 px-4 py-2 rounded text-sm font-medium bg-accent text-background hover:bg-accent-hover transition-colors"
          >
            <Copy className="w-4 h-4" />
            {copied ? t('common.copied') : t('webhooks.templates.copy')}
          </button>
        </div>
      </div>
    </div>
  )
}


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

export default function TemplateCard({ templateId, webhookUrl, type }: TemplateCardProps) {
  const [script, setScript] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [previewOpen, setPreviewOpen] = useState(false)

  const meta = TEMPLATE_META[templateId]
  if (!meta) return null

  const Icon = meta.icon

  const handleGenerate = () => {
    setLoading(true)
    setError(null)
    try {
      if (!webhookUrl || !webhookUrl.startsWith('http')) {
        throw new Error('Invalid webhook URL')
      }
      const luaScript = generateLuaScript(templateId, webhookUrl, type)
      setScript(luaScript)
    } catch (err) {
      setError((err as Error).message)
    } finally {
      setLoading(false)
    }
  }

  const previewJson = JSON.stringify(meta.preview, null, 2)

  return (
    <>
      <div className="flex flex-col rounded-lg bg-elevated border border-border transition-all duration-150 hover:border-text-secondary/30 overflow-hidden">
        {/* Accent bar */}
        <div className="h-1 bg-accent" />

        <div className="p-5 flex-1 flex flex-col">
          {/* Header */}
          <div className="flex items-center gap-3 mb-3">
            <div className="w-9 h-9 rounded-full bg-accent/10 flex items-center justify-center">
              <Icon className="w-4.5 h-4.5 text-accent" />
            </div>
            <h3 className="text-text-primary font-semibold text-base">{t(meta.titleKey)}</h3>
          </div>

          {/* Description */}
          <p className="text-sm text-text-secondary mb-4 flex-1">{meta.description}</p>

          {/* Preview toggle */}
          <button
            onClick={() => setPreviewOpen(!previewOpen)}
            className="flex items-center gap-1.5 text-xs text-accent hover:text-accent-hover transition-colors mb-3"
          >
            {previewOpen ? <ChevronUp className="w-3.5 h-3.5" /> : <ChevronDown className="w-3.5 h-3.5" />}
            {t('webhooks.templates.preview')}
          </button>

          {previewOpen && (
            <div className="mb-4 bg-background border border-border rounded p-3 overflow-x-auto">
              <pre className="text-[10px] font-mono text-text-secondary whitespace-pre-wrap">{previewJson}</pre>
            </div>
          )}

          {/* Error */}
          {error && (
            <p className="text-xs text-danger mb-3">{error}</p>
          )}

          {/* Action */}
          <button
            onClick={handleGenerate}
            disabled={loading || !webhookUrl}
            className="flex items-center justify-center gap-2 w-full px-4 py-2 rounded text-sm font-medium bg-accent text-background hover:bg-accent-hover transition-colors disabled:opacity-50"
          >
            <Code className="w-4 h-4" />
            {loading ? t('common.loading') : t('webhooks.templates.generate')}
          </button>
        </div>
      </div>

      {script && (
        <ScriptModal script={script} onClose={() => setScript(null)} />
      )}
    </>
  )
}
