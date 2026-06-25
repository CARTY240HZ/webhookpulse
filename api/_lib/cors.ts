export function getCorsHeaders(type: 'public' | 'private') {
  const appUrl = process.env.APP_URL || ''
  const origin = type === 'public' ? '*' : appUrl
  if (type === 'private' && !origin) {
    console.warn('APP_URL not set — CORS private requests may fail')
  }
  return {
    'Access-Control-Allow-Origin': origin || (type === 'public' ? '*' : ''),
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Webhook-Secret',
    'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  }
}

export function setCorsHeaders(res: any, type: 'public' | 'private'): void {
  const headers = getCorsHeaders(type)
  for (const [key, value] of Object.entries(headers)) {
    res.setHeader(key, value)
  }
}
