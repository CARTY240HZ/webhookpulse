import { createClient } from '@supabase/supabase-js'
import { isSupabaseConfigured } from './config'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || ''
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || ''

export const supabase = isSupabaseConfigured
  ? createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        persistSession: true,
        storageKey: 'webhookpulse-auth',
        storage: typeof window !== 'undefined' ? localStorage : undefined,
        autoRefreshToken: true,
        detectSessionInUrl: true,
      },
    })
  : null as unknown as ReturnType<typeof createClient>

export function getSupabase() {
  if (!supabase || !isSupabaseConfigured) {
    throw new Error(
      'Supabase is not configured. Please set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY environment variables.'
    )
  }
  return supabase
}

export { configError } from './config'
export { isSupabaseConfigured } from './config'
