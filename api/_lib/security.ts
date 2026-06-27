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

// ─── SSE Short-Lived Token ───
const SSE_TOKENS = new Map<string, { userId: string; webhookId: string; expiresAt: number }>()
const SSE_TOKEN_LIFETIME_MS = 5 * 60 * 1000 // 5 minutes

export function generateSseToken(userId: string, webhookId: string): string {
  const token = crypto.randomBytes(32).toString('hex')
  const expiresAt = Date.now() + SSE_TOKEN_LIFETIME_MS
  SSE_TOKENS.set(token, { userId, webhookId, expiresAt })
  // Cleanup old tokens every generation (lazy)
  const now = Date.now()
  for (const [k, v] of SSE_TOKENS) {
    if (v.expiresAt < now) SSE_TOKENS.delete(k)
  }
  return token
}

export function validateSseToken(token: string): { userId: string; webhookId: string } | null {
  const entry = SSE_TOKENS.get(token)
  if (!entry) return null
  if (entry.expiresAt < Date.now()) {
    SSE_TOKENS.delete(token)
    return null
  }
  // Single-use: delete after validation
  SSE_TOKENS.delete(token)
  return { userId: entry.userId, webhookId: entry.webhookId }
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
