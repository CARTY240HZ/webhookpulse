import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || ''
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || ''

const isConfigured = supabaseUrl.length > 0 && supabaseAnonKey.length > 0

export const supabase = isConfigured
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
  if (!supabase || !isConfigured) {
    throw new Error(
      'Supabase is not configured. Please set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY environment variables.'
    )
  }
  return supabase
}

export const configError = isConfigured
  ? null
  : 'Missing Supabase configuration. Please set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY in your environment variables.'
