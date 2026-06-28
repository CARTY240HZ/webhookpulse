import { useEffect, useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import { Activity, Shield, Zap, Globe, ArrowRight, Webhook, Lock, BarChart3 } from 'lucide-react'
import { useAuth } from '../hooks/useAuth'

/* Animated counter hook */
function useCountUp(end: number, duration = 2000) {
  const [count, setCount] = useState(0)
  const ref = useRef<HTMLSpanElement>(null)
  useEffect(() => {
    const el = ref.current
    if (!el) return
    let start = 0
    const step = (timestamp: number) => {
      if (!start) start = timestamp
      const progress = Math.min((timestamp - start) / duration, 1)
      setCount(Math.floor(progress * end))
      if (progress < 1) requestAnimationFrame(step)
    }
    const obs = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) requestAnimationFrame(step)
    }, { threshold: 0.3 })
    obs.observe(el)
    return () => obs.disconnect()
  }, [end, duration])
  return { ref, count }
}

export default function LandingPage() {
  const { user } = useAuth()
  const isAuthenticated = !!user
  const totalLogs = useCountUp(2847193)
  const totalWebhooks = useCountUp(48291)
  const uptime = useCountUp(99)

  return (
    <div className="min-h-screen flex flex-col" style={{ background: 'var(--bg)', color: 'var(--text-primary)' }}>
      {/* Header */}
      <header
        className="h-16 flex items-center justify-between px-6 lg:px-12 sticky top-0 z-50 border-b border-[var(--border)]"
        style={{
          background: 'rgba(8,8,10,0.85)',
          backdropFilter: 'blur(12px) saturate(140%)',
          WebkitBackdropFilter: 'blur(12px) saturate(140%)',
        }}
      >
        <div className="flex items-center gap-2.5">
          <div className="w-8 h-8 rounded-lg flex items-center justify-center" style={{ background: 'var(--accent)' }}>
            <Activity className="w-4.5 h-4.5" style={{ color: 'var(--bg)' }} />
          </div>
          <span className="font-bold tracking-tight text-lg">WebhookPulse</span>
        </div>
        <div className="flex items-center gap-4">
          {isAuthenticated ? (
            <Link
              to="/dashboard"
              className="btn-glow px-5 py-2 rounded-lg text-sm font-semibold inline-flex items-center gap-2"
            >
              Go to Dashboard
              <ArrowRight className="w-4 h-4" />
            </Link>
          ) : (
            <>
              <Link to="/login" className="text-sm font-medium text-[var(--text-secondary)] hover:text-[var(--text-primary)] transition-colors">
                Sign in
              </Link>
              <Link to="/register" className="btn-glow px-5 py-2 rounded-lg text-sm font-semibold">
                Get started
              </Link>
            </>
          )}
        </div>
      </header>

      {/* Hero */}
      <main className="flex-1 flex flex-col">
        <section className="relative flex flex-col items-center justify-center px-6 py-24 lg:py-32 overflow-hidden">
          {/* Background glow */}
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] rounded-full opacity-20 pointer-events-none"
            style={{ background: 'radial-gradient(circle, rgba(212,232,58,0.15) 0%, transparent 70%)' }} />

          <div className="max-w-3xl text-center relative z-10">
            <div className="animate-fade-in mb-6">
              <span className="inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-semibold uppercase tracking-wider border border-[var(--border)]"
                style={{ background: 'rgba(212,232,58,0.08)', color: 'var(--accent)' }}>
                <Zap className="w-3.5 h-3.5" />
                Webhook infrastructure for professionals
              </span>
            </div>
            <h1 className="text-5xl lg:text-7xl font-bold mb-6 leading-[1.1] tracking-tight animate-fade-in-up">
              Capture every{' '}
              <span className="text-gradient">webhook</span>
              <br />
              in real time
            </h1>
            <p className="text-lg lg:text-xl text-[var(--text-secondary)] mb-10 leading-relaxed max-w-2xl mx-auto animate-fade-in-up stagger-1">
              A professional receiver for Discord, Slack, and custom webhooks. Real-time logs, secure secrets, and a dashboard built for precision.
            </p>
            <div className="flex items-center justify-center gap-4 animate-fade-in-up stagger-2">
              {isAuthenticated ? (
                <Link to="/dashboard" className="btn-glow px-8 py-3.5 rounded-xl text-base font-semibold inline-flex items-center gap-2">
                  Go to Dashboard
                  <ArrowRight className="w-5 h-5" />
                </Link>
              ) : (
                <>
                  <Link to="/register" className="btn-glow px-8 py-3.5 rounded-xl text-base font-semibold">
                    Start for free
                  </Link>
                  <Link to="/login" className="btn-ghost px-8 py-3.5 rounded-xl text-base font-semibold">
                    Sign in
                  </Link>
                </>
              )}
            </div>
          </div>
        </section>

        {/* Stats */}
        <section className="px-6 py-12 border-y border-[var(--border)]">
          <div className="max-w-5xl mx-auto grid grid-cols-1 md:grid-cols-3 gap-8">
            <div className="text-center">
              <span ref={totalLogs.ref} className="text-4xl lg:text-5xl font-bold text-gradient tabular-nums">
                {totalLogs.count.toLocaleString()}
              </span>
              <p className="text-sm text-[var(--text-secondary)] mt-2 font-medium">Webhooks received</p>
            </div>
            <div className="text-center">
              <span ref={totalWebhooks.ref} className="text-4xl lg:text-5xl font-bold text-gradient tabular-nums">
                {totalWebhooks.count.toLocaleString()}
              </span>
              <p className="text-sm text-[var(--text-secondary)] mt-2 font-medium">Active endpoints</p>
            </div>
            <div className="text-center">
              <span ref={uptime.ref} className="text-4xl lg:text-5xl font-bold text-gradient tabular-nums">
                {uptime.count}%
              </span>
              <p className="text-sm text-[var(--text-secondary)] mt-2 font-medium">Uptime guaranteed</p>
            </div>
          </div>
        </section>

        {/* Features */}
        <section className="px-6 py-20 lg:py-28">
          <div className="max-w-5xl mx-auto">
            <div className="text-center mb-16">
              <h2 className="text-3xl lg:text-4xl font-bold mb-4">Built for speed and security</h2>
              <p className="text-[var(--text-secondary)] max-w-xl mx-auto">Everything you need to capture, inspect, and manage webhooks at scale.</p>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              {[
                { icon: Zap, title: 'Real-time logs', desc: 'See incoming payloads the moment they arrive. No refresh needed. Supabase Realtime pushes updates instantly.' },
                { icon: Shield, title: 'Secret validation', desc: 'Protect endpoints with optional secrets. HMAC-SHA256 verification rejects unauthorized requests silently.' },
                { icon: Globe, title: 'Generic receiver', desc: 'Discord, Slack, or custom JSON services. Any payload accepted. Native URL + Discord re-forwarding.' },
                { icon: Lock, title: 'IP filtering', desc: 'Block or allow specific IPs per webhook. Rate limiting with token-bucket algorithm.' },
                { icon: BarChart3, title: 'Analytics', desc: 'Stats per webhook: request volume, response times, error rates. Visual charts and activity timeline.' },
                { icon: Webhook, title: 'Roblox integration', desc: 'Native ZEX script support. Transmit player data, server info, and events directly from Roblox.' },
              ].map((feat, i) => (
                <div
                  key={feat.title}
                  className="group rounded-xl p-6 border border-[var(--border)] hover:border-[var(--border-hover)] transition-all duration-300 card-hover"
                  style={{
                    background: 'var(--bg-elevated)',
                    boxShadow: '0 4px 24px rgba(0,0,0,0.3), inset 0 1px 0 rgba(255,255,255,0.03)',
                  }}
                >
                  <div className="w-10 h-10 rounded-xl flex items-center justify-center mb-5 transition-transform duration-300 group-hover:scale-110"
                    style={{ background: 'rgba(212,232,58,0.1)' }}>
                    <feat.icon className="w-5 h-5" style={{ color: 'var(--accent)' }} />
                  </div>
                  <h3 className="font-semibold text-[var(--text-primary)] mb-2">{feat.title}</h3>
                  <p className="text-sm text-[var(--text-secondary)] leading-relaxed">{feat.desc}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* CTA */}
        <section className="px-6 py-20 lg:py-28 relative overflow-hidden">
          <div className="absolute inset-0 opacity-30 pointer-events-none"
            style={{ background: 'radial-gradient(ellipse at center, rgba(212,232,58,0.08) 0%, transparent 60%)' }} />
          <div className="max-w-2xl mx-auto text-center relative z-10">
            <h2 className="text-3xl lg:text-4xl font-bold mb-4">Ready to capture everything?</h2>
            <p className="text-[var(--text-secondary)] mb-8">Start receiving webhooks in seconds. No credit card required.</p>
            <Link to="/register" className="btn-glow px-10 py-4 rounded-xl text-lg font-semibold inline-flex items-center gap-2">
              Get started free
              <ArrowRight className="w-5 h-5" />
            </Link>
          </div>
        </section>

        {/* Footer */}
        <footer className="border-t border-[var(--border)] px-6 py-8">
          <div className="max-w-5xl mx-auto flex flex-col md:flex-row items-center justify-between gap-4">
            <div className="flex items-center gap-2">
              <div className="w-6 h-6 rounded-md flex items-center justify-center" style={{ background: 'var(--accent)' }}>
                <Activity className="w-3.5 h-3.5" style={{ color: 'var(--bg)' }} />
              </div>
              <span className="font-semibold text-sm">WebhookPulse</span>
            </div>
            <p className="text-xs text-[var(--text-muted)]">Professional webhook infrastructure. Built with precision.</p>
          </div>
        </footer>
      </main>
    </div>
  )
}
