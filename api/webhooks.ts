import crypto from 'crypto'
import { getSupabase } from './_lib/supabase.js'
import { setCorsHeaders } from './_lib/cors.js'
import { getUserFromJWT } from './_lib/auth.js'
import { validateWebhookInput, clampString, isValidUUID } from './_lib/validate.js'
import { apiError } from './_lib/errors.js'
import { captureException } from './_lib/sentry.js'

function generateSlug(name: string): string {
  const base = name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
  const rand = crypto.randomBytes(3).toString('hex')
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
    setCorsHeaders(res, 'private', req.headers.origin)
    return res.status(204).end()
  }

  if (req.method !== 'GET' && req.method !== 'POST' && req.method !== 'DELETE') {
    return apiError(res, 405, 'METHOD_NOT_ALLOWED')
  }

  try {
    const supabase = getSupabase()
    const authHeader = req.headers.authorization || ''
    const user = await getUserFromJWT(authHeader)
    if (!user) {
      return apiError(res, 401, 'UNAUTHORIZED')
    }

    if (req.method === 'GET') {
      // ─── LIST WEBHOOKS ───
      // S5: Select 'secret' to compute discord_url and has_secret.
      const { data: webhooks, error } = await supabase
        .from('webhooks')
        .select('id, user_id, name, description, url_path, is_active, secret, created_at, updated_at, webhook_logs(count)')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false })

      if (error) {
        captureException(error)
        return apiError(res, 500, 'WEBHOOK_FETCH_FAILED')
      }

      const baseUrl = process.env.APP_URL || 'https://webhookpulse.vercel.app'

      const enriched = (webhooks || []).map((w: Record<string, unknown>) => {
        const secret = w.secret ? String(w.secret).trim() : ''
        const hasSecret = secret !== '' && secret !== 'null' && secret.length >= 32
        const discordUrl = hasSecret ? `${baseUrl}/api/webhooks/${w.id}/${secret}` : null
        const nativeUrl = `${baseUrl}/api/webhook-receive?path=${w.url_path}`
        // Exclude plaintext secret from response — never send it after creation
        const { secret: _secret, ...rest } = w
        return {
          ...rest,
          log_count: (w.webhook_logs as { count: number }[])?.[0]?.count ?? 0,
          has_secret: hasSecret,
          discord_url: discordUrl,
          native_url: nativeUrl,
        }
      })

      return res.status(200).json({ webhooks: enriched })
    }

    if (req.method === 'POST') {
      // ─── CREATE WEBHOOK ───
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
      if (type !== 'native' && type !== 'discord') {
        return apiError(res, 400, 'INVALID_TYPE')
      }

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

      // Return URLs based on type (token only shown once — copy it immediately)
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
        response.warning = 'Copy this token now — it will not be shown again'
      }

      return res.status(201).json(response)
    }

    // ─── DELETE WEBHOOK ───
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
