// Sentry integration placeholder
// Will be initialized in Phase 6 when SENTRY_DSN env var is configured
// import * as Sentry from '@sentry/node'

export function initSentry(): void {
  const dsn = process.env.SENTRY_DSN
  if (!dsn) {
    console.log('[Sentry] Skipped: SENTRY_DSN not set')
    return
  }
  // Sentry.init({ dsn, environment: process.env.VERCEL_ENV || 'development' })
  console.log('[Sentry] Initialized (Phase 6)')
}

export function captureException(err: Error): void {
  console.error('[Sentry capture]', err)
  // if (Sentry) Sentry.captureException(err)
}
