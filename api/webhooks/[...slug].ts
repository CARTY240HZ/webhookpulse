import crypto from 'crypto'
import { getSupabase } from '../../_lib/supabase.js'
import { captureException } from '../../_lib/sentry.js'
import { checkIpAgainstRules } from '../../_lib/ipfilter.js'
import { isValidUUID, getQueryParamString } from '../../_lib/validate.js'
import { checkRateLimit } from '../../_lib/ratelimit.js'
import { verifyWebhookSecret } from '../../_lib/hmac.js'

// ============================================================
// DISCORD WEBHOOK API — CATCH-ALL ROUTE
// Vercel Serverless Functions: api/webhooks/[...slug].ts
// Matches: /api/webhooks/{webhookId}/{token}
// ============================================================

const ERR_UNKNOWN_WEBHOOK = { code: 10015, message: 'Unknown Webhook' }
const ERR_RATE_LIMITED = { code: 20028, message: 'The resource is being rate limited.' }

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

function nowIso(): string {
  return new Date().toISOString()
}

function generateSnowflakeLike(): string {
  const timestamp = Date.now()
  const worker = 1
  const process = 1
  const increment = Math.floor(Math.random() * 4096)
  const snowflake = ((BigInt(timestamp) - BigInt(1420070400000)) << BigInt(22)) |
    (BigInt(worker) << BigInt(17)) |
    (BigInt(process) << BigInt(12)) |
    BigInt(increment)
  return snowflake.toString()
}

function coerceString(val: unknown): string | null {
  if (val === null || val === undefined) return null
  if (typeof val === 'string') return val
  return String(val)
}
function coerceNumber(val: unknown): number | null {
  if (val === null || val === undefined) return null
  if (typeof val === 'number') return Number.isFinite(val) ? val : null
  const n = Number(val)
  return Number.isFinite(n) ? n : null
}
function coerceBoolean(val: unknown): boolean {
  if (typeof val === 'boolean') return val
  if (typeof val === 'string') return val.toLowerCase() === 'true'
  return !!val
}
function sanitizeEmbed(embed: any): Record<string, unknown> | null {
  if (!embed || typeof embed !== 'object') return null
  const sanitized: Record<string, unknown> = {}
  if (embed.title !== undefined) sanitized.title = coerceString(embed.title)
  if (embed.type !== undefined) sanitized.type = coerceString(embed.type)
  if (embed.description !== undefined) sanitized.description = coerceString(embed.description)
  if (embed.url !== undefined) sanitized.url = coerceString(embed.url)
  if (embed.timestamp !== undefined) sanitized.timestamp = coerceString(embed.timestamp)
  if (embed.color !== undefined) {
    const color = coerceNumber(embed.color)
    if (color !== null) sanitized.color = color
  }
  if (embed.footer && typeof embed.footer === 'object') {
    sanitized.footer = { text: coerceString(embed.footer.text) }
    if (embed.footer.icon_url !== undefined) sanitized.footer.icon_url = coerceString(embed.footer.icon_url)
  }
  if (embed.image && typeof embed.image === 'object') {
    sanitized.image = { url: coerceString(embed.image.url) }
  }
  if (embed.thumbnail && typeof embed.thumbnail === 'object') {
    sanitized.thumbnail = { url: coerceString(embed.thumbnail.url) }
  }
  if (embed.author && typeof embed.author === 'object') {
    sanitized.author = { name: coerceString(embed.author.name) }
    if (embed.author.url !== undefined) sanitized.author.url = coerceString(embed.author.url)
    if (embed.author.icon_url !== undefined) sanitized.author.icon_url = coerceString(embed.author.icon_url)
  }
  if (Array.isArray(embed.fields)) {
    sanitized.fields = embed.fields
      .map((f: any) => {
        if (!f || typeof f !== 'object') return null
        const field: Record<string, unknown> = {}
        if (f.name !== undefined) field.name = coerceString(f.name)
        if (f.value !== undefined) field.value = coerceString(f.value)
        if (f.inline !== undefined) field.inline = coerceBoolean(f.inline)
        return field
      })
      .filter(Boolean)
  }
  return Object.keys(sanitized).length > 0 ? sanitized : null
}

export default async function handler(req: any, res: any) {
  const appUrl = process.env.APP_URL || 'https://webhookpulse.vercel.app'
  const origin = req.headers.origin || ''
  const allowedOrigins = new Set([
    appUrl,
    'https://webhookpulse.vercel.app',
    'http://localhost:5173',
    'http://localhost:3000',
  ])
  if (origin && allowedOrigins.has(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin)
  }
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization')
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS')

  if (req.method === 'OPTIONS') {
    return res.status(204).end()
  }

  if (req.method !== 'POST') {
    return discordError(res, 405, { code: 0, message: 'Method Not Allowed' })
  }

  try {
    // Extract path segments from catch-all route
    // Vercel: req.query.slug is a string for 1 segment, array for 2+
    const slug = req.query?.slug
    let segments: string[] = []
    if (Array.isArray(slug)) {
      segments = slug
    } else if (typeof slug === 'string') {
      segments = [slug]
    }

    // Must be exactly 2 segments: webhookId / token
    if (segments.length !== 2) {
      return discordError(res, 404, ERR_UNKNOWN_WEBHOOK)
    }

    const webhookId = segments[0]
    const token = segments[1]

    if (!isValidUUID(webhookId) || !token) {
      return discordError(res, 404, ERR_UNKNOWN_WEBHOOK)
    }

    const supabase = getSupabase()

    const { data: webhook, error: findError } = await supabase
      .from('webhooks')
      .select('id, secret, secret_hash, is_active, name')
      .eq('id', webhookId)
      .single()

    if (findError || !webhook) {
      return discordError(res, 404, ERR_UNKNOWN_WEBHOOK)
    }

    if (!webhook.is_active) {
      return discordError(res, 404, ERR_UNKNOWN_WEBHOOK)
    }

    const storedToken = webhook.secret ? String(webhook.secret).trim() : ''
    const storedHash = webhook.secret_hash ? String(webhook.secret_hash).trim() : ''
    const isLegacy = !storedToken && !storedHash

    if (isLegacy) {
      return discordError(res, 404, ERR_UNKNOWN_WEBHOOK)
    }

    const tokenValid = await verifyWebhookSecret(token, storedToken || null, storedHash || null)
    if (!tokenValid) {
      return discordError(res, 401, ERR_UNKNOWN_WEBHOOK)
    }

    // Parse body — accept ANY JSON, text, or empty body
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
      body = { _raw: String(req.body || '') }
    }

    // --- LOOSE MODE: sanitize and accept any payload ---
    let normalizedPayload: Record<string, unknown> = {}

    const rawContent = coerceString(body.content)
    const rawUsername = coerceString(body.username)
    const rawAvatarUrl = coerceString(body.avatar_url)
    const rawTts = coerceBoolean(body.tts)
    const rawFlags = coerceNumber(body.flags)

    if (rawContent !== null) normalizedPayload.content = rawContent
    if (rawUsername !== null) normalizedPayload.username = rawUsername
    if (rawAvatarUrl !== null) normalizedPayload.avatar_url = rawAvatarUrl
    normalizedPayload.tts = rawTts

    let rawEmbeds: unknown[] = []
    if (body.embeds !== undefined) {
      if (Array.isArray(body.embeds)) {
        rawEmbeds = body.embeds
      } else if (body.embeds && typeof body.embeds === 'object') {
        rawEmbeds = [body.embeds]
      }
    }
    const sanitizedEmbeds = rawEmbeds.map(sanitizeEmbed).filter(Boolean) as Record<string, unknown>[]
    if (sanitizedEmbeds.length > 0) normalizedPayload.embeds = sanitizedEmbeds

    if (body.title !== undefined || body.description !== undefined || body.color !== undefined) {
      const rootEmbed = sanitizeEmbed(body)
      if (rootEmbed) {
        const existing = (normalizedPayload.embeds as Record<string, unknown>[]) || []
        normalizedPayload.embeds = [rootEmbed, ...existing]
      }
    }

    if (!normalizedPayload.content && !normalizedPayload.embeds) {
      normalizedPayload.content = 'Webhook received'
      normalizedPayload._raw_body = body
    }

    // --- IP filtering ---
    const rawIp = req.headers['x-forwarded-for'] || req.headers['client-ip'] || null
    const ipAddress = rawIp ? String(rawIp).split(',')[0].trim() : null

    if (ipAddress) {
      const { data: ipRules } = await supabase
        .from('ip_rules')
        .select('ip, action')
        .eq('webhook_id', webhook.id)

      const ipCheck = checkIpAgainstRules(ipAddress, ipRules || [])
      if (!ipCheck.allowed) {
        return discordError(res, 403, { code: 0, message: 'Forbidden' })
      }
    }

    // --- Rate limit ---
    if (ipAddress) {
      const allowed = await checkRateLimit(ipAddress)
      if (!allowed) {
        const resetAfter = '2'
        res.setHeader('Retry-After', resetAfter)
        res.setHeader('X-RateLimit-Limit', '5')
        res.setHeader('X-RateLimit-Remaining', '0')
        res.setHeader('X-RateLimit-Reset', String(Math.floor(Date.now() / 1000) + 2))
        res.setHeader('X-RateLimit-Reset-After', resetAfter)
        res.setHeader('X-RateLimit-Bucket', webhookId)
        res.setHeader('X-RateLimit-Global', 'false')
        return discordError(res, 429, ERR_RATE_LIMITED)
      }
    }

    // --- Store log ---
    const filteredHeaders = filterHeaders(req.headers as Record<string, string>)

    const payload: Record<string, unknown> = {
      content: normalizedPayload.content ?? null,
      username: normalizedPayload.username ?? null,
      avatar_url: normalizedPayload.avatar_url ?? null,
      tts: normalizedPayload.tts ?? false,
      embeds: normalizedPayload.embeds ?? [],
      allowed_mentions: body.allowed_mentions ?? null,
      components: body.components ?? null,
      attachments: body.attachments ?? null,
      flags: rawFlags,
      thread_name: body.thread_name ?? null,
      applied_tags: body.applied_tags ?? null,
      nonce: body.nonce ?? null,
      message_reference: body.message_reference ?? null,
      sticker_items: body.sticker_items ?? null,
      poll: body.poll ?? null,
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
      return discordError(res, 500, { code: 0, message: 'Internal Server Error' })
    }

    const logId = insertResult.data.id
    const wait = getQueryParamString(req, 'wait') === 'true' || getQueryParamString(req, 'wait') === '1'

    if (wait) {
      const msgId = generateSnowflakeLike()
      const now = nowIso()

      const messageObj: Record<string, unknown> = {
        id: msgId,
        type: 0,
        content: (normalizedPayload.content as string) || '',
        channel_id: webhookId,
        guild_id: null,
        author: {
          id: webhookId,
          username: (normalizedPayload.username as string) || webhook.name,
          discriminator: '0000',
          global_name: null,
          avatar: null,
          bot: true,
          system: false,
          mfa_enabled: false,
          banner: null,
          accent_color: null,
          locale: 'en-US',
          verified: true,
          email: null,
          flags: 0,
          premium_type: 0,
          public_flags: 0,
          webhook_id: webhookId,
        },
        member: null,
        attachments: (body.attachments as any[]) ?? [],
        embeds: (normalizedPayload.embeds as any[]) ?? [],
        mentions: [],
        mention_roles: [],
        pinned: false,
        mention_everyone: false,
        tts: normalizedPayload.tts ?? false,
        timestamp: now,
        edited_timestamp: null,
        flags: rawFlags ?? 0,
        components: (body.components as any[]) ?? null,
        nonce: body.nonce ?? null,
        referenced_message: null,
        webhook_id: webhookId,
        position: null,
        role_subscription_data: null,
        sticker_items: (body.sticker_items as any[]) ?? null,
        resolved: null,
        poll: body.poll ?? null,
        thread: null,
        mention_channels: null,
        activity: null,
        application: null,
        application_id: null,
        interaction: null,
        message_reference: body.message_reference ?? null,
        reactions: [],
      }

      return res.status(200).json(messageObj)
    }

    return res.status(204).end()
  } catch (err) {
    captureException(err as Error)
    return discordError(res, 500, { code: 0, message: 'Internal Server Error' })
  }
}
