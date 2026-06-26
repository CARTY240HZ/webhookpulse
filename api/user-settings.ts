import { getSupabase } from './_lib/supabase.js'
import { setCorsHeaders } from './_lib/cors.js'
import { getUserFromJWT } from './_lib/auth.js'
import { apiError } from './_lib/errors.js'
import { captureException } from './_lib/sentry.js'
import { createClient } from '@supabase/supabase-js'

export default async function handler(req: any, res: any) {
  if (req.method === 'OPTIONS') {
    setCorsHeaders(res, 'private', req.headers.origin)
    return res.status(204).end()
  }

  if (req.method !== 'GET' && req.method !== 'POST' && req.method !== 'DELETE') {
    return apiError(res, 405, 'METHOD_NOT_ALLOWED')
  }

  try {
    const supabase = getSupabase()
    const authHeader = req.headers.authorization || ''
    const user = await getUserFromJWT(authHeader)
    if (!user) {
      return apiError(res, 401, 'UNAUTHORIZED')
    }

    // GET: fetch profile data with fallback
    if (req.method === 'GET') {
      // Try full columns first (new schema)
      let data: any = null
      let error: any = null
      
      try {
        const result = await supabase
          .from('profiles')
          .select('full_name, avatar_url, phone, bio, location, website, theme, notifications_enabled, language, created_at, updated_at')
          .eq('id', user.id)
          .single()
        data = result.data
        error = result.error
      } catch (e) {
        // Fallback: try basic columns only (old schema)
        const result = await supabase
          .from('profiles')
          .select('full_name, avatar_url, created_at')
          .eq('id', user.id)
          .single()
        data = result.data
        error = result.error
      }

      if (error) {
        console.error('Profile fetch error:', error)
        return apiError(res, 500, 'PROFILE_FETCH_FAILED')
      }

      // Get email from auth.users (admin only, requires service_role)
      let email = ''
      try {
        const { data: userData } = await supabase.auth.admin.getUserById(user.id)
        email = userData?.user?.email || ''
      } catch (e) {
        // Fallback: email might be in the JWT payload
        email = user.email || ''
      }

      return res.status(200).json({
        full_name: data?.full_name || '',
        avatar_url: data?.avatar_url || '',
        phone: data?.phone || '',
        bio: data?.bio || '',
        location: data?.location || '',
        website: data?.website || '',
        theme: data?.theme || 'dark',
        notifications_enabled: data?.notifications_enabled ?? true,
        language: data?.language || 'en',
        created_at: data?.created_at || '',
        updated_at: data?.updated_at || '',
        email,
      })
    }

    // POST: update profile or account settings
    if (req.method === 'POST') {
      const body = req.body || {}
      const action = body.action || 'update_profile'

      if (action === 'update_profile') {
        const updates: Record<string, unknown> = {}
        const fields = ['full_name', 'phone', 'bio', 'location', 'website', 'theme', 'notifications_enabled', 'language']
        for (const field of fields) {
          if (body[field] !== undefined) {
            updates[field] = body[field]
          }
        }

        // Try update, but some columns might not exist yet
        const { error } = await supabase
          .from('profiles')
          .update(updates)
          .eq('id', user.id)

        if (error) {
          // If error is about missing column, try updating only basic fields
          const basicUpdates: Record<string, unknown> = {}
          if (body.full_name !== undefined) basicUpdates.full_name = body.full_name
          
          if (Object.keys(basicUpdates).length > 0) {
            const { error: basicError } = await supabase
              .from('profiles')
              .update(basicUpdates)
              .eq('id', user.id)
            if (basicError) {
              captureException(error)
              return apiError(res, 500, 'PROFILE_UPDATE_FAILED')
            }
            return res.status(200).json({ success: true, partial: true, message: 'Profile partially updated. Run migration 002 for full features.' })
          }
          
          captureException(error)
          return apiError(res, 500, 'PROFILE_UPDATE_FAILED')
        }
        return res.status(200).json({ success: true })
      }

      if (action === 'change_email') {
        const { current_password, new_email } = body
        if (!current_password || !new_email) {
          return apiError(res, 400, 'MISSING_FIELDS')
        }

        // Verify password
        const { data: userData } = await supabase.auth.admin.getUserById(user.id)
        const email = userData?.user?.email
        if (!email) {
          return apiError(res, 401, 'USER_EMAIL_NOT_FOUND')
        }

        const supabaseUrl = process.env.SUPABASE_URL || ''
        const supabaseAnonKey = process.env.SUPABASE_ANON_KEY || process.env.VITE_SUPABASE_ANON_KEY || ''
        const authClient = createClient(supabaseUrl, supabaseAnonKey, {
          auth: { autoRefreshToken: false, persistSession: false }
        })

        const { error: signInError } = await authClient.auth.signInWithPassword({
          email,
          password: current_password,
        })

        if (signInError) {
          return apiError(res, 401, 'INVALID_PASSWORD')
        }

        // Update email
        const { error: updateError } = await supabase.auth.admin.updateUserById(user.id, {
          email: new_email,
        })

        if (updateError) {
          captureException(updateError)
          return apiError(res, 500, 'EMAIL_UPDATE_FAILED')
        }

        return res.status(200).json({ success: true, message: 'Email updated. Check your inbox for verification.' })
      }

      if (action === 'change_password') {
        const { current_password, new_password } = body
        if (!current_password || !new_password) {
          return apiError(res, 400, 'MISSING_FIELDS')
        }
        if (new_password.length < 8) {
          return apiError(res, 400, 'PASSWORD_TOO_SHORT')
        }

        // Verify current password
        const { data: userData } = await supabase.auth.admin.getUserById(user.id)
        const email = userData?.user?.email
        if (!email) {
          return apiError(res, 401, 'USER_EMAIL_NOT_FOUND')
        }

        const supabaseUrl = process.env.SUPABASE_URL || ''
        const supabaseAnonKey = process.env.SUPABASE_ANON_KEY || process.env.VITE_SUPABASE_ANON_KEY || ''
        const authClient = createClient(supabaseUrl, supabaseAnonKey, {
          auth: { autoRefreshToken: false, persistSession: false }
        })

        const { error: signInError } = await authClient.auth.signInWithPassword({
          email,
          password: current_password,
        })

        if (signInError) {
          return apiError(res, 401, 'INVALID_PASSWORD')
        }

        // Update password
        const { error: updateError } = await supabase.auth.admin.updateUserById(user.id, {
          password: new_password,
        })

        if (updateError) {
          captureException(updateError)
          return apiError(res, 500, 'PASSWORD_UPDATE_FAILED')
        }

        return res.status(200).json({ success: true, message: 'Password updated successfully.' })
      }

      return apiError(res, 400, 'INVALID_ACTION')
    }

    // DELETE: delete account
    if (req.method === 'DELETE') {
      const { password } = req.body || {}
      if (!password) {
        return apiError(res, 400, 'PASSWORD_REQUIRED')
      }

      // Verify password
      const { data: userData } = await supabase.auth.admin.getUserById(user.id)
      const email = userData?.user?.email
      if (!email) {
        return apiError(res, 401, 'USER_EMAIL_NOT_FOUND')
      }

      const supabaseUrl = process.env.SUPABASE_URL || ''
      const supabaseAnonKey = process.env.SUPABASE_ANON_KEY || process.env.VITE_SUPABASE_ANON_KEY || ''
      const authClient = createClient(supabaseUrl, supabaseAnonKey, {
        auth: { autoRefreshToken: false, persistSession: false }
      })

      const { error: signInError } = await authClient.auth.signInWithPassword({
        email,
        password,
      })

      if (signInError) {
        return apiError(res, 401, 'INVALID_PASSWORD')
      }

      // Delete user (cascades to profiles/webhooks/logs via FK)
      const { error: deleteError } = await supabase.auth.admin.deleteUser(user.id)
      if (deleteError) {
        captureException(deleteError)
        return apiError(res, 500, 'ACCOUNT_DELETE_FAILED')
      }

      return res.status(200).json({ success: true, message: 'Account deleted permanently.' })
    }

  } catch (err) {
    captureException(err as Error)
    return apiError(res, 500, 'INTERNAL_ERROR')
  }
}
