import { Link, useLocation } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { Activity, Settings, Home, LogOut, BarChart3 } from 'lucide-react'

export default function Sidebar() {
  const { signOut } = useAuth()
  const location = useLocation()

  const isActive = (path: string) => location.pathname.startsWith(path)

  return (
    <aside className="w-64 bg-surface border-r border-border flex flex-col">
      <div className="h-16 flex items-center px-6 border-b border-border">
        <Activity className="w-5 h-5 text-accent mr-2" />
        <span className="font-bold text-text-primary tracking-tight">WebhookPulse</span>
      </div>
      <nav className="flex-1 px-3 py-4 space-y-1">
        <Link
          to="/dashboard"
          className={`flex items-center px-3 py-2 rounded text-sm font-medium transition-colors ${
            isActive('/dashboard') && !isActive('/dashboard/settings') && !isActive('/dashboard/stats')
              ? 'bg-elevated text-accent'
              : 'text-text-secondary hover:bg-elevated hover:text-text-primary'
          }`}
        >
          <Home className="w-4 h-4 mr-3" />
          Dashboard
        </Link>
        <Link
          to="/dashboard/stats"
          className={`flex items-center px-3 py-2 rounded text-sm font-medium transition-colors ${
            isActive('/dashboard/stats')
              ? 'bg-elevated text-accent'
              : 'text-text-secondary hover:bg-elevated hover:text-text-primary'
          }`}
        >
          <BarChart3 className="w-4 h-4 mr-3" />
          Stats
        </Link>
        <Link
          to="/dashboard/settings"
          className={`flex items-center px-3 py-2 rounded text-sm font-medium transition-colors ${
            isActive('/dashboard/settings')
              ? 'bg-elevated text-accent'
              : 'text-text-secondary hover:bg-elevated hover:text-text-primary'
          }`}
        >
          <Settings className="w-4 h-4 mr-3" />
          Settings
        </Link>
      </nav>
      <div className="p-3 border-t border-border">
        <button
          onClick={signOut}
          className="flex items-center w-full px-3 py-2 rounded text-sm font-medium text-text-secondary hover:bg-elevated hover:text-text-primary transition-colors"
        >
          <LogOut className="w-4 h-4 mr-3" />
          Sign out
        </button>
      </div>
    </aside>
  )
}
