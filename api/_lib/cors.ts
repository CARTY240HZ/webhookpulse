export function getCorsHeaders(type: 'public' | 'private') {
  const origin = type === 'public' ? '*' : (process.env.APP_URL || '*')
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Webhook-Secret',
    'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
  }
}
