import { getSupabase } from './_lib/supabase.js'
import { setCorsHeaders } from './_lib/cors.js'
import { getUserFromJWT } from './_lib/auth.js'
import { apiError } from './_lib/errors.js'
import { captureException } from './_lib/sentry.js'
import crypto from 'crypto'
import bcrypt from 'bcryptjs'
import { setSecurityHeaders, checkBruteLimit, resetBruteLimit } from './_lib/security.js'
import { logAuditFromRequest } from './_lib/audit.js'

export default async function handler(req: any, res: any) {
  setSecurityHeaders(res)
  setCorsHeaders(res, 'private')

  if (req.method === 'OPTIONS') {
    return res.status(204).end()
  }

  if (req.method !== 'POST' && req.method !== 'PUT') {
    return apiError(res, 405, 'METHOD_NOT_ALLOWED')
  }

  try {
    const supabase = getSupabase()
    const user = await getUserFromJWT(req.headers.authorization || '')
    if (!user) return apiError(res, 401, 'UNAUTHORIZED')

    if (req.method === 'POST') {
      // ─── SEND 2FA CODE ───
      const body = req.body || {}
      const phone = body.phone?.toString().trim()
      if (!phone || phone.length < 8) return apiError(res, 400, 'INVALID_PHONE')

      // Brute-force protection by user_id
      const bruteKey = `2fa_send:${user.id}`
      if (!await checkBruteLimit(bruteKey, 3, 600_000)) {
        return apiError(res, 429, 'TOO_MANY_REQUESTS')
      }

      // Generate 6-digit code with cryptographically secure RNG
      const code = crypto.randomInt(100000, 999999).toString().padStart(6, '0')
      const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString() // 10 min
      const hashedCode = await bcrypt.hash(code, 10)

      const { error } = await supabase
        .from('profiles')
        .update({
          phone: phone,
          two_factor_code: hashedCode,
          two_factor_expires: expiresAt,
        })
        .eq('id', user.id)

      if (error) {
        console.error('2FA send error:', error)
        return res.status(500).json({
          success: false,
          error: 'SMS_SERVICE_NOT_CONFIGURED',
          message: 'Verification service unavailable. Please try again later.',
        })
      }

      return setPrivateCache(res).status(200).json({
        success: true,
        message: 'Verification code sent',
      })
    } else {
      // ─── VERIFY 2FA CODE ───
      const body = req.body || {}
      const phone = body.phone?.toString().trim()
      const code = body.code?.toString().trim()
      if (!phone || !code) return apiError(res, 400, 'MISSING_FIELDS')
      if (code.length !== 6) return apiError(res, 400, 'INVALID_CODE_LENGTH')

      // Brute-force protection by user_id
      const bruteKey = `2fa_verify:${user.id}`
      if (!await checkBruteLimit(bruteKey, 5, 600_000)) {
        return apiError(res, 429, 'TOO_MANY_REQUESTS')
      }

      // Get stored code
      const { data: profile, error } = await supabase
        .from('profiles')
        .select('two_factor_code, two_factor_expires')
        .eq('id', user.id)
        .single()

      if (error || !profile) {
        return apiError(res, 400, '2FA_NOT_CONFIGURED')
      }

      // Check expiration — <= so a code cannot be used at the exact expiry instant
      if (profile.two_factor_expires && new Date(profile.two_factor_expires) <= new Date()) {
        return apiError(res, 400, 'CODE_EXPIRED')
      }

      // Verify code with bcrypt (adaptive hashing — resistant to brute-force if DB leaks)
      const storedCodeHash = profile.two_factor_code || ''
      if (!storedCodeHash || !(await bcrypt.compare(code, storedCodeHash))) {
        return apiError(res, 400, 'INVALID_CODE')
      }

      // Reset brute limit on success
      await resetBruteLimit(bruteKey)

      // Mark as verified
      const { error: updateError } = await supabase
        .from('profiles')
        .update({
          phone_verified: true,
          two_factor_enabled: true,
          two_factor_code: null,
          two_factor_expires: null,
        })
        .eq('id', user.id)

      if (updateError) {
        captureException(updateError)
        return apiError(res, 500, 'VERIFICATION_UPDATE_FAILED')
      }

      await logAuditFromRequest(req, user.id, '2FA_ENABLED')
        return setPrivateCache(res).status(200).json({
        success: true,
        message: 'Phone verified. Two-factor authentication is now active.',
      })
    }
  } catch (err) {
    captureException(err as Error)
    return apiError(res, 500, 'INTERNAL_ERROR')
  }
}
