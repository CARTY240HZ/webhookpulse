import * as Sentry from '@sentry/node'

let initialized = false

export function initSentry(): void {
  const dsn = process.env.SENTRY_DSN
  if (!dsn) {
    console.log('[Sentry] Skipped: SENTRY_DSN not set')
    return
  }
  if (initialized) return

  Sentry.init({
    dsn,
    environment: process.env.VERCEL_ENV || 'development',
    tracesSampleRate: 0.1,
    beforeSend(event) {
      const status = event.extra?.status as number | undefined
      if (status && [400, 401, 403, 404, 429].includes(status)) {
        return null
      }
      return event
    },
  })
  initialized = true
  console.log('[Sentry] Initialized')
}

export function setUserContext(userId: string): void {
  if (!initialized) return
  Sentry.setUser({ id: userId })
}

export function captureException(err: Error): void {
  initSentry()
  if (!initialized) {
    console.error('[Sentry]', err)
    return
  }
  Sentry.captureException(err)
}
