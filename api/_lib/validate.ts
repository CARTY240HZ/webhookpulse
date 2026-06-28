const PATH_REGEX = /^[a-zA-Z0-9_-]{1,64}$/
const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

export function isValidPath(s: string): boolean {
  return PATH_REGEX.test(s)
}

export function isValidUUID(s: string): boolean {
  return UUID_REGEX.test(s)
}

export function clampString(s: string, max: number): string {
  if (!s) return s
  return s.length > max ? s.substring(0, max) : s
}

export function getQueryParam(req: any, key: string): string | undefined {
  // Vercel Serverless Functions may not expose req.query consistently.
  // Fallback to URL parsing from req.url.
  const fromQuery = req.query?.[key]
  if (fromQuery !== undefined && fromQuery !== null && fromQuery !== '') {
    return String(fromQuery)
  }
  const rawUrl = req.url || ''
  if (rawUrl.includes('?')) {
    try {
      const url = new URL(rawUrl, 'http://localhost')
      const val = url.searchParams.get(key)
      if (val) return val
    } catch {
      // ignore parse error
    }
  }
  return undefined
}

export function getQueryParamString(req: any, key: string): string {
  return getQueryParam(req, key) || ''
}

export function getQueryParamInt(req: any, key: string, defaultVal: number): number {
  const val = getQueryParam(req, key)
  if (!val) return defaultVal
  const n = parseInt(val, 10)
  return isNaN(n) ? defaultVal : n
}
  if (!name || name.trim().length === 0) {
    return { ok: false, code: 'NAME_REQUIRED' }
  }
  if (name.trim().length > 100) {
    return { ok: false, code: 'NAME_TOO_LONG' }
  }
  if (description && description.length > 500) {
    return { ok: false, code: 'DESCRIPTION_TOO_LONG' }
  }
  return { ok: true }
}
