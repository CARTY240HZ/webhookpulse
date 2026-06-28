import { getSupabase } from './_lib/supabase.js'
import { getCorsHeaders } from './_lib/cors.js'
import { isValidPath } from './_lib/validate.js'
import { checkRateLimit } from './_lib/ratelimit.js'
import { apiError } from './_lib/errors.js'
import { verifySecret } from './_lib/hmac.js'
import { captureException } from './_lib/sentry.js'
import { checkIpAgainstRules } from './_lib/ipfilter.js'
import { setSecurityHeaders, honeypotDelay, getTrustedIp, setPrivateCache } from './_lib/security.js'
import crypto from 'crypto'

// Disable Vercel's body parser to read raw body for backwards compat with ZEX v7.4.1
// (which does not send Content-Type header)
export const config = {
  api: {
    bodyParser: false,
  },
}

const MAX_BODY_SIZE = 256 * 1024 // 256 KB

const ALLOWED_HEADERS = new Set([
  'content-type',
  'user-agent',
  'x-webhook-secret',
  'x-vercel-forwarded-for',
  'x-vercel-ip',
  'accept-encoding',
  'host',
  'content-length',
])

function filterHeaders(headers: Record<string, string>): Record<string, string> {
  const filtered: Record<string, string> = {}
  for (const [key, value] of Object.entries(headers)) {
    if (ALLOWED_HEADERS.has(key.toLowerCase())) {
      filtered[key] = value
    }
  }
  return filtered
}

// Read raw body from request stream (works with or without Content-Type)
async function readRawBody(req: any): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = []
    let totalSize = 0

    req.on('data', (chunk: Buffer) => {
      totalSize += chunk.length
      if (totalSize > MAX_BODY_SIZE) {
        req.destroy()
        reject(new Error('PAYLOAD_TOO_LARGE'))
        return
      }
      chunks.push(chunk)
    })

    req.on('end', () => {
      resolve(Buffer.concat(chunks))
    })

    req.on('error', (err: Error) => {
      reject(err)
    })
  })
}

export default async function handler(req: any, res: any) {
  setSecurityHeaders(res)

  if (req.method === 'OPTIONS') {
    res.set(getCorsHeaders('public'))
    return res.status(204).end()
  }

  if (req.method !== 'POST') {
    return apiError(res, 405, 'METHOD_NOT_ALLOWED')
  }

  // Honeypot timing: constant delay to prevent enumeration via timing
  await honeypotDelay()

  try {
    const supabase = getSupabase()

    // 1. Validate path format
    const path = req.query?.path || ''
    if (!path || !isValidPath(String(path))) {
      return res.status(200).json({ received: true })
    }

    // 2. Read raw body (works regardless of Content-Type)
    let rawBody: Buffer
    try {
      rawBody = await readRawBody(req)
    } catch (err: any) {
      if (err.message === 'PAYLOAD_TOO_LARGE') {
        return apiError(res, 413, 'PAYLOAD_TOO_LARGE')
      }
      throw err
    }

    const bodySize = rawBody.length
    if (bodySize > MAX_BODY_SIZE) {
      return apiError(res, 413, 'PAYLOAD_TOO_LARGE')
    }

    // 3. Parse payload safely (JSON or empty)
    let payload: unknown = null
    try {
      if (bodySize > 0) {
        payload = JSON.parse(rawBody.toString('utf-8'))
      }
    } catch (parseErr) {
      captureException(parseErr as Error)
      payload = {}
    }

    // 4. Extract IP (trust Vercel's forwarded header ONLY)
    const ipAddress = getTrustedIp(req)

    // 5. Find webhook by path (indexed query, not in-memory filter)
    const pathStr = String(path)
    const { data: webhook, error: findError } = await supabase
      .from('webhooks')
      .select('id, secret, is_active, url_path')
      .eq('url_path', pathStr)
      .single()

    // S10: If webhook doesn't exist or is inactive, return 200 anyway (honeypot)
    if (findError || !webhook) {
      console.error('[webhook-receive] findError:', findError?.message, 'path:', pathStr)
      return res.status(200).json({ received: true })
    }

    if (!webhook.is_active) {
      return res.status(200).json({ received: true })
    }

    // 6. IP filtering (before secret check — prevents secret probing from blocked IPs)
    if (ipAddress) {
      const { data: ipRules } = await supabase
        .from('ip_rules')
        .select('ip, action')
        .eq('webhook_id', webhook.id)

      const ipCheck = checkIpAgainstRules(ipAddress, ipRules || [])
      if (!ipCheck.allowed) {
        return res.status(200).json({ received: true, reason: 'ip_blocked' })
      }
    }

    // 7. Check secret (legacy: direct comparison)
    const providedSecret = req.headers['x-webhook-secret'] || ''
    let secretValid = false
    
    if (webhook.secret && String(webhook.secret).trim() !== '' && String(webhook.secret).trim() !== 'null') {
      secretValid = crypto.timingSafeEqual(
        Buffer.from(String(providedSecret)),
        Buffer.from(String(webhook.secret))
      )
    } else {
      // No secret configured — allow all
      secretValid = true
    }
    
    if (!secretValid) {
      return res.status(200).json({ received: true })
    }

    // Health-check probe: do NOT store log or apply rate limit
    const isHealthCheck = req.headers['x-health-check'] === 'true' || req.headers['X-Health-Check'] === 'true'
    if (isHealthCheck) {
      return res.status(200).json({ received: true, health_check: true })
    }

    // 7. Rate limiting
    if (ipAddress) {
      const allowed = await checkRateLimit(supabase, ipAddress)
      if (!allowed) {
        return apiError(res, 429, 'RATE_LIMIT_EXCEEDED')
      }
    }

    // 8. Store log (S4: filter headers)
    const filteredHeaders = filterHeaders(req.headers as Record<string, string>)

    let insertResult = await supabase
      .from('webhook_logs')
      .insert({
        webhook_id: webhook.id,
        payload: payload ?? {},
        headers: filteredHeaders,
        ip_address: ipAddress,
      })
      .select('id')
      .single()

    if (insertResult.error && insertResult.error.code === '22P02') {
      // 22P02 = invalid_text_representation (inet type error)
      insertResult = await supabase
        .from('webhook_logs')
        .insert({
          webhook_id: webhook.id,
          payload: payload ?? {},
          headers: filteredHeaders,
          ip_address: null,
        })
        .select('id')
        .single()
    }

    if (insertResult.error) {
      captureException(insertResult.error)
      return apiError(res, 500, 'WEBHOOK_STORE_FAILED')
    }

    return setPrivateCache(res).status(200).json({ success: true, logId: insertResult.data.id })
  } catch (err) {
    captureException(err as Error)
    return apiError(res, 500, 'INTERNAL_ERROR')
  }
}
