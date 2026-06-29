import { useState, useRef, useEffect } from 'react'
import { Plus, Zap, MessageSquare } from 'lucide-react'
import type { Webhook } from '../types'
import { Button, Modal } from '../components/ui'

type CreateResult = Webhook & { native_url: string; discord_url?: string; token?: string }

interface CreateWebhookModalProps {
  onClose: () => void
  onCreate: (name: string, description?: string, type?: 'native' | 'discord') => Promise<CreateResult>
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


  const handleSubmit = async (e: React.FormEvent) => {
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
    <Modal isOpen={true} onClose={onClose} title="Create Webhook">

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
                    <Button onClick={() => navigator.clipboard.writeText(result.native_url)} variant="ghost" size="sm" className="text-xs text-accent hover:text-accent-hover p-1">
                      Copy
                    </Button>
                  </div>
                </div>
                {result.discord_url && (
                  <div>
                    <label className="text-xs text-text-secondary">Discord URL</label>
                    <div className="flex gap-2">
                      <code className="flex-1 text-xs bg-background border border-border rounded px-2 py-1 text-text-primary truncate">
                        {result.discord_url}
                      </code>
                      <Button onClick={() => navigator.clipboard.writeText(result.discord_url || '')} variant="ghost" size="sm" className="text-xs text-accent hover:text-accent-hover p-1">
                        Copy
                      </Button>
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
                      <Button onClick={() => navigator.clipboard.writeText(result.token || '')} variant="ghost" size="sm" className="text-xs text-accent hover:text-accent-hover p-1">
                        Copy
                      </Button>
                    </div>
                    <p className="text-xs text-danger mt-1">Copy it now or retrieve it later in the Dashboard panel with your password.</p>
                  </div>
                )}
              </div>
            </div>
            <div className="flex justify-end">
              <Button onClick={onClose}>
                Done
              </Button>
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
              <Button type="button" onClick={onClose} variant="secondary">
                Cancel
              </Button>
              <Button type="submit" disabled={loading || !name.trim()} isLoading={loading} leftIcon={<Plus className="w-4 h-4" />}>
                {loading ? 'Creating...' : 'Create'}
              </Button>
            </div>
          </form>
        )}
    </Modal>
  )
}
