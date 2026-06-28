import { getSupabase } from './_lib/supabase.js'
import { isValidPath } from './_lib/validate.js'
import { setSecurityHeaders, honeypotDelay, getTrustedIp } from './_lib/security.js'

export default async function handler(req: any, res: any) {
  setSecurityHeaders(res)

  const logs: string[] = []
  function log(msg: string) {
    logs.push(msg)
    console.log(msg)
  }

  try {
    log('1. Starting debug-webhook handler')
    
    const supabase = getSupabase()
    log('2. Supabase client created')

    const path = req.query?.path || ''
    log(`3. Path: ${path}`)
    
    if (!path || !isValidPath(String(path))) {
      return res.status(200).json({ received: true, debug: logs })
    }
    log('4. Path is valid')

    const pathStr = String(path)
    const { data: webhook, error: findError } = await supabase
      .from('webhooks')
      .select('id, secret, is_active, url_path')
      .eq('url_path', pathStr)
      .single()
    
    log(`5. Query result: webhook=${!!webhook}, error=${findError?.message || 'none'}`)

    if (findError || !webhook) {
      return res.status(200).json({ received: true, debug: logs, reason: 'webhook_not_found' })
    }
    log(`6. Webhook found: id=${webhook.id}, active=${webhook.is_active}`)

    if (!webhook.is_active) {
      return res.status(200).json({ received: true, debug: logs, reason: 'inactive' })
    }

    // Try to insert a test log
    const ipAddress = getTrustedIp(req)
    log(`7. IP: ${ipAddress}`)

    const insertResult = await supabase
      .from('webhook_logs')
      .insert({
        webhook_id: webhook.id,
        payload: { test: true, debug: true },
        headers: {},
        ip_address: ipAddress,
      })
      .select('id')
      .single()
    
    log(`8. Insert result: error=${insertResult.error?.message || 'none'}, data=${!!insertResult.data}`)

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
