import { getSupabase } from './_lib/supabase.js'
import { getCorsHeaders } from './_lib/cors.js'
import { isValidPath } from './_lib/validate.js'
import { checkRateLimit } from './_lib/ratelimit.js'
import { apiError } from './_lib/errors.js'
import { captureException } from './_lib/sentry.js'
import { checkIpAgainstRules } from './_lib/ipfilter.js'
import { setSecurityHeaders, honeypotDelay, getTrustedIp, setPrivateCache } from './_lib/security.js'
import crypto from 'crypto'

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

    // 2. Body handling: Vercel parses body automatically. If Content-Type is missing,
    // req.body may be a raw string or Buffer. Try to parse JSON from it.
    let rawBody: string = ''
    if (req.body) {
      if (Buffer.isBuffer(req.body)) {
        rawBody = req.body.toString('utf-8')
      } else if (typeof req.body === 'string') {
        rawBody = req.body
      } else if (typeof req.body === 'object') {
        // Already parsed by Vercel body parser
        rawBody = JSON.stringify(req.body)
      }
    }

    const bodySize = rawBody.length
    if (bodySize > MAX_BODY_SIZE) {
      return apiError(res, 413, 'PAYLOAD_TOO_LARGE')
    }

    // 3. Parse payload safely
    let payload: unknown = null
    try {
      if (bodySize > 0) {
        payload = JSON.parse(rawBody)
      }
    } catch (parseErr) {
      captureException(parseErr as Error)
      payload = {}
    }

    // 4. Extract IP (trust Vercel's forwarded header ONLY)
    const ipAddress = getTrustedIp(req)

    // 5. Find webhook by path
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

    // 6. IP filtering
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

    // 7. Check secret (legacy direct comparison)
    const providedSecret = req.headers['x-webhook-secret'] || ''
    let secretValid = false
    
    if (webhook.secret && String(webhook.secret).trim() !== '' && String(webhook.secret).trim() !== 'null') {
      secretValid = crypto.timingSafeEqual(
        Buffer.from(String(providedSecret)),
        Buffer.from(String(webhook.secret))
      )
    } else {
      secretValid = true
    }
    
    if (!secretValid) {
      return res.status(200).json({ received: true })
    }

    // Health-check probe
    const isHealthCheck = req.headers['x-health-check'] === 'true' || req.headers['X-Health-Check'] === 'true'
    if (isHealthCheck) {
      return res.status(200).json({ received: true, health_check: true })
    }

    // 8. Rate limiting
    if (ipAddress) {
      const allowed = await checkRateLimit(supabase, ipAddress)
      if (!allowed) {
        return apiError(res, 429, 'RATE_LIMIT_EXCEEDED')
      }
    }

    // 9. Store log
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
