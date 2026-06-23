import { useState } from 'react'
import { Copy, Trash2, Activity, PauseCircle, PlayCircle } from 'lucide-react'
import type { Webhook } from '../types'

interface WebhookCardProps {
  webhook: Webhook
  onDelete: (id: string) => void
  onToggle: (id: string, isActive: boolean) => void
  onNavigate?: (id: string) => void
}

export default function WebhookCard({ webhook, onDelete, onToggle, onNavigate }: WebhookCardProps) {
  const [copied, setCopied] = useState(false)
  const baseUrl = typeof window !== 'undefined' ? window.location.origin : ''
  const fullUrl = `${baseUrl}/.netlify/functions/webhook-receive?path=${webhook.url_path}`

  const handleCopy = async (e: React.MouseEvent) => {
    e.stopPropagation()
    try {
      await navigator.clipboard.writeText(fullUrl)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch {
      // ignore
    }
  }

  return (
    <div className="bg-surface border border-border rounded p-6 transition-all duration-150 hover:border-text-secondary/30">
      <div className="flex items-start justify-between mb-4">
        <div className="flex items-center gap-3">
          <Activity className="w-5 h-5 text-accent" />
          <div>
            {onNavigate ? (
              <button
                onClick={() => onNavigate(webhook.id)}
                className="text-left"
              >
                <h3 className="text-text-primary font-semibold text-base hover:text-accent transition-colors">{webhook.name}</h3>
              </button>
            ) : (
              <h3 className="text-text-primary font-semibold text-base">{webhook.name}</h3>
            )}
            {webhook.description && (
              <p className="text-text-secondary text-sm mt-0.5">{webhook.description}</p>
            )}
          </div>
        </div>
        <div className="flex items-center gap-2">
          {webhook.is_active ? (
            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded text-xs font-medium bg-success/10 text-success">
              <span className="w-1.5 h-1.5 rounded-full bg-success" />
              Active
            </span>
          ) : (
            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded text-xs font-medium bg-danger/10 text-danger">
              <span className="w-1.5 h-1.5 rounded-full bg-danger" />
              Inactive
            </span>
          )}
        </div>
      </div>

      <div className="flex items-center gap-2 bg-background border border-border rounded px-3 py-2 mb-4">
        <code className="text-sm text-text-secondary truncate flex-1">{fullUrl}</code>
        <button
          onClick={handleCopy}
          className="flex items-center gap-1.5 text-xs font-medium text-accent hover:text-accent-hover transition-colors"
        >
          <Copy className="w-3.5 h-3.5" />
          {copied ? 'Copied' : 'Copy'}
        </button>
      </div>

      <div className="flex items-center justify-between">
        <div className="text-sm text-text-secondary">
          <span className="text-text-primary font-medium">{webhook.log_count ?? 0}</span> logs received
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={(e) => { e.stopPropagation(); onToggle(webhook.id, webhook.is_active) }}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded text-sm font-medium bg-surface border border-border text-text-primary hover:bg-elevated transition-colors"
            title={webhook.is_active ? 'Pause' : 'Resume'}
          >
            {webhook.is_active ? (
              <PauseCircle className="w-4 h-4" />
            ) : (
              <PlayCircle className="w-4 h-4" />
            )}
            {webhook.is_active ? 'Pause' : 'Resume'}
          </button>
          <button
            onClick={(e) => { e.stopPropagation(); onDelete(webhook.id) }}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded text-sm font-medium bg-danger/10 text-danger hover:bg-danger/20 transition-colors"
          >
            <Trash2 className="w-4 h-4" />
            Delete
          </button>
        </div>
      </div>
    </div>
  )
}
