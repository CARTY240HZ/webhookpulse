import { useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Pause, Play, Radio } from 'lucide-react'
import { useActivityFeed } from '../hooks/useActivityFeed'
import { t } from '../i18n'
import type { LogItem } from '../hooks/useActivityFeed'

interface ActivityFeedProps {
  className?: string
}

function getRelativeTime(dateStr: string): string {
  const date = new Date(dateStr)
  const seconds = Math.floor((Date.now() - date.getTime()) / 1000)
  if (seconds < 10) return t('activity.now')
  if (seconds < 60) return t('activity.secondsAgo').replace('{{s}}', String(seconds))
  const minutes = Math.floor(seconds / 60)
  if (minutes < 60) return t('activity.minutesAgo').replace('{{m}}', String(minutes))
  return t('activity.minutesAgo').replace('{{m}}', String(minutes))
}

function StatusDot({ status }: { status: LogItem['status'] }) {
  const colorMap = {
    success: 'bg-success',
    honeypot: 'bg-yellow-500',
    rate_limited: 'bg-danger',
  }
  return <span className={`inline-block w-2 h-2 rounded-full ${colorMap[status]}`} />
}

function TypeBadge({ type }: { type: LogItem['type'] }) {
  const isDiscord = type === 'discord'
  return (
    <span
      className={`inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium ${
        isDiscord
          ? 'bg-blue-500/10 text-blue-400'
          : 'bg-accent/10 text-accent'
      }`}
    >
      {isDiscord ? 'Discord' : 'Native'}
    </span>
  )
}

export default function ActivityFeed({ className = '' }: ActivityFeedProps) {
  const { logs, isPaused, setIsPaused, isConnected } = useActivityFeed()
  const navigate = useNavigate()
  const listRef = useRef<HTMLDivElement>(null)
  const prevLogCount = useRef(logs.length)
  const [, forceUpdate] = useState({})

  // Update relative times every 10 seconds
  useEffect(() => {
    const interval = setInterval(() => forceUpdate({}), 10000)
    return () => clearInterval(interval)
  }, [])

  // Auto-scroll to top when new items arrive (unless paused)
  useEffect(() => {
    if (!isPaused && listRef.current && logs.length > prevLogCount.current) {
      listRef.current.scrollTop = 0
    }
    prevLogCount.current = logs.length
  }, [logs.length, isPaused])

  return (
    <aside className={`flex flex-col bg-surface border-l border-border ${className}`}>
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 border-b border-border shrink-0">
        <div className="flex items-center gap-2">
          <Radio className="w-4 h-4 text-accent" />
          <h2 className="text-sm font-semibold text-text-primary">
            {t('activity.title')}
          </h2>
          <span
            className={`inline-block w-2 h-2 rounded-full ${
              isConnected ? 'bg-success' : 'bg-danger'
            }`}
            title={
              isConnected
                ? t('activity.connected')
                : t('activity.disconnected')
            }
          />
        </div>
        <button
          onClick={() => setIsPaused(!isPaused)}
          className="flex items-center gap-1.5 text-xs font-medium text-text-secondary hover:text-text-primary transition-colors"
          title={isPaused ? t('activity.resume') : t('activity.pause')}
        >
          {isPaused ? (
            <>
              <Play className="w-3.5 h-3.5" />
              <span className="hidden sm:inline">{t('activity.paused')}</span>
            </>
          ) : (
            <>
              <Pause className="w-3.5 h-3.5" />
              <span className="hidden sm:inline">{t('activity.pause')}</span>
            </>
          )}
        </button>
      </div>

      {/* Log List */}
      <div ref={listRef} className="flex-1 overflow-y-auto min-h-0">
        {logs.length === 0 ? (
          <div className="flex flex-col items-center justify-center px-4 py-12 text-center">
            <p className="text-sm text-text-secondary">{t('activity.empty')}</p>
          </div>
        ) : (
          <div className="divide-y divide-border">
            {logs.map((log) => (
              <button
                key={log.id}
                onClick={() =>
                  navigate(`/dashboard/webhooks/${log.webhook_id}`)
                }
                className={`w-full text-left px-4 py-3 transition-all duration-300 hover:bg-elevated ${
                  log.isNew ? 'animate-fade-in-slide' : ''
                }`}
              >
                <div className="flex items-center justify-between mb-1.5">
                  <span className="text-sm font-semibold text-text-primary truncate pr-2">
                    {log.webhook_name}
                  </span>
                  <div className="flex items-center gap-1.5 shrink-0">
                    <TypeBadge type={log.type} />
                    {log.source && (
                      <span className="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium bg-purple-500/10 text-purple-400">
                        {log.source}
                      </span>
                    )}
                    <StatusDot status={log.status} />
                  </div>
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-xs text-text-secondary font-mono">
                    {log.ip_address || '-'}
                  </span>
                  <span className="text-xs text-text-secondary">
                    {getRelativeTime(log.created_at)}
                  </span>
                </div>
              </button>
            ))}
          </div>
        )}
      </div>
    </aside>
  )
}
