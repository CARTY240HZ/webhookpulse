import { Link } from 'react-router-dom'
import { Activity, Shield, Zap, Globe } from 'lucide-react'
import { useAuth } from '../hooks/useAuth'

export default function LandingPage() {
  const { user } = useAuth()
  const isAuthenticated = !!user

  return (
    <div className="min-h-screen bg-background flex flex-col">
      <header className="h-16 border-b border-border flex items-center justify-between px-6 lg:px-12">
        <div className="flex items-center gap-2">
          <Activity className="w-5 h-5 text-accent" />
          <span className="font-bold text-text-primary tracking-tight text-lg">WebhookPulse</span>
        </div>
        <div className="flex items-center gap-4">
          {isAuthenticated ? (
            <Link to="/dashboard" className="px-4 py-2 rounded text-sm font-medium bg-accent text-background hover:bg-accent-hover transition-colors">
              Go to Dashboard
            </Link>
          ) : (
            <>
              <Link to="/login" className="text-sm font-medium text-text-secondary hover:text-text-primary transition-colors">
                Sign in
              </Link>
              <Link to="/register" className="px-4 py-2 rounded text-sm font-medium bg-accent text-background hover:bg-accent-hover transition-colors">
                Get started
              </Link>
            </>
          )}
        </div>
      </header>

      <main className="flex-1 flex flex-col items-center justify-center px-6 py-16">
        <div className="max-w-2xl text-center">
          <h1 className="text-4xl lg:text-5xl font-bold text-text-primary mb-6 leading-tight">
            Capture and inspect every webhook
          </h1>
          <p className="text-lg text-text-secondary mb-10 leading-relaxed">
            A professional receiver for Discord and generic webhooks. Real-time logs, secure secrets, and a dashboard built for precision.
          </p>
          <div className="flex items-center justify-center gap-4">
            {isAuthenticated ? (
              <Link to="/dashboard" className="px-6 py-3 rounded text-base font-semibold bg-accent text-background hover:bg-accent-hover transition-colors">
                Go to Dashboard
              </Link>
            ) : (
              <>
                <Link to="/register" className="px-6 py-3 rounded text-base font-semibold bg-accent text-background hover:bg-accent-hover transition-colors">
                  Start for free
                </Link>
                <Link to="/login" className="px-6 py-3 rounded text-base font-semibold bg-surface border border-border text-text-primary hover:bg-elevated transition-colors">
                  Sign in
                </Link>
              </>
            )}
          </div>
        </div>

        <div className="mt-20 grid grid-cols-1 md:grid-cols-3 gap-6 max-w-4xl w-full">
          <div className="bg-surface border border-border rounded p-6">
            <Zap className="w-6 h-6 text-accent mb-4" />
            <h3 className="text-text-primary font-semibold mb-2">Real-time logs</h3>
            <p className="text-text-secondary text-sm leading-relaxed">See incoming payloads the moment they arrive. No refresh needed.</p>
          </div>
          <div className="bg-surface border border-border rounded p-6">
            <Shield className="w-6 h-6 text-accent mb-4" />
            <h3 className="text-text-primary font-semibold mb-2">Secret validation</h3>
            <p className="text-text-secondary text-sm leading-relaxed">Protect endpoints with optional secrets. Reject unauthorized requests.</p>
          </div>
          <div className="bg-surface border border-border rounded p-6">
            <Globe className="w-6 h-6 text-accent mb-4" />
            <h3 className="text-text-primary font-semibold mb-2">Generic receiver</h3>
            <p className="text-text-secondary text-sm leading-relaxed">Discord, Slack, or custom services. Any JSON payload accepted.</p>
          </div>
        </div>
      </main>

      <footer className="border-t border-border px-6 py-6 text-center">
        <p className="text-sm text-text-secondary">WebhookPulse</p>
      </footer>
    </div>
  )
}
