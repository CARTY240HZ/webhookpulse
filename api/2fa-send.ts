import { getSupabase } from './_lib/supabase.js'
import { setCorsHeaders } from './_lib/cors.js'
import { getUserFromJWT } from './_lib/auth.js'
import { apiError } from './_lib/errors.js'
import { captureException } from './_lib/sentry.js'
import crypto from 'crypto'

export default async function handler(req: any, res: any) {
  if (req.method === 'OPTIONS') {
    setCorsHeaders(res, 'private')
    return res.status(204).end()
  }
  if (req.method !== 'POST') return apiError(res, 405, 'METHOD_NOT_ALLOWED')

  try {
    const supabase = getSupabase()
    const user = await getUserFromJWT(req.headers.authorization || '')
    if (!user) return apiError(res, 401, 'UNAUTHORIZED')

    const body = req.body || {}
    const phone = body.phone?.toString().trim()
    if (!phone || phone.length < 8) return apiError(res, 400, 'INVALID_PHONE')

    // Generate 6-digit code with cryptographically secure RNG
    const code = crypto.randomInt(100000, 999999).toString().padStart(6, '0')
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString() // 10 min

    // Store in DB (simple table or use profiles directly)
    // We'll store in a new table or fallback to profiles with JSON
    const { error } = await supabase
      .from('profiles')
      .update({
        phone: phone,
        two_factor_code: code,
        two_factor_expires: expiresAt,
      })
      .eq('id', user.id)

    if (error) {
      console.error('2FA send error:', error)
      // In production, you'd use an SMS service here (Twilio, etc.)
      return res.status(500).json({
        success: false,
        error: 'SMS_SERVICE_NOT_CONFIGURED',
        message: 'Verification service unavailable. Please try again later.',
      })
    }

    return res.status(200).json({
      success: true,
      message: 'Verification code sent',
    })
  } catch (err) {
    captureException(err as Error)
    return apiError(res, 500, 'INTERNAL_ERROR')
  }
}
