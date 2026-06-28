import { getSupabase } from './_lib/supabase.js'
import { isValidPath } from './_lib/validate.js'
import { setSecurityHeaders, honeypotDelay, getTrustedIp, setPrivateCache } from './_lib/security.js'
import { checkIpAgainstRules } from './_lib/ipfilter.js'
import { checkRateLimit } from './_lib/ratelimit.js'
import { apiError } from './_lib/errors.js'
import { captureException } from './_lib/sentry.js'
import crypto from 'crypto'

const MAX_BODY_SIZE = 256 * 1024

const ALLOWED_HEADERS = new Set([
  'content-type', 'user-agent', 'x-webhook-secret',
  'x-vercel-forwarded-for', 'x-vercel-ip',
  'accept-encoding', 'host', 'content-length',
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

  if (req.method !== 'POST') {
    return apiError(res, 405, 'METHOD_NOT_ALLOWED')
  }

  await honeypotDelay()

  try {
    const supabase = getSupabase()

    const path = req.query?.path || ''
    if (!path || !isValidPath(String(path))) {
      return res.status(200).json({ received: true })
    }

    let rawBody: string = ''
    if (req.body) {
      if (Buffer.isBuffer(req.body)) {
        rawBody = req.body.toString('utf-8')
      } else if (typeof req.body === 'string') {
        rawBody = req.body
      } else if (typeof req.body === 'object') {
        rawBody = JSON.stringify(req.body)
      }
    }

    if (rawBody.length > MAX_BODY_SIZE) {
      return apiError(res, 413, 'PAYLOAD_TOO_LARGE')
    }

    let payload: unknown = null
    try {
      if (rawBody.length > 0) {
        payload = JSON.parse(rawBody)
      }
    } catch (parseErr) {
      captureException(parseErr as Error)
      payload = {}
    }

    const ipAddress = getTrustedIp(req)

    const pathStr = String(path)
    const { data: webhook, error: findError } = await supabase
      .from('webhooks')
      .select('id, secret, is_active, url_path')
      .eq('url_path', pathStr)
      .single()

    if (findError || !webhook) {
      return res.status(200).json({ received: true })
    }

    if (!webhook.is_active) {
      return res.status(200).json({ received: true })
    }

    // IP filtering
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

    // Secret check
    const providedSecret = req.headers['x-webhook-secret'] || ''
    let secretValid = false
    if (webhook.secret && String(webhook.secret).trim() !== '' && String(webhook.secret).trim() !== 'null') {
      try {
        secretValid = crypto.timingSafeEqual(
          Buffer.from(String(providedSecret)),
          Buffer.from(String(webhook.secret))
        )
      } catch {
        secretValid = false
      }
    } else {
      secretValid = true
    }
    if (!secretValid) {
      return res.status(200).json({ received: true })
    }

    // Health check
    if (req.headers['x-health-check'] === 'true') {
      return res.status(200).json({ received: true, health_check: true })
    }

    // Rate limiting
    if (ipAddress) {
      const allowed = await checkRateLimit(supabase, ipAddress)
      if (!allowed) {
        return apiError(res, 429, 'RATE_LIMIT_EXCEEDED')
      }
    }

    // Store log
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
