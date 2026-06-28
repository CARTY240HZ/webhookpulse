// In-memory mock for @upstash/redis used in tests
// No network calls — deterministic and fast

interface MockStore {
  [key: string]: { value: any; expiresAt?: number }
}

const store: MockStore = {}

export function __resetStore(): void {
  for (const key of Object.keys(store)) {
    delete store[key]
  }
}

export function __getStore(): MockStore {
  return store
}

class MockRedis {
  async incr(key: string): Promise<number> {
    const now = Date.now()
    const entry = store[key]
    if (entry && entry.expiresAt && entry.expiresAt < now) {
      delete store[key]
    }
    const current = (store[key]?.value || 0) + 1
    store[key] = { value: current }
    return current
  }

  async pexpire(key: string, ms: number): Promise<number> {
    if (!store[key]) return 0
    store[key].expiresAt = Date.now() + ms
    return 1
  }

  async expire(key: string, seconds: number): Promise<number> {
    return this.pexpire(key, seconds * 1000)
  }

  async del(key: string): Promise<number> {
    if (store[key]) {
      delete store[key]
      return 1
    }
    return 0
  }

  async hmget(key: string, ...fields: string[]): Promise<(string | null)[]> {
    const entry = store[key]
    if (!entry) return fields.map(() => null)
    const obj = entry.value || {}
    return fields.map((f) => (obj[f] !== undefined ? String(obj[f]) : null))
  }

  async hmset(key: string, obj: Record<string, any>): Promise<'OK'> {
    store[key] = { value: { ...(store[key]?.value || {}), ...obj } }
    return 'OK'
  }
}

export const Redis = class Redis extends MockRedis {}
