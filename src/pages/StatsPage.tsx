import { useState, useEffect } from 'react'
import { supabase } from '../lib/supabase'
import { useAuth } from '../hooks/useAuth'
import { BarChart3, Globe, Monitor, Users, Zap } from 'lucide-react'

interface HourlyData {
  hour: string
  count: number
}

interface WebhookStat {
  name: string
  count: number
}

interface TopIp {
  ip: string
  count: number
}

interface SourceStat {
  source: string
  count: number
}

export default function StatsPage() {
  const { user } = useAuth()
  const [loading, setLoading] = useState(true)
  const [hourly, setHourly] = useState<HourlyData[]>([])
  const [webhooks, setWebhooks] = useState<WebhookStat[]>([])
  const [topIps, setTopIps] = useState<TopIp[]>([])
  const [sources, setSources] = useState<SourceStat[]>([])
  const [totalLogs, setTotalLogs] = useState(0)
  const [totalWebhooks, setTotalWebhooks] = useState(0)

  useEffect(() => {
    if (!user) return
    fetchStats()
  }, [user])

  const fetchStats = async () => {
    setLoading(true)
    try {
      // Total webhooks
      const { count: whCount } = await supabase
        .from('webhooks')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', user!.id)
      setTotalWebhooks(whCount || 0)

      // Get all webhook IDs for this user
      const { data: whData } = await supabase
        .from('webhooks')
        .select('id, name')
        .eq('user_id', user!.id)

      const whIds = whData?.map((w) => w.id) || []
      const whMap = new Map(whData?.map((w) => [w.id, w.name]))

      if (whIds.length === 0) {
        setLoading(false)
        return
      }

      // Total logs
      const { count: logCount } = await supabase
        .from('webhook_logs')
        .select('id', { count: 'exact', head: true })
        .in('webhook_id', whIds)
      setTotalLogs(logCount || 0)

      // Hourly data (last 24h)
      const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()
      const { data: hourlyData } = await supabase
        .from('webhook_logs')
        .select('created_at')
        .in('webhook_id', whIds)
        .gte('created_at', twentyFourHoursAgo)

      const hourlyMap = new Map<string, number>()
      for (let i = 23; i >= 0; i--) {
        const d = new Date(Date.now() - i * 60 * 60 * 1000)
        const key = `${d.getHours().toString().padStart(2, '0')}:00`
        hourlyMap.set(key, 0)
      }
      hourlyData?.forEach((log) => {
        const d = new Date(log.created_at)
        const key = `${d.getHours().toString().padStart(2, '0')}:00`
        hourlyMap.set(key, (hourlyMap.get(key) || 0) + 1)
      })
      setHourly(Array.from(hourlyMap.entries()).map(([hour, count]) => ({ hour, count })))

      // Logs per webhook
      const { data: whLogs } = await supabase
        .from('webhook_logs')
        .select('webhook_id')
        .in('webhook_id', whIds)

      const whCountMap = new Map<string, number>()
      whLogs?.forEach((log) => {
        whCountMap.set(log.webhook_id, (whCountMap.get(log.webhook_id) || 0) + 1)
      })
      setWebhooks(
        Array.from(whCountMap.entries())
          .map(([id, count]) => ({ name: whMap.get(id) || 'Unknown', count }))
          .sort((a, b) => b.count - a.count)
      )

      // Top IPs
      const { data: ipData } = await supabase
        .from('webhook_logs')
        .select('ip_address')
        .in('webhook_id', whIds)
        .not('ip_address', 'is', null)

      const ipMap = new Map<string, number>()
      ipData?.forEach((log) => {
        if (log.ip_address) {
          ipMap.set(log.ip_address, (ipMap.get(log.ip_address) || 0) + 1)
        }
      })
      setTopIps(
        Array.from(ipMap.entries())
          .map(([ip, count]) => ({ ip, count }))
          .sort((a, b) => b.count - a.count)
          .slice(0, 10)
      )

      // Sources
      const { data: sourceData } = await supabase
        .from('webhook_logs')
        .select('payload')
        .in('webhook_id', whIds)

      const sourceMap = new Map<string, number>()
      sourceData?.forEach((log) => {
        const payload = log.payload as Record<string, unknown> | null
        const source = payload?.source ? String(payload.source) : 'unknown'
        sourceMap.set(source, (sourceMap.get(source) || 0) + 1)
      })
      setSources(
        Array.from(sourceMap.entries())
          .map(([source, count]) => ({ source, count }))
          .sort((a, b) => b.count - a.count)
      )
    } catch {
      // ignore
    } finally {
      setLoading(false)
    }
  }

  const maxHourly = Math.max(...hourly.map((h) => h.count), 1)
  const maxWebhook = Math.max(...webhooks.map((w) => w.count), 1)
  const maxIp = Math.max(...topIps.map((i) => i.count), 1)
  const maxSource = Math.max(...sources.map((s) => s.count), 1)
  const totalSource = sources.reduce((sum, s) => sum + s.count, 0)

  const Card = ({ icon: Icon, label, value }: { icon: any; label: string; value: string | number }) => (
    <div className="bg-surface border border-border rounded p-5">
      <div className="flex items-center gap-3 mb-3">
        <div className="w-8 h-8 rounded bg-accent/10 flex items-center justify-center">
          <Icon className="w-4 h-4 text-accent" />
        </div>
        <span className="text-xs uppercase tracking-wider text-text-secondary font-semibold">{label}</span>
      </div>
      <div className="text-2xl font-bold text-text-primary">{value}</div>
    </div>
  )

  const BarChart = ({ data, max, labelKey }: { data: any[]; max: number; labelKey: string }) => (
    <div className="space-y-2">
      {data.map((item, i) => {
        const pct = max > 0 ? (item.count / max) * 100 : 0
        return (
          <div key={i} className="flex items-center gap-3">
            <span className="text-xs text-text-secondary w-24 truncate text-right shrink-0">{item[labelKey]}</span>
            <div className="flex-1 h-6 bg-elevated rounded overflow-hidden">
              <div
                className="h-full bg-accent rounded transition-all duration-500"
                style={{ width: `${pct}%`, minWidth: pct > 0 ? '4px' : '0' }}
              />
            </div>
            <span className="text-xs text-text-primary font-mono w-8 text-right shrink-0">{item.count}</span>
          </div>
        )
      })}
    </div>
  )

  const DonutChart = ({ data, total }: { data: SourceStat[]; total: number }) => {
    const colors = ['#D4E83A', '#22C55E', '#EF4444', '#A1A1AA', '#27272A']
    let accumulated = 0
    const segments = data.map((item, i) => {
      const pct = total > 0 ? (item.count / total) * 100 : 0
      const start = accumulated
      accumulated += pct
      return { ...item, pct, start, color: colors[i % colors.length] }
    })

    return (
      <div className="flex items-center gap-6">
        <div className="relative w-32 h-32 shrink-0">
          <svg viewBox="0 0 100 100" className="w-full h-full -rotate-90">
            <circle cx="50" cy="50" r="40" fill="none" stroke="#1C1C1E" strokeWidth="20" />
            {segments.map((seg, i) => {
              const circumference = 2 * Math.PI * 40
              const dashArray = `${(seg.pct / 100) * circumference} ${circumference}`
              const dashOffset = -((seg.start / 100) * circumference)
              return (
                <circle
                  key={i}
                  cx="50"
                  cy="50"
                  r="40"
                  fill="none"
                  stroke={seg.color}
                  strokeWidth="20"
                  strokeDasharray={dashArray}
                  strokeDashoffset={dashOffset}
                  strokeLinecap="butt"
                />
              )
            })}
          </svg>
        </div>
        <div className="space-y-1.5">
          {segments.map((seg, i) => (
            <div key={i} className="flex items-center gap-2">
              <span className="w-2.5 h-2.5 rounded-sm shrink-0" style={{ backgroundColor: seg.color }} />
              <span className="text-xs text-text-secondary">{seg.source}</span>
              <span className="text-xs text-text-primary font-mono">{seg.count}</span>
            </div>
          ))}
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-text-primary">Stats</h1>
        <p className="text-sm text-text-secondary mt-1">Activity overview and analytics.</p>
      </div>

      {loading ? (
        <div className="text-sm text-text-secondary">Loading stats...</div>
      ) : (
        <>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <Card icon={Zap} label="Total logs" value={totalLogs} />
            <Card icon={Globe} label="Webhooks" value={totalWebhooks} />
            <Card icon={Users} label="Unique IPs" value={topIps.length} />
            <Card icon={Monitor} label="Sources" value={sources.length} />
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {/* Hourly activity */}
            <div className="bg-surface border border-border rounded p-5">
              <div className="flex items-center gap-2 mb-4">
                <BarChart3 className="w-4 h-4 text-accent" />
                <h3 className="text-sm font-semibold text-text-primary">Logs per hour (last 24h)</h3>
              </div>
              <BarChart data={hourly} max={maxHourly} labelKey="hour" />
            </div>

            {/* Logs per webhook */}
            <div className="bg-surface border border-border rounded p-5">
              <div className="flex items-center gap-2 mb-4">
                <BarChart3 className="w-4 h-4 text-accent" />
                <h3 className="text-sm font-semibold text-text-primary">Logs per webhook</h3>
              </div>
              <BarChart data={webhooks} max={maxWebhook} labelKey="name" />
            </div>

            {/* Top IPs */}
            <div className="bg-surface border border-border rounded p-5">
              <div className="flex items-center gap-2 mb-4">
                <Globe className="w-4 h-4 text-accent" />
                <h3 className="text-sm font-semibold text-text-primary">Top IPs</h3>
              </div>
              <BarChart data={topIps} max={maxIp} labelKey="ip" />
            </div>

            {/* Sources */}
            <div className="bg-surface border border-border rounded p-5">
              <div className="flex items-center gap-2 mb-4">
                <Monitor className="w-4 h-4 text-accent" />
                <h3 className="text-sm font-semibold text-text-primary">Sources</h3>
              </div>
              {sources.length > 0 ? (
                <DonutChart data={sources} total={totalSource} />
              ) : (
                <div className="text-sm text-text-secondary">No data</div>
              )}
            </div>
          </div>
        </>
      )}
    </div>
  )
}
