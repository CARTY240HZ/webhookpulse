import { getSupabase } from './_lib/supabase.js'
import { getCorsHeaders } from './_lib/cors.js'
import { isValidPath } from './_lib/validate.js'
import { checkRateLimit } from './_lib/ratelimit.js'
import { apiError } from './_lib/errors.js'
import { verifySecret } from './_lib/hmac.js'
import { captureException } from './_lib/sentry.js'

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
    console.log(`[webhook-receive] DEBUG: raw path="${path}", query keys=${Object.keys(req.query || {}).join(',')}`)
    if (!path || !isValidPath(String(path))) {
      console.log(`[webhook-receive] HONEYPOT: invalid path format, path="${path}"`)
      return res.status(200).json({ received: true, reason: 'invalid_path' })
    }

    console.log(`[webhook-receive] DEBUG: path is valid, proceeding with lookup`)

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
    } catch {
      payload = {}
    }

    // 4. Extract IP
    const rawIp = req.headers['x-forwarded-for'] || req.headers['client-ip'] || null
    const ipAddress = rawIp ? String(rawIp).split(',')[0].trim() : null

    // 5. Find webhook (silently — S10 honeypot)
    const { data: webhook, error: findError } = await supabase
      .from('webhooks')
      .select('id, secret, secret_hash, is_active')
      .eq('url_path', path)
      .single()

    // S10: If webhook doesn't exist or is inactive, return 200 anyway
    if (findError || !webhook) {
      console.log(`[webhook-receive] HONEYPOT: webhook not found for path="${path}"`)
      console.log(`[webhook-receive] DEBUG findError=${JSON.stringify(findError)}`)
      // TEMP: Count total webhooks to diagnose if table is empty or path mismatch
      const { count: totalWebhooks } = await supabase.from('webhooks').select('id', { count: 'exact', head: true })
      console.log(`[webhook-receive] DEBUG total_webhooks=${totalWebhooks}`)
      return res.status(200).json({ received: true, reason: 'webhook_not_found', total_webhooks: totalWebhooks || 0 })
    }

    console.log(`[webhook-receive] DEBUG: webhook found id=${webhook.id}, is_active=${webhook.is_active}, secret=${!!webhook.secret}, secret_hash=${!!webhook.secret_hash}`)

    if (!webhook.is_active) {
      console.log(`[webhook-receive] HONEYPOT: webhook inactive, path="${path}"`)
      return res.status(200).json({ received: true, reason: 'webhook_inactive' })
    }

    // 6. Check secret (S2: HMAC verification, backward-compatible)
    const providedSecret = req.headers['x-webhook-secret'] || ''
    let secretValid = false
    
    // Normalize: treat null/empty/"null" as "no secret"
    const hasSecretHash = webhook.secret_hash && String(webhook.secret_hash).trim() !== '' && String(webhook.secret_hash).trim() !== 'null'
    const hasSecretPlain = webhook.secret && String(webhook.secret).trim() !== '' && String(webhook.secret).trim() !== 'null'
    
    if (hasSecretHash && providedSecret) {
      secretValid = verifySecret(String(providedSecret), String(webhook.secret_hash))
    } else if (hasSecretPlain && providedSecret) {
      // Legacy: direct comparison during migration period
      secretValid = String(providedSecret) === String(webhook.secret)
    } else if (!hasSecretHash && !hasSecretPlain) {
      // No secret configured — allow all
      secretValid = true
    }
    
    if (!secretValid) {
      console.log(`[webhook-receive] HONEYPOT: secret mismatch, path="${path}", hasSecretHash=${hasSecretHash}, hasSecretPlain=${hasSecretPlain}, provided=${!!providedSecret}`)
      return res.status(200).json({ received: true, reason: 'secret_mismatch' })
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

    if (insertResult.error && insertResult.error.message.includes('inet')) {
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
