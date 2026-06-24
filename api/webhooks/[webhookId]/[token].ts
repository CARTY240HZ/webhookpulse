import { getSupabase } from '../../_lib/supabase.js'
import { captureException } from '../../_lib/sentry.js'
import { isValidUUID } from '../../_lib/validate.js'
import { checkRateLimit } from '../../_lib/ratelimit.js'

// Discord-compatible error codes
const DISCORD_ERRORS = {
  UNKNOWN_WEBHOOK: { code: 10015, message: 'Unknown Webhook' },
  EMPTY_MESSAGE: { code: 50006, message: 'Cannot send an empty message' },
  INVALID_FORM: { code: 50035, message: 'Invalid Form Body' },
  RATE_LIMITED: { code: 20028, message: 'The resource is being rate limited.' },
  SERVER_ERROR: { code: 0, message: 'Internal Server Error' },
}

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Allow-Methods': 'POST, GET, PATCH, DELETE, OPTIONS',
}

const ALLOWED_HEADERS = new Set([
  'content-type',
  'user-agent',
  'x-forwarded-for',
  'accept-encoding',
  'host',
  'content-length',
])

function discordError(res: any, status: number, err: { code: number; message: string }) {
  return res.status(status).json(err)
}

function filterHeaders(headers: Record<string, string>): Record<string, string> {
  const out: Record<string, string> = {}
  for (const [k, v] of Object.entries(headers)) {
    if (ALLOWED_HEADERS.has(k.toLowerCase())) out[k] = v
  }
  return out
}

export default async function handler(req: any, res: any) {
  res.setHeader('Access-Control-Allow-Origin', '*')
  res.setHeader('Access-Control-Allow-Headers', CORS_HEADERS['Access-Control-Allow-Headers'])
  res.setHeader('Access-Control-Allow-Methods', CORS_HEADERS['Access-Control-Allow-Methods'])

  if (req.method === 'OPTIONS') {
    return res.status(204).end()
  }

  if (req.method !== 'POST') {
    return discordError(res, 405, { code: 0, message: 'Method Not Allowed' })
  }

  try {
    const webhookId = String(req.query?.webhookId || '')
    const token = String(req.query?.token || '')

    // Validate ID format (must be UUID)
    if (!isValidUUID(webhookId) || !token) {
      return discordError(res, 404, DISCORD_ERRORS.UNKNOWN_WEBHOOK)
    }

    const supabase = getSupabase()

    // Look up webhook by UUID
    const { data: webhook, error: findError } = await supabase
      .from('webhooks')
      .select('id, secret, is_active, name')
      .eq('id', webhookId)
      .single()

    if (findError || !webhook) {
      return discordError(res, 404, DISCORD_ERRORS.UNKNOWN_WEBHOOK)
    }

    if (!webhook.is_active) {
      return discordError(res, 404, DISCORD_ERRORS.UNKNOWN_WEBHOOK)
    }

    // Verify token matches secret
    const hasSecret = webhook.secret && String(webhook.secret).trim() !== ''
    if (hasSecret) {
      if (token !== String(webhook.secret)) {
        return discordError(res, 401, DISCORD_ERRORS.UNKNOWN_WEBHOOK)
      }
    }
    // If no secret configured, any token accepted (open webhook)

    // Parse body
    let body: Record<string, unknown> = {}
    try {
      if (req.body) {
        if (Buffer.isBuffer(req.body)) {
          body = JSON.parse(req.body.toString('utf-8'))
        } else if (typeof req.body === 'string') {
          body = JSON.parse(req.body)
        } else {
          body = req.body as Record<string, unknown>
        }
      }
    } catch {
      return discordError(res, 400, DISCORD_ERRORS.INVALID_FORM)
    }

    // Discord validation: need at least content or embeds
    const content = body.content as string | undefined
    const embeds = body.embeds as unknown[] | undefined
    const hasContent = content && typeof content === 'string' && content.trim().length > 0
    const hasEmbeds = Array.isArray(embeds) && embeds.length > 0

    if (!hasContent && !hasEmbeds) {
      return discordError(res, 400, DISCORD_ERRORS.EMPTY_MESSAGE)
    }

    // Validate limits
    if (hasContent && content!.length > 2000) {
      return discordError(res, 400, {
        code: 50035,
        message: 'Invalid Form Body',
      })
    }
    if (hasEmbeds && embeds!.length > 10) {
      return discordError(res, 400, {
        code: 50035,
        message: 'Invalid Form Body',
      })
    }

    // Rate limit by IP
    const rawIp = req.headers['x-forwarded-for'] || req.headers['client-ip'] || null
    const ipAddress = rawIp ? String(rawIp).split(',')[0].trim() : null

    if (ipAddress) {
      const allowed = await checkRateLimit(supabase, ipAddress)
      if (!allowed) {
        return discordError(res, 429, DISCORD_ERRORS.RATE_LIMITED)
      }
    }

    // Store as webhook_log with Discord payload
    const filteredHeaders = filterHeaders(req.headers as Record<string, string>)
    const payload = {
      _discord_format: true,
      content: body.content ?? null,
      username: body.username ?? null,
      avatar_url: body.avatar_url ?? null,
      tts: body.tts ?? false,
      embeds: body.embeds ?? [],
      allowed_mentions: body.allowed_mentions ?? null,
      flags: body.flags ?? null,
      thread_name: body.thread_name ?? null,
    }

    let insertResult = await supabase
      .from('webhook_logs')
      .insert({
        webhook_id: webhook.id,
        payload,
        headers: filteredHeaders,
        ip_address: ipAddress,
      })
      .select('id')
      .single()

    if (insertResult.error?.message?.includes('inet')) {
      insertResult = await supabase
        .from('webhook_logs')
        .insert({
          webhook_id: webhook.id,
          payload,
          headers: filteredHeaders,
          ip_address: null,
        })
        .select('id')
        .single()
    }

    if (insertResult.error) {
      captureException(insertResult.error)
      return discordError(res, 500, DISCORD_ERRORS.SERVER_ERROR)
    }

    const logId = insertResult.data.id
    const wait = req.query?.wait === 'true' || req.query?.wait === '1'

    if (wait) {
      // Discord returns a message object when ?wait=true
      return res.status(200).json({
        id: logId,
        type: 0,
        content: body.content ?? '',
        channel_id: webhookId,
        author: {
          id: webhookId,
          username: (body.username as string) || webhook.name,
          discriminator: '0000',
          bot: true,
          webhook_id: webhookId,
        },
        attachments: [],
        embeds: body.embeds ?? [],
        mentions: [],
        mention_roles: [],
        pinned: false,
        mention_everyone: false,
        tts: body.tts ?? false,
        timestamp: new Date().toISOString(),
        edited_timestamp: null,
        flags: body.flags ?? 0,
        webhook_id: webhookId,
      })
    }

    // Default Discord behavior: 204 No Content
    return res.status(204).end()
  } catch (err) {
    captureException(err as Error)
    return discordError(res, 500, DISCORD_ERRORS.SERVER_ERROR)
  }
}
