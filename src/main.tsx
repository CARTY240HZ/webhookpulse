import React from 'react'
import ReactDOM from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import * as Sentry from '@sentry/react'
import { configError } from './lib/supabase'
import App from './App'
import './index.css'

// Sentry frontend init (only if DSN is configured)
const sentryDsn = import.meta.env.VITE_SENTRY_DSN
if (sentryDsn) {
  Sentry.init({
    dsn: sentryDsn,
    environment: import.meta.env.MODE || 'development',
    tracesSampleRate: 0.1,
    beforeSend(event) {
      // Strip PII
      if (event.user) {
        event.user = { id: event.user.id }
      }
      return event
    },
  })
}

function ConfigError() {
  return (
    <div className="min-h-screen bg-background flex items-center justify-center px-6">
      <div className="max-w-md w-full bg-surface border border-border rounded-lg p-8 text-center">
        <div className="w-12 h-12 rounded-full bg-danger/10 flex items-center justify-center mx-auto mb-4">
          <svg className="w-6 h-6 text-danger" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
          </svg>
        </div>
        <h1 className="text-xl font-bold text-text-primary mb-2">Configuration Error</h1>
        <p className="text-sm text-text-secondary mb-6 leading-relaxed">
          {configError}
        </p>
        <div className="bg-background border border-border rounded p-4 text-left text-sm text-text-secondary space-y-2">
          <p className="font-medium text-text-primary">Required environment variables:</p>
          <ul className="list-disc list-inside space-y-1">
            <li><code className="text-accent">VITE_SUPABASE_URL</code></li>
            <li><code className="text-accent">VITE_SUPABASE_ANON_KEY</code></li>
          </ul>
          <p className="mt-2">Set these in your Vercel project settings under Environment variables.</p>
        </div>
      </div>
    </div>
  )
}

if (configError) {
  ReactDOM.createRoot(document.getElementById('root')!).render(
    <React.StrictMode>
      <ConfigError />
    </React.StrictMode>
  )
} else {
  ReactDOM.createRoot(document.getElementById('root')!).render(
    <React.StrictMode>
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </React.StrictMode>
  )
}
