import { createClient, SupabaseClient } from '@supabase/supabase-js'

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

export default async function handler(req: any, res: any) {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders())
    return res.status(204).end()
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' })
  }

  try {
    const supabase = getSupabase()
    const authHeader = req.headers.authorization || ''
    const user = await getUserFromJWT(supabase, authHeader)
    if (!user) {
      return res.status(401).json({ error: 'Unauthorized' })
    }

    const body = req.body || {}
    const name = (body.name as string) || ''
    if (!name || name.trim().length === 0) {
      return res.status(400).json({ error: 'Name is required' })
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
      return res.status(500).json({ error: 'Failed to create webhook', details: error.message })
    }

    return res.status(201).json({ webhook })
  } catch (err) {
    return res.status(500).json({ error: 'Internal error', details: (err as Error).message })
  }
}
