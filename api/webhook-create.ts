import { getSupabase } from './_lib/supabase'
import { getCorsHeaders } from './_lib/cors'
import { getUserFromJWT } from './_lib/auth'
import { validateWebhookInput, clampString } from './_lib/validate'
import { apiError } from './_lib/errors'
import { captureException } from './_lib/sentry'

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

    const validation = validateWebhookInput(name, description)
    if (!validation.ok) {
      return apiError(res, 400, validation.code)
    }

    const urlPath = generateSlug(name)

    const { data: webhook, error } = await supabase
      .from('webhooks')
      .insert({
        user_id: user.id,
        name: name.trim(),
        description: description || null,
        url_path: urlPath,
        secret: (body.secret as string) || null,
      })
      .select('id, user_id, name, description, url_path, is_active, created_at, updated_at')
      .single()

    if (error) {
      captureException(error)
      return apiError(res, 500, 'WEBHOOK_CREATE_FAILED')
    }

    return res.status(201).json({ webhook })
  } catch (err) {
    captureException(err as Error)
    return apiError(res, 500, 'INTERNAL_ERROR')
  }
}
