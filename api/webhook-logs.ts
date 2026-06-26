import { getSupabase } from './_lib/supabase.js'
import { setCorsHeaders } from './_lib/cors.js'
import { getUserFromJWT } from './_lib/auth.js'
import { isValidUUID } from './_lib/validate.js'
import { apiError, apiSuccess } from './_lib/errors.js'
import { captureException } from './_lib/sentry.js'

const MAX_EXPORT_ROWS = 10_000

function escapeCsvCell(value: string): string {
  // Prevent CSV injection: prefix formulas that Excel/LibreOffice would execute
  const dangerous = /^[\=\+\-\@\%\t]/
  let sanitized = value
  if (dangerous.test(value)) {
    sanitized = "'" + value
  }
  // Escape quotes and wrap if contains special chars
  if (sanitized.includes('"') || sanitized.includes(',') || sanitized.includes('\n') || sanitized.includes('\r')) {
    return '"' + sanitized.replace(/"/g, '""') + '"'
  }
  return sanitized
}

export default async function handler(req: any, res: any) {
  if (req.method === 'OPTIONS') {
    setCorsHeaders(res, 'private', req.headers.origin)
    return res.status(204).end()
  }

  setCorsHeaders(res, 'private', req.headers.origin)

  if (req.method !== 'GET' && req.method !== 'DELETE') {
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

    // Verify ownership and retrieve webhook type info for type filtering
    const { data: webhook, error: ownerError } = await supabase
      .from('webhooks')
      .select('id, has_secret, discord_url')
      .eq('id', webhookId)
      .eq('user_id', user.id)
      .single()

    if (ownerError || !webhook) {
      return apiError(res, 404, 'WEBHOOK_NOT_FOUND')
    }

    if (req.method === 'DELETE') {
      const body = req.body || {}
      const logIds = body.logIds || []
      const deleteAll = body.deleteAll === true

      if (deleteAll) {
        const { error: delError } = await supabase
          .from('webhook_logs')
          .delete()
          .eq('webhook_id', webhookId)
        if (delError) {
          captureException(delError)
          return apiError(res, 500, 'LOGS_DELETE_FAILED')
        }
        return res.status(200).json({ success: true, deleted: 'all' })
      }

      if (logIds.length === 0) {
        return apiError(res, 400, 'NO_LOG_IDS')
      }

      const { error: delError } = await supabase
        .from('webhook_logs')
        .delete()
        .in('id', logIds)
        .eq('webhook_id', webhookId)
      if (delError) {
        captureException(delError)
        return apiError(res, 500, 'LOGS_DELETE_FAILED')
      }
      return res.status(200).json({ success: true, deleted: logIds.length })
    }

    // ─── GET: CSV EXPORT or LIST LOGS ───
    if (req.query?.format === 'csv') {
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

      res.setHeader('Content-Type', 'text/csv; charset=utf-8')
      res.setHeader('Content-Disposition', `attachment; filename="webhook-logs-${webhookId}.csv"`)
      if (truncated) res.setHeader('X-Truncated', 'true')

      return res.status(200).send(csv)
    }

    // ─── LIST LOGS ───
    // Parse query parameters for filtering
    const MAX_QUERY_LENGTH = 200
    const q = typeof req.query?.q === 'string' ? req.query.q.slice(0, MAX_QUERY_LENGTH) : undefined
    const ip = typeof req.query?.ip === 'string' ? req.query.ip : undefined
    const from = typeof req.query?.from === 'string' ? req.query.from : undefined
    const to = typeof req.query?.to === 'string' ? req.query.to : undefined
    const source = typeof req.query?.source === 'string' ? req.query.source : undefined
    const type = typeof req.query?.type === 'string' ? req.query.type : undefined

    // Type filter: since the endpoint is scoped to a single webhook,
    // verify the webhook's type matches the requested filter.
    const webhookIsDiscord = webhook.has_secret && !!webhook.discord_url
    if (type) {
      if (type === 'discord' && !webhookIsDiscord) {
        return apiSuccess(res, { logs: [], total: 0, page: 1, limit: 50, hasMore: false })
      }
      if (type === 'native' && webhookIsDiscord) {
        return apiSuccess(res, { logs: [], total: 0, page: 1, limit: 50, hasMore: false })
      }
    }

    const page = Math.max(1, parseInt(req.query?.page || '1', 10))
    const limit = Math.min(200, Math.max(1, parseInt(req.query?.limit || '50', 10)))
    const offset = (page - 1) * limit

    let query = supabase
      .from('webhook_logs')
      .select('*', { count: 'exact' })
      .eq('webhook_id', webhookId)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1)

    if (q) {
      query = query.ilike('payload::text', `%${q}%`)
    }

    if (ip) {
      query = query.eq('ip_address', ip)
    }

    if (from) {
      query = query.gte('created_at', from)
    }

    if (to) {
      query = query.lte('created_at', to)
    }

    if (source) {
      query = query.eq('payload->>source', source)
    }

    const { data: logs, error, count } = await query

    if (error) {
      captureException(error)
      return apiError(res, 500, 'LOGS_FETCH_FAILED')
    }

    const total = count ?? 0
    const hasMore = offset + (logs?.length ?? 0) < total

    return apiSuccess(res, { logs: logs || [], total, page, limit, hasMore })
  } catch (err) {
    captureException(err as Error)
    return apiError(res, 500, 'INTERNAL_ERROR')
  }
}
