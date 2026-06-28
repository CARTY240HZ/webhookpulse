import { vi, describe, it, expect } from 'vitest'

vi.mock('../../src/lib/supabase', () => ({
  supabase: {},
}))

import { mapLogToItem } from '../../src/hooks/useActivityFeed'
import type { Webhook, WebhookLog } from '../../src/types'

describe('mapLogToItem', () => {
  const webhookMap = new Map<string, Webhook>([
    [
      'w1',
      {
        id: 'w1',
        user_id: 'u1',
        name: 'TestWebhook',
        url_path: '/hook1',
        is_active: true,
        created_at: '2024-01-01T00:00:00Z',
        updated_at: '2024-01-01T00:00:00Z',
        has_secret: true,
        discord_url: 'https://discord.com/api/webhooks/xxx',
      },
    ],
    [
      'w2',
      {
        id: 'w2',
        user_id: 'u1',
        name: 'NativeWebhook',
        url_path: '/hook2',
        is_active: true,
        created_at: '2024-01-01T00:00:00Z',
        updated_at: '2024-01-01T00:00:00Z',
      },
    ],
  ])

  const baseLog: WebhookLog = {
    id: 'l1',
    webhook_id: 'w1',
    payload: { source: 'roblox', status: 'success' },
    ip_address: '1.2.3.4',
    created_at: '2024-06-15T12:00:00Z',
  }

  it('maps a Discord webhook log correctly', () => {
    const item = mapLogToItem(baseLog, webhookMap, true)
    expect(item.id).toBe('l1')
    expect(item.webhook_id).toBe('w1')
    expect(item.webhook_name).toBe('TestWebhook')
    expect(item.type).toBe('discord')
    expect(item.source).toBe('roblox')
    expect(item.ip_address).toBe('1.2.3.4')
    expect(item.status).toBe('success')
    expect(item.isNew).toBe(true)
  })

  it('maps a native webhook log correctly', () => {
    const log: WebhookLog = { ...baseLog, webhook_id: 'w2' }
    const item = mapLogToItem(log, webhookMap)
    expect(item.type).toBe('native')
    expect(item.webhook_name).toBe('NativeWebhook')
    expect(item.isNew).toBe(false)
  })

  it('handles unknown webhook', () => {
    const log: WebhookLog = { ...baseLog, webhook_id: 'unknown' }
    const item = mapLogToItem(log, webhookMap)
    expect(item.webhook_name).toBe('Unknown')
    expect(item.type).toBe('native')
  })

  it('detects honeypot status', () => {
    const log: WebhookLog = {
      ...baseLog,
      payload: { status: 'honeypot' },
    }
    const item = mapLogToItem(log, webhookMap)
    expect(item.status).toBe('honeypot')
  })

  it('detects rate_limited status', () => {
    const log: WebhookLog = {
      ...baseLog,
      payload: { status: 'rate_limited' },
    }
    const item = mapLogToItem(log, webhookMap)
    expect(item.status).toBe('rate_limited')
  })

  it('defaults to success for unknown status', () => {
    const log: WebhookLog = {
      ...baseLog,
      payload: { status: 'unknown' },
    }
    const item = mapLogToItem(log, webhookMap)
    expect(item.status).toBe('success')
  })

  it('handles null source gracefully', () => {
    const log: WebhookLog = {
      ...baseLog,
      payload: {},
    }
    const item = mapLogToItem(log, webhookMap)
    expect(item.source).toBeNull()
  })

  it('handles null ip_address', () => {
    const log: WebhookLog = { ...baseLog, ip_address: undefined }
    const item = mapLogToItem(log, webhookMap)
    expect(item.ip_address).toBeNull()
  })
})
