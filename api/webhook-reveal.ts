import { getSupabase } from './_lib/supabase.js'
import { setCorsHeaders } from './_lib/cors.js'
import { getUserFromJWT } from './_lib/auth.js'
import { apiError } from './_lib/errors.js'
import { captureException } from './_lib/sentry.js'
import { isValidUUID } from './_lib/validate.js'

export default async function handler(req: any, res: any) {
  if (req.method === 'OPTIONS') {
    setCorsHeaders(res, 'private')
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

    const body = req.body || {}
    const webhookId = body.webhookId
    const password = body.password

    if (!webhookId || !isValidUUID(webhookId)) {
      return apiError(res, 400, 'INVALID_WEBHOOK_ID')
    }
    if (!password || typeof password !== 'string' || password.length < 1) {
      return apiError(res, 400, 'PASSWORD_REQUIRED')
    }

    // Verify password by attempting to sign in
    const { data: userData } = await supabase.auth.admin.getUserById(user.id)
    const email = userData?.user?.email
    if (!email) {
      return apiError(res, 401, 'USER_EMAIL_NOT_FOUND')
    }

    // Create a temporary auth client to verify password
    const { createClient } = await import('@supabase/supabase-js')
    const supabaseUrl = process.env.SUPABASE_URL || ''
    const supabaseAnonKey = process.env.VITE_SUPABASE_ANON_KEY || ''
    
    const authClient = createClient(supabaseUrl, supabaseAnonKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    })

    const { error: signInError } = await authClient.auth.signInWithPassword({
      email,
      password,
    })

    if (signInError) {
      return apiError(res, 401, 'INVALID_PASSWORD')
    }

    // Fetch webhook and verify ownership
    const { data: webhook, error: fetchError } = await supabase
      .from('webhooks')
      .select('id, user_id, secret')
      .eq('id', webhookId)
      .single()

    if (fetchError || !webhook) {
      return apiError(res, 404, 'WEBHOOK_NOT_FOUND')
    }

    if (webhook.user_id !== user.id) {
      return apiError(res, 403, 'FORBIDDEN')
    }

    if (!webhook.secret) {
      return apiError(res, 404, 'TOKEN_NOT_FOUND')
    }

    const baseUrl = process.env.APP_URL || 'https://webhookpulse.vercel.app'
    const discordUrl = `${baseUrl}/api/webhooks/${webhook.id}/${webhook.secret}`

    return res.status(200).json({
      token: webhook.secret,
      discord_url: discordUrl,
    })
  } catch (err) {
    captureException(err as Error)
    return apiError(res, 500, 'INTERNAL_ERROR')
  }
}
