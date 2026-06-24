import { describe, it, expect, vi } from 'vitest'

// Mock Supabase client before importing handler
const mockSingle = vi.fn()
const mockEq = vi.fn(() => ({ single: mockSingle }))
const mockSelect = vi.fn(() => ({ eq: mockEq }))
const mockInsert = vi.fn(() => ({ select: vi.fn(() => ({ single: vi.fn(() => ({ data: { id: 'log-1' }, error: null })) })) }))

const mockSupabase = {
  from: vi.fn((table: string) => {
    if (table === 'webhooks') {
      return { select: mockSelect }
    }
    if (table === 'webhook_logs') {
      return { insert: mockInsert }
    }
    return {}
  }),
  auth: { getUser: vi.fn() }
}

vi.mock('../../api/_lib/supabase', () => ({
  getSupabase: () => mockSupabase
}))

// Import handler after mock
import webhookReceive from '../../api/webhook-receive'

describe('webhook-receive integration', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('returns 200 received for invalid path (honeypot)', async () => {
    const req = { method: 'POST', query: { path: '../hack' }, headers: {}, body: {} }
    const res = { status: vi.fn(() => res), json: vi.fn(() => res), set: vi.fn() }
    await webhookReceive(req, res)
    expect(res.status).toHaveBeenCalledWith(200)
    expect(res.json).toHaveBeenCalledWith({ received: true })
  })

  it('returns 200 received for unknown webhook (honeypot)', async () => {
    mockSingle.mockResolvedValue({ data: null, error: { message: 'not found' } })
    const req = { method: 'POST', query: { path: 'unknown-path' }, headers: {}, body: {} }
    const res = { status: vi.fn(() => res), json: vi.fn(() => res), set: vi.fn() }
    await webhookReceive(req, res)
    expect(res.status).toHaveBeenCalledWith(200)
    expect(res.json).toHaveBeenCalledWith({ received: true })
  })

  it('returns 413 for oversized body', async () => {
    const req = { method: 'POST', query: { path: 'valid-path' }, headers: {}, body: 'x'.repeat(300 * 1024) }
    const res = { status: vi.fn(() => res), json: vi.fn(() => res), set: vi.fn() }
    await webhookReceive(req, res)
    expect(res.status).toHaveBeenCalledWith(413)
    expect(res.json).toHaveBeenCalledWith({ error: 'PAYLOAD_TOO_LARGE' })
  })
})
