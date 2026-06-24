const ALLOWED_ORIGIN = process.env.APP_URL || '*'

export function getCorsHeaders(type: 'public' | 'private') {
  const origin = type === 'public' ? '*' : ALLOWED_ORIGIN
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Webhook-Secret',
    'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  }
}
