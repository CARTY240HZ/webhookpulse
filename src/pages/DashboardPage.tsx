import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Plus, Inbox, LayoutTemplate, Zap, Activity, BarChart3, Clock } from 'lucide-react'
import { useWebhooks } from '../hooks/useWebhooks'
import { t } from '../i18n'
import WebhookCard from '../components/WebhookCard'
import TemplateCard from '../components/TemplateCard'
import CreateWebhookModal from '../components/CreateWebhookModal'
import RevealWebhookUrlModal from '../components/RevealWebhookUrlModal'
import { SkeletonCard } from '../components/Skeleton'
import { useAdaptiveServing } from '../hooks/useAdaptiveServing'
import type { Webhook } from '../types'
import { Button, Card } from '../components/ui'

export default function DashboardPage() {
  const { webhooks, loading, error, createWebhook, deleteWebhook, toggleWebhook, revealWebhook } = useWebhooks()
  const [modalOpen, setModalOpen] = useState(false)
  const [selectedWebhookId, setSelectedWebhookId] = useState<string>('')
  const [revealModalWebhook, setRevealModalWebhook] = useState<{ id: string; name: string } | null>(null)
  const navigate = useNavigate()

  const handleCreate = async (name: string, description?: string, type: 'native' | 'discord' = 'native') => {
    return await createWebhook(name, description, type)
  }

  const activeWebhooks = webhooks.filter((w) => w.is_active)
  const selectedWebhook = activeWebhooks.find((w) => w.id === selectedWebhookId) || activeWebhooks[0]

  const getWebhookUrlAndType = (webhook: Webhook | undefined): { url: string; type: 'native' | 'discord' } => {
    if (!webhook) return { url: '', type: 'native' }
    const type = webhook.type || 'native'
    return {
      url: type === 'discord' ? (webhook.discord_url || '') : (webhook.native_url || ''),
      type,
    }
  }

  const { url: selectedUrl, type: selectedType } = getWebhookUrlAndType(selectedWebhook)
  const connection = useAdaptiveServing()
  const isSlowConnection = connection.effectiveType === '2g' || connection.effectiveType === 'slow-2g' || connection.saveData

  const totalLogs = webhooks.reduce((acc, w) => acc + (w.log_count || 0), 0)
  const activeCount = webhooks.filter(w => w.is_active).length
  const uptimeMs = webhooks.reduce((acc, w) => acc + (Date.now() - new Date(w.created_at).getTime()), 0)
  const avgUptimeDays = webhooks.length > 0 ? Math.round(uptimeMs / webhooks.length / 86400000) : 0

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-[var(--text-primary)] tracking-tight">Webhooks</h1>
          <p className="text-sm text-[var(--text-secondary)] mt-1">Manage your endpoints and inspect incoming logs.</p>
        </div>
        <div className="flex items-center gap-3">
          {isSlowConnection && (
            <span className="text-xs text-[var(--text-secondary)] px-3 py-1.5 rounded-lg border border-[var(--border)]"
              style={{ background: 'var(--bg-elevated)' }}>
              Slow connection — reduced data mode
            </span>
          )}
          <Button onClick={() => setModalOpen(true)} leftIcon={<Plus className="w-4 h-4" />}>
            New webhook
          </Button>
        </div>
      </div>

      {/* Stats row */}
      {!loading && webhooks.length > 0 && (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          {[
            { icon: Zap, label: 'Total webhooks', value: webhooks.length, color: 'var(--accent)' },
            { icon: Activity, label: 'Active', value: activeCount, color: 'var(--success)' },
            { icon: BarChart3, label: 'Logs today', value: totalLogs.toLocaleString(), color: 'var(--info)' },
            { icon: Clock, label: 'Avg age', value: `${avgUptimeDays}d`, color: 'var(--warning)' },
          ].map((stat) => (
            <Card key={stat.label} variant="elevated" hover={true} className="p-5"
              style={{ boxShadow: '0 4px 24px rgba(0,0,0,0.3), inset 0 1px 0 rgba(255,255,255,0.03)' }}>
              <div className="flex items-center gap-2 mb-3">
                <stat.icon className="w-4 h-4" style={{ color: stat.color }} />
                <span className="text-xs font-semibold uppercase tracking-wider text-[var(--text-muted)]">{stat.label}</span>
              </div>
              <span className="text-2xl font-bold text-[var(--text-primary)] tabular-nums">{stat.value}</span>
            </Card>
          ))}
        </div>
      )}

      {/* Loading */}
      {loading && (
        <div className="grid grid-cols-1 gap-4">
          <SkeletonCard />
          <SkeletonCard />
          <SkeletonCard />
        </div>
      )}

      {/* Error */}
      {error && (
        <div className="rounded-xl p-4 text-sm border"
          style={{ background: 'rgba(248,113,113,0.08)', borderColor: 'rgba(248,113,113,0.15)', color: 'var(--danger)' }}>
          {error}
        </div>
      )}

      {/* Empty state */}
      {!loading && webhooks.length === 0 && (
        <Card variant="elevated" className="p-12 text-center"
          style={{ boxShadow: '0 4px 24px rgba(0,0,0,0.3), inset 0 1px 0 rgba(255,255,255,0.03)' }}>
          <div className="w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-6"
            style={{ background: 'rgba(212,232,58,0.08)' }}>
            <Inbox className="w-8 h-8" style={{ color: 'var(--accent)' }} />
          </div>
          <h3 className="text-[var(--text-primary)] font-semibold text-lg mb-2">No webhooks yet</h3>
          <p className="text-sm text-[var(--text-secondary)] mb-6 max-w-sm mx-auto">Create your first webhook to start receiving events from Discord, Roblox, or any custom service.</p>
          <Button onClick={() => setModalOpen(true)} leftIcon={<Plus className="w-4 h-4" />} size="lg">
            Create webhook
          </Button>
        </Card>
      )}

      {/* Webhook list */}
      {!loading && webhooks.length > 0 && (
        <div className="grid grid-cols-1 gap-4">
          {webhooks.map((webhook) => (
            <WebhookCard
              key={webhook.id}
              webhook={webhook}
              onDelete={(id) => deleteWebhook(id)}
              onToggle={(id, active) => toggleWebhook(id, active)}
              onNavigate={(id) => navigate(`/dashboard/webhooks/${id}`)}
              onReveal={(id, name) => setRevealModalWebhook({ id, name })}
            />
          ))}
        </div>
      )}

      {/* Templates */}
      {!loading && webhooks.length > 0 && selectedWebhook && (
        <div className="space-y-4 pt-2">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div className="flex items-center gap-2">
              <LayoutTemplate className="w-5 h-5" style={{ color: 'var(--accent)' }} />
              <h2 className="text-xl font-bold text-[var(--text-primary)]">{t('webhooks.templates.title')}</h2>
            </div>
            {activeWebhooks.length > 1 && (
              <div className="flex items-center gap-2">
                <label className="text-xs text-[var(--text-secondary)]">Webhook:</label>
                <select
                  value={selectedWebhook.id}
                  onChange={(e) => setSelectedWebhookId(e.target.value)}
                  className="px-3 py-1.5 rounded-lg text-sm text-[var(--text-primary)] border border-[var(--border)] focus:border-[var(--accent)] transition-colors"
                  style={{ background: 'var(--bg-elevated)' }}
                >
                  {activeWebhooks.map((w) => (
                    <option key={w.id} value={w.id}>{w.name}</option>
                  ))}
                </select>
              </div>
            )}
          </div>
          <div className={`grid grid-cols-1 sm:grid-cols-2 ${isSlowConnection ? '' : 'lg:grid-cols-4'} gap-4`}>
            <TemplateCard templateId="player_join" webhookUrl={selectedUrl} type={selectedType} />
            <TemplateCard templateId="server_stats" webhookUrl={selectedUrl} type={selectedType} />
            {!isSlowConnection && (
              <>
                <TemplateCard templateId="error_logger" webhookUrl={selectedUrl} type={selectedType} />
                <TemplateCard templateId="admin_command" webhookUrl={selectedUrl} type={selectedType} />
              </>
            )}
          </div>
        </div>
      )}

      {modalOpen && (
        <CreateWebhookModal
          onClose={() => setModalOpen(false)}
          onCreate={handleCreate}
        />
      )}

      {revealModalWebhook && (
        <RevealWebhookUrlModal
          webhookId={revealModalWebhook.id}
          webhookName={revealModalWebhook.name}
          onClose={() => setRevealModalWebhook(null)}
          onReveal={revealWebhook}
        />
      )}
    </div>
  )
}
