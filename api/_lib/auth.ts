import type { SupabaseClient } from '@supabase/supabase-js'
import { getSupabase } from './supabase'
import { setUserContext } from './sentry'

export async function getUserFromJWT(authHeader: string): Promise<{ id: string } | null> {
  const token = authHeader.replace('Bearer ', '').trim()
  if (!token) return null

  const supabase = getSupabase()
  const { data, error } = await supabase.auth.getUser(token)
  if (error || !data.user) return null

  setUserContext(data.user.id)
  return { id: data.user.id }
}

export async function requireAuth(req: any, res: any): Promise<{ id: string } | null> {
  const authHeader = req.headers.authorization || ''
  const user = await getUserFromJWT(authHeader)
  if (!user) {
    res.status(401).json({ error: 'UNAUTHORIZED' })
    return null
  }
  return user
}
