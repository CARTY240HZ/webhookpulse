import { getSupabase } from './_lib/supabase.js'
import { setCorsHeaders } from './_lib/cors.js'
import { getUserFromJWT } from './_lib/auth.js'
import { apiError } from './_lib/errors.js'
import { generateSseToken, setSecurityHeaders, setPrivateCache } from './_lib/security.js'

export default async function handler(req: any, res: any) {
  setSecurityHeaders(res)

  if (req.method === 'OPTIONS') {
    setCorsHeaders(res, 'private', req.headers.origin)
    return res.status(204).end()
  }

  if (req.method !== 'POST') {
    return apiError(res, 405, 'METHOD_NOT_ALLOWED')
  }

  setCorsHeaders(res, 'private', req.headers.origin)

  try {
    const user = await getUserFromJWT(req.headers.authorization || '')
    if (!user) {
      return apiError(res, 401, 'UNAUTHORIZED')
    }

    const supabase = getSupabase()
    const { webhookId } = req.body || {}

    if (!webhookId || typeof webhookId !== 'string') {
      return apiError(res, 400, 'MISSING_WEBHOOK_ID')
    }

    // Verify ownership
    const { data: webhook } = await supabase
      .from('webhooks')
      .select('id')
      .eq('id', webhookId)
      .eq('user_id', user.id)
      .single()

    if (!webhook) {
      return apiError(res, 404, 'WEBHOOK_NOT_FOUND')
    }

    const token = generateSseToken(user.id, webhookId)
    setPrivateCache(res)
    return res.status(200).json({ token, expiresIn: 300 }) // 5 minutes
  } catch (err) {
    return apiError(res, 500, 'INTERNAL_ERROR')
  }
}
