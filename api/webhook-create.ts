import { getSupabase } from './_lib/supabase.js'
import { getCorsHeaders } from './_lib/cors.js'
import { getUserFromJWT } from './_lib/auth.js'
import { validateWebhookInput, clampString } from './_lib/validate.js'
import { hashSecret } from './_lib/hmac.js'
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

    const body = req.body || {}
    const name = clampString((body.name as string) || '', 100)
    const description = clampString((body.description as string) || '', 500)
    const rawSecret = (body.secret as string) || null

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

    // S2: Hash secret before storing (HMAC-SHA256)
    const secretHash = rawSecret ? hashSecret(rawSecret) : null

    const { data: webhook, error } = await supabase
      .from('webhooks')
      .insert({
        user_id: user.id,
        name: name.trim(),
        description: description || null,
        url_path: urlPath,
        secret: rawSecret || null,
        secret_hash: secretHash,
      })
      .select('id, user_id, name, description, url_path, is_active, created_at, updated_at')
      .single()

    if (error) {
      captureException(error)
      return apiError(res, 500, 'WEBHOOK_CREATE_FAILED')
    }

    // Return the raw secret ONE TIME so the user can copy it
    return res.status(201).json({ webhook, secret: rawSecret })
  } catch (err) {
    captureException(err as Error)
    return apiError(res, 500, 'INTERNAL_ERROR')
  }
}
