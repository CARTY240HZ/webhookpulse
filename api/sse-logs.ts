// Server-Sent Events endpoint for real-time webhook logs
// Replaces WebSockets (not supported on Vercel Serverless)
// Works in free tier with keep-alive connections

import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.SUPABASE_URL || ''
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY || ''

export default async function handler(req: any, res: any) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' })
  }

  const { webhookId } = req.query
  if (!webhookId) {
    return res.status(400).json({ error: 'Missing webhookId' })
  }

  // Validate JWT
  const authHeader = req.headers.authorization || ''
  const token = authHeader.replace('Bearer ', '')
  if (!token) {
    return res.status(401).json({ error: 'Unauthorized' })
  }

  const supabase = createClient(supabaseUrl, supabaseServiceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  const { data: { user }, error: authError } = await supabase.auth.getUser(token)
  if (authError || !user) {
    return res.status(401).json({ error: 'Unauthorized' })
  }

  // Verify webhook ownership
  const { data: webhook } = await supabase
    .from('webhooks')
    .select('id')
    .eq('id', webhookId)
    .eq('user_id', user.id)
    .single()

  if (!webhook) {
    return res.status(404).json({ error: 'Webhook not found' })
  }

  // Set SSE headers
  res.setHeader('Content-Type', 'text/event-stream')
  res.setHeader('Cache-Control', 'no-cache, no-transform')
  res.setHeader('Connection', 'keep-alive')
  res.setHeader('X-Accel-Buffering', 'no') // Disable nginx buffering
  res.flushHeaders()

  // Send initial connection event
  res.write('event: connected\n')
  res.write(`data: ${JSON.stringify({ webhookId, timestamp: Date.now() })}\n\n`)

  // Subscribe to Supabase Realtime for new logs
  const channel = supabase
    .channel(`sse-logs-${webhookId}`)
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'webhook_logs',
        filter: `webhook_id=eq.${webhookId}`,
      },
      (payload: any) => {
        res.write('event: log\n')
        res.write(`data: ${JSON.stringify(payload.new)}\n\n`)
      }
    )
    .subscribe()

  // Keep-alive ping every 30s
  const interval = setInterval(() => {
    res.write('event: ping\n')
    res.write(`data: ${Date.now()}\n\n`)
  }, 30000)

  // Cleanup on disconnect
  req.on('close', () => {
    clearInterval(interval)
    supabase.removeChannel(channel)
  })
}
