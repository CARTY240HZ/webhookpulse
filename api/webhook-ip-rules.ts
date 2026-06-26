import { getSupabase } from './_lib/supabase.js'
import { getCorsHeaders, setCorsHeaders } from './_lib/cors.js'
import { requireAuth } from './_lib/auth.js'
import { apiError, apiSuccess } from './_lib/errors.js'
import { isValidIpOrCidr } from './_lib/ipfilter.js'

export default async function handler(req: any, res: any) {
  setCorsHeaders(res, 'private', req.headers.origin)

  if (req.method === 'OPTIONS') {
    return res.status(204).end()
  }

  if (!['GET', 'POST', 'DELETE'].includes(req.method)) {
    return apiError(res, 405, 'METHOD_NOT_ALLOWED')
  }

  const user = await requireAuth(req, res)
  if (!user) return

  const supabase = getSupabase()

  try {
    if (req.method === 'GET') {
      const webhookId = String(req.query?.webhookId || '')
      if (!webhookId) {
        return apiError(res, 400, 'WEBHOOK_ID_REQUIRED')
      }

      // Verify ownership
      const { data: webhook, error: webhookError } = await supabase
        .from('webhooks')
        .select('id')
        .eq('id', webhookId)
        .eq('user_id', user.id)
        .single()

      if (webhookError || !webhook) {
        return apiError(res, 403, 'FORBIDDEN')
      }

      const { data: rules, error } = await supabase
        .from('ip_rules')
        .select('id, webhook_id, ip, action, description, created_at')
        .eq('webhook_id', webhookId)
        .order('created_at', { ascending: false })

      if (error) {
        return apiError(res, 500, 'DB_ERROR')
      }

      return apiSuccess(res, { rules: rules || [] })
    }

    if (req.method === 'POST') {
      const { webhookId, ip, action, description } = req.body || {}

      if (!webhookId || !ip || !action) {
        return apiError(res, 400, 'MISSING_FIELDS')
      }

      if (!['allow', 'block'].includes(action)) {
        return apiError(res, 400, 'INVALID_ACTION')
      }

      if (!isValidIpOrCidr(ip)) {
        return apiError(res, 400, 'INVALID_IP')
      }

      // Verify ownership
      const { data: webhook, error: webhookError } = await supabase
        .from('webhooks')
        .select('id')
        .eq('id', webhookId)
        .eq('user_id', user.id)
        .single()

      if (webhookError || !webhook) {
        return apiError(res, 403, 'FORBIDDEN')
      }

      const { data: rule, error } = await supabase
        .from('ip_rules')
        .insert({
          webhook_id: webhookId,
          ip: ip.trim(),
          action,
          description: description ? String(description).trim() : null,
        })
        .select('id, webhook_id, ip, action, description, created_at')
        .single()

      if (error) {
        return apiError(res, 500, 'DB_ERROR')
      }

      return res.status(201).json({ rule })
    }

    if (req.method === 'DELETE') {
      const { ruleId } = req.body || {}

      if (!ruleId) {
        return apiError(res, 400, 'RULE_ID_REQUIRED')
      }

      // Get rule to verify webhook ownership
      const { data: rule, error: ruleError } = await supabase
        .from('ip_rules')
        .select('webhook_id')
        .eq('id', ruleId)
        .single()

      if (ruleError || !rule) {
        return apiError(res, 404, 'NOT_FOUND')
      }

      // Verify ownership
      const { data: webhook, error: webhookError } = await supabase
        .from('webhooks')
        .select('id')
        .eq('id', rule.webhook_id)
        .eq('user_id', user.id)
        .single()

      if (webhookError || !webhook) {
        return apiError(res, 403, 'FORBIDDEN')
      }

      const { error } = await supabase
        .from('ip_rules')
        .delete()
        .eq('id', ruleId)

      if (error) {
        return apiError(res, 500, 'DB_ERROR')
      }

      return apiSuccess(res, { success: true })
    }
  } catch (err) {
    return apiError(res, 500, 'INTERNAL_ERROR', err)
  }
}
