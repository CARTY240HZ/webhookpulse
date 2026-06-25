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

  if (req.method !== 'GET') {
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

    const webhookId = req.query?.webhookId || req.query?.webhook_id
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
