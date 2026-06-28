import crypto from 'crypto'
import { createClient } from '@supabase/supabase-js'
import { getSupabase } from '../_lib/supabase.js'
import { setCorsHeaders } from '../_lib/cors.js'
import { getUserFromJWT } from '../_lib/auth.js'
import { apiError } from '../_lib/errors.js'
import { captureException } from '../_lib/sentry.js'
import { hashSecretBcrypt } from '../_lib/hmac.js'
import { setSecurityHeaders, setPrivateCache } from '../_lib/security.js'

// Generate a Discord-like cryptographically secure token (~68 chars)
function generateDiscordToken(): string {
  const bytes = crypto.randomBytes(48)
  return bytes.toString('base64url').replace(/[^a-zA-Z0-9_-]/g, '').slice(0, 68)
}

export default async function handler(req: any, res: any) {
  setSecurityHeaders(res)

  if (req.method === 'OPTIONS') {
    setCorsHeaders(res, 'private', req.headers.origin)
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
    const { webhookId, password } = body

    if (!webhookId || !password || typeof webhookId !== 'string' || typeof password !== 'string') {
      return apiError(res, 400, 'MISSING_FIELDS')
    }

    // Verify webhook ownership
    const { data: webhook, error: findError } = await supabase
      .from('webhooks')
      .select('id, user_id, type, name')
      .eq('id', webhookId)
      .eq('user_id', user.id)
      .single()

    if (findError || !webhook) {
      return apiError(res, 404, 'WEBHOOK_NOT_FOUND')
    }

    if (webhook.type !== 'discord') {
      return apiError(res, 400, 'NOT_DISCORD_WEBHOOK')
    }

    // Verify password with Supabase Auth (sign-in check)
    const supabaseUrl = process.env.SUPABASE_URL || ''
    const anonKey = process.env.VITE_SUPABASE_ANON_KEY || ''
    const tempClient = createClient(supabaseUrl, anonKey)

    const { data: signInData, error: signInError } = await tempClient.auth.signInWithPassword({
      email: user.email || '',
      password,
    })

    if (signInError || !signInData.session) {
      return apiError(res, 401, 'INVALID_PASSWORD')
    }

    // Generate new token and update hash
    const newToken = generateDiscordToken()
    const newHash = await hashSecretBcrypt(newToken)

    const { error: updateError } = await supabase
      .from('webhooks')
      .update({ secret_hash: newHash, updated_at: new Date().toISOString() })
      .eq('id', webhookId)
      .eq('user_id', user.id)

    if (updateError) {
      captureException(updateError)
      return apiError(res, 500, 'TOKEN_UPDATE_FAILED')
    }

    const baseUrl = process.env.APP_URL || 'https://webhookpulse.vercel.app'
    const discordUrl = `${baseUrl}/api/webhooks/${webhookId}/${newToken}`

    return res.status(200).json({
      discord_url: discordUrl,
      token: newToken,
      warning: 'Copy this token now — the previous token is no longer valid.',
    })
  } catch (err) {
    captureException(err as Error)
    return apiError(res, 500, 'INTERNAL_ERROR')
  }
}
