import { describe, it, expect } from 'vitest'
import { getCorsHeaders } from '../../../api/_lib/cors'

describe('getCorsHeaders', () => {
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
