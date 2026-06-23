import { createClient, SupabaseClient } from '@supabase/supabase-js'
import type { Handler, HandlerEvent, HandlerContext } from '@netlify/functions'

const supabaseUrl = process.env.SUPABASE_URL || ''
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY || ''

function getSupabase(): SupabaseClient {
  if (!supabaseUrl || !supabaseServiceKey) {
    throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_KEY')
  }
  return createClient(supabaseUrl, supabaseServiceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })
}

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Webhook-Secret',
    'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  }
}

function jsonResponse(statusCode: number, body: unknown) {
  return {
    statusCode,
    headers: { 'Content-Type': 'application/json', ...corsHeaders() },
    body: JSON.stringify(body),
  }
}

export const handler: Handler = async (event: HandlerEvent, _context: HandlerContext) => {
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 204, headers: corsHeaders() }
  }

  if (event.httpMethod !== 'POST') {
    return jsonResponse(405, { error: 'Method not allowed' })
  }

  try {
    const supabase = getSupabase()
    const path = event.queryStringParameters?.path || ''
    if (!path) {
      return jsonResponse(400, { error: 'Missing path parameter' })
    }

    const { data: webhook, error: findError } = await supabase
      .from('webhooks')
      .select('id, secret, is_active, user_id')
      .eq('url_path', path)
      .single()

    if (findError || !webhook) {
      return jsonResponse(404, { error: 'Webhook not found' })
    }

    if (!webhook.is_active) {
      return jsonResponse(403, { error: 'Webhook is inactive' })
    }

    const providedSecret = event.headers['x-webhook-secret'] || ''
    if (webhook.secret && providedSecret !== webhook.secret) {
      return jsonResponse(401, { error: 'Invalid secret' })
    }

    let payload: unknown = null
    try {
      payload = event.body ? JSON.parse(event.body) : null
    } catch {
      payload = event.body
    }

    const rawIp = event.headers['x-forwarded-for'] || event.headers['client-ip'] || null
    const ipAddress = rawIp ? String(rawIp).split(',')[0].trim() : null

    let insertResult = await supabase
      .from('webhook_logs')
      .insert({
        webhook_id: webhook.id,
        payload: payload ?? {},
        headers: event.headers as Record<string, string>,
        ip_address: ipAddress,
      })
      .select('id')
      .single()

    if (insertResult.error && insertResult.error.message.includes('inet')) {
      insertResult = await supabase
        .from('webhook_logs')
        .insert({
          webhook_id: webhook.id,
          payload: payload ?? {},
          headers: event.headers as Record<string, string>,
          ip_address: null,
        })
        .select('id')
        .single()
    }

    if (insertResult.error) {
      return jsonResponse(500, { error: 'Failed to store log', details: insertResult.error.message })
    }

    return jsonResponse(200, { success: true, logId: insertResult.data.id })
  } catch (err) {
    return jsonResponse(500, { error: 'Internal error', details: (err as Error).message })
  }
}
