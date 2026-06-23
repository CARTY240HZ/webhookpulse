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

function generateSlug(name: string): string {
  const base = name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
  const rand = Math.random().toString(36).substring(2, 8)
  return `${base}-${rand}`
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
    const authHeader = event.headers.authorization || ''
    const user = await getUserFromJWT(supabase, authHeader)
    if (!user) {
      return jsonResponse(401, { error: 'Unauthorized' })
    }

    let body: Record<string, unknown> = {}
    try {
      body = event.body ? JSON.parse(event.body) : {}
    } catch {
      return jsonResponse(400, { error: 'Invalid JSON body' })
    }

    const name = (body.name as string) || ''
    if (!name || name.trim().length === 0) {
      return jsonResponse(400, { error: 'Name is required' })
    }

    const urlPath = generateSlug(name)

    const { data: webhook, error } = await supabase
      .from('webhooks')
      .insert({
        user_id: user.id,
        name: name.trim(),
        description: (body.description as string) || null,
        url_path: urlPath,
        secret: (body.secret as string) || null,
      })
      .select('*')
      .single()

    if (error) {
      return jsonResponse(500, { error: 'Failed to create webhook', details: error.message })
    }

    return jsonResponse(201, { webhook })
  } catch (err) {
    return jsonResponse(500, { error: 'Internal error', details: (err as Error).message })
  }
}
