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

export default async function handler(req: any, res: any) {
  if (req.method === 'OPTIONS') {
    res.set(corsHeaders())
    return res.status(204).end()
  }

  if (req.method !== 'DELETE') {
    return res.status(405).json({ error: 'Method not allowed' })
  }

  try {
    const supabase = getSupabase()
    const authHeader = req.headers.authorization || ''
    const user = await getUserFromJWT(supabase, authHeader)
    if (!user) {
      return res.status(401).json({ error: 'Unauthorized' })
    }

    const id = req.query?.id || ''
    if (!id) {
      return res.status(400).json({ error: 'Missing id' })
    }

    const { data: webhook, error: findError } = await supabase
      .from('webhooks')
      .select('id')
      .eq('id', id)
      .eq('user_id', user.id)
      .single()

    if (findError || !webhook) {
      return res.status(404).json({ error: 'Webhook not found' })
    }

    const { error: deleteError } = await supabase.from('webhooks').delete().eq('id', id)

    if (deleteError) {
      return res.status(500).json({ error: 'Failed to delete webhook', details: deleteError.message })
    }

    return res.status(200).json({ success: true })
  } catch (err) {
    return res.status(500).json({ error: 'Internal error', details: (err as Error).message })
  }
}
