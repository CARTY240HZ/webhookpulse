import { getSupabase } from './_lib/supabase.js'
import { getCorsHeaders } from './_lib/cors.js'
import { getUserFromJWT } from './_lib/auth.js'
import { isValidUUID } from './_lib/validate.js'
import { apiError } from './_lib/errors.js'
import { captureException } from './_lib/sentry.js'

export default async function handler(req: any, res: any) {
  if (req.method === 'OPTIONS') {
    res.set(getCorsHeaders('private'))
    return res.status(204).end()
  }

  if (req.method !== 'GET' && req.method !== 'DELETE') {
    return apiError(res, 405, 'METHOD_NOT_ALLOWED')
  }

  try {
    const supabase = getSupabase()
    const authHeader = req.headers.authorization || ''
    const user = await getUserFromJWT(authHeader)
    if (!user) {
      return apiError(res, 401, 'UNAUTHORIZED')
    }

    const webhookId = req.query?.webhookId || ''
    if (!webhookId || !isValidUUID(String(webhookId))) {
      return apiError(res, 400, 'INVALID_WEBHOOK_ID')
    }

    const { data: webhook, error: ownerError } = await supabase
      .from('webhooks')
      .select('id')
      .eq('id', webhookId)
      .eq('user_id', user.id)
      .single()

    if (ownerError || !webhook) {
      return apiError(res, 404, 'WEBHOOK_NOT_FOUND')
    }

    if (req.method === 'DELETE') {
      const body = req.body || {}
      const logIds = body.logIds || []
      const deleteAll = body.deleteAll === true

      if (deleteAll) {
        const { error: delError } = await supabase
          .from('webhook_logs')
          .delete()
          .eq('webhook_id', webhookId)
        if (delError) {
          captureException(delError)
          return apiError(res, 500, 'LOGS_DELETE_FAILED')
        }
        return res.status(200).json({ success: true, deleted: 'all' })
      }

      if (logIds.length === 0) {
        return apiError(res, 400, 'NO_LOG_IDS')
      }

      const { error: delError } = await supabase
        .from('webhook_logs')
        .delete()
        .in('id', logIds)
        .eq('webhook_id', webhookId)
      if (delError) {
        captureException(delError)
        return apiError(res, 500, 'LOGS_DELETE_FAILED')
      }
      return res.status(200).json({ success: true, deleted: logIds.length })
    }

    const { data: logs, error } = await supabase
      .from('webhook_logs')
      .select('*')
      .eq('webhook_id', webhookId)
      .order('created_at', { ascending: false })
      .limit(200)

    if (error) {
      captureException(error)
      return apiError(res, 500, 'LOGS_FETCH_FAILED')
    }

    return res.status(200).json({ logs: logs || [] })
  } catch (err) {
    captureException(err as Error)
    return apiError(res, 500, 'INTERNAL_ERROR')
  }
}
