import { getSupabase } from './_lib/supabase.js'
import { setCorsHeaders } from './_lib/cors.js'
import { getUserFromJWT } from './_lib/auth.js'
import { isValidUUID } from './_lib/validate.js'
import { apiError } from './_lib/errors.js'
import { captureException } from './_lib/sentry.js'

export default async function handler(req: any, res: any) {
  if (req.method === 'OPTIONS') {
    setCorsHeaders(res, 'private')
    return res.status(204).end()
  }

  if (req.method !== 'DELETE') {
    return apiError(res, 405, 'METHOD_NOT_ALLOWED')
  }

  try {
    const supabase = getSupabase()
    const authHeader = req.headers.authorization || ''
    const user = await getUserFromJWT(authHeader)
    if (!user) {
      return apiError(res, 401, 'UNAUTHORIZED')
    }

    const id = req.query?.id || ''
    if (!id || !isValidUUID(String(id))) {
      return apiError(res, 400, 'INVALID_UUID')
    }

    const { data: webhook, error: findError } = await supabase
      .from('webhooks')
      .select('id')
      .eq('id', id)
      .eq('user_id', user.id)
      .single()

    if (findError || !webhook) {
      return apiError(res, 404, 'WEBHOOK_NOT_FOUND')
    }

    const { error: deleteError } = await supabase
      .from('webhooks')
      .delete()
      .eq('id', id)
      .eq('user_id', user.id)

    if (deleteError) {
      captureException(deleteError)
      return apiError(res, 500, 'WEBHOOK_DELETE_FAILED')
    }

    return res.status(200).json({ success: true })
  } catch (err) {
    captureException(err as Error)
    return apiError(res, 500, 'INTERNAL_ERROR')
  }
}
