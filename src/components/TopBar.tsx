import { useAuth } from '../hooks/useAuth'
import { User } from 'lucide-react'

export default function TopBar() {
  const { profile } = useAuth()

  return (
    <header className="h-16 bg-surface border-b border-border flex items-center justify-between px-6">
      <div className="text-sm text-text-secondary">WebhookPulse Dashboard</div>
      <div className="flex items-center gap-3">
        <div className="w-8 h-8 rounded-full bg-elevated border border-border flex items-center justify-center">
          <User className="w-4 h-4 text-text-secondary" />
        </div>
        <span className="text-sm text-text-primary font-medium">{profile?.full_name || 'User'}</span>
      </div>
    </header>
  )
}
