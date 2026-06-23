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
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
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

async function getUserFromJWT(supabase: SupabaseClient, authHeader: string) {
  const token = authHeader.replace('Bearer ', '').trim()
  if (!token) return null
  const { data, error } = await supabase.auth.getUser(token)
  if (error || !data.user) return null
  return data.user
}

export const handler: Handler = async (event: HandlerEvent, _context: HandlerContext) => {
  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 204, headers: corsHeaders() }
  }

  if (event.httpMethod !== 'GET') {
    return jsonResponse(405, { error: 'Method not allowed' })
  }

  try {
    const supabase = getSupabase()
    const authHeader = event.headers.authorization || ''
    const user = await getUserFromJWT(supabase, authHeader)
    if (!user) {
      return jsonResponse(401, { error: 'Unauthorized' })
    }

    const { data: webhooks, error } = await supabase
      .from('webhooks')
      .select('*, webhook_logs(count)')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })

    if (error) {
      return jsonResponse(500, { error: 'Failed to fetch webhooks', details: error.message })
    }

    const enriched = (webhooks || []).map((w: Record<string, unknown>) => ({
      ...w,
      log_count: (w.webhook_logs as { count: number }[])?.[0]?.count ?? 0,
    }))

    return jsonResponse(200, { webhooks: enriched })
  } catch (err) {
    return jsonResponse(500, { error: 'Internal error', details: (err as Error).message })
  }
}
