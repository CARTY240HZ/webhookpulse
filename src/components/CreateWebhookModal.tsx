import { useState, useRef, useEffect } from 'react'
import { X, Plus, Zap, MessageSquare } from 'lucide-react'
import type { Webhook } from '../types'

type CreateResult = Webhook & { native_url: string; discord_url?: string; token?: string }

interface CreateWebhookModalProps {
  onClose: () => void
  onCreate: (name: string, description?: string, type: 'native' | 'discord') => Promise<CreateResult>
}

export default function CreateWebhookModal({ onClose, onCreate }: CreateWebhookModalProps) {
  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [type, setType] = useState<'native' | 'discord'>('native')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [result, setResult] = useState<CreateResult | null>(null)
  const nameInputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    nameInputRef.current?.focus()
  }, [])

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') onClose()
  }
    e.preventDefault()
    if (!name.trim()) return
    setLoading(true)
    setError(null)
    try {
      const webhook = await onCreate(name.trim(), description.trim() || undefined, type)
      setResult(webhook)
    } catch (err) {
      setError((err as Error).message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60" onKeyDown={handleKeyDown}>
      <div className="bg-surface border border-border rounded-lg p-6 w-full max-w-lg mx-4">
        <div className="flex items-center justify-between mb-6">
          <h2 className="text-lg font-semibold text-text-primary">Create Webhook</h2>
          <button onClick={onClose} className="text-text-secondary hover:text-text-primary transition-colors">
            <X className="w-5 h-5" />
          </button>
        </div>

        {result ? (
          <div className="space-y-4">
            <div className="bg-success/10 border border-success/20 rounded p-4">
              <p className="text-sm text-success font-medium mb-2">Webhook created successfully!</p>
              <div className="space-y-2">
                <div>
                  <label className="text-xs text-text-secondary">Native URL</label>
                  <div className="flex gap-2">
                    <code className="flex-1 text-xs bg-background border border-border rounded px-2 py-1 text-text-primary truncate">
                      {result.native_url}
                    </code>
                    <button
                      onClick={() => navigator.clipboard.writeText(result.native_url)}
                      className="text-xs text-accent hover:text-accent-hover"
                    >
                      Copy
                    </button>
                  </div>
                </div>
                {result.discord_url && (
                  <div>
                    <label className="text-xs text-text-secondary">Discord URL</label>
                    <div className="flex gap-2">
                      <code className="flex-1 text-xs bg-background border border-border rounded px-2 py-1 text-text-primary truncate">
                        {result.discord_url}
                      </code>
                      <button
                        onClick={() => navigator.clipboard.writeText(result.discord_url)}
                        className="text-xs text-accent hover:text-accent-hover"
                      >
                        Copy
                      </button>
                    </div>
                  </div>
                )}
                {result.token && (
                  <div>
                    <label className="text-xs text-text-secondary">Token</label>
                    <div className="flex gap-2">
                      <code className="flex-1 text-xs bg-background border border-border rounded px-2 py-1 text-text-primary truncate">
                        {result.token}
                      </code>
                      <button
                        onClick={() => navigator.clipboard.writeText(result.token)}
                        className="text-xs text-accent hover:text-accent-hover"
                      >
                        Copy
                      </button>
                    </div>
                    <p className="text-xs text-danger mt-1">Copy it now or retrieve it later in the Dashboard panel with your password.</p>
                  </div>
                )}
              </div>
            </div>
            <div className="flex justify-end">
              <button
                onClick={onClose}
                className="px-4 py-2 rounded text-sm font-medium bg-accent text-background hover:bg-accent-hover transition-colors"
              >
                Done
              </button>
            </div>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="space-y-4">
            {/* Type Selector */}
            <div className="grid grid-cols-2 gap-3">
              <button
                type="button"
                onClick={() => setType('native')}
                className={`flex flex-col items-center gap-2 p-4 rounded-lg border transition-all ${
                  type === 'native'
                    ? 'border-accent bg-accent/10 text-accent'
                    : 'border-border bg-background text-text-secondary hover:border-text-secondary'
                }`}
              >
                <Zap className="w-6 h-6" />
                <span className="text-sm font-medium">Native</span>
                <span className="text-xs opacity-70">Path-based</span>
              </button>
              <button
                type="button"
                onClick={() => setType('discord')}
                className={`flex flex-col items-center gap-2 p-4 rounded-lg border transition-all ${
                  type === 'discord'
                    ? 'border-accent bg-accent/10 text-accent'
                    : 'border-border bg-background text-text-secondary hover:border-text-secondary'
                }`}
              >
                <MessageSquare className="w-6 h-6" />
                <span className="text-sm font-medium">Discord</span>
                <span className="text-xs opacity-70">API-compatible</span>
              </button>
            </div>

            <div>
              <label className="block text-sm font-medium text-text-secondary mb-1.5">Name</label>
              <input
                ref={nameInputRef}
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                className="w-full px-3 py-2 bg-background border border-border rounded text-text-primary text-sm focus:border-accent transition-colors"
                placeholder="My webhook"
                required
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-text-secondary mb-1.5">Description</label>
              <input
                type="text"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                className="w-full px-3 py-2 bg-background border border-border rounded text-text-primary text-sm focus:border-accent transition-colors"
                placeholder="Optional"
              />
            </div>

            {type === 'native' && (
              <div className="bg-elevated/50 border border-border rounded p-3">
                <p className="text-xs text-text-secondary">
                  Native webhooks use a simple path-based URL. Compatible with any HTTP client.
                </p>
              </div>
            )}

            {type === 'discord' && (
              <div className="bg-elevated/50 border border-border rounded p-3">
                <p className="text-xs text-text-secondary">
                  Discord-compatible webhooks use a cryptographically secure token. Identical to Discord's webhook API.
                </p>
              </div>
            )}

            {error && <p className="text-sm text-danger">{error}</p>}
            <div className="flex items-center justify-end gap-3 pt-2">
              <button
                type="button"
                onClick={onClose}
                className="px-4 py-2 rounded text-sm font-medium bg-surface border border-border text-text-primary hover:bg-elevated transition-colors"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={loading || !name.trim()}
                className="flex items-center gap-2 px-4 py-2 rounded text-sm font-medium bg-accent text-background hover:bg-accent-hover transition-colors disabled:opacity-50"
              >
                <Plus className="w-4 h-4" />
                {loading ? 'Creating...' : 'Create'}
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  )
}
