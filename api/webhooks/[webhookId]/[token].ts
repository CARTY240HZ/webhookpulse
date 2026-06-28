import crypto from 'crypto'
import { getSupabase } from '../../_lib/supabase.js'
import { captureException } from '../../_lib/sentry.js'
import { checkIpAgainstRules } from '../../_lib/ipfilter.js'
import { isValidUUID } from '../../_lib/validate.js'
import { checkRateLimit } from '../../_lib/ratelimit.js'
import { verifyWebhookSecret } from '../../_lib/hmac.js'

// ============================================================
// DISCORD WEBHOOK API — IDENTICAL TO DISCORD API v10
// https://discord.com/developers/docs/resources/webhook#execute-webhook
// ============================================================

// --- Error codes (exact Discord codes) ---
const ERR_UNKNOWN_WEBHOOK = { code: 10015, message: 'Unknown Webhook' }
const ERR_EMPTY_MESSAGE = { code: 50006, message: 'Cannot send an empty message' }
const ERR_INVALID_FORM = { code: 50035, message: 'Invalid Form Body' }
const ERR_RATE_LIMITED = { code: 20028, message: 'The resource is being rate limited.' }

// --- Constants (Discord exact limits) ---
const MAX_CONTENT_LENGTH = 2000
const MAX_EMBEDS = 10
const MAX_EMBED_TITLE = 256
const MAX_EMBED_DESCRIPTION = 4096
const MAX_EMBED_FIELDS = 25
const MAX_EMBED_FIELD_NAME = 256
const MAX_EMBED_FIELD_VALUE = 1024
const MAX_EMBED_FOOTER_TEXT = 2048
const MAX_EMBED_AUTHOR_NAME = 256
const MAX_USERNAME_LENGTH = 80
const MAX_COMPONENTS = 5
const MAX_ATTACHMENTS = 10

// --- Allowed headers for storage ---
const ALLOWED_HEADERS = new Set([
  'content-type',
  'user-agent',
  'x-forwarded-for',
  'accept-encoding',
  'host',
  'content-length',
])

// --- Helpers ---
function discordError(res: any, status: number, err: { code: number; message: string }) {
  return res.status(status).json(err)
}

function discordErrorForm(res: any, status: number, errors: Record<string, any>) {
  return res.status(status).json({
    code: 50035,
    message: 'Invalid Form Body',
    errors,
  })
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
  // Discord snowflakes are 64-bit integers: 41 bits timestamp + 5 bits worker + 5 bits process + 12 bits increment
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

// --- Embed validation (Discord exact spec) ---
function validateEmbed(embed: any, index: number): string[] {
  const errors: string[] = []
  if (!embed || typeof embed !== 'object') {
    errors.push(`embeds[${index}]: must be an object`)
    return errors
  }

  // title: max 256
  if (embed.title !== undefined) {
    if (typeof embed.title !== 'string') errors.push(`embeds[${index}].title: must be a string`)
    else if (embed.title.length > MAX_EMBED_TITLE) errors.push(`embeds[${index}].title: Must be ${MAX_EMBED_TITLE} or fewer in length.`)
  }

  // type: string (rich, image, video, gifv, article, link)
  if (embed.type !== undefined && typeof embed.type !== 'string') {
    errors.push(`embeds[${index}].type: must be a string`)
  }

  // description: max 4096
  if (embed.description !== undefined) {
    if (typeof embed.description !== 'string') errors.push(`embeds[${index}].description: must be a string`)
    else if (embed.description.length > MAX_EMBED_DESCRIPTION) errors.push(`embeds[${index}].description: Must be ${MAX_EMBED_DESCRIPTION} or fewer in length.`)
  }

  // url: string
  if (embed.url !== undefined && typeof embed.url !== 'string') {
    errors.push(`embeds[${index}].url: must be a string`)
  }

  // timestamp: ISO8601 string
  if (embed.timestamp !== undefined && typeof embed.timestamp !== 'string') {
    errors.push(`embeds[${index}].timestamp: must be a string`)
  }

  // color: integer
  if (embed.color !== undefined && !Number.isInteger(embed.color)) {
    errors.push(`embeds[${index}].color: must be an integer`)
  }

  // footer
  if (embed.footer !== undefined) {
    if (typeof embed.footer !== 'object') errors.push(`embeds[${index}].footer: must be an object`)
    else {
      if (embed.footer.text !== undefined) {
        if (typeof embed.footer.text !== 'string') errors.push(`embeds[${index}].footer.text: must be a string`)
        else if (embed.footer.text.length > MAX_EMBED_FOOTER_TEXT) errors.push(`embeds[${index}].footer.text: Must be ${MAX_EMBED_FOOTER_TEXT} or fewer in length.`)
      }
      if (embed.footer.icon_url !== undefined && typeof embed.footer.icon_url !== 'string') {
        errors.push(`embeds[${index}].footer.icon_url: must be a string`)
      }
      if (embed.footer.proxy_icon_url !== undefined && typeof embed.footer.proxy_icon_url !== 'string') {
        errors.push(`embeds[${index}].footer.proxy_icon_url: must be a string`)
      }
    }
  }

  // image
  if (embed.image !== undefined) {
    if (typeof embed.image !== 'object') errors.push(`embeds[${index}].image: must be an object`)
    else {
      if (embed.image.url !== undefined && typeof embed.image.url !== 'string') {
        errors.push(`embeds[${index}].image.url: must be a string`)
      }
      if (embed.image.proxy_url !== undefined && typeof embed.image.proxy_url !== 'string') {
        errors.push(`embeds[${index}].image.proxy_url: must be a string`)
      }
      if (embed.image.height !== undefined && !Number.isInteger(embed.image.height)) {
        errors.push(`embeds[${index}].image.height: must be an integer`)
      }
      if (embed.image.width !== undefined && !Number.isInteger(embed.image.width)) {
        errors.push(`embeds[${index}].image.width: must be an integer`)
      }
    }
  }

  // thumbnail
  if (embed.thumbnail !== undefined) {
    if (typeof embed.thumbnail !== 'object') errors.push(`embeds[${index}].thumbnail: must be an object`)
    else {
      if (embed.thumbnail.url !== undefined && typeof embed.thumbnail.url !== 'string') {
        errors.push(`embeds[${index}].thumbnail.url: must be a string`)
      }
      if (embed.thumbnail.proxy_url !== undefined && typeof embed.thumbnail.proxy_url !== 'string') {
        errors.push(`embeds[${index}].thumbnail.proxy_url: must be a string`)
      }
      if (embed.thumbnail.height !== undefined && !Number.isInteger(embed.thumbnail.height)) {
        errors.push(`embeds[${index}].thumbnail.height: must be an integer`)
      }
      if (embed.thumbnail.width !== undefined && !Number.isInteger(embed.thumbnail.width)) {
        errors.push(`embeds[${index}].thumbnail.width: must be an integer`)
      }
    }
  }

  // video
  if (embed.video !== undefined) {
    if (typeof embed.video !== 'object') errors.push(`embeds[${index}].video: must be an object`)
    else {
      if (embed.video.url !== undefined && typeof embed.video.url !== 'string') {
        errors.push(`embeds[${index}].video.url: must be a string`)
      }
      if (embed.video.proxy_url !== undefined && typeof embed.video.proxy_url !== 'string') {
        errors.push(`embeds[${index}].video.proxy_url: must be a string`)
      }
      if (embed.video.height !== undefined && !Number.isInteger(embed.video.height)) {
        errors.push(`embeds[${index}].video.height: must be an integer`)
      }
      if (embed.video.width !== undefined && !Number.isInteger(embed.video.width)) {
        errors.push(`embeds[${index}].video.width: must be an integer`)
      }
    }
  }

  // provider
  if (embed.provider !== undefined) {
    if (typeof embed.provider !== 'object') errors.push(`embeds[${index}].provider: must be an object`)
    else {
      if (embed.provider.name !== undefined && typeof embed.provider.name !== 'string') {
        errors.push(`embeds[${index}].provider.name: must be a string`)
      }
      if (embed.provider.url !== undefined && typeof embed.provider.url !== 'string') {
        errors.push(`embeds[${index}].provider.url: must be a string`)
      }
    }
  }

  // author
  if (embed.author !== undefined) {
    if (typeof embed.author !== 'object') errors.push(`embeds[${index}].author: must be an object`)
    else {
      if (embed.author.name !== undefined) {
        if (typeof embed.author.name !== 'string') errors.push(`embeds[${index}].author.name: must be a string`)
        else if (embed.author.name.length > MAX_EMBED_AUTHOR_NAME) errors.push(`embeds[${index}].author.name: Must be ${MAX_EMBED_AUTHOR_NAME} or fewer in length.`)
      }
      if (embed.author.url !== undefined && typeof embed.author.url !== 'string') {
        errors.push(`embeds[${index}].author.url: must be a string`)
      }
      if (embed.author.icon_url !== undefined && typeof embed.author.icon_url !== 'string') {
        errors.push(`embeds[${index}].author.icon_url: must be a string`)
      }
      if (embed.author.proxy_icon_url !== undefined && typeof embed.author.proxy_icon_url !== 'string') {
        errors.push(`embeds[${index}].author.proxy_icon_url: must be a string`)
      }
    }
  }

  // fields: max 25
  if (embed.fields !== undefined) {
    if (!Array.isArray(embed.fields)) {
      errors.push(`embeds[${index}].fields: must be an array`)
    } else {
      if (embed.fields.length > MAX_EMBED_FIELDS) {
        errors.push(`embeds[${index}].fields: Must be ${MAX_EMBED_FIELDS} or fewer in length.`)
      }
      for (let i = 0; i < embed.fields.length; i++) {
        const f = embed.fields[i]
        if (!f || typeof f !== 'object') {
          errors.push(`embeds[${index}].fields[${i}]: must be an object`)
          continue
        }
        if (f.name !== undefined) {
          if (typeof f.name !== 'string') errors.push(`embeds[${index}].fields[${i}].name: must be a string`)
          else if (f.name.length > MAX_EMBED_FIELD_NAME) errors.push(`embeds[${index}].fields[${i}].name: Must be ${MAX_EMBED_FIELD_NAME} or fewer in length.`)
        }
        if (f.value !== undefined) {
          if (typeof f.value !== 'string') errors.push(`embeds[${index}].fields[${i}].value: must be a string`)
          else if (f.value.length > MAX_EMBED_FIELD_VALUE) errors.push(`embeds[${index}].fields[${i}].value: Must be ${MAX_EMBED_FIELD_VALUE} or fewer in length.`)
        }
        if (f.inline !== undefined && typeof f.inline !== 'boolean') {
          errors.push(`embeds[${index}].fields[${i}].inline: must be a boolean`)
        }
      }
    }
  }

  return errors
}

export default async function handler(req: any, res: any) {
  // CORS: exact-match whitelist only (prevents CSRF from malicious sites)
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
    const webhookId = String(req.query?.webhookId || '')
    const token = String(req.query?.token || '')

    // Discord uses snowflake IDs (18-20 digits). We accept UUID as our internal mapping.
    if (!isValidUUID(webhookId) || !token) {
      return discordError(res, 404, ERR_UNKNOWN_WEBHOOK)
    }

    const supabase = getSupabase()

    // Look up webhook by UUID
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

    // Verify token. Discord tokens are cryptographically random (~68 chars).
    // We generate one on creation. Legacy webhooks without a proper token are rejected.
    const storedToken = webhook.secret ? String(webhook.secret).trim() : ''
    const storedHash = webhook.secret_hash ? String(webhook.secret_hash).trim() : ''
    const isLegacy = !storedToken && !storedHash

    if (isLegacy) {
      // Legacy webhook without proper token — treated as unknown
      return discordError(res, 404, ERR_UNKNOWN_WEBHOOK)
    }

    const tokenValid = await verifyWebhookSecret(token, storedToken || null, storedHash || null)
    if (!tokenValid) {
      return discordError(res, 401, ERR_UNKNOWN_WEBHOOK)
    }

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
      return discordError(res, 400, ERR_INVALID_FORM)
    }

    // --- Discord validation: content or embeds required ---
    const content = body.content as string | undefined
    const embeds = body.embeds as unknown[] | undefined
    const hasContent = content && typeof content === 'string' && content.trim().length > 0
    const hasEmbeds = Array.isArray(embeds) && embeds.length > 0

    if (!hasContent && !hasEmbeds) {
      return discordError(res, 400, ERR_EMPTY_MESSAGE)
    }

    // --- Validate limits and structure (Discord exact) ---
    const formErrors: Record<string, any> = {}

    if (content !== undefined) {
      if (typeof content !== 'string') {
        formErrors.content = { _errors: [{ code: 'BASE_TYPE_BAD_TYPE', message: 'Must be a string.' }] }
      } else if (content.length > MAX_CONTENT_LENGTH) {
        formErrors.content = { _errors: [{ code: 'BASE_TYPE_MAX_LENGTH', message: `Must be ${MAX_CONTENT_LENGTH} or fewer in length.` }] }
      }
    }

    if (body.username !== undefined) {
      if (typeof body.username !== 'string') {
        formErrors.username = { _errors: [{ code: 'BASE_TYPE_BAD_TYPE', message: 'Must be a string.' }] }
      } else if ((body.username as string).length > MAX_USERNAME_LENGTH) {
        formErrors.username = { _errors: [{ code: 'BASE_TYPE_MAX_LENGTH', message: `Must be ${MAX_USERNAME_LENGTH} or fewer in length.` }] }
      }
    }

    if (body.avatar_url !== undefined && typeof body.avatar_url !== 'string') {
      formErrors.avatar_url = { _errors: [{ code: 'BASE_TYPE_BAD_TYPE', message: 'Must be a string.' }] }
    }

    if (body.tts !== undefined && typeof body.tts !== 'boolean') {
      formErrors.tts = { _errors: [{ code: 'BASE_TYPE_BAD_TYPE', message: 'Must be a boolean.' }] }
    }

    if (embeds !== undefined) {
      if (!Array.isArray(embeds)) {
        formErrors.embeds = { _errors: [{ code: 'BASE_TYPE_BAD_TYPE', message: 'Must be an array.' }] }
      } else if (embeds.length > MAX_EMBEDS) {
        formErrors.embeds = { _errors: [{ code: 'ARRAY_TYPE_MAX_LENGTH', message: `Must be ${MAX_EMBEDS} or fewer in length.` }] }
      } else {
        const embedErrors: Record<string, any> = {}
        for (let i = 0; i < embeds.length; i++) {
          const errs = validateEmbed(embeds[i], i)
          if (errs.length > 0) {
            embedErrors[i] = { _errors: errs.map(e => ({ code: 'BASE_TYPE_INVALID', message: e })) }
          }
        }
        if (Object.keys(embedErrors).length > 0) {
          formErrors.embeds = embedErrors
        }
      }
    }

    if (body.components !== undefined) {
      if (!Array.isArray(body.components)) {
        formErrors.components = { _errors: [{ code: 'BASE_TYPE_BAD_TYPE', message: 'Must be an array.' }] }
      } else if ((body.components as any[]).length > MAX_COMPONENTS) {
        formErrors.components = { _errors: [{ code: 'ARRAY_TYPE_MAX_LENGTH', message: `Must be ${MAX_COMPONENTS} or fewer in length.` }] }
      }
    }

    if (body.attachments !== undefined) {
      if (!Array.isArray(body.attachments)) {
        formErrors.attachments = { _errors: [{ code: 'BASE_TYPE_BAD_TYPE', message: 'Must be an array.' }] }
      } else if ((body.attachments as any[]).length > MAX_ATTACHMENTS) {
        formErrors.attachments = { _errors: [{ code: 'ARRAY_TYPE_MAX_LENGTH', message: `Must be ${MAX_ATTACHMENTS} or fewer in length.` }] }
      }
    }

    if (body.flags !== undefined && !Number.isInteger(body.flags)) {
      formErrors.flags = { _errors: [{ code: 'BASE_TYPE_BAD_TYPE', message: 'Must be an integer.' }] }
    }

    if (body.nonce !== undefined) {
      if (typeof body.nonce !== 'string' && typeof body.nonce !== 'number') {
        formErrors.nonce = { _errors: [{ code: 'BASE_TYPE_BAD_TYPE', message: 'Must be a string or number.' }] }
      }
    }

    if (Object.keys(formErrors).length > 0) {
      return discordErrorForm(res, 400, formErrors)
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

    // --- Rate limit (Discord: 5 req / 2 sec per webhook) ---
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

    // --- Store log (Discord payload) ---
    const filteredHeaders = filterHeaders(req.headers as Record<string, string>)

    const payload: Record<string, unknown> = {
      content: body.content ?? null,
      username: body.username ?? null,
      avatar_url: body.avatar_url ?? null,
      tts: body.tts ?? false,
      embeds: body.embeds ?? [],
      allowed_mentions: body.allowed_mentions ?? null,
      components: body.components ?? null,
      attachments: body.attachments ?? null,
      flags: body.flags ?? null,
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
    const wait = req.query?.wait === 'true' || req.query?.wait === '1'

    // --- Discord Message object (for ?wait=true) ---
    if (wait) {
      const msgId = generateSnowflakeLike()
      const now = nowIso()

      const messageObj: Record<string, unknown> = {
        id: msgId,
        type: 0,
        content: body.content ?? '',
        channel_id: webhookId,
        guild_id: null,
        author: {
          id: webhookId,
          username: (body.username as string) || webhook.name,
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
        embeds: (body.embeds as any[]) ?? [],
        mentions: [],
        mention_roles: [],
        pinned: false,
        mention_everyone: false,
        tts: body.tts ?? false,
        timestamp: now,
        edited_timestamp: null,
        flags: body.flags ?? 0,
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

    // Default Discord behavior: 204 No Content
    return res.status(204).end()
  } catch (err) {
    captureException(err as Error)
    return discordError(res, 500, { code: 0, message: 'Internal Server Error' })
  }
}
