import crypto from 'crypto'

const SALT = process.env.WEBHOOK_SECRET_SALT

if (!SALT) {
  throw new Error('WEBHOOK_SECRET_SALT environment variable is required. Set a strong random secret (e.g. openssl rand -hex 32).')
}

export function hashSecret(secret: string): string {
  return crypto.createHmac('sha256', SALT).update(secret).digest('hex')
}

export function verifySecret(provided: string, storedHash: string): boolean {
  const computed = hashSecret(provided)
  try {
    return crypto.timingSafeEqual(Buffer.from(computed, 'hex'), Buffer.from(storedHash, 'hex'))
  } catch {
    return false
  }
}

export function generateToken(length: number = 32): string {
  return crypto.randomBytes(length).toString('hex')
}
