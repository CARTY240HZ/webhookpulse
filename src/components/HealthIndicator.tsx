import { useState } from 'react'
import { useHealthChecks } from '../hooks/useHealthChecks'
import { t } from '../i18n'

interface HealthIndicatorProps {
  webhookId: string
}

function statusDotClass(status: string | null): string {
  switch (status) {
    case 'online':
      return 'bg-green-500'
    case 'degraded':
      return 'bg-yellow-500'
    case 'offline':
      return 'bg-red-500'
    default:
      return 'bg-gray-400'
  }
}

function statusBadgeClass(status: string | null): string {
  switch (status) {
    case 'online':
      return 'bg-green-500/10 text-green-400'
    case 'degraded':
      return 'bg-yellow-500/10 text-yellow-400'
    case 'offline':
      return 'bg-red-500/10 text-red-400'
    default:
      return 'bg-gray-500/10 text-gray-400'
  }
}

function statusLabel(status: string | null): string {
  switch (status) {
    case 'online':
      return t('health.online')
    case 'degraded':
      return t('health.degraded')
    case 'offline':
      return t('health.offline')
    default:
      return t('health.unknown')
  }
}

export default function HealthIndicator({ webhookId }: HealthIndicatorProps) {
  const { checks, latest, loading } = useHealthChecks(webhookId)
  const [open, setOpen] = useState(false)

  if (checks.length === 0 && !loading) {
    return null
  }

  const status = latest?.status ?? null

  return (
    <div
      className="relative inline-flex"
      tabIndex={0}
      onMouseEnter={() => setOpen(true)}
      onMouseLeave={() => setOpen(false)}
      onFocus={() => setOpen(true)}
      onBlur={() => setOpen(false)}
      onKeyDown={(e) => { if (e.key === 'Escape') setOpen(false) }}
      role="button"
      aria-expanded={open}
      aria-label="Health status indicator"
    >
      <span
        className={`inline-flex items-center gap-1.5 px-2 py-1 rounded text-xs font-medium ${statusBadgeClass(status)}`}
      >
        <span className={`w-1.5 h-1.5 rounded-full ${statusDotClass(status)}`} />
        {loading ? t('health.checking') : statusLabel(status)}
      </span>

      {open && checks.length > 0 && (
        <div className="absolute left-0 bottom-full mb-2 z-50 w-72 rounded-lg border border-border bg-elevated shadow-xl p-3">
          <p className="text-xs font-semibold text-text-primary mb-2">
            {t('health.history')}
          </p>
          <div className="flex flex-col gap-1.5 max-h-60 overflow-auto">
            {checks.map((c, i) => (
              <div
                key={i}
                className="flex items-center justify-between rounded px-2 py-1.5 bg-background/50"
              >
                <div className="flex items-center gap-2">
                  <span className={`w-1.5 h-1.5 rounded-full ${statusDotClass(c.status)}`} />
                  <span className="text-xs font-medium text-text-primary">
                    {statusLabel(c.status)}
                  </span>
                </div>
                <div className="text-right">
                  <span className="text-[10px] text-text-secondary block">
                    {c.responseTimeMs}ms
                  </span>
                  <span className="text-[10px] text-text-secondary">
                    {new Date(c.checkedAt).toLocaleString()}
                  </span>
                </div>
              </div>
            ))}
          </div>
          {latest && (
            <p className="text-[10px] text-text-secondary mt-2 pt-2 border-t border-border">
              {t('health.lastCheck')}: {new Date(latest.checkedAt).toLocaleString()}
            </p>
          )}
        </div>
      )}
    </div>
  )
}
