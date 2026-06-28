import crypto from 'crypto'

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
  return process.env.JWT_SECRET || process.env.WEBHOOK_SECRET_SALT || 'fallback-sse-secret-change-me'
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

// ─── Brute-Force Limiter (in-memory) ───
interface BruteEntry { count: number; resetAt: number }
const BRUTE_LIMITS = new Map<string, BruteEntry>()

export function checkBruteLimit(
  key: string,
  maxAttempts: number = 5,
  windowMs: number = 600_000
): boolean {
  const now = Date.now()
  const entry = BRUTE_LIMITS.get(key)
  if (!entry || now > entry.resetAt) {
    BRUTE_LIMITS.set(key, { count: 1, resetAt: now + windowMs })
    return true
  }
  if (entry.count >= maxAttempts) return false
  entry.count++
  return true
}

export function resetBruteLimit(key: string): void {
  BRUTE_LIMITS.delete(key)
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
