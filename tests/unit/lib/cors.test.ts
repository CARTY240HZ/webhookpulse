import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import { getCorsHeaders } from '../../../api/_lib/cors'

describe('getCorsHeaders', () => {
  const originalAppUrl = process.env.APP_URL

  beforeEach(() => {
    process.env.APP_URL = 'https://webhookpulse.vercel.app'
  })

  afterEach(() => {
    if (originalAppUrl === undefined) delete process.env.APP_URL
    else process.env.APP_URL = originalAppUrl
  })

  it('returns wildcard for public type', () => {
    const headers = getCorsHeaders('public')
    expect(headers['Access-Control-Allow-Origin']).toBe('*')
    expect(headers['Access-Control-Allow-Headers']).toContain('Authorization')
    expect(headers['Access-Control-Allow-Methods']).toContain('POST')
  })

  it('returns domain-locked for private type', () => {
    const headers = getCorsHeaders('private')
    expect(headers['Access-Control-Allow-Origin']).not.toBe('*')
    expect(headers['Access-Control-Allow-Headers']).toContain('Authorization')
  })

  it('includes X-Webhook-Secret in allowed headers', () => {
    const headers = getCorsHeaders('public')
    expect(headers['Access-Control-Allow-Headers']).toContain('X-Webhook-Secret')
  })
})
