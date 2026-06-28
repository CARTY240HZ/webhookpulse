import { Redis } from '@upstash/redis'

const redis = new Redis({
  url: process.env.KV_REST_API_URL || process.env.UPSTASH_REDIS_REST_URL || '',
  token: process.env.KV_REST_API_TOKEN || process.env.UPSTASH_REDIS_REST_TOKEN || '',
})

const RATE_LIMIT_BURST = 60
const RATE_LIMIT_REFILL_PER_SECOND = 1
const RATE_LIMIT_TTL_SECONDS = 60

/**
 * Token bucket rate limiter using Redis.
 * Returns true if the request is allowed, false if rate limited.
 */
export async function checkRateLimit(ip: string): Promise<boolean> {
  if (!ip) return false // fail closed

  const key = `ratelimit:token:${ip}`
  const now = Date.now()

  try {
    const raw = await redis.hmget(key, 'tokens', 'last')
    const tokens = Number(raw[0]) || RATE_LIMIT_BURST
    const last = Number(raw[1]) || now

    const elapsed = (now - last) / 1000
    const newTokens = Math.min(
      RATE_LIMIT_BURST,
      tokens + elapsed * RATE_LIMIT_REFILL_PER_SECOND
    )

    if (newTokens < 1) {
      return false
    }

    await redis.hmset(key, { tokens: newTokens - 1, last: now })
    await redis.expire(key, RATE_LIMIT_TTL_SECONDS)
    return true
  } catch (err) {
    console.error('Redis rate limit error:', err)
    return true // fail open on Redis error to avoid blocking legitimate traffic
  }
}

/**
 * Fixed-window counter rate limiter for simpler use cases.
 */
export async function checkFixedWindowRateLimit(
  key: string,
  maxRequests: number,
  windowSeconds: number
): Promise<boolean> {
  try {
    const current = await redis.incr(`ratelimit:fixed:${key}`)
    if (current === 1) {
      await redis.expire(`ratelimit:fixed:${key}`, windowSeconds)
    }
    return current <= maxRequests
  } catch (err) {
    console.error('Redis fixed window error:', err)
    return true
  }
}
