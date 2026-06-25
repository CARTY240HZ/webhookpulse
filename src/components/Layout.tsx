import { Outlet, useLocation } from 'react-router-dom'
import Sidebar from './Sidebar'
import TopBar from './TopBar'
import ActivityFeed from './ActivityFeed'

export default function Layout() {
  const location = useLocation()
  const showActivityFeed =
    location.pathname === '/dashboard' ||
    location.pathname.startsWith('/dashboard/webhooks/')

  return (
    <div className="flex h-full bg-background">
      <Sidebar />
      <div className="flex-1 flex flex-col min-w-0">
        <TopBar />
        <div className="flex-1 flex overflow-hidden">
          <main className={`flex-1 overflow-auto p-6 ${showActivityFeed ? 'lg:pr-0' : ''}`}>
            <Outlet />
          </main>
          {showActivityFeed && (
            <ActivityFeed className="hidden lg:flex w-80 shrink-0" />
          )}
        </div>
      </div>
    </div>
  )
}
