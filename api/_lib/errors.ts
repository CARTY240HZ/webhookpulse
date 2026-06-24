import { captureException } from './sentry.js'

export function apiError(
  res: any,
  status: number,
  code: string,
  devDetails?: Error | string
): any {
  if (devDetails) {
    const err = devDetails instanceof Error ? devDetails : new Error(String(devDetails))
    captureException(err)
  }

  // Client gets only the error code, never details
  return res.status(status).json({ error: code })
}

export function apiSuccess(res: any, data: Record<string, unknown>): any {
  return res.status(200).json(data)
}
