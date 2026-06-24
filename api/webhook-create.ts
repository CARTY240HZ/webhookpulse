import crypto from 'crypto'
import { getSupabase } from './_lib/supabase.js'
import { setCorsHeaders } from './_lib/cors.js'
import { getUserFromJWT } from './_lib/auth.js'
import { validateWebhookInput, clampString } from './_lib/validate.js'
import { apiError } from './_lib/errors.js'
import { captureException } from './_lib/sentry.js'

function generateSlug(name: string): string {
  const base = name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
  const rand = Math.random().toString(36).substring(2, 8)
  return `${base}-${rand}`
}

// Generate a Discord-like cryptographically secure token (~68 chars)
function generateDiscordToken(): string {
  const bytes = crypto.randomBytes(48)
  // base64url encoding gives ~64 chars, we pad to match Discord's ~68
  return bytes.toString('base64url').replace(/[^a-zA-Z0-9_-]/g, '').slice(0, 68)
}

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
    const name = clampString((body.name as string) || '', 100)
    const description = clampString((body.description as string) || '', 500)

    const validation = validateWebhookInput(name, description)
    if (validation.ok === false) {
      return apiError(res, 400, validation.code)
    }

    // S9: Check webhook limit per user
    const MAX_WEBHOOKS = parseInt(process.env.MAX_WEBHOOKS_PER_USER || '20', 10)
    const { count: currentCount, error: countError } = await supabase
      .from('webhooks')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', user.id)
    if (!countError && (currentCount || 0) >= MAX_WEBHOOKS) {
      return apiError(res, 429, 'WEBHOOK_LIMIT_EXCEEDED')
    }

    const urlPath = generateSlug(name)
    const type = (body.type as string) || 'native'
    
    let secret: string | null = null
    let discordUrl: string | null = null
    
    if (type === 'discord') {
      // Generate Discord-compatible token automatically (cryptographically secure)
      secret = generateDiscordToken()
    }

    const { data: webhook, error } = await supabase
      .from('webhooks')
      .insert({
        user_id: user.id,
        name: name.trim(),
        description: description || null,
        url_path: urlPath,
        secret: secret,
      })
      .select('id, user_id, name, description, url_path, is_active, created_at, updated_at')
      .single()

    if (error) {
      captureException(error)
      return apiError(res, 500, 'WEBHOOK_CREATE_FAILED')
    }

    // Return URLs based on type
    const baseUrl = process.env.APP_URL || 'https://webhookpulse.vercel.app'
    const nativeUrl = `${baseUrl}/api/webhook-receive?path=${urlPath}`
    
    if (type === 'discord' && secret) {
      discordUrl = `${baseUrl}/api/webhooks/${webhook.id}/${secret}`
    }

    const response: Record<string, unknown> = {
      webhook,
      native_url: nativeUrl,
    }
    
    if (discordUrl) {
      response.discord_url = discordUrl
      response.token = secret
    }

    return res.status(201).json(response)
  } catch (err) {
    captureException(err as Error)
    return apiError(res, 500, 'INTERNAL_ERROR')
  }
}
