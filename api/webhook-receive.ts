import { getSupabase } from './_lib/supabase.js'
import { isValidPath } from './_lib/validate.js'
import { setSecurityHeaders, honeypotDelay, getTrustedIp } from './_lib/security.js'
import { captureException } from './_lib/sentry.js'

export default async function handler(req: any, res: any) {
  setSecurityHeaders(res)

  const logs: string[] = []
  function log(msg: string) { logs.push(msg); console.log(msg) }

  try {
    log('1. Starting')
    await honeypotDelay()
    log('2. Honeypot done')
    
    const supabase = getSupabase()
    log('3. Supabase created')

    const path = req.query?.path || ''
    log(`4. Path: ${path}`)
    
    if (!path || !isValidPath(String(path))) {
      return res.status(200).json({ received: true, debug: logs })
    }
    log('5. Path valid')

    const pathStr = String(path)
    const { data: webhook, error: findError } = await supabase
      .from('webhooks')
      .select('id, secret, is_active, url_path')
      .eq('url_path', pathStr)
      .single()
    
    log(`6. Query: webhook=${!!webhook}, error=${findError?.message || 'none'}`)

    if (findError || !webhook) {
      return res.status(200).json({ received: true, debug: logs, reason: 'not_found' })
    }
    log(`7. Webhook: id=${webhook.id}, active=${webhook.is_active}`)

    if (!webhook.is_active) {
      return res.status(200).json({ received: true, debug: logs, reason: 'inactive' })
    }

    const ipAddress = getTrustedIp(req)
    log(`8. IP: ${ipAddress}`)

    // Body handling
    let rawBody: string = ''
    if (req.body) {
      if (Buffer.isBuffer(req.body)) {
        rawBody = req.body.toString('utf-8')
      } else if (typeof req.body === 'string') {
        rawBody = req.body
      } else if (typeof req.body === 'object') {
        rawBody = JSON.stringify(req.body)
      }
    }
    log(`9. Body size: ${rawBody.length}`)

    let payload: unknown = null
    try {
      if (rawBody.length > 0) {
        payload = JSON.parse(rawBody)
      }
    } catch (parseErr) {
      captureException(parseErr as Error)
      payload = {}
    }
    log(`10. Payload parsed: ${!!payload}`)

    const insertResult = await supabase
      .from('webhook_logs')
      .insert({
        webhook_id: webhook.id,
        payload: payload ?? {},
        headers: { 'user-agent': req.headers['user-agent'] || '' },
        ip_address: ipAddress,
      })
      .select('id')
      .single()
    
    log(`11. Insert: error=${insertResult.error?.message || 'none'}, data=${!!insertResult.data}`)

    if (insertResult.error) {
      return res.status(500).json({ error: insertResult.error.message, debug: logs })
    }

    return res.status(200).json({ 
      success: true, 
      logId: insertResult.data?.id,
      debug: logs 
    })
  } catch (err: any) {
    log(`ERROR: ${err.message}`)
    return res.status(500).json({ error: err.message, stack: err.stack, debug: logs })
  }
}
