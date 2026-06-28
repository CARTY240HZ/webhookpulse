export default async function handler(req: any, res: any) {
  try {
    const imports: Record<string, any> = {}
    const errors: Record<string, string> = {}

    try { imports.supabase = await import('./_lib/supabase.js') } catch (e: any) { errors.supabase = e.message + ' | ' + e.stack }
    try { imports.sentry = await import('./_lib/sentry.js') } catch (e: any) { errors.sentry = e.message }
    try { imports.ipfilter = await import('./_lib/ipfilter.js') } catch (e: any) { errors.ipfilter = e.message }
    try { imports.validate = await import('./_lib/validate.js') } catch (e: any) { errors.validate = e.message }
    try { imports.ratelimit = await import('./_lib/ratelimit.js') } catch (e: any) { errors.ratelimit = e.message }
    try { imports.hmac = await import('./_lib/hmac.js') } catch (e: any) { errors.hmac = e.message }

    return res.status(200).json({ ok: Object.keys(errors).length === 0, errors, imports: Object.keys(imports) })
  } catch (e: any) {
    return res.status(500).json({ error: e.message, stack: e.stack })
  }
}
