import { useState } from 'react'
import { User, Activity, AlertTriangle, Shield, Copy, X, Code, ChevronDown, ChevronUp } from 'lucide-react'
import { t, type TranslationKey } from '../i18n'
import { supabase } from '../lib/supabase'

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

export default function TemplateCard({ templateId, webhookUrl, type }: TemplateCardProps) {
  const [script, setScript] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [previewOpen, setPreviewOpen] = useState(false)

  const meta = TEMPLATE_META[templateId]
  if (!meta) return null

  const Icon = meta.icon
  const API_BASE = import.meta.env.VITE_API_URL || ''

  const handleGenerate = async () => {
    setLoading(true)
    setError(null)
    try {
      const { data: authData } = await supabase.auth.getSession()
      const session = authData?.session
      if (!session) throw new Error('Not authenticated')

      const res = await fetch(`${API_BASE}/api/webhook-template`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${session.access_token}`,
        },
        body: JSON.stringify({ templateId, webhookUrl, type }),
      })

      const data = await res.json()
      if (!res.ok) {
        throw new Error(data.error || 'Failed to generate script')
      }

      setScript(data.luaScript)
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
