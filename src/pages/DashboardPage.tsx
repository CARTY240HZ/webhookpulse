import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Plus, Inbox } from 'lucide-react'
import { useWebhooks } from '../hooks/useWebhooks'
import WebhookCard from '../components/WebhookCard'
import CreateWebhookModal from '../components/CreateWebhookModal'
import type { Webhook } from '../types'

export default function DashboardPage() {
  const { webhooks, loading, error, createWebhook, deleteWebhook, toggleWebhook } = useWebhooks()
  const [modalOpen, setModalOpen] = useState(false)
  const navigate = useNavigate()

  const handleCreate = async (name: string, description?: string, secret?: string) => {
    return await createWebhook(name, description, secret)
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-text-primary">Webhooks</h1>
          <p className="text-sm text-text-secondary mt-1">Manage your endpoints and inspect incoming logs.</p>
        </div>
        <button
          onClick={() => setModalOpen(true)}
          className="flex items-center gap-2 px-4 py-2 rounded text-sm font-medium bg-accent text-background hover:bg-accent-hover transition-colors"
        >
          <Plus className="w-4 h-4" />
          New webhook
        </button>
      </div>

      {loading && (
        <div className="text-sm text-text-secondary">Loading webhooks...</div>
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

      {modalOpen && (
        <CreateWebhookModal
          onClose={() => setModalOpen(false)}
          onCreate={handleCreate}
        />
      )}
    </div>
  )
}
