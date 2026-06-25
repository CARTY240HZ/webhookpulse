import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Plus, Inbox, LayoutTemplate } from 'lucide-react'
import { useWebhooks } from '../hooks/useWebhooks'
import { t } from '../i18n'
import WebhookCard from '../components/WebhookCard'
import TemplateCard from '../components/TemplateCard'
import CreateWebhookModal from '../components/CreateWebhookModal'
import { SkeletonCard } from '../components/Skeleton'
import { useAdaptiveServing } from '../hooks/useAdaptiveServing'
import type { Webhook } from '../types'

export default function DashboardPage() {
  const { webhooks, loading, error, createWebhook, deleteWebhook, toggleWebhook } = useWebhooks()
  const [modalOpen, setModalOpen] = useState(false)
  const [selectedWebhookId, setSelectedWebhookId] = useState<string>('')
  const navigate = useNavigate()

  const handleCreate = async (name: string, description?: string, type: 'native' | 'discord' = 'native') => {
    return await createWebhook(name, description, type)
  }

  const activeWebhooks = webhooks.filter((w) => w.is_active)
  const selectedWebhook = activeWebhooks.find((w) => w.id === selectedWebhookId) || activeWebhooks[0]

  const getWebhookUrlAndType = (webhook: Webhook | undefined): { url: string; type: 'native' | 'discord' } => {
    if (!webhook) return { url: '', type: 'native' }
    const isDiscord = webhook.has_secret && !!webhook.discord_url
    return {
      url: isDiscord ? (webhook.discord_url || '') : (webhook.native_url || ''),
      type: isDiscord ? 'discord' : 'native',
    }
  }

  const { url: selectedUrl, type: selectedType } = getWebhookUrlAndType(selectedWebhook)
  const connection = useAdaptiveServing()
  const isSlowConnection = connection.effectiveType === '2g' || connection.effectiveType === 'slow-2g' || connection.saveData


  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-text-primary">Webhooks</h1>
          <p className="text-sm text-text-secondary mt-1">Manage your endpoints and inspect incoming logs.</p>
        </div>
        <div className="flex items-center gap-3">
          {isSlowConnection && (
            <span className="text-xs text-text-secondary bg-surface border border-border rounded px-2 py-1">
              Slow connection — reduced data mode
            </span>
          )}
          <button
            onClick={() => setModalOpen(true)}
            className="flex items-center gap-2 px-4 py-2 rounded text-sm font-medium bg-accent text-background hover:bg-accent-hover transition-colors"
          >
            <Plus className="w-4 h-4" />
            New webhook
          </button>
        </div>
      </div>

      {loading && (
        <div className="grid grid-cols-1 gap-4">
          <SkeletonCard />
          <SkeletonCard />
          <SkeletonCard />
        </div>
      )}

      {error && (
        <div className="bg-danger/10 border border-danger/20 rounded p-4 text-sm text-danger">
          {error}
        </div>
      )}

      {!loading && webhooks.length === 0 && (
        <div className="bg-surface border border-border rounded p-12 text-center">
          <Inbox className="w-8 h-8 text-text-secondary mx-auto mb-4" />
          <h3 className="text-text-primary font-medium mb-1">No webhooks yet</h3>
          <p className="text-sm text-text-secondary mb-4">Create your first webhook to start receiving events.</p>
          <button
            onClick={() => setModalOpen(true)}
            className="inline-flex items-center gap-2 px-4 py-2 rounded text-sm font-medium bg-accent text-background hover:bg-accent-hover transition-colors"
          >
            <Plus className="w-4 h-4" />
            Create webhook
          </button>
        </div>
      )}

      {!loading && webhooks.length > 0 && (
        <div className="grid grid-cols-1 gap-4">
          {webhooks.map((webhook) => (
            <WebhookCard
              key={webhook.id}
              webhook={webhook}
              onDelete={(id) => deleteWebhook(id)}
              onToggle={(id, active) => toggleWebhook(id, active)}
              onNavigate={(id) => navigate(`/dashboard/webhooks/${id}`)}
            />
          ))}
        </div>
      )}

      {/* Templates Section */}
      {!loading && webhooks.length > 0 && selectedWebhook && (
        <div className="space-y-4 pt-2">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div className="flex items-center gap-2">
              <LayoutTemplate className="w-5 h-5 text-accent" />
              <h2 className="text-xl font-bold text-text-primary">{t('webhooks.templates.title')}</h2>
            </div>
            {activeWebhooks.length > 1 && (
              <div className="flex items-center gap-2">
                <label className="text-xs text-text-secondary">Webhook:</label>
                <select
                  value={selectedWebhook.id}
                  onChange={(e) => setSelectedWebhookId(e.target.value)}
                  className="px-3 py-1.5 bg-background border border-border rounded text-sm text-text-primary focus:border-accent transition-colors"
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
    </div>
  )
}
