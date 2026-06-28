import { getSupabase } from './_lib/supabase.js'

export default async function handler(req: any, res: any) {
  try {
    const supabase = getSupabase()
    const { data, error } = await supabase
      .from('webhooks')
      .select('secret')
      .eq('url_path', 'as-66cn5z')
      .single()
    
    if (error) return res.status(500).json({ error: error.message })
    
    return res.status(200).json({
      secret: data?.secret,
      length: data?.secret?.length || 0,
    })
  } catch (err: any) {
    return res.status(500).json({ error: err.message })
  }
}
