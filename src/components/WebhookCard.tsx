import { useState } from 'react'
import { Copy, Trash2, PauseCircle, PlayCircle, Zap, ExternalLink, Clock } from 'lucide-react'
import type { Webhook } from '../types'
import HealthIndicator from './HealthIndicator'

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
    } catch { /* ignore */ }
  }
  return (
    <div className="flex items-center gap-2 rounded-lg px-3 py-2 border border-[var(--border)]"
      style={{ background: 'var(--bg)' }}>
      <span className="text-[10px] uppercase tracking-wider text-[var(--text-muted)] font-semibold shrink-0">
        {label}
      </span>
      <code className="text-xs text-[var(--text-secondary)] truncate flex-1 font-mono">{url}</code>
      <button
        onClick={handleCopy}
        className="flex items-center gap-1 text-[10px] font-medium text-[var(--accent)] hover:text-[var(--accent-hover)] transition-colors shrink-0"
      >
        <Copy className="w-3 h-3" />
        {copied ? 'Copied' : 'Copy'}
      </button>
    </div>
  )
}

export default function WebhookCard({ webhook, onDelete, onToggle, onNavigate }: WebhookCardProps) {
  const type = webhook.type || 'native'
  const typeLabel = type === 'discord' ? 'Discord' : 'Native'
  const typeColor = type === 'discord' ? 'bg-blue-500/10 text-blue-400' : 'bg-[var(--accent)]/10 text-[var(--accent)]'

  return (
    <div className="group relative rounded-xl overflow-hidden transition-all duration-300 ease-[var(--ease-smooth)] border border-[var(--border)] hover:border-[var(--border-hover)] hover:-translate-y-0.5"
      style={{
        background: 'var(--bg-elevated)',
        boxShadow: '0 4px 24px rgba(0,0,0,0.3), inset 0 1px 0 rgba(255,255,255,0.03)',
      }}
    >
      {/* Left accent bar */}
      <div className="absolute left-0 top-0 bottom-0 w-1" style={{ background: 'var(--accent)' }} />

      <div className="flex-1 p-5 pl-6">
        {/* Header */}
        <div className="flex items-start justify-between mb-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl flex items-center justify-center"
              style={{ background: 'rgba(212,232,58,0.1)' }}>
              <Zap className="w-5 h-5" style={{ color: 'var(--accent)' }} />
            </div>
            <div>
              {onNavigate ? (
                <button onClick={() => onNavigate(webhook.id)} className="text-left">
                  <h3 className="font-semibold text-base text-[var(--text-primary)] hover:text-[var(--accent)] transition-colors">
                    {webhook.name}
                  </h3>
                </button>
              ) : (
                <h3 className="font-semibold text-base text-[var(--text-primary)]">{webhook.name}</h3>
              )}
              {webhook.description && (
                <p className="text-[var(--text-secondary)] text-sm mt-0.5">{webhook.description}</p>
              )}
            </div>
          </div>
          <div className="flex items-center gap-2">
            <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-[10px] font-semibold uppercase tracking-wider ${typeColor}`}>
              {typeLabel}
            </span>
            {webhook.is_active ? (
              <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[10px] font-semibold uppercase tracking-wider"
                style={{ background: 'rgba(74,222,128,0.1)', color: 'var(--success)' }}>
                <span className="w-1.5 h-1.5 rounded-full animate-pulse" style={{ background: 'var(--success)' }} />
                Active
              </span>
            ) : (
              <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[10px] font-semibold uppercase tracking-wider"
                style={{ background: 'rgba(248,113,113,0.1)', color: 'var(--danger)' }}>
                <span className="w-1.5 h-1.5 rounded-full" style={{ background: 'var(--danger)' }} />
                Inactive
              </span>
            )}
            <HealthIndicator webhookId={webhook.id} />
          </div>
        </div>

        {/* URLs */}
        <div className="flex flex-col gap-2 mb-5">
          {webhook.native_url && <CopyUrl url={webhook.native_url} label="Native" />}
          {webhook.discord_url && <CopyUrl url={webhook.discord_url} label="Discord" />}
          {!webhook.native_url && !webhook.discord_url && (
            <div className="flex items-center gap-2 rounded-lg px-3 py-2 border border-[var(--border)]"
              style={{ background: 'var(--bg)' }}>
              <span className="text-sm text-[var(--text-muted)]">No URL available</span>
            </div>
          )}
        </div>

        {/* Stats row */}
        <div className="flex items-center gap-6 mb-5">
          <div className="flex flex-col">
            <span className="text-[10px] uppercase tracking-wider text-[var(--text-muted)] font-semibold mb-1">
              Messages
            </span>
            <span className="text-2xl font-bold text-[var(--text-primary)] tabular-nums">
              {webhook.log_count ?? 0}
            </span>
          </div>
          <div className="h-10 w-px" style={{ background: 'var(--border)' }} />
          <div className="flex flex-col">
            <span className="text-[10px] uppercase tracking-wider text-[var(--text-muted)] font-semibold mb-1">
              Path
            </span>
            <span className="text-sm font-mono text-[var(--text-primary)]">{webhook.url_path}</span>
          </div>
          <div className="h-10 w-px" style={{ background: 'var(--border)' }} />
          <div className="flex flex-col">
            <span className="text-[10px] uppercase tracking-wider text-[var(--text-muted)] font-semibold mb-1">
              Secret
            </span>
            <span className="text-sm text-[var(--text-primary)]">{webhook.has_secret ? 'Yes' : 'No'}</span>
          </div>
          <div className="h-10 w-px" style={{ background: 'var(--border)' }} />
          <div className="flex flex-col">
            <span className="text-[10px] uppercase tracking-wider text-[var(--text-muted)] font-semibold mb-1">
              Created
            </span>
            <span className="text-sm text-[var(--text-secondary)] flex items-center gap-1">
              <Clock className="w-3.5 h-3.5" />
              {new Date(webhook.created_at).toLocaleDateString()}
            </span>
          </div>
        </div>

        {/* Actions */}
        <div className="flex items-center gap-2">
          <button
            onClick={(e) => { e.stopPropagation(); onToggle(webhook.id, webhook.is_active) }}
            className="flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium border border-[var(--border)] text-[var(--text-primary)] hover:bg-[var(--bg-elevated)] hover:border-[var(--border-hover)] transition-all duration-200"
            style={{ background: 'var(--bg)' }}
            title={webhook.is_active ? 'Pause' : 'Resume'}
          >
            {webhook.is_active ? <PauseCircle className="w-4 h-4" /> : <PlayCircle className="w-4 h-4" />}
            {webhook.is_active ? 'Pause' : 'Resume'}
          </button>
          {onNavigate && (
            <button
              onClick={(e) => { e.stopPropagation(); onNavigate(webhook.id) }}
              className="flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium text-[var(--accent)] hover:text-[var(--accent-hover)] transition-colors"
            >
              <ExternalLink className="w-4 h-4" />
              View
            </button>
          )}
          <button
            onClick={(e) => { e.stopPropagation(); onDelete(webhook.id) }}
            className="flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition-all duration-200 ml-auto"
            style={{ background: 'rgba(248,113,113,0.08)', color: 'var(--danger)' }}
            onMouseEnter={(e) => {
              (e.target as HTMLElement).style.background = 'rgba(248,113,113,0.15)'
            }}
            onMouseLeave={(e) => {
              (e.target as HTMLElement).style.background = 'rgba(248,113,113,0.08)'
            }}
          >
            <Trash2 className="w-4 h-4" />
            Delete
          </button>
        </div>
      </div>

      {/* Hover glow overlay */}
      <div className="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-500 pointer-events-none"
        style={{ boxShadow: 'inset 0 0 60px rgba(212,232,58,0.03)' }} />
    </div>
  )
}
