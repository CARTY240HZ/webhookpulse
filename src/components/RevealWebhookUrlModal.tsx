import { useState } from 'react'
import { Eye, Copy } from 'lucide-react'
import { Button, Modal } from '../components/ui'

interface RevealWebhookUrlModalProps {
  webhookName: string
  webhookId: string
  onClose: () => void
  onReveal: (id: string, password: string) => Promise<{ discord_url: string; token: string; warning: string }>
}

export default function RevealWebhookUrlModal({ webhookName, webhookId, onClose, onReveal }: RevealWebhookUrlModalProps) {
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [result, setResult] = useState<{ discord_url: string; token: string; warning: string } | null>(null)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!password.trim()) return
    setLoading(true)
    setError(null)
    try {
      const data = await onReveal(webhookId, password.trim())
      setResult(data)
    } catch (err: any) {
      setError(err.message || 'Failed to reveal URL')
    } finally {
      setLoading(false)
    }
  }

  const handleCopy = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text)
    } catch { /* ignore */ }
  }

  return (
    <Modal isOpen={true} onClose={onClose} title="Reveal Discord URL">
        {result ? (
          <div className="space-y-4">
            <div className="bg-danger/10 border border-danger/20 rounded p-4">
              <p className="text-sm text-danger font-medium mb-2">{result.warning}</p>
              <p className="text-xs text-danger/80">The previous token is no longer valid.</p>
            </div>

            <div className="space-y-2">
              <div>
                <label className="text-xs text-text-secondary">Discord URL</label>
                <div className="flex gap-2">
                  <code className="flex-1 text-xs bg-background border border-border rounded px-2 py-1 text-text-primary truncate">
                    {result.discord_url}
                  </code>
                  <Button onClick={() => handleCopy(result.discord_url)} variant="ghost" size="sm" className="text-xs text-accent hover:text-accent-hover p-1">
                    <Copy className="w-4 h-4" />
                  </Button>
                </div>
              </div>
              <div>
                <label className="text-xs text-text-secondary">Token</label>
                <div className="flex gap-2">
                  <code className="flex-1 text-xs bg-background border border-border rounded px-2 py-1 text-text-primary truncate">
                    {result.token}
                  </code>
                  <Button onClick={() => handleCopy(result.token)} variant="ghost" size="sm" className="text-xs text-accent hover:text-accent-hover p-1">
                    <Copy className="w-4 h-4" />
                  </Button>
                </div>
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
            <p className="text-sm text-text-secondary">
              Enter your account password to reveal the Discord URL for <strong className="text-text-primary">{webhookName}</strong>.
              A new token will be generated and the previous one will be invalidated.
            </p>
            <div>
              <label className="block text-sm font-medium text-text-secondary mb-1.5">Password</label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full px-3 py-2 bg-background border border-border rounded text-text-primary text-sm focus:border-accent transition-colors"
                placeholder="Your account password"
                required
              />
            </div>
            {error && <p className="text-sm text-danger">{error}</p>}
            <div className="flex items-center justify-end gap-3 pt-2">
              <Button type="button" onClick={onClose} variant="secondary">
                Cancel
              </Button>
              <Button type="submit" disabled={loading || !password.trim()} isLoading={loading} leftIcon={<Eye className="w-4 h-4" />}>
                {loading ? 'Verifying...' : 'Reveal URL'}
              </Button>
            </div>
          </form>
        )}
    </Modal>
  )
}
