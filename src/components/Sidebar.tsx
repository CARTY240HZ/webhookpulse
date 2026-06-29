import { useState } from 'react'
import { Link, useLocation } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { Activity, Settings, Home, LogOut, BarChart3, ChevronLeft, ChevronRight } from 'lucide-react'
import { Button } from '../components/ui'

export default function Sidebar() {
  const { signOut } = useAuth()
  const location = useLocation()
  const [collapsed, setCollapsed] = useState(false)

  const isActive = (path: string) => {
    if (path === '/dashboard') {
      return location.pathname === '/dashboard' || location.pathname.startsWith('/dashboard/webhooks')
    }
    return location.pathname.startsWith(path)
  }

  const navItems = [
    { to: '/dashboard', icon: Home, label: 'Dashboard' },
    { to: '/dashboard/stats', icon: BarChart3, label: 'Stats' },
    { to: '/dashboard/settings', icon: Settings, label: 'Settings' },
  ]

  return (
    <aside
      className={`flex flex-col h-full border-r border-[var(--border)] transition-all duration-300 ease-[var(--ease-smooth)] ${
        collapsed ? 'w-16' : 'w-60'
      }`}
      style={{ background: 'var(--bg-secondary)' }}
    >
      {/* Brand */}
      <div className="h-14 flex items-center px-4 border-b border-[var(--border)] shrink-0">
        <div className="w-8 h-8 rounded-lg flex items-center justify-center shrink-0"
          style={{ background: 'var(--accent)', color: 'var(--bg)' }}>
          <Activity className="w-4 h-4" />
        </div>
        {!collapsed && (
          <span className="ml-3 font-bold text-[var(--text-primary)] tracking-tight text-sm whitespace-nowrap overflow-hidden">
            WebhookPulse
          </span>
        )}
        <Button onClick={() => setCollapsed(!collapsed)} variant="ghost" size="sm" className="ml-auto p-1 text-[var(--text-muted)] hover:text-[var(--text-primary)] hover:bg-[var(--bg-elevated)]">
          {collapsed ? <ChevronRight className="w-4 h-4" /> : <ChevronLeft className="w-4 h-4" />}
        </Button>
      </div>

      {/* Navigation */}
      <nav className="flex-1 px-2 py-4 space-y-1 overflow-y-auto">
        {navItems.map((item) => {
          const active = isActive(item.to)
          return (
            <Link
              key={item.to}
              to={item.to}
              className={`group flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-all duration-200 ease-[var(--ease-smooth)] relative ${
                active
                  ? 'text-[var(--accent)]'
                  : 'text-[var(--text-secondary)] hover:text-[var(--text-primary)]'
              }`}
              style={active ? { background: 'rgba(212,232,58,0.08)' } : {}}
            >
              {/* Active indicator bar */}
              {active && (
                <div className="absolute left-0 top-1/2 -translate-y-1/2 w-1 h-6 rounded-full"
                  style={{ background: 'var(--accent)' }} />
              )}
              <item.icon className={`w-4.5 h-4.5 shrink-0 transition-transform duration-200 ${active ? '' : 'group-hover:scale-110'}`} />
              {!collapsed && (
                <span className="whitespace-nowrap overflow-hidden">{item.label}</span>
              )}
            </Link>
          )
        })}
      </nav>

      {/* Sign out */}
      <div className="p-2 border-t border-[var(--border)] shrink-0">
        <Button onClick={signOut} variant="ghost" size="sm" className="group w-full flex items-center gap-3 text-[var(--text-muted)] hover:text-[var(--text-primary)] hover:bg-[var(--bg-elevated)]">
          <LogOut className="w-4.5 h-4.5 shrink-0 transition-transform duration-200 group-hover:scale-110" />
          {!collapsed && <span className="whitespace-nowrap overflow-hidden">Sign out</span>}
        </Button>
      </div>
    </aside>
  )
}
