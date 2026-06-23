import { useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { ArrowLeft, Copy, Trash2, Activity, CheckSquare, Square } from 'lucide-react'
import { useRealtimeLogs } from '../hooks/useRealtimeLogs'
import { supabase } from '../lib/supabase'
import { useWebhooks } from '../hooks/useWebhooks'
import LogRow from '../components/LogRow'
import type { Webhook } from '../types'

export default function WebhookDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { webhooks, refresh } = useWebhooks()
  const { logs, loading: logsLoading, deleteLog, deleteSelectedLogs, deleteAllLogs } = useRealtimeLogs(id || null)
  const [copied, setCopied] = useState(false)
  const [deleting, setDeleting] = useState(false)
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set())
  const [batchDeleting, setBatchDeleting] = useState(false)

  const webhook = webhooks.find((w) => w.id === id) as Webhook | undefined

  const baseUrl = typeof window !== 'undefined' ? window.location.origin : ''
  const fullUrl = webhook ? `${baseUrl}/api/webhook-receive?path=${webhook.url_path}` : ''

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(fullUrl)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    } catch {
      // ignore
    }
  }

  const handleDelete = async () => {
    if (!id || !confirm('Delete this webhook and all its logs? This cannot be undone.')) return
    setDeleting(true)
    try {
      await supabase.from('webhooks').delete().eq('id', id)
      await refresh()
      navigate('/dashboard')
    } catch {
      // ignore
    } finally {
      setDeleting(false)
    }
  }

  const handleToggle = async () => {
    if (!webhook) return
    await supabase
      .from('webhooks')
      .update({ is_active: !webhook.is_active, updated_at: new Date().toISOString() })
      .eq('id', webhook.id)
    await refresh()
  }

  const handleSelect = (logId: string, checked: boolean) => {
    setSelectedIds((prev) => {
      const next = new Set(prev)
      if (checked) next.add(logId)
      else next.delete(logId)
      return next
    })
  }

  const handleSelectAll = () => {
    if (selectedIds.size === logs.length) {
      setSelectedIds(new Set())
    } else {
      setSelectedIds(new Set(logs.map((l) => l.id)))
    }
  }

  const handleDeleteSelected = async () => {
    if (selectedIds.size === 0) return
    if (!confirm(`Delete ${selectedIds.size} selected log(s)? This cannot be undone.`)) return
    setBatchDeleting(true)
    try {
      await deleteSelectedLogs(Array.from(selectedIds))
      setSelectedIds(new Set())
    } catch {
      // ignore
    } finally {
      setBatchDeleting(false)
    }
  }

  const handleDeleteAll = async () => {
    if (logs.length === 0) return
    if (!confirm(`Delete ALL ${logs.length} logs? This cannot be undone.`)) return
    setBatchDeleting(true)
    try {
      await deleteAllLogs()
      setSelectedIds(new Set())
    } catch {
      // ignore
    } finally {
      setBatchDeleting(false)
    }
  }

  const allSelected = logs.length > 0 && selectedIds.size === logs.length
  const someSelected = selectedIds.size > 0 && selectedIds.size < logs.length

  if (!webhook && !webhooks.length) {
    return <div className="text-sm text-text-secondary">Loading...</div>
  }

  if (!webhook) {
    return <div className="text-sm text-danger">Webhook not found.</div>
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <button
          onClick={() => navigate('/dashboard')}
          className="flex items-center gap-1.5 text-sm text-text-secondary hover:text-text-primary transition-colors"
        >
          <ArrowLeft className="w-4 h-4" />
          Back
        </button>
      </div>

      <div className="bg-surface border border-border rounded p-6">
        <div className="flex items-start justify-between mb-6">
          <div className="flex items-center gap-3">
            <Activity className="w-5 h-5 text-accent" />
            <div>
              <h1 className="text-xl font-bold text-text-primary">{webhook.name}</h1>
              {webhook.description && (
                <p className="text-sm text-text-secondary mt-0.5">{webhook.description}</p>
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

        <div className="flex items-center gap-3">
          <button
            onClick={handleToggle}
            className="px-4 py-2 rounded text-sm font-medium bg-surface border border-border text-text-primary hover:bg-elevated transition-colors"
          >
            {webhook.is_active ? 'Pause' : 'Resume'}
          </button>
          <button
            onClick={handleDelete}
            disabled={deleting}
            className="flex items-center gap-2 px-4 py-2 rounded text-sm font-medium bg-danger/10 text-danger hover:bg-danger/20 transition-colors disabled:opacity-50"
          >
            <Trash2 className="w-4 h-4" />
            {deleting ? 'Deleting...' : 'Delete'}
          </button>
        </div>
      </div>

      <div>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold text-text-primary">Recent logs</h2>
          {!logsLoading && logs.length > 0 && (
            <div className="flex items-center gap-2">
              <button
                onClick={handleSelectAll}
                className="flex items-center gap-1.5 text-sm text-text-secondary hover:text-text-primary transition-colors"
              >
                {allSelected ? (
                  <CheckSquare className="w-4 h-4 text-accent" />
                ) : someSelected ? (
                  <Square className="w-4 h-4 text-accent" />
                ) : (
                  <Square className="w-4 h-4" />
                )}
                {allSelected ? 'Deselect all' : 'Select all'}
              </button>
              {selectedIds.size > 0 && (
                <button
                  onClick={handleDeleteSelected}
                  disabled={batchDeleting}
                  className="flex items-center gap-1.5 px-3 py-1.5 rounded text-sm font-medium bg-danger/10 text-danger hover:bg-danger/20 transition-colors disabled:opacity-50"
                >
                  <Trash2 className="w-3.5 h-3.5" />
                  Delete {selectedIds.size}
                </button>
              )}
              <button
                onClick={handleDeleteAll}
                disabled={batchDeleting}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded text-sm font-medium bg-danger/10 text-danger hover:bg-danger/20 transition-colors disabled:opacity-50"
              >
                <Trash2 className="w-3.5 h-3.5" />
                Delete all
              </button>
            </div>
          )}
        </div>

        <div className="bg-surface border border-border rounded overflow-hidden">
          {logsLoading && (
            <div className="px-4 py-6 text-sm text-text-secondary text-center">Loading logs...</div>
          )}
          {!logsLoading && logs.length === 0 && (
            <div className="px-4 py-6 text-sm text-text-secondary text-center">No logs yet. Send a request to the URL above.</div>
          )}
          {!logsLoading && logs.length > 0 && (
            <div>
              {logs.map((log) => (
                <LogRow
                  key={log.id}
                  log={log}
                  selected={selectedIds.has(log.id)}
                  onSelect={handleSelect}
                  onDelete={(logId) => { deleteLog(logId); setSelectedIds((prev) => { const next = new Set(prev); next.delete(logId); return next }) }}
                />
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
