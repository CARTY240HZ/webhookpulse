import { Redis } from '@upstash/redis'
import crypto from 'crypto'

const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL || '',
  token: process.env.UPSTASH_REDIS_REST_TOKEN || '',
})

// ─── Security Headers ───
export const SECURITY_HEADERS: Record<string, string> = {
  'Strict-Transport-Security': 'max-age=63072000; includeSubDomains; preload',
  'X-Frame-Options': 'DENY',
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'Permissions-Policy': 'camera=(), microphone=(), geolocation=(), payment=()',
}

export function setSecurityHeaders(res: any): void {
  for (const [key, value] of Object.entries(SECURITY_HEADERS)) {
    res.setHeader(key, value)
  }
}

// ─── Honeypot Timing ───
const HONEYPOT_MIN_MS = 80
const HONEYPOT_JITTER_MS = 120 // total 80-200ms

export async function honeypotDelay(): Promise<void> {
  const delay = HONEYPOT_MIN_MS + Math.floor(Math.random() * HONEYPOT_JITTER_MS)
  return new Promise((r) => setTimeout(r, delay))
}

// ─── Trusted IP Extraction ───
// Only trust Vercel headers. Never trust x-forwarded-for from client.
export function getTrustedIp(req: any): string | null {
  const raw =
    req.headers['x-vercel-forwarded-for'] ||
    req.headers['x-vercel-ip'] ||
    null
  if (!raw) return null
  return String(raw).split(',')[0].trim()
}

// ─── SSE Short-Lived Token (stateless, signed) ───
const SSE_TOKEN_LIFETIME_MS = 5 * 60 * 1000 // 5 minutes

function getSseSecret(): string {
  const secret = process.env.JWT_SECRET || process.env.WEBHOOK_SECRET_SALT
  if (!secret || secret.length < 32) {
    throw new Error(
      'SSE_SECRET must be defined and at least 32 characters. ' +
      'Set JWT_SECRET or WEBHOOK_SECRET_SALT in your environment.'
    )
  }
  return secret
}

function signPayload(payload: string): string {
  return crypto.createHmac('sha256', getSseSecret()).update(payload).digest('hex')
}

export function generateSseToken(userId: string, webhookId: string): string {
  const expiresAt = Date.now() + SSE_TOKEN_LIFETIME_MS
  const payload = `${userId}:${webhookId}:${expiresAt}`
  const signature = signPayload(payload)
  return `${Buffer.from(payload).toString('base64url')}.${signature}`
}

export function validateSseToken(token: string): { userId: string; webhookId: string } | null {
  const parts = token.split('.')
  if (parts.length !== 2) return null

  const [payloadB64, signature] = parts
  let payload: string
  try {
    payload = Buffer.from(payloadB64, 'base64url').toString('utf-8')
  } catch {
    return null
  }

  const expectedSig = signPayload(payload)
  if (signature.length !== expectedSig.length) return null
  if (!crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expectedSig))) return null

  const [userId, webhookId, expiresAtStr] = payload.split(':')
  if (!userId || !webhookId || !expiresAtStr) return null

  const expiresAt = parseInt(expiresAtStr, 10)
  if (isNaN(expiresAt) || expiresAt < Date.now()) return null

  return { userId, webhookId }
}

// ─── Brute-Force Limiter (Redis-backed) ───
const BRUTE_MAX_ATTEMPTS = 5
const BRUTE_WINDOW_MS = 600_000 // 10 minutes

export async function checkBruteLimit(
  key: string,
  maxAttempts: number = BRUTE_MAX_ATTEMPTS,
  windowMs: number = BRUTE_WINDOW_MS
): Promise<boolean> {
  const redisKey = `brute:${key}`
  try {
    const current = await redis.incr(redisKey)
    if (current === 1) {
      await redis.pexpire(redisKey, windowMs)
    }
    return current <= maxAttempts
  } catch (err) {
    console.error('Redis brute force error:', err)
    return true // fail open on Redis error
  }
}

export async function resetBruteLimit(key: string): Promise<void> {
  try {
    await redis.del(`brute:${key}`)
  } catch (err) {
    console.error('Redis brute force reset error:', err)
  }
}

// ─── Cache-Control for Private Responses ───
export function setPrivateCache(res: any): void {
  res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, private')
  res.setHeader('Pragma', 'no-cache')
  res.setHeader('Expires', '0')
}

// ─── Safe Parse Int ───
export function parseIntSafe(val: unknown, defaultVal: number): number {
  const n = parseInt(String(val), 10)
  return isNaN(n) ? defaultVal : n
}
