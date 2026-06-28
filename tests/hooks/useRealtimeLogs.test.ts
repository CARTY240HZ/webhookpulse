import { vi, describe, it, expect } from 'vitest'

vi.mock('../../src/lib/supabase', () => ({
  supabase: {},
}))

import { buildFilterQuery, logMatchesFilters, getActiveFilterCount } from '../../src/hooks/useRealtimeLogs'
import type { LogFilters } from '../../src/hooks/useRealtimeLogs'
import type { WebhookLog } from '../../src/types'

describe('buildFilterQuery', () => {
  it('returns empty string for no filters', () => {
    expect(buildFilterQuery({})).toBe('')
  })

  it('builds query from all filters', () => {
    const filters: LogFilters = {
      q: 'search',
      ip: '1.2.3.4',
      from: '2024-01-01',
      to: '2024-12-31',
      source: 'roblox',
      type: 'discord',
    }
    const qs = buildFilterQuery(filters)
    expect(qs).toContain('q=search')
    expect(qs).toContain('ip=1.2.3.4')
    expect(qs).toContain('from=2024-01-01')
    expect(qs).toContain('to=2024-12-31')
    expect(qs).toContain('source=roblox')
    expect(qs).toContain('type=discord')
  })

  it('skips type=all', () => {
    const qs = buildFilterQuery({ type: 'all' })
    expect(qs).not.toContain('type=')
  })
})

describe('logMatchesFilters', () => {
  const baseLog: WebhookLog = {
    id: '1',
    webhook_id: 'w1',
    payload: { source: 'roblox', data: 'hello world' },
    ip_address: '1.2.3.4',
    created_at: '2024-06-15T12:00:00Z',
  }

  it('matches empty filters', () => {
    expect(logMatchesFilters(baseLog, {})).toBe(true)
  })

  it('matches by q in payload', () => {
    expect(logMatchesFilters(baseLog, { q: 'hello' })).toBe(true)
    expect(logMatchesFilters(baseLog, { q: 'nope' })).toBe(false)
  })

  it('matches by ip', () => {
    expect(logMatchesFilters(baseLog, { ip: '1.2.3.4' })).toBe(true)
    expect(logMatchesFilters(baseLog, { ip: '5.6.7.8' })).toBe(false)
  })

  it('matches by date range', () => {
    expect(logMatchesFilters(baseLog, { from: '2024-01-01' })).toBe(true)
    expect(logMatchesFilters(baseLog, { from: '2024-12-31' })).toBe(false)
    expect(logMatchesFilters(baseLog, { to: '2024-12-31' })).toBe(true)
    expect(logMatchesFilters(baseLog, { to: '2024-01-01' })).toBe(false)
  })

  it('matches by source', () => {
    expect(logMatchesFilters(baseLog, { source: 'roblox' })).toBe(true)
    expect(logMatchesFilters(baseLog, { source: 'discord' })).toBe(false)
  })

  it('matches by webhook type', () => {
    expect(logMatchesFilters(baseLog, { type: 'native' }, 'native')).toBe(true)
    expect(logMatchesFilters(baseLog, { type: 'discord' }, 'native')).toBe(false)
    expect(logMatchesFilters(baseLog, { type: 'all' }, 'native')).toBe(true)
  })
})

describe('getActiveFilterCount', () => {
  it('counts only active filters', () => {
    expect(getActiveFilterCount({})).toBe(0)
    expect(getActiveFilterCount({ q: 'x' })).toBe(1)
    expect(getActiveFilterCount({ q: 'x', type: 'all' })).toBe(1)
    expect(getActiveFilterCount({ q: 'x', ip: '1', type: 'discord' })).toBe(3)
  })
})
