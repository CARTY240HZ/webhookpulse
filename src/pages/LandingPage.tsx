import { useEffect, useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import { Activity, Shield, Zap, Globe, ArrowRight, Webhook, Lock, BarChart3, Check, Terminal, Send, Eye, Copy } from 'lucide-react'
import { useAuth } from '../hooks/useAuth'

/* Floating element with parallax */
function FloatingOrb({ className, style }: { className?: string; style?: React.CSSProperties }) {
  return (
    <div
      className={`absolute rounded-full pointer-events-none blur-3xl ${className}`}
      style={style}
    />
  )
}

/* Animated gradient border card */
function GradientBorderCard({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <div className={`relative group ${className}`}>
      <div className="absolute -inset-[1px] rounded-2xl opacity-0 group-hover:opacity-100 transition-opacity duration-500"
        style={{
          background: 'linear-gradient(135deg, rgba(212,232,58,0.4), rgba(212,232,58,0.1), rgba(212,232,58,0.3))',
        }}
      />
      <div className="relative rounded-2xl p-6 h-full"
        style={{
          background: 'var(--bg-elevated)',
          border: '1px solid var(--border)',
          boxShadow: '0 4px 24px rgba(0,0,0,0.3), inset 0 1px 0 rgba(255,255,255,0.03)',
        }}>
        {children}
      </div>
    </div>
  )
}

/* Code block with copy button */
function CodeBlock({ code, label }: { code: string; label: string }) {
  const [copied, setCopied] = useState(false)
  const handleCopy = () => {
    navigator.clipboard.writeText(code)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  return (
    <div className="rounded-xl overflow-hidden border border-[var(--border)]"
      style={{ background: 'var(--bg-secondary)' }}>
      <div className="flex items-center justify-between px-4 py-2.5 border-b border-[var(--border)]"
        style={{ background: 'var(--bg-elevated)' }}>
        <div className="flex items-center gap-2">
          <div className="flex gap-1.5">
            <div className="w-3 h-3 rounded-full" style={{ background: 'var(--danger)' }} />
            <div className="w-3 h-3 rounded-full" style={{ background: 'var(--warning)' }} />
            <div className="w-3 h-3 rounded-full" style={{ background: 'var(--success)' }} />
          </div>
          <span className="text-xs text-[var(--text-muted)] ml-2 font-mono">{label}</span>
        </div>
        <button onClick={handleCopy}
          className="flex items-center gap-1.5 text-xs text-[var(--text-muted)] hover:text-[var(--accent)] transition-colors">
          {copied ? <Check className="w-3.5 h-3.5" /> : <Copy className="w-3.5 h-3.5" />}
          {copied ? 'Copied' : 'Copy'}
        </button>
      </div>
      <pre className="p-4 overflow-x-auto text-sm font-mono leading-relaxed" style={{ color: 'var(--text-secondary)' }}>
        <code>{code}</code>
      </pre>
    </div>
  )
}

/* Step card */
function StepCard({ number, title, desc, icon: Icon }: { number: string; title: string; desc: string; icon: any }) {
  return (
    <div className="relative group">
      <div className="absolute -left-4 top-0 text-7xl font-bold opacity-[0.03] select-none"
        style={{ color: 'var(--accent)' }}>
        {number}
      </div>
      <div className="relative pl-8">
        <div className="w-10 h-10 rounded-xl flex items-center justify-center mb-4 transition-all duration-300 group-hover:scale-110"
          style={{ background: 'rgba(212,232,58,0.1)' }}>
          <Icon className="w-5 h-5" style={{ color: 'var(--accent)' }} />
        </div>
        <h3 className="font-semibold text-[var(--text-primary)] mb-2">{title}</h3>
        <p className="text-sm text-[var(--text-secondary)] leading-relaxed">{desc}</p>
      </div>
    </div>
  )
}

export default function LandingPage() {
  const { user } = useAuth()
  const isAuthenticated = !!user
  const heroRef = useRef<HTMLDivElement>(null)
  const [mousePos, setMousePos] = useState({ x: 0, y: 0 })

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      if (!heroRef.current) return
      const rect = heroRef.current.getBoundingClientRect()
      setMousePos({
        x: (e.clientX - rect.left - rect.width / 2) / 30,
        y: (e.clientY - rect.top - rect.height / 2) / 30,
      })
    }
    window.addEventListener('mousemove', handleMouseMove)
    return () => window.removeEventListener('mousemove', handleMouseMove)
  }, [])

  const exampleCode = `curl -X POST "https://webhookpulse.vercel.app/api/webhook-receive?path=your-path" \\
  -H "Content-Type: application/json" \\
  -d '{
    "source": "roblox",
    "player": {
      "name": "Player1",
      "health": 100
    }
  }'`

  const features = [
    { icon: Zap, title: 'Real-time logs', desc: 'See incoming payloads the moment they arrive. No refresh needed. Supabase Realtime pushes updates instantly.' },
    { icon: Shield, title: 'Secret validation', desc: 'Protect endpoints with optional secrets. HMAC-SHA256 verification rejects unauthorized requests silently.' },
    { icon: Globe, title: 'Generic receiver', desc: 'Discord, Slack, or custom JSON services. Any payload accepted. Native URL + Discord re-forwarding.' },
    { icon: Lock, title: 'IP filtering', desc: 'Block or allow specific IPs per webhook. Rate limiting with token-bucket algorithm.' },
    { icon: BarChart3, title: 'Analytics', desc: 'Stats per webhook: request volume, response times, error rates. Visual charts and activity timeline.' },
    { icon: Webhook, title: 'Roblox integration', desc: 'Native ZEX script support. Transmit player data, server info, and events directly from Roblox.' },
  ]

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
            <Link to="/dashboard" className="btn-glow px-5 py-2 rounded-lg text-sm font-semibold inline-flex items-center gap-2">
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

      <main className="flex-1 flex flex-col">
        {/* Hero */}
        <section ref={heroRef} className="relative flex flex-col items-center justify-center px-6 py-24 lg:py-32 overflow-hidden">
          {/* Grid pattern */}
          <div className="absolute inset-0 opacity-[0.03] pointer-events-none"
            style={{
              backgroundImage: 'linear-gradient(rgba(212,232,58,0.3) 1px, transparent 1px), linear-gradient(90deg, rgba(212,232,58,0.3) 1px, transparent 1px)',
              backgroundSize: '60px 60px',
            }} />

          {/* Floating orbs with mouse parallax */}
          <FloatingOrb className="w-[500px] h-[500px] top-1/4 left-1/4 opacity-20"
            style={{
              background: 'radial-gradient(circle, rgba(212,232,58,0.15) 0%, transparent 70%)',
              transform: `translate(${mousePos.x * -1}px, ${mousePos.y * -1}px)`,
              transition: 'transform 0.3s ease-out',
            }} />
          <FloatingOrb className="w-[400px] h-[400px] bottom-1/4 right-1/4 opacity-15"
            style={{
              background: 'radial-gradient(circle, rgba(212,232,58,0.1) 0%, transparent 70%)',
              transform: `translate(${mousePos.x * 0.5}px, ${mousePos.y * 0.5}px)`,
              transition: 'transform 0.3s ease-out',
            }} />

          <div className="max-w-3xl text-center relative z-10">
            <div className="animate-fade-in mb-6">
              <span className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-xs font-semibold uppercase tracking-wider border border-[var(--border)]"
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

        {/* How it works - replaces fake stats */}
        <section className="px-6 py-20 lg:py-28 border-y border-[var(--border)]">
          <div className="max-w-5xl mx-auto">
            <div className="text-center mb-16">
              <h2 className="text-3xl lg:text-4xl font-bold mb-4">How it works</h2>
              <p className="text-[var(--text-secondary)] max-w-xl mx-auto">Three simple steps to start receiving webhooks.</p>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-12">
              <StepCard number="01" icon={Send} title="Create a webhook" desc="Generate a unique endpoint with one click. Get a Native URL and optional Discord forwarding URL." />
              <StepCard number="02" icon={Terminal} title="Send payloads" desc="Use curl, your script, or any service. POST JSON to your endpoint. We accept any payload structure." />
              <StepCard number="03" icon={Eye} title="Inspect in real time" desc="Logs appear instantly in your dashboard. Filter by source, view headers, and export data." />
            </div>
          </div>
        </section>

        {/* Code preview */}
        <section className="px-6 py-20 lg:py-28">
          <div className="max-w-5xl mx-auto">
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
              <div>
                <h2 className="text-3xl lg:text-4xl font-bold mb-4">Send from anywhere</h2>
                <p className="text-[var(--text-secondary)] mb-8 leading-relaxed">
                  Any HTTP client works. Just POST JSON to your unique endpoint. No SDK required. No configuration files.
                </p>
                <div className="space-y-4">
                  {[
                    'Native URL for any HTTP client',
                    'Discord-compatible for bots',
                    'Roblox script integration',
                    'Custom headers and secrets',
                  ].map((item) => (
                    <div key={item} className="flex items-center gap-3">
                      <div className="w-5 h-5 rounded-full flex items-center justify-center shrink-0"
                        style={{ background: 'rgba(74,222,128,0.15)' }}>
                        <Check className="w-3 h-3" style={{ color: 'var(--success)' }} />
                      </div>
                      <span className="text-sm text-[var(--text-secondary)]">{item}</span>
                    </div>
                  ))}
                </div>
              </div>
              <CodeBlock code={exampleCode} label="example.sh" />
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
              {features.map((feat) => (
                <GradientBorderCard key={feat.title}>
                  <div className="w-10 h-10 rounded-xl flex items-center justify-center mb-5 transition-transform duration-300 group-hover:scale-110"
                    style={{ background: 'rgba(212,232,58,0.1)' }}>
                    <feat.icon className="w-5 h-5" style={{ color: 'var(--accent)' }} />
                  </div>
                  <h3 className="font-semibold text-[var(--text-primary)] mb-2">{feat.title}</h3>
                  <p className="text-sm text-[var(--text-secondary)] leading-relaxed">{feat.desc}</p>
                </GradientBorderCard>
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
