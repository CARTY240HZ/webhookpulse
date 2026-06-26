export function getCorsHeaders(type: 'public' | 'private', reqOrigin?: string) {
  const appUrl = process.env.APP_URL || ''
  let origin = type === 'public' ? '*' : appUrl
  if (type === 'private' && !origin) {
    origin = reqOrigin || ''
    if (!origin) {
      console.warn('APP_URL not set and no request origin — CORS private requests may fail')
    }
  }
  return {
    'Access-Control-Allow-Origin': origin || (type === 'public' ? '*' : ''),
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Webhook-Secret',
    'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  }
}

export function setCorsHeaders(res: any, type: 'public' | 'private', reqOrigin?: string): void {
  const headers = getCorsHeaders(type, reqOrigin)
  for (const [key, value] of Object.entries(headers)) {
    res.setHeader(key, value)
  }
}
