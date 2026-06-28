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

  const isDebug = process.env.NODE_ENV === 'development'
  const logs: string[] = []
  function log(msg: string) { logs.push(msg); console.log(msg) }

  try {
    log('1. POST received')

    if (req.method !== 'POST') {
      log('2. Not POST, returning 405')
      return apiError(res, 405, 'METHOD_NOT_ALLOWED')
    }
    log('2. Is POST')

    await honeypotDelay()
    log('3. Honeypot done')

    const supabase = getSupabase()
    log('4. Supabase created')

    const path = req.query?.path || ''
    log(`5. Path: ${path}`)
    if (!path || !isValidPath(String(path))) {
      log('6. Path invalid, returning honeypot')
      return res.status(200).json({ received: true, ...(isDebug ? { debug: logs } : {}) })
    }
    log('6. Path valid')

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
    log(`7. Body size: ${rawBody.length}`)
    if (rawBody.length > MAX_BODY_SIZE) {
      log('8. Body too large')
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
    log(`8. Payload parsed: ${!!payload}`)

    const ipAddress = getTrustedIp(req)
    log(`9. IP: ${ipAddress}`)

    const pathStr = String(path)
    log(`10. Querying webhooks for path: ${pathStr}`)
    const { data: webhook, error: findError } = await supabase
      .from('webhooks')
      .select('id, secret, is_active, url_path')
      .eq('url_path', pathStr)
      .single()

    log(`11. Query result: data=${!!webhook}, error=${findError?.message || 'none'}`)

    if (findError || !webhook) {
      log('12. Webhook not found or error, returning honeypot')
      return res.status(200).json({ received: true, ...(isDebug ? { debug: logs } : {}), reason: 'webhook_not_found' })
    }
    log(`12. Webhook found: id=${webhook.id}, active=${webhook.is_active}`)

    if (!webhook.is_active) {
      log('13. Webhook inactive, returning honeypot')
      return res.status(200).json({ received: true, ...(isDebug ? { debug: logs } : {}), reason: 'inactive' })
    }

    // IP filtering
    if (ipAddress) {
      log('14. Checking IP rules')
      const { data: ipRules } = await supabase
        .from('ip_rules')
        .select('ip, action')
        .eq('webhook_id', webhook.id)
      log(`15. IP rules: ${ipRules?.length || 0} rules`)
      const ipCheck = checkIpAgainstRules(ipAddress, ipRules || [])
      log(`16. IP check: allowed=${ipCheck.allowed}`)
      if (!ipCheck.allowed) {
        return res.status(200).json({ received: true, reason: 'ip_blocked', ...(isDebug ? { debug: logs } : {}) })
      }
    }

    // Secret check
    const providedSecret = req.headers['x-webhook-secret'] || ''
    log(`17. Secret check: provided=${!!providedSecret}, webhook_secret=${!!webhook.secret}`)
    let secretValid = false
    const ws = String(webhook.secret || '')
    const ps = String(providedSecret)
    if (ws.trim() !== '' && ws.trim() !== 'null') {
      // timingSafeEqual requires EXACT same length — compare length first
      if (ps.length !== ws.length) {
        secretValid = false
      } else {
        try {
          secretValid = crypto.timingSafeEqual(Buffer.from(ps), Buffer.from(ws))
        } catch (err: any) {
          log(`18. timingSafeEqual error: ${err.message}`)
          secretValid = false
        }
      }
    } else {
      secretValid = true
    }
    log(`18. Secret valid: ${secretValid}`)
    if (!secretValid) {
      return res.status(200).json({ received: true, ...(isDebug ? { debug: logs } : {}), reason: 'invalid_secret' })
    }

    // Health check
    if (req.headers['x-health-check'] === 'true') {
      return res.status(200).json({ received: true, health_check: true, ...(isDebug ? { debug: logs } : {}) })
    }

    // Rate limiting
    if (ipAddress) {
      log('19. Checking rate limit')
      const allowed = await checkRateLimit(ipAddress)
      log(`20. Rate limit: allowed=${allowed}`)
      if (!allowed) {
        return apiError(res, 429, 'RATE_LIMIT_EXCEEDED')
      }
    }

    // Store log
    const filteredHeaders = filterHeaders(req.headers as Record<string, string>)
    log('21. Inserting log')

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

    log(`22. Insert result: error=${insertResult.error?.message || 'none'}, data=${!!insertResult.data}`)

    if (insertResult.error && insertResult.error.code === '22P02') {
      log('23. Retrying insert with null IP')
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
      log(`24. Retry result: error=${insertResult.error?.message || 'none'}`)
    }

    if (insertResult.error) {
      captureException(insertResult.error)
      return apiError(res, 500, 'WEBHOOK_STORE_FAILED')
    }

    log(`25. Success: logId=${insertResult.data?.id}`)
    return setPrivateCache(res).status(200).json({ success: true, logId: insertResult.data.id, ...(isDebug ? { debug: logs } : {}) })
  } catch (err: any) {
    log(`ERROR: ${err.message}`)
    return apiError(res, 500, 'INTERNAL_ERROR')
  }
}
