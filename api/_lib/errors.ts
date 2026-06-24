import { getSupabase } from './supabase'

export function apiError(
  res: any,
  status: number,
  code: string,
  devDetails?: Error | string
): any {
  // Log to console (future: Sentry capture)
  if (devDetails) {
    const detail = devDetails instanceof Error ? devDetails.message : String(devDetails)
    console.error(`[API ERROR ${code}]`, detail)
  }

  // Client gets only the error code, never details
  return res.status(status).json({ error: code })
}

export function apiSuccess(res: any, data: Record<string, unknown>): any {
  return res.status(200).json(data)
}
