import { useState } from 'react'
import { Copy, Trash2, Activity, PauseCircle, PlayCircle, Zap } from 'lucide-react'
import type { Webhook } from '../types'

interface WebhookCardProps {
  webhook: Webhook
  onDelete: (id: string) => void
  onToggle: (id: string, isActive: boolean) => void
  onNavigate?: (id: string) => void
}

function CopyUrl({ url, label }: { url: string; label: string }) {
  const [copied, setCopied] = useState(false)
  const handleCopy = async (e: React.MouseEvent) => {
    e.stopPropagation()
    try {
      await navigator.clipboard.writeText(url)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch {
      // ignore
    }
  }
  return (
    <div className="flex items-center gap-2 bg-background border border-border rounded px-3 py-2">
      <span className="text-[10px] uppercase tracking-wider text-text-secondary font-semibold shrink-0">
        {label}
      </span>
      <code className="text-sm text-text-secondary truncate flex-1">{url}</code>
      <button
        onClick={handleCopy}
        className="flex items-center gap-1.5 text-xs font-medium text-accent hover:text-accent-hover transition-colors shrink-0"
      >
        <Copy className="w-3.5 h-3.5" />
        {copied ? 'Copied' : 'Copy'}
      </button>
    </div>
  )
}

export default function WebhookCard({ webhook, onDelete, onToggle, onNavigate }: WebhookCardProps) {
  const isDiscord = webhook.has_secret && !!webhook.discord_url
  const typeLabel = isDiscord ? 'Discord' : 'Native'
  const typeColor = isDiscord ? 'bg-blue-500/10 text-blue-400' : 'bg-accent/10 text-accent'

  return (
    <div className="flex rounded-lg overflow-hidden bg-elevated border border-border transition-all duration-150 hover:border-text-secondary/30">
      {/* Barra lateral estilo Discord embed */}
      <div className="w-1 shrink-0 bg-accent" />

      <div className="flex-1 p-5">
        {/* Header: Nombre + Tipo + Estado */}
        <div className="flex items-start justify-between mb-4">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-full bg-accent/10 flex items-center justify-center">
              <Zap className="w-4.5 h-4.5 text-accent" />
            </div>
            <div>
              {onNavigate ? (
                <button onClick={() => onNavigate(webhook.id)} className="text-left">
                  <h3 className="text-text-primary font-semibold text-base hover:text-accent transition-colors">
                    {webhook.name}
                  </h3>
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
            <span className={`inline-flex items-center px-2 py-1 rounded text-xs font-medium ${typeColor}`}>
              {typeLabel}
            </span>
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

        {/* URLs del webhook */}
        <div className="flex flex-col gap-2 mb-5">
          {webhook.native_url && (
            <CopyUrl url={webhook.native_url} label="Native" />
          )}
          {webhook.discord_url && (
            <CopyUrl url={webhook.discord_url} label="Discord" />
          )}
          {!webhook.native_url && !webhook.discord_url && (
            <div className="flex items-center gap-2 bg-background border border-border rounded px-3 py-2">
              <span className="text-sm text-text-secondary">No URL available</span>
            </div>
          )}
        </div>

        {/* Embed body: Mensajes recibidos */}
        <div className="flex items-center gap-6 mb-5">
          <div className="flex flex-col">
            <span className="text-[10px] uppercase tracking-wider text-text-secondary font-semibold mb-1">
              Mensajes recibidos
            </span>
            <span className="text-2xl font-bold text-text-primary">
              {webhook.log_count ?? 0}
            </span>
          </div>
          <div className="h-10 w-px bg-border" />
          <div className="flex flex-col">
            <span className="text-[10px] uppercase tracking-wider text-text-secondary font-semibold mb-1">
              Path
            </span>
            <span className="text-sm font-mono text-text-primary">
              {webhook.url_path}
            </span>
          </div>
          <div className="h-10 w-px bg-border" />
          <div className="flex flex-col">
            <span className="text-[10px] uppercase tracking-wider text-text-secondary font-semibold mb-1">
              Secret
            </span>
            <span className="text-sm text-text-primary">
              {webhook.has_secret ? 'Si' : 'No'}
            </span>
          </div>
        </div>

        {/* Footer actions */}
        <div className="flex items-center gap-2">
          <button
            onClick={(e) => { e.stopPropagation(); onToggle(webhook.id, webhook.is_active) }}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded text-sm font-medium bg-surface border border-border text-text-primary hover:bg-background transition-colors"
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
