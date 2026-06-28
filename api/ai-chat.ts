import Anthropic from '@anthropic-ai/sdk'
import { getCorsHeaders } from './_lib/cors.js'
import { apiError, apiSuccess } from './_lib/errors.js'

// ─────────────────────────────────────────────────────────────────────────────
// ZEX Assistant — proxies the in-game GUI to the Claude Messages API.
//
// Architecture:
//   ZEX (Lua, executor)  --request()-->  /api/ai-chat  --SDK-->  Claude
//                        <--reply-------               <--------
//
// Key handling: a public executor script must never embed a billable API key.
// The user supplies their OWN Anthropic key in ZEX Settings; the Lua sends it as
// the `X-Anthropic-Key` header. We use it only for that single request and never
// store it. `ANTHROPIC_API_KEY` (Vercel env) is the fallback for private deploys.
// ─────────────────────────────────────────────────────────────────────────────

const MODEL = 'claude-opus-4-8'
const MAX_BODY_SIZE = 96 * 1024 // 96 KB
const MAX_HISTORY = 16
const MAX_MSG_CHARS = 4000

type ChatMsg = { role: 'user' | 'assistant'; content: string }
type CmdInfo = { name: string; desc: string; category: string }

function parseBody(req: any): any {
  if (!req.body) return {}
  if (Buffer.isBuffer(req.body)) return JSON.parse(req.body.toString('utf-8'))
  if (typeof req.body === 'string') return JSON.parse(req.body)
  return req.body
}

function bodySize(req: any): number {
  if (!req.body) return 0
  if (Buffer.isBuffer(req.body)) return req.body.length
  if (typeof req.body === 'string') return req.body.length
  return JSON.stringify(req.body).length
}

function buildSystem(commands: CmdInfo[]): string {
  const list = commands
    .slice(0, 80)
    .filter((c) => c && typeof c.name === 'string')
    .map((c) => `;${c.name} — ${c.desc ?? ''} [${c.category ?? ''}]`)
    .join('\n')
  return [
    'You are ZEX Assistant, an AI helper embedded inside the ZEX Roblox executor GUI.',
    'You help the user understand and control their Roblox session using ZEX commands.',
    'Be concise — this is an in-game chat window. Reply in the same language the user writes in.',
    'When you recommend an action the user can run, put each command on its OWN line prefixed',
    'with "» " and nothing else on that line, e.g.\n» fly 200\n» esp',
    'Only suggest commands that appear in the list below. Never invent commands.',
    'You cannot execute anything yourself — the GUI runs commands locally when the user clicks Run.',
    'Never reveal or ask for API keys, tokens, passwords, or backend internals.',
    '',
    'Available ZEX commands:',
    list || '(command list not provided)',
  ].join('\n')
}

export default async function handler(req: any, res: any) {
  res.set(getCorsHeaders('public'))
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Webhook-Secret, X-Anthropic-Key')

  if (req.method === 'OPTIONS') return res.status(204).end()
  if (req.method !== 'POST') return apiError(res, 405, 'METHOD_NOT_ALLOWED')

  const userKey = String(req.headers?.['x-anthropic-key'] ?? '').trim()
  const apiKey = userKey || process.env.ANTHROPIC_API_KEY
  if (!apiKey) return apiError(res, 400, 'NO_API_KEY')

  try {
    if (bodySize(req) > MAX_BODY_SIZE) return apiError(res, 413, 'PAYLOAD_TOO_LARGE')

    let body: any
    try {
      body = parseBody(req)
    } catch {
      return apiError(res, 400, 'INVALID_JSON')
    }

    const rawHistory: ChatMsg[] = Array.isArray(body?.messages) ? body.messages : []
    const commands: CmdInfo[] = Array.isArray(body?.commands) ? body.commands : []
    const context = body?.context && typeof body.context === 'object' ? body.context : null

    const messages: Anthropic.MessageParam[] = rawHistory
      .filter(
        (m) =>
          m &&
          (m.role === 'user' || m.role === 'assistant') &&
          typeof m.content === 'string' &&
          m.content.length > 0,
      )
      .slice(-MAX_HISTORY)
      .map((m) => ({ role: m.role, content: m.content.slice(0, MAX_MSG_CHARS) }))

    if (messages.length === 0 || messages[0].role !== 'user') {
      return apiError(res, 400, 'INVALID_CONVERSATION')
    }

    // Inject the live game snapshot into the most recent user turn (volatile → not cached).
    if (context) {
      for (let i = messages.length - 1; i >= 0; i--) {
        if (messages[i].role === 'user') {
          const ctx = JSON.stringify(context).slice(0, MAX_MSG_CHARS)
          messages[i] = { role: 'user', content: `${messages[i].content}\n\n[live game context]\n${ctx}` }
          break
        }
      }
    }

    const client = new Anthropic({ apiKey })
    const response = await client.messages.create({
      model: MODEL,
      max_tokens: 2048,
      thinking: { type: 'adaptive' },
      output_config: { effort: 'low' },
      // System (persona + command list) is stable → cache it to cut cost on follow-ups.
      system: [{ type: 'text', text: buildSystem(commands), cache_control: { type: 'ephemeral' } }],
      messages,
    })

    if (response.stop_reason === 'refusal') {
      return apiSuccess(res, { reply: 'I can’t help with that request.', refused: true })
    }

    let reply = ''
    for (const block of response.content) {
      if (block.type === 'text') reply += block.text
    }
    reply = reply.trim() || '(no response)'

    return apiSuccess(res, {
      reply,
      model: MODEL,
      usage: { input: response.usage.input_tokens, output: response.usage.output_tokens },
    })
  } catch (error) {
    if (error instanceof Anthropic.AuthenticationError) return apiError(res, 502, 'AI_AUTH_FAILED', error)
    if (error instanceof Anthropic.RateLimitError) return apiError(res, 429, 'AI_RATE_LIMITED', error)
    if (error instanceof Anthropic.APIError) return apiError(res, 502, 'AI_UPSTREAM_ERROR', error as Error)
    return apiError(res, 500, 'AI_INTERNAL_ERROR', error as Error)
  }
}
