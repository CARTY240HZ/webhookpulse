export interface Profile {
  id: string
  full_name?: string
  avatar_url?: string
  created_at: string
}

export interface Webhook {
  id: string
  user_id: string
  name: string
  description?: string
  url_path: string
  secret?: string
  is_active: boolean
  created_at: string
  updated_at: string
  log_count?: number
}

export interface WebhookLog {
  id: string
  webhook_id: string
  payload: Record<string, unknown>
  headers?: Record<string, string>
  ip_address?: string
  created_at: string
}

export interface AuthState {
  user: { id: string; email?: string } | null
  profile: Profile | null
  loading: boolean
}
