import { getSupabase } from './_lib/supabase.js'

export default async function handler(req: any, res: any) {
  try {
    const supabase = getSupabase()
    const { data, error } = await supabase.from('webhooks').select('id').limit(1)
    return res.status(200).json({
      envCheck: {
        hasSupabaseUrl: !!process.env.SUPABASE_URL,
        hasServiceKey: !!process.env.SUPABASE_SERVICE_KEY,
        hasAnonKey: !!process.env.SUPABASE_ANON_KEY,
      },
      supabaseTest: error ? { error: error.message } : { ok: true, count: data?.length },
    })
  } catch (err: any) {
    return res.status(500).json({ error: err.message, stack: err.stack })
  }
}
