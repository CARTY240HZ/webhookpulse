import crypto from 'crypto'

function getSalt(): string {
  const salt = process.env.WEBHOOK_SECRET_SALT
  if (!salt) throw new Error('WEBHOOK_SECRET_SALT environment variable is required.')
  return salt
}

export function hashSecret(secret: string): string {
  return crypto.createHmac('sha256', getSalt()).update(secret).digest('hex')
}

export function verifySecret(provided: string, storedHash: string): boolean {
  const expectedHashLength = 64 // HMAC-SHA256 hex = 64 chars
  if (storedHash.length !== expectedHashLength) return false
  const computed = hashSecret(provided)
  if (computed.length !== expectedHashLength) return false
  return crypto.timingSafeEqual(Buffer.from(computed, 'hex'), Buffer.from(storedHash, 'hex'))
}

export function generateToken(length: number = 32): string {
  return crypto.randomBytes(length).toString('hex')
}
