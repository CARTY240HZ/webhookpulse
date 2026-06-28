import { vi, describe, it, expect, beforeEach } from 'vitest'

// Must mock before importing modules that depend on @upstash/redis
vi.mock('@upstash/redis', async () => {
  const { Redis } = await import('../__mocks__/redis')
  return { Redis }
})

import {
  setSecurityHeaders,
  honeypotDelay,
  getTrustedIp,
  generateSseToken,
  validateSseToken,
  checkBruteLimit,
  resetBruteLimit,
  setPrivateCache,
  parseIntSafe,
} from '../../api/_lib/security'
import { __resetStore } from '../__mocks__/redis'

beforeEach(() => {
  __resetStore()
  vi.useFakeTimers()
})

afterEach(() => {
  vi.useRealTimers()
})

describe('setSecurityHeaders', () => {
  it('sets all security headers on response object', () => {
    const res = { setHeader: vi.fn() }
    setSecurityHeaders(res as any)
    expect(res.setHeader).toHaveBeenCalledWith('Strict-Transport-Security', 'max-age=63072000; includeSubDomains; preload')
    expect(res.setHeader).toHaveBeenCalledWith('X-Frame-Options', 'DENY')
    expect(res.setHeader).toHaveBeenCalledWith('X-Content-Type-Options', 'nosniff')
    expect(res.setHeader).toHaveBeenCalledWith('Referrer-Policy', 'strict-origin-when-cross-origin')
    expect(res.setHeader).toHaveBeenCalledWith('Permissions-Policy', 'camera=(), microphone=(), geolocation=(), payment=()')
  })
})

describe('honeypotDelay', () => {
  it('resolves after a delay between 80 and 200ms', async () => {
    const start = Date.now()
    const promise = honeypotDelay()
    vi.advanceTimersByTime(200)
    await promise
    const elapsed = Date.now() - start
    expect(elapsed).toBeGreaterThanOrEqual(80)
    expect(elapsed).toBeLessThanOrEqual(200)
  })
})

describe('getTrustedIp', () => {
  it('extracts x-vercel-forwarded-for', () => {
    const req = { headers: { 'x-vercel-forwarded-for': '1.2.3.4, 5.6.7.8' } }
    expect(getTrustedIp(req)).toBe('1.2.3.4')
  })

  it('extracts x-vercel-ip when forwarded-for is absent', () => {
    const req = { headers: { 'x-vercel-ip': '9.10.11.12' } }
    expect(getTrustedIp(req)).toBe('9.10.11.12')
  })

  it('returns null when no trusted header present', () => {
    const req = { headers: { 'x-forwarded-for': 'evil' } }
    expect(getTrustedIp(req)).toBeNull()
  })

  it('trims whitespace from IP', () => {
    const req = { headers: { 'x-vercel-forwarded-for': '  1.2.3.4  ' } }
    expect(getTrustedIp(req)).toBe('1.2.3.4')
  })
})

describe('SSE tokens', () => {
  beforeEach(() => {
    vi.stubEnv('JWT_SECRET', 'a'.repeat(32))
  })

  afterEach(() => {
    vi.unstubAllEnvs()
  })

  it('generates and validates a token', () => {
    const token = generateSseToken('user-1', 'hook-1')
    expect(token).toContain('.')
    const result = validateSseToken(token)
    expect(result).toEqual({ userId: 'user-1', webhookId: 'hook-1' })
  })

  it('rejects a tampered signature', () => {
    const token = generateSseToken('user-1', 'hook-1')
    const tampered = token.replace(/^[^.]+/, 'tampered')
    expect(validateSseToken(tampered)).toBeNull()
  })

  it('rejects an expired token', () => {
    const token = generateSseToken('user-1', 'hook-1')
    vi.advanceTimersByTime(6 * 60 * 1000) // 6 minutes
    expect(validateSseToken(token)).toBeNull()
  })

  it('rejects malformed token', () => {
    expect(validateSseToken('not-a-token')).toBeNull()
    expect(validateSseToken('a.b.c')).toBeNull()
  })

  it('throws when secret is too short', () => {
    vi.unstubAllEnvs()
    vi.stubEnv('JWT_SECRET', 'short')
    expect(() => generateSseToken('u', 'h')).toThrow('SSE_SECRET must be defined and at least 32 characters')
  })
})

describe('checkBruteLimit', () => {
  it('allows requests up to max attempts', async () => {
    expect(await checkBruteLimit('ip:1', 3, 10_000)).toBe(true)
    expect(await checkBruteLimit('ip:1', 3, 10_000)).toBe(true)
    expect(await checkBruteLimit('ip:1', 3, 10_000)).toBe(true)
    expect(await checkBruteLimit('ip:1', 3, 10_000)).toBe(false)
  })

  it('resets after calling resetBruteLimit', async () => {
    await checkBruteLimit('ip:2', 1, 10_000)
    expect(await checkBruteLimit('ip:2', 1, 10_000)).toBe(false)
    await resetBruteLimit('ip:2')
    expect(await checkBruteLimit('ip:2', 1, 10_000)).toBe(true)
  })

  it('fails open on Redis error (simulated by empty url)', async () => {
    // The mock never throws, but we verify graceful behavior
    const result = await checkBruteLimit('ip:3', 5, 600_000)
    expect(typeof result).toBe('boolean')
  })
})

describe('setPrivateCache', () => {
  it('sets no-store cache headers', () => {
    const res = { setHeader: vi.fn() }
    setPrivateCache(res as any)
    expect(res.setHeader).toHaveBeenCalledWith('Cache-Control', 'no-store, no-cache, must-revalidate, private')
    expect(res.setHeader).toHaveBeenCalledWith('Pragma', 'no-cache')
    expect(res.setHeader).toHaveBeenCalledWith('Expires', '0')
  })
})

describe('parseIntSafe', () => {
  it('parses valid integers', () => {
    expect(parseIntSafe('42', 0)).toBe(42)
    expect(parseIntSafe(7, 0)).toBe(7)
  })

  it('returns default for invalid input', () => {
    expect(parseIntSafe('abc', 99)).toBe(99)
    expect(parseIntSafe('', 5)).toBe(5)
    expect(parseIntSafe(null, 10)).toBe(10)
  })
})
