import { useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { User, ArrowLeft, Home } from 'lucide-react'

export default function TopBar() {
  const { profile } = useAuth()
  const location = useLocation()
  const navigate = useNavigate()

  const path = location.pathname.replace(/\/$/, '') || '/'
  const isDashboard = path === '/dashboard'
  const isDetail = path.startsWith('/dashboard/webhooks/')

  const handleBack = () => {
    if (isDetail) {
      navigate('/dashboard')
    } else {
      navigate('/')
    }
  }

  const showBack = isDetail || isDashboard

  return (
    <header className="h-16 bg-surface border-b border-border flex items-center justify-between px-6">
      <div className="flex items-center gap-3 min-w-0">
        {showBack ? (
          <button
            onClick={handleBack}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded bg-elevated border border-border text-sm text-text-secondary hover:text-text-primary hover:border-text-secondary transition-colors"
          >
            {isDetail ? (
              <>
                <ArrowLeft className="w-4 h-4" />
                Back
              </>
            ) : (
              <>
                <Home className="w-4 h-4" />
                Home
              </>
            )}
          </button>
        ) : (
          <span className="text-sm text-text-secondary font-medium">WebhookPulse</span>
        )}
      </div>
      <div className="flex items-center gap-3">
        <div className="w-8 h-8 rounded-full bg-elevated border border-border flex items-center justify-center">
          <User className="w-4 h-4 text-text-secondary" />
        </div>
        <span className="text-sm text-text-primary font-medium">{profile?.full_name || 'User'}</span>
      </div>
    </header>
  )
}
