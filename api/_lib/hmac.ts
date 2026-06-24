import crypto from 'crypto'

const SALT = process.env.WEBHOOK_SECRET_SALT || 'webhookpulse-default-salt-change-me'

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
