import { getSupabase } from './_lib/supabase'
import { getCorsHeaders } from './_lib/cors'
import { getUserFromJWT } from './_lib/auth'
import { hashSecret } from './_lib/hmac'
import { apiError } from './_lib/errors'
import { captureException } from './_lib/sentry'

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

    let migrated = 0
    for (const wh of webhooks || []) {
      if (!wh.secret) continue
      const hash = hashSecret(wh.secret)
      const { error: updError } = await supabase
        .from('webhooks')
        .update({ secret_hash: hash })
        .eq('id', wh.id)
      if (!updError) migrated++
    }

    return res.status(200).json({ success: true, migrated })
  } catch (err) {
    captureException(err as Error)
    return apiError(res, 500, 'INTERNAL_ERROR')
  }
}
