import { getSupabase } from './_lib/supabase.js'
import { setCorsHeaders } from './_lib/cors.js'
import { getUserFromJWT } from './_lib/auth.js'
import { apiError, apiSuccess } from './_lib/errors.js'
import { getQueryParam } from './_lib/validate.js'
import { captureException } from './_lib/sentry.js'
import { setSecurityHeaders } from './_lib/security.js'
import { checkFixedWindowRateLimit } from './_lib/ratelimit.js'

export default async function handler(req: any, res: any) {
  setSecurityHeaders(res)

  if (req.method === 'OPTIONS') {
    setCorsHeaders(res, 'private', req.headers.origin)
    return res.status(204).end()
  }

  if (req.method !== 'GET' && req.method !== 'POST') {
    return apiError(res, 405, 'METHOD_NOT_ALLOWED')
  }

  setCorsHeaders(res, 'private', req.headers.origin)

  try {
    const supabase = getSupabase()
    const authHeader = req.headers.authorization || ''
    const user = await getUserFromJWT(authHeader)
    if (!user) {
      return apiError(res, 401, 'UNAUTHORIZED')
    }

    // Rate limit: 30 requests per minute per user
    const rateAllowed = await checkFixedWindowRateLimit(`health:${user.id}`, 30, 60)
    if (!rateAllowed) {
      return apiError(res, 429, 'RATE_LIMIT_EXCEEDED')
    }

    if (req.method === 'POST') {
      // ─── RUN SINGLE HEALTH CHECK ───
      const { webhookId } = req.body || {}
      if (!webhookId || typeof webhookId !== 'string') {
        return apiError(res, 400, 'MISSING_WEBHOOK_ID')
      }

      // Verify webhook ownership
      const { data: webhook, error: webhookError } = await supabase
        .from('webhooks')
        .select('id, user_id, url_path')
        .eq('id', webhookId)
        .single()

      if (webhookError || !webhook) {
        return apiError(res, 404, 'WEBHOOK_NOT_FOUND')
      }

      if (webhook.user_id !== user.id) {
        return apiError(res, 403, 'FORBIDDEN')
      }

      const baseUrl = process.env.APP_URL || 'https://webhookpulse.vercel.app'
      const nativeUrl = `${baseUrl}/api/webhook-receive?path=${webhook.url_path}`

      const start = Date.now()
      let status: 'online' | 'degraded' | 'offline' = 'offline'
      let responseTimeMs = 0

      try {
        const controller = new AbortController()
        const timeout = setTimeout(() => controller.abort(), 5000)

        const response = await fetch(nativeUrl, {
          method: 'POST',
          headers: { 
            'Content-Type': 'application/json',
            'X-Health-Check': 'true'
          },
          body: JSON.stringify({ type: 'health_check', timestamp: Date.now() }),
          signal: controller.signal,
        })

        clearTimeout(timeout)
        responseTimeMs = Date.now() - start

        if (responseTimeMs < 500) {
          status = 'online'
        } else if (responseTimeMs <= 2000) {
          status = 'degraded'
        } else {
          status = 'offline'
        }
      } catch (fetchErr) {
        responseTimeMs = Date.now() - start
        status = 'offline'
        captureException(fetchErr as Error)
      }

      const checkedAt = new Date().toISOString()

      const { error: insertError } = await supabase
        .from('health_checks')
        .insert({
          webhook_id: webhookId,
          status,
          response_time_ms: responseTimeMs,
          checked_at: checkedAt,
        })

      if (insertError) {
        captureException(insertError)
        return apiError(res, 500, 'HEALTH_CHECK_INSERT_FAILED')
      }

      return apiSuccess(res, { status, responseTimeMs, checkedAt })
    }

    // ─── LIST HEALTH CHECKS ───
    const webhookId = getQueryParam(req, 'webhookId')
    if (!webhookId || typeof webhookId !== 'string') {
      return apiError(res, 400, 'MISSING_WEBHOOK_ID')
    }

    // Verify webhook ownership
    const { data: webhook, error: webhookError } = await supabase
      .from('webhooks')
      .select('id, user_id')
      .eq('id', webhookId)
      .single()

    if (webhookError || !webhook) {
      return apiError(res, 404, 'WEBHOOK_NOT_FOUND')
    }

    if (webhook.user_id !== user.id) {
      return apiError(res, 403, 'FORBIDDEN')
    }

    const { data: checks, error } = await supabase
      .from('health_checks')
      .select('status, response_time_ms, checked_at')
      .eq('webhook_id', webhookId)
      .order('checked_at', { ascending: false })
      .limit(10)

    if (error) {
      captureException(error)
      return apiError(res, 500, 'HEALTH_CHECKS_FETCH_FAILED')
    }

    const formatted = (checks || []).map((c: Record<string, unknown>) => ({
      status: c.status as string,
      responseTimeMs: c.response_time_ms as number,
      checkedAt: c.checked_at as string,
    }))

    return apiSuccess(res, { checks: formatted })
  } catch (err) {
    captureException(err as Error)
    return apiError(res, 500, 'INTERNAL_ERROR')
  }
}
