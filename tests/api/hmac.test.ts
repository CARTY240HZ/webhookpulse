import { vi, describe, it, expect, beforeEach } from 'vitest'

// Must mock before importing modules that depend on @upstash/redis
vi.mock('@upstash/redis', async () => {
  const { Redis } = await import('../__mocks__/redis')
  return { Redis }
})

import {
  hashSecret,
  verifySecret,
  hashSecretBcrypt,
  verifySecretBcrypt,
  verifyWebhookSecret,
  generateToken,
} from '../../api/_lib/hmac'

beforeEach(() => {
  vi.stubEnv('WEBHOOK_SECRET_SALT', 'test-salt-12345678901234567890123456789012')
})

afterEach(() => {
  vi.unstubAllEnvs()
})

describe('Legacy HMAC-SHA256', () => {
  it('hashSecret produces a 64-char hex string', () => {
    const hash = hashSecret('my-secret')
    expect(hash).toHaveLength(64)
    expect(hash).toMatch(/^[a-f0-9]{64}$/)
  })

  it('verifySecret returns true for matching secret', () => {
    const hash = hashSecret('my-secret')
    expect(verifySecret('my-secret', hash)).toBe(true)
  })

  it('verifySecret returns false for wrong secret', () => {
    const hash = hashSecret('my-secret')
    expect(verifySecret('wrong-secret', hash)).toBe(false)
  })

  it('verifySecret returns false for malformed hash', () => {
    expect(verifySecret('my-secret', 'not-64-chars')).toBe(false)
    expect(verifySecret('my-secret', 'a'.repeat(63))).toBe(false)
  })
})

describe('Bcrypt', () => {
  it('hashSecretBcrypt produces a bcrypt string', async () => {
    const hash = await hashSecretBcrypt('my-secret')
    expect(hash.startsWith('$2')).toBe(true)
    expect(hash).toHaveLength(60)
  })

  it('verifySecretBcrypt returns true for matching secret', async () => {
    const hash = await hashSecretBcrypt('my-secret')
    expect(await verifySecretBcrypt('my-secret', hash)).toBe(true)
  })

  it('verifySecretBcrypt returns false for wrong secret', async () => {
    const hash = await hashSecretBcrypt('my-secret')
    expect(await verifySecretBcrypt('wrong-secret', hash)).toBe(false)
  })

  it('verifySecretBcrypt returns false for non-bcrypt hash', async () => {
    expect(await verifySecretBcrypt('my-secret', 'a'.repeat(64))).toBe(false)
    expect(await verifySecretBcrypt('my-secret', '')).toBe(false)
  })
})

describe('Dual verifyWebhookSecret', () => {
  it('returns true when no secret is stored', async () => {
    expect(await verifyWebhookSecret('anything', null, null)).toBe(true)
    expect(await verifyWebhookSecret('anything', 'null', null)).toBe(true)
    expect(await verifyWebhookSecret('anything', '', null)).toBe(true)
  })

  it('verifies bcrypt hash first', async () => {
    const hash = await hashSecretBcrypt('my-secret')
    expect(await verifyWebhookSecret('my-secret', 'my-secret', hash)).toBe(true)
    expect(await verifyWebhookSecret('wrong', 'my-secret', hash)).toBe(false)
  })

  it('falls back to legacy HMAC when bcrypt prefix missing', async () => {
    const hash = hashSecret('my-secret')
    expect(await verifyWebhookSecret('my-secret', 'my-secret', hash)).toBe(true)
  })

  it('falls back to plaintext timing-safe comparison', async () => {
    expect(await verifyWebhookSecret('plain', 'plain', null)).toBe(true)
    expect(await verifyWebhookSecret('plain', 'different', null)).toBe(false)
  })

  it('returns false for length mismatch in plaintext', async () => {
    expect(await verifyWebhookSecret('short', 'longer-string', null)).toBe(false)
  })
})

describe('generateToken', () => {
  it('generates a hex token of requested length', () => {
    const token = generateToken(16)
    expect(token).toHaveLength(32) // 16 bytes = 32 hex chars
    expect(token).toMatch(/^[a-f0-9]+$/)
  })

  it('defaults to 32 bytes', () => {
    const token = generateToken()
    expect(token).toHaveLength(64)
  })
})
