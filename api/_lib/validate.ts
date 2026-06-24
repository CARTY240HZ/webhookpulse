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

export function validateWebhookInput(name: string, description?: string): { ok: true } | { ok: false; code: string } {
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
