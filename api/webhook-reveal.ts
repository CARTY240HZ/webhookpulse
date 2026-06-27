import { getSupabase } from './_lib/supabase.js'
import { setCorsHeaders } from './_lib/cors.js'
import { getUserFromJWT } from './_lib/auth.js'
import { apiError } from './_lib/errors.js'
import { captureException } from './_lib/sentry.js'
import { setSecurityHeaders } from './_lib/security.js'
import { isValidUUID } from './_lib/validate.js'
import { checkRateLimit } from './_lib/ratelimit.js'

export default async function handler(req: any, res: any) {
  setSecurityHeaders(res)
  // CORS must be set before any early return so browser XHR sees the headers
  setCorsHeaders(res, 'private')

  if (req.method === 'OPTIONS') {
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

    // Rate limit by IP — split comma-separated forwarded-for chains (same as webhook-receive.ts)
    const rawIp = req.headers['x-vercel-forwarded-for'] || req.headers['x-forwarded-for'] || req.connection?.remoteAddress || ''
    const clientIp = rawIp ? String(rawIp).split(',')[0].trim() : ''
    const allowed = await checkRateLimit(supabase, clientIp)
    if (!allowed) return apiError(res, 429, 'RATE_LIMITED')

    // Verify password by attempting to sign in
    const { data: userData } = await supabase.auth.admin.getUserById(user.id)
    const email = userData?.user?.email
    if (!email) {
      return apiError(res, 401, 'USER_EMAIL_NOT_FOUND')
    }

    // Verify password without creating a session (using signIn + immediate signOut)
    // SECURITY: use ANON key, never service_role key for user auth operations
    const { createClient } = await import('@supabase/supabase-js')
    const supabaseUrl = process.env.SUPABASE_URL || ''
    const supabaseAnonKey = process.env.SUPABASE_ANON_KEY || process.env.VITE_SUPABASE_ANON_KEY || ''

    const authClient = createClient(supabaseUrl, supabaseAnonKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    })

    // Delay wraps the auth call so it pads total response time to a constant floor,
    // preventing the observer from isolating the signInWithPassword timing.
    const authStart = Date.now()
    const { error: signInError } = await authClient.auth.signInWithPassword({ email, password })
    await authClient.auth.signOut({ scope: 'local' })
    const authElapsed = Date.now() - authStart
    await new Promise(r => setTimeout(r, Math.max(0, 500 - authElapsed)))

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
