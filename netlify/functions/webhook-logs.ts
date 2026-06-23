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

  if (event.httpMethod !== 'GET' && event.httpMethod !== 'DELETE') {
    return jsonResponse(405, { error: 'Method not allowed' })
  }

  try {
    const supabase = getSupabase()
    const authHeader = event.headers.authorization || ''
    const user = await getUserFromJWT(supabase, authHeader)
    if (!user) {
      return jsonResponse(401, { error: 'Unauthorized' })
    }

    const webhookId = event.queryStringParameters?.webhookId || ''
    if (!webhookId) {
      return jsonResponse(400, { error: 'Missing webhookId' })
    }

    const { data: webhook, error: ownerError } = await supabase
      .from('webhooks')
      .select('id')
      .eq('id', webhookId)
      .eq('user_id', user.id)
      .single()

    if (ownerError || !webhook) {
      return jsonResponse(404, { error: 'Webhook not found' })
    }

    if (event.httpMethod === 'DELETE') {
      const body = event.body ? JSON.parse(event.body) : {}
      const logIds = body.logIds || []
      const deleteAll = body.deleteAll === true

      if (deleteAll) {
        const { error: delError } = await supabase
          .from('webhook_logs')
          .delete()
          .eq('webhook_id', webhookId)
        if (delError) {
          return jsonResponse(500, { error: 'Failed to delete logs', details: delError.message })
        }
        return jsonResponse(200, { success: true, deleted: 'all' })
      }

      if (logIds.length === 0) {
        return jsonResponse(400, { error: 'No logIds provided' })
      }

      const { error: delError } = await supabase
        .from('webhook_logs')
        .delete()
        .in('id', logIds)
        .eq('webhook_id', webhookId)
      if (delError) {
        return jsonResponse(500, { error: 'Failed to delete logs', details: delError.message })
      }
      return jsonResponse(200, { success: true, deleted: logIds.length })
    }

    const { data: logs, error } = await supabase
      .from('webhook_logs')
      .select('*')
      .eq('webhook_id', webhookId)
      .order('created_at', { ascending: false })
      .limit(200)

    if (error) {
      return jsonResponse(500, { error: 'Failed to fetch logs', details: error.message })
    }

    return jsonResponse(200, { logs: logs || [] })
  } catch (err) {
    return jsonResponse(500, { error: 'Internal error', details: (err as Error).message })
  }
}
