import crypto from 'crypto'
import bcrypt from 'bcryptjs'

const SALT = process.env.WEBHOOK_SECRET_SALT

function validateSalt(): string {
  if (!SALT) {
    throw new Error('WEBHOOK_SECRET_SALT environment variable is required. Set a strong random secret (e.g. openssl rand -hex 32).')
  }
  return SALT
}

// ─── Legacy HMAC-SHA256 (used for existing webhook secrets before bcrypt migration) ───
export function hashSecret(secret: string): string {
  return crypto.createHmac('sha256', validateSalt()).update(secret).digest('hex')
}

export function verifySecret(provided: string, storedHash: string): boolean {
  const expectedHashLength = 64 // HMAC-SHA256 hex = 64 chars
  if (storedHash.length !== expectedHashLength) return false
  const computed = hashSecret(provided)
  if (computed.length !== expectedHashLength) return false
  return crypto.timingSafeEqual(Buffer.from(computed, 'hex'), Buffer.from(storedHash, 'hex'))
}

// ─── Bcrypt (production standard for new webhook secrets) ───
export async function hashSecretBcrypt(secret: string): Promise<string> {
  return bcrypt.hash(secret, 12) // 12 rounds ≈ 250ms
}

export async function verifySecretBcrypt(provided: string, hash: string): Promise<boolean> {
  if (!hash || !hash.startsWith('$2')) return false
  return bcrypt.compare(provided, hash)
}

// ─── Dual verification with lazy migration ───
export async function verifyWebhookSecret(
  provided: string,
  storedPlain: string | null,
  storedHash: string | null
): Promise<boolean> {
  // No secret required
  if (!storedPlain || storedPlain === 'null' || storedPlain.trim() === '') {
    return true
  }

  // 1. Try bcrypt hash first (new webhooks)
  if (storedHash && storedHash.startsWith('$2')) {
    return verifySecretBcrypt(provided, storedHash)
  }

  // 2. Fallback to legacy HMAC-SHA256
  if (storedHash && storedHash.length === 64) {
    return verifySecret(provided, storedHash)
  }

  // 3. Final fallback to plaintext comparison (legacy webhooks before any hashing)
  if (provided.length !== storedPlain.length) return false
  try {
    return crypto.timingSafeEqual(Buffer.from(provided), Buffer.from(storedPlain))
  } catch {
    return false
  }
}

export function generateToken(length: number = 32): string {
  return crypto.randomBytes(length).toString('hex')
}
