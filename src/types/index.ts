export interface WebhookTemplate {
  id: string
  title: string
  description: string
  icon: string
  previewPayload: Record<string, unknown>
}

export interface Profile {
  id: string
  full_name?: string
  avatar_url?: string
  phone?: string
  location?: string
  theme?: string
  notifications_enabled?: boolean
  language?: string
  created_at: string
  updated_at: string
  email?: string
  phone_verified?: boolean
  two_factor_enabled?: boolean
}

export interface AccountSettings {
  email: string
  full_name: string
  phone: string
  location: string
  theme: string
  notifications_enabled: boolean
  language: string
  created_at: string
  updated_at: string
  phone_verified?: boolean
  two_factor_enabled?: boolean
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
  has_secret?: boolean
  discord_url?: string | null
  native_url?: string
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
