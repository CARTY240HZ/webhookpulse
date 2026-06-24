import { getSupabase } from './_lib/supabase.js'
import { getCorsHeaders, setCorsHeaders } from './_lib/cors.js'
import { getUserFromJWT } from './_lib/auth.js'
import { isValidUUID } from './_lib/validate.js'
import { apiError } from './_lib/errors.js'
import { captureException } from './_lib/sentry.js'

const MAX_EXPORT_ROWS = 10_000

function escapeCsvCell(value: string): string {
  if (value.includes('"') || value.includes(',') || value.includes('\n') || value.includes('\r')) {
    return '"' + value.replace(/"/g, '""') + '"'
  }
  return value
}

export default async function handler(req: any, res: any) {
  if (req.method === 'OPTIONS') {
    setCorsHeaders(res, 'private')
    return res.status(204).end()
  }

  if (req.method !== 'GET') {
    return apiError(res, 405, 'METHOD_NOT_ALLOWED')
  }

  try {
    const supabase = getSupabase()
    const authHeader = req.headers.authorization || ''
    const user = await getUserFromJWT(authHeader)
    if (!user) {
      return apiError(res, 401, 'UNAUTHORIZED')
    }

    const webhookId = req.query?.webhookId || ''
    if (!webhookId || !isValidUUID(String(webhookId))) {
      return apiError(res, 400, 'INVALID_WEBHOOK_ID')
    }

    const { data: webhook, error: ownerError } = await supabase
      .from('webhooks')
      .select('id')
      .eq('id', webhookId)
      .eq('user_id', user.id)
      .single()

    if (ownerError || !webhook) {
      return apiError(res, 404, 'WEBHOOK_NOT_FOUND')
    }

    // S7: Cap at 10,000 rows
    const { data: logs, error, count } = await supabase
      .from('webhook_logs')
      .select('id, created_at, ip_address, payload', { count: 'exact' })
      .eq('webhook_id', webhookId)
      .order('created_at', { ascending: false })
      .limit(MAX_EXPORT_ROWS)

    if (error) {
      captureException(error)
      return apiError(res, 500, 'LOGS_EXPORT_FAILED')
    }

    const rows = logs || []
    const headers = ['id', 'created_at', 'source_ip', 'payload_json']
    const csvRows = [headers.join(',')]

    for (const row of rows) {
      const payloadStr = row.payload ? JSON.stringify(row.payload) : ''
      csvRows.push(
        [
          escapeCsvCell(String(row.id)),
          escapeCsvCell(row.created_at ? new Date(row.created_at).toISOString() : ''),
          escapeCsvCell(row.ip_address || ''),
          escapeCsvCell(payloadStr),
        ].join(',')
      )
    }

    const csv = csvRows.join('\r\n')
    const truncated = (count || 0) > MAX_EXPORT_ROWS

    setCorsHeaders(res, 'private')
    res.setHeader('Content-Type', 'text/csv; charset=utf-8')
    res.setHeader('Content-Disposition', `attachment; filename="webhook-logs-${webhookId}.csv"`)
    if (truncated) res.setHeader('X-Truncated', 'true')

    return res.status(200).send(csv)
  } catch (err) {
    captureException(err as Error)
    return apiError(res, 500, 'INTERNAL_ERROR')
  }
}
