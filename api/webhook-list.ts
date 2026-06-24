import { getSupabase } from './_lib/supabase'
import { getCorsHeaders } from './_lib/cors'
import { getUserFromJWT } from './_lib/auth'
import { apiError } from './_lib/errors'
import { captureException } from './_lib/sentry'

export default async function handler(req: any, res: any) {
  if (req.method === 'OPTIONS') {
    res.set(getCorsHeaders('private'))
    return res.status(204).end()
  }

  if (req.method !== 'GET') {
    return apiError(res, 405, 'METHOD_NOT_ALLOWED')
  }

  try {
    const supabase = getSupabase()
    const authHeader = req.headers.authorization || ''
    const user = await getUserFromJWT(authHeader)
    if (!user) {
      return apiError(res, 401, 'UNAUTHORIZED')
    }

    // S5: Exclude 'secret' from response. Be explicit with field list.
    const { data: webhooks, error } = await supabase
      .from('webhooks')
      .select('id, user_id, name, description, url_path, is_active, created_at, updated_at, webhook_logs(count)')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })

    if (error) {
      captureException(error)
      return apiError(res, 500, 'WEBHOOK_FETCH_FAILED')
    }

    const enriched = (webhooks || []).map((w: Record<string, unknown>) => ({
      ...w,
      log_count: (w.webhook_logs as { count: number }[])?.[0]?.count ?? 0,
    }))

    return res.status(200).json({ webhooks: enriched })
  } catch (err) {
    captureException(err as Error)
    return apiError(res, 500, 'INTERNAL_ERROR')
  }
}
