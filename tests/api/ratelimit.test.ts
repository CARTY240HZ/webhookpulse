import { vi, describe, it, expect, beforeEach } from 'vitest'

vi.mock('@upstash/redis', async () => {
  const { Redis } = await import('../__mocks__/redis')
  return { Redis }
})

import { checkRateLimit, checkFixedWindowRateLimit } from '../../api/_lib/ratelimit'
import { __resetStore } from '../__mocks__/redis'

beforeEach(() => {
  __resetStore()
  vi.useFakeTimers()
})

afterEach(() => {
  vi.useRealTimers()
})

describe('checkRateLimit (token bucket)', () => {
  it('allows the first request', async () => {
    expect(await checkRateLimit('1.2.3.4')).toBe(true)
  })

  it('allows up to burst requests immediately', async () => {
    const ip = '1.2.3.4'
    for (let i = 0; i < 60; i++) {
      expect(await checkRateLimit(ip)).toBe(true)
    }
    // 61st should be denied
    expect(await checkRateLimit(ip)).toBe(false)
  })

  it('refills tokens over time', async () => {
    const ip = '1.2.3.5'
    // Exhaust burst
    for (let i = 0; i < 60; i++) {
      await checkRateLimit(ip)
    }
    expect(await checkRateLimit(ip)).toBe(false)

    // Wait 1 second for 1 token refill
    vi.advanceTimersByTime(1000)
    expect(await checkRateLimit(ip)).toBe(true)
    expect(await checkRateLimit(ip)).toBe(false)
  })

  it('fails closed when IP is empty', async () => {
    expect(await checkRateLimit('')).toBe(false)
  })

  it('tracks different IPs independently', async () => {
    const ipA = '1.2.3.6'
    const ipB = '1.2.3.7'
    for (let i = 0; i < 60; i++) {
      expect(await checkRateLimit(ipA)).toBe(true)
    }
    expect(await checkRateLimit(ipA)).toBe(false)
    expect(await checkRateLimit(ipB)).toBe(true)
  })
})

describe('checkFixedWindowRateLimit', () => {
  it('allows requests up to max in window', async () => {
    const key = 'user:alice'
    for (let i = 0; i < 5; i++) {
      expect(await checkFixedWindowRateLimit(key, 5, 60)).toBe(true)
    }
    expect(await checkFixedWindowRateLimit(key, 5, 60)).toBe(false)
  })

  it('tracks different keys independently', async () => {
    for (let i = 0; i < 5; i++) {
      expect(await checkFixedWindowRateLimit('a', 5, 60)).toBe(true)
    }
    expect(await checkFixedWindowRateLimit('a', 5, 60)).toBe(false)
    expect(await checkFixedWindowRateLimit('b', 5, 60)).toBe(true)
  })
})
