import { getSupabase } from './supabase.js'

export interface AuditEntry {
  user_id: string
  action: string
  ip_address?: string
  user_agent?: string
  metadata?: Record<string, unknown>
}

export async function logAudit(entry: AuditEntry): Promise<void> {
  const supabase = getSupabase()
  try {
    await supabase.from('audit_logs').insert({
      user_id: entry.user_id,
      action: entry.action,
      ip_address: entry.ip_address || null,
      user_agent: entry.user_agent || null,
      metadata: entry.metadata || null,
      created_at: new Date().toISOString(),
    })
  } catch (err) {
    // Never crash the request because of audit logging
    console.error('[AUDIT] Failed to log:', err)
  }
}

export async function logAuditFromRequest(
  req: any,
  userId: string,
  action: string,
  metadata?: Record<string, unknown>
): Promise<void> {
  const ip =
    req.headers['x-vercel-forwarded-for'] ||
    req.headers['x-vercel-ip'] ||
    null
  const userAgent = req.headers['user-agent'] || null
  await logAudit({
    user_id: userId,
    action,
    ip_address: ip ? String(ip).split(',')[0].trim() : null,
    user_agent: userAgent ? String(userAgent) : null,
    metadata,
  })
}
