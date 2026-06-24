import { getSupabase } from './_lib/supabase.js'
import { getCorsHeaders } from './_lib/cors.js'
import { getUserFromJWT } from './_lib/auth.js'
import { hashSecret } from './_lib/hmac.js'
import { apiError } from './_lib/errors.js'
import { captureException } from './_lib/sentry.js'

export default async function handler(req: any, res: any) {
  if (req.method === 'OPTIONS') {
    res.set(getCorsHeaders('private'))
    return res.status(204).end()
  }

  if (req.method !== 'POST') {
    return apiError(res, 405, 'METHOD_NOT_ALLOWED')
  }

  try {
    const supabase = getSupabase()
    const authHeader = req.headers.authorization || ''
    const user = await getUserFromJWT(authHeader)
    if (!user) {
      return apiError(res, 401, 'UNAUTHORIZED')
    }

    // Fetch all webhooks of this user with a plaintext secret
    const { data: webhooks, error } = await supabase
      .from('webhooks')
      .select('id, secret')
      .eq('user_id', user.id)
      .not('secret', 'is', null)

    if (error) {
      captureException(error)
      return apiError(res, 500, 'MIGRATION_FETCH_FAILED')
    }

    // NOTE: secret_hash column doesn't exist in DB yet.
    // Return info until the column is added via SQL migration.
    return res.status(200).json({ success: true, migrated: 0, note: 'secret_hash column not ready — migration deferred' })
  } catch (err) {
    captureException(err as Error)
    return apiError(res, 500, 'INTERNAL_ERROR')
  }
}
