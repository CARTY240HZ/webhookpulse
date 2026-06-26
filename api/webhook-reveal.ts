import { getSupabase } from './_lib/supabase.js'
import { setCorsHeaders } from './_lib/cors.js'
import { getUserFromJWT } from './_lib/auth.js'
import { apiError } from './_lib/errors.js'
import { captureException } from './_lib/sentry.js'
import { isValidUUID } from './_lib/validate.js'
import { checkRateLimit } from './_lib/ratelimit.js'

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

    // Rate limit by IP (fail-closed)
    const clientIp = req.headers['x-vercel-forwarded-for'] || req.headers['x-forwarded-for'] || req.connection?.remoteAddress || ''
    const allowed = await checkRateLimit(supabase, String(clientIp))
    if (!allowed) return apiError(res, 429, 'RATE_LIMITED')

    // Verify password by attempting to sign in
    const { data: userData } = await supabase.auth.admin.getUserById(user.id)
    const email = userData?.user?.email
    if (!email) {
      return apiError(res, 401, 'USER_EMAIL_NOT_FOUND')
    }

    // Artificial delay to mitigate timing attacks
    await new Promise(r => setTimeout(r, 100 + Math.random() * 400))

    // Verify password without creating a session (using signIn + immediate signOut)
    const { createClient } = await import('@supabase/supabase-js')
    const supabaseUrl = process.env.SUPABASE_URL || ''
    const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY || ''
    
    const authClient = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    })

    const { error: signInError } = await authClient.auth.signInWithPassword({
      email,
      password,
    })

    // Immediately sign out to prevent session accumulation
    await authClient.auth.signOut({ scope: 'local' })

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
