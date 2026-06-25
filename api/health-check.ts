import { getSupabase } from './_lib/supabase.js'
import { setCorsHeaders } from './_lib/cors.js'
import { getUserFromJWT } from './_lib/auth.js'
import { apiError, apiSuccess } from './_lib/errors.js'
import { captureException } from './_lib/sentry.js'

export default async function handler(req: any, res: any) {
  if (req.method === 'OPTIONS') {
    setCorsHeaders(res, 'private')
    return res.status(204).end()
  }

  if (req.method !== 'POST') {
    return apiError(res, 405, 'METHOD_NOT_ALLOWED')
  }

  setCorsHeaders(res, 'private')

  try {
    const supabase = getSupabase()
    const authHeader = req.headers.authorization || ''
    const user = await getUserFromJWT(authHeader)
    if (!user) {
      return apiError(res, 401, 'UNAUTHORIZED')
    }

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
        headers: { 'Content-Type': 'application/json' },
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
  } catch (err) {
    captureException(err as Error)
    return apiError(res, 500, 'INTERNAL_ERROR')
  }
}
