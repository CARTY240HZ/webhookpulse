import { useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { User, ArrowLeft, Home, Bell } from 'lucide-react'

export default function TopBar() {
  const { profile } = useAuth()
  const location = useLocation()
  const navigate = useNavigate()

  const path = location.pathname.replace(/\/$/, '') || '/'
  const isDashboard = path === '/dashboard'
  const isDetail = path.startsWith('/dashboard/webhooks/')
  const isStats = path === '/dashboard/stats'
  const isSettings = path === '/dashboard/settings'

  const pageTitle = isDetail
    ? 'Webhook Details'
    : isStats
    ? 'Statistics'
    : isSettings
    ? 'Settings'
    : 'Dashboard'

  const handleBack = () => {
    if (isDetail) navigate('/dashboard')
    else navigate('/')
  }

  return (
    <header
      className="h-14 flex items-center justify-between px-6 shrink-0 border-b border-[var(--border)]"
      style={{
        background: 'rgba(15,15,18,0.8)',
        backdropFilter: 'blur(12px) saturate(140%)',
        WebkitBackdropFilter: 'blur(12px) saturate(140%)',
      }}
    >
      <div className="flex items-center gap-3 min-w-0">
        {isDetail ? (
          <button
            onClick={handleBack}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium text-[var(--text-secondary)] hover:text-[var(--text-primary)] hover:bg-[var(--bg-elevated)] border border-[var(--border)] hover:border-[var(--border-hover)] transition-all duration-200"
          >
            <ArrowLeft className="w-4 h-4" />
            Back
          </button>
        ) : (
          <button
            onClick={handleBack}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm font-medium text-[var(--text-secondary)] hover:text-[var(--text-primary)] hover:bg-[var(--bg-elevated)] border border-[var(--border)] hover:border-[var(--border-hover)] transition-all duration-200"
          >
            <Home className="w-4 h-4" />
            Home
          </button>
        )}
        <div className="h-4 w-px bg-[var(--border)] mx-2" />
        <h1 className="text-sm font-semibold text-[var(--text-primary)] tracking-tight">{pageTitle}</h1>
      </div>

      <div className="flex items-center gap-4">
        <button className="relative p-2 rounded-lg text-[var(--text-muted)] hover:text-[var(--text-primary)] hover:bg-[var(--bg-elevated)] transition-all duration-200">
          <Bell className="w-4.5 h-4.5" />
          <span className="absolute top-1.5 right-1.5 w-2 h-2 rounded-full" style={{ background: 'var(--accent)' }} />
        </button>
        <div className="flex items-center gap-2.5 pl-4 border-l border-[var(--border)]">
          <div className="w-8 h-8 rounded-full flex items-center justify-center border border-[var(--border)]"
            style={{ background: 'var(--bg-elevated)' }}>
            <User className="w-4 h-4 text-[var(--text-secondary)]" />
          </div>
          <span className="text-sm font-medium text-[var(--text-primary)] hidden md:block">
            {profile?.full_name || 'User'}
          </span>
        </div>
      </div>
    </header>
  )
}
