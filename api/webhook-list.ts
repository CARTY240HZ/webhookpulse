import { getSupabase } from './_lib/supabase.js'
import { setCorsHeaders } from './_lib/cors.js'
import { getUserFromJWT } from './_lib/auth.js'
import { apiError } from './_lib/errors.js'
import { captureException } from './_lib/sentry.js'

export default async function handler(req: any, res: any) {
  if (req.method === 'OPTIONS') {
    setCorsHeaders(res, 'private')
    return res.status(204).end()
  }

  if (req.method !== 'GET') {
    return apiError(res, 405, 'METHOD_NOT_ALLOWED')
  }

  try {
    const supabase = getSupabase()
    const authHeader = req.headers.authorization || ''
    const user = await getUserFromJWT(authHeader)
    if (!user) {
      return apiError(res, 401, 'UNAUTHORIZED')
    }

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
  } catch (err) {
    captureException(err as Error)
    return apiError(res, 500, 'INTERNAL_ERROR')
  }
}
