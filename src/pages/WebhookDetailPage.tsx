import { useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { Copy, Trash2, Activity, CheckSquare, Square, Download, Eye, EyeOff, LogOut, Shield } from 'lucide-react'
import { useRealtimeLogs } from '../hooks/useRealtimeLogs'
import { supabase } from '../lib/supabase'
import { useWebhooks } from '../hooks/useWebhooks'
import { useIpRules } from '../hooks/useIpRules'
import LogRow from '../components/LogRow'
import SearchBar from '../components/SearchBar'
import { t } from '../i18n'
import IpRulesModal from '../components/IpRulesModal'
import SseStatus from '../components/SseStatus'
import { useVirtualList } from '../hooks/useVirtualList'
import type { Webhook } from '../types'

export default function WebhookDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const { webhooks, refresh, deleteWebhook, toggleWebhook } = useWebhooks()
  const webhook = webhooks.find((w) => w.id === id) as Webhook | undefined
  const isDiscord = webhook?.type === 'discord'
  const webhookType = isDiscord ? 'discord' : 'native'

  const {
    logs,
    loading: logsLoading,
    loadingMore,
    hasMore,
    loadMore,
    deleteLog,
    deleteSelectedLogs,
    deleteAllLogs,
    filters,
    setFilters,
    totalCount,
    hasActiveFilters,
  } = useRealtimeLogs(id || null, webhookType)
  const [copied, setCopied] = useState(false)
  const [deleting, setDeleting] = useState(false)
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set())
  const [batchDeleting, setBatchDeleting] = useState(false)

  const [exporting, setExporting] = useState(false)
  const baseUrl = typeof window !== 'undefined' ? window.location.origin : ''

  // Token reveal state
  const [showTokenReveal, setShowTokenReveal] = useState(false)
  const [tokenPassword, setTokenPassword] = useState('')
  const [revealedToken, setRevealedToken] = useState<string | null>(null)
  const [tokenError, setTokenError] = useState<string | null>(null)
  const [revealing, setRevealing] = useState(false)
  const [showPassword, setShowPassword] = useState(false)
  const [showIpRules, setShowIpRules] = useState(false)

  const { rules: ipRules } = useIpRules(id || null)

  // Virtual list for performance with large log sets
  const { containerRef: logContainerRef, visibleItems: visibleLogs, totalHeight: logTotalHeight, offsetY: logOffsetY } = useVirtualList(logs, { itemHeight: 60, overscan: 5 })

  const handleExport = async () => {
    if (!id) return
    setExporting(true)
    try {
      const { data: sessionData } = await supabase.auth.getSession()
      const token = sessionData.session?.access_token
      if (!token) {
        alert('Session expired. Please log in again.')
        return
      }
      const res = await fetch(`${baseUrl}/api/webhook-logs?webhookId=${id}&format=csv`, {
        headers: { Authorization: `Bearer ${token}` },
      })
      if (!res.ok) {
        const err = await res.json().catch(() => ({ error: 'Export failed' }))
        alert(err.error || 'Export failed')
        return
      }
      const blob = await res.blob()
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `webhook-logs-${id}.csv`
      document.body.appendChild(a)
      a.click()
      a.remove()
      URL.revokeObjectURL(url)
    } catch {
      alert('Export failed')
    } finally {
      setExporting(false)
    }
  }

  const typeLabel = isDiscord ? 'Discord' : 'Native'
  const typeColor = isDiscord ? 'bg-info/10 text-info' : 'bg-accent/10 text-accent'

  const handleCopy = async (url: string) => {
    try {
      await navigator.clipboard.writeText(url)
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
      await deleteWebhook(id)
      navigate('/dashboard')
    } catch (err: any) {
      alert(err.message || 'Failed to delete webhook')
    } finally {
      setDeleting(false)
    }
  }

  const handleToggle = async () => {
    if (!webhook) return
    try {
      await toggleWebhook(webhook.id, webhook.is_active)
    } catch (err: any) {
      alert(err.message || 'Failed to toggle webhook')
    }
  }

  const handleRevealToken = async () => {
    if (!id || !tokenPassword) return
    setRevealing(true)
    setTokenError(null)
    try {
      const { data: sessionData } = await supabase.auth.getSession()
      const token = sessionData.session?.access_token
      if (!token) {
        setTokenError('Session expired. Please log in again.')
        setRevealing(false)
        return
      }
      const res = await fetch(`${baseUrl}/api/webhook-reveal`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
        body: JSON.stringify({ webhookId: id, password: tokenPassword }),
      })
      const data = await res.json()
      if (!res.ok) {
        setTokenError(data.error || 'Failed to reveal token. Check your password.')
        setRevealing(false)
        return
      }
      setRevealedToken(data.token)
      setShowTokenReveal(false)
    } catch {
      setTokenError('Network error. Please try again.')
    } finally {
      setRevealing(false)
    }
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

  const handleSignOut = async () => {
    await supabase.auth.signOut()
    setSelectedIds(new Set())
    setShowIpRules(false)
    navigate('/')
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-end">
        <button
          onClick={handleSignOut}
          className="flex items-center gap-1.5 text-sm text-danger hover:text-danger/80 transition-colors"
        >
          <LogOut className="w-4 h-4" />
          Sign out
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
          <div className="flex items-center gap-2 mb-4">
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
            {ipRules.length > 0 && (
              <span className="inline-flex items-center gap-1 px-2 py-1 rounded text-xs font-medium bg-accent/10 text-accent">
                <Shield className="w-3 h-3" />
                IP
              </span>
            )}
            <SseStatus webhookId={webhook.id} />
          </div>
        </div>

          {/* Native URL */}
          {webhook.native_url && (
            <div className="bg-background border border-border rounded px-3 py-2 mb-3">
              <div className="flex items-center justify-between mb-1">
                <span className="text-[10px] uppercase tracking-wider text-text-secondary font-semibold">
                  Native
                </span>
                <button
                  onClick={() => handleCopy(webhook.native_url!)}
                  className="flex items-center gap-1.5 text-xs font-medium text-accent hover:text-accent-hover transition-colors"
                >
                  <Copy className="w-3.5 h-3.5" />
                  {copied ? 'Copied' : 'Copy'}
                </button>
              </div>
              <code className="block text-sm text-text-secondary truncate">{webhook.native_url}</code>
            </div>
          )}

          {/* Discord URL */}
          {webhook.discord_url && (
            <div className="bg-background border border-border rounded px-3 py-2 mb-4">
              <div className="flex items-center justify-between mb-1">
                <span className="text-[10px] uppercase tracking-wider text-text-secondary font-semibold">
                  Discord
                </span>
                <button
                  onClick={() => handleCopy(webhook.discord_url!)}
                  className="flex items-center gap-1.5 text-xs font-medium text-accent hover:text-accent-hover transition-colors"
                >
                  <Copy className="w-3.5 h-3.5" />
                  {copied ? 'Copied' : 'Copy'}
                </button>
              </div>
              <code className="block text-sm text-text-secondary truncate">{webhook.discord_url}</code>
            </div>
          )}

          {/* Reveal Token */}
          {isDiscord && (
            <div className="bg-background border border-border rounded px-3 py-2 mb-4">
              {!revealedToken ? (
                <>
                  {!showTokenReveal ? (
                    <button
                      onClick={() => { setShowTokenReveal(true); setTokenError(null) }}
                      className="flex items-center gap-2 text-sm font-medium text-accent hover:text-accent-hover transition-colors"
                    >
                      <Eye className="w-4 h-4" />
                      Want to see your token?
                    </button>
                  ) : (
                    <div className="space-y-2">
                      <p className="text-xs text-text-secondary">Enter your password to reveal the token:</p>
                      <div className="flex items-center gap-2">
                        <div className="relative flex-1">
                          <input
                            type={showPassword ? 'text' : 'password'}
                            value={tokenPassword}
                            onChange={(e) => setTokenPassword(e.target.value)}
                            onKeyDown={(e) => e.key === 'Enter' && handleRevealToken()}
                            placeholder="Your password"
                            className="w-full px-3 py-2 pr-10 bg-surface border border-border rounded text-text-primary text-sm focus:border-accent transition-colors"
                          />
                          <button
                            type="button"
                            onClick={() => setShowPassword(!showPassword)}
                            className="absolute right-2 top-1/2 -translate-y-1/2 text-text-secondary hover:text-text-primary"
                          >
                            {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                          </button>
                        </div>
                        <button
                          onClick={handleRevealToken}
                          disabled={revealing || !tokenPassword}
                          className="px-4 py-2 rounded text-sm font-medium bg-accent text-background hover:bg-accent-hover transition-colors disabled:opacity-50"
                        >
                          {revealing ? 'Verifying...' : 'Reveal'}
                        </button>
                      </div>
                      {tokenError && (
                        <p className="text-xs text-danger">{tokenError}</p>
                      )}
                    </div>
                  )}
                </>
              ) : (
                <div className="space-y-2">
                  <div className="flex items-center justify-between mb-1">
                    <span className="text-[10px] uppercase tracking-wider text-text-secondary font-semibold">
                      Token
                    </span>
                    <button
                      onClick={() => navigator.clipboard.writeText(revealedToken)}
                      className="flex items-center gap-1.5 text-xs font-medium text-accent hover:text-accent-hover transition-colors"
                    >
                      <Copy className="w-3.5 h-3.5" />
                      Copy
                    </button>
                  </div>
                  <code className="block text-sm text-text-secondary truncate">{revealedToken}</code>
                </div>
              )}
            </div>
          )}

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
          <div className="flex items-center gap-3">
            <h2 className="text-lg font-semibold text-text-primary">Recent logs</h2>
            {hasActiveFilters && (
              <span className="text-sm text-text-secondary">
                {t('search.results', { count: totalCount })}
              </span>
            )}
          </div>
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
              <button
                onClick={handleExport}
                disabled={exporting || logs.length === 0}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded text-sm font-medium bg-surface border border-border text-text-primary hover:bg-elevated transition-colors disabled:opacity-50"
              >
                <Download className="w-3.5 h-3.5" />
                {exporting ? 'Exporting...' : 'Export CSV'}
              </button>
              <button
                onClick={() => setShowIpRules(true)}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded text-sm font-medium bg-surface border border-border text-text-primary hover:bg-elevated transition-colors"
              >
                <Shield className="w-3.5 h-3.5" />
                IP Rules
              </button>
            </div>
          )}
        </div>

        <SearchBar
          filters={filters}
          onChange={setFilters}
          sources={Array.from(
            new Set(
              logs
                .map((l) => l.payload?.source)
                .filter((s): s is string => typeof s === 'string')
            )
          )}
        />

        <div className="bg-surface border border-border rounded overflow-hidden mt-4">
          {logsLoading && (
            <div className="px-4 py-6 text-sm text-text-secondary text-center">Loading logs...</div>
          )}
          {!logsLoading && logs.length === 0 && hasActiveFilters && (
            <div className="px-4 py-6 text-sm text-text-secondary text-center">{t('search.noResults')}</div>
          )}
          {!logsLoading && logs.length === 0 && !hasActiveFilters && (
            <div className="px-4 py-6 text-sm text-text-secondary text-center">No logs yet. Send a request to the URL above.</div>
          )}
          {!logsLoading && logs.length > 0 && (
            <div>
              <div
                ref={logContainerRef}
                style={{ height: 600, overflowY: 'auto' }}
                className="relative"
              >
                <div style={{ height: logTotalHeight, position: 'relative' }}>
                  <div style={{ transform: `translateY(${logOffsetY}px)` }}>
                    {visibleLogs.map((log) => (
                      <LogRow
                        key={log.id}
                        log={log}
                        selected={selectedIds.has(log.id)}
                        onSelect={handleSelect}
                        onDelete={(logId) => { deleteLog(logId); setSelectedIds((prev) => { const next = new Set(prev); next.delete(logId); return next }) }}
                      />
                    ))}
                  </div>
                </div>
              </div>
              {hasMore && (
                <div className="px-4 py-4 text-center">
                  <button
                    onClick={loadMore}
                    disabled={loadingMore}
                    className="px-4 py-2 rounded text-sm font-medium bg-surface border border-border text-text-primary hover:bg-elevated transition-colors disabled:opacity-50"
                  >
                    {loadingMore ? 'Loading...' : 'Load more'}
                  </button>
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {showIpRules && id && (
        <IpRulesModal webhookId={id} onClose={() => setShowIpRules(false)} />
      )}
    </div>
  )
}
