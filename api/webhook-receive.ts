import { getSupabase } from './_lib/supabase.js'
import { getCorsHeaders } from './_lib/cors.js'
import { isValidPath } from './_lib/validate.js'
import { checkRateLimit } from './_lib/ratelimit.js'
import { apiError } from './_lib/errors.js'
import { verifySecret } from './_lib/hmac.js'
import { captureException } from './_lib/sentry.js'
import { checkIpAgainstRules } from './_lib/ipfilter.js'
import crypto from 'crypto'

const MAX_BODY_SIZE = 256 * 1024 // 256 KB

const ALLOWED_HEADERS = new Set([
  'content-type',
  'user-agent',
  'x-webhook-secret',
  'x-forwarded-for',
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

export default async function handler(req: any, res: any) {
  if (req.method === 'OPTIONS') {
    res.set(getCorsHeaders('public'))
    return res.status(204).end()
  }

  if (req.method !== 'POST') {
    return apiError(res, 405, 'METHOD_NOT_ALLOWED')
  }

  try {
    const supabase = getSupabase()

    // 1. Validate path format
    const path = req.query?.path || ''
    if (!path || !isValidPath(String(path))) {
      return res.status(200).json({ received: true })
    }

    // 2. Body size limit
    const bodySize = req.body
      ? Buffer.isBuffer(req.body)
        ? req.body.length
        : typeof req.body === 'string'
          ? req.body.length
          : JSON.stringify(req.body).length
      : 0

    if (bodySize > MAX_BODY_SIZE) {
      return apiError(res, 413, 'PAYLOAD_TOO_LARGE')
    }

    // 3. Parse payload safely
    let payload: unknown = null
    try {
      if (req.body) {
        if (Buffer.isBuffer(req.body)) {
          payload = JSON.parse(req.body.toString('utf-8'))
        } else if (typeof req.body === 'string') {
          payload = JSON.parse(req.body)
        } else {
          payload = req.body
        }
      }
    } catch (parseErr) {
      captureException(parseErr as Error)
      payload = {}
    }

    // 4. Extract IP (trust Vercel's forwarded header, not raw x-forwarded-for)
    const rawIp = req.headers['x-vercel-forwarded-for'] || req.headers['x-vercel-ip'] || req.headers['x-forwarded-for'] || req.headers['client-ip'] || null
    const ipAddress = rawIp ? String(rawIp).split(',')[0].trim() : null

    // 5. Find webhook by path (indexed query, not in-memory filter)
    const pathStr = String(path)
    const { data: webhook, error: findError } = await supabase
      .from('webhooks')
      .select('id, secret, secret_hash, is_active, url_path')
      .eq('url_path', pathStr)
      .single()

    // S10: If webhook doesn't exist or is inactive, return 200 anyway (honeypot)
    if (findError || !webhook) {
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

    // 7. Check secret (S2: HMAC-SHA256 constant-time verification)
    const providedSecret = req.headers['x-webhook-secret'] || ''
    let secretValid = false
    
    if (webhook.secret_hash && String(webhook.secret_hash).trim() !== '') {
      // New: hashed secret with timing-safe comparison
      secretValid = verifySecret(String(providedSecret), String(webhook.secret_hash))
    } else if (webhook.secret && String(webhook.secret).trim() !== '' && String(webhook.secret).trim() !== 'null') {
      // Legacy: direct comparison (deprecated, migrate to secret_hash)
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

    return res.status(200).json({ success: true, logId: insertResult.data.id })
  } catch (err) {
    captureException(err as Error)
    return apiError(res, 500, 'INTERNAL_ERROR')
  }
}
