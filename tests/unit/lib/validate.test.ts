import { describe, it, expect } from 'vitest'
import { isValidPath, isValidUUID, clampString, validateWebhookInput } from '../../../api/_lib/validate'

describe('isValidPath', () => {
  it('accepts valid alphanumeric paths', () => {
    expect(isValidPath('abc-123')).toBe(true)
    expect(isValidPath('webhook_test')).toBe(true)
    expect(isValidPath('a')).toBe(true)
  })

  it('rejects empty string', () => {
    expect(isValidPath('')).toBe(false)
  })

  it('rejects paths with special characters', () => {
    expect(isValidPath('path:with:colon')).toBe(false)
    expect(isValidPath('path/with/slash')).toBe(false)
    expect(isValidPath('path space')).toBe(false)
    expect(isValidPath('path.dot')).toBe(false)
  })

  it('rejects paths over 64 chars', () => {
    expect(isValidPath('a'.repeat(65))).toBe(false)
  })

  it('rejects exactly 65 chars', () => {
    expect(isValidPath('a'.repeat(65))).toBe(false)
  })

  it('accepts exactly 64 chars', () => {
    expect(isValidPath('a'.repeat(64))).toBe(true)
  })
})

describe('isValidUUID', () => {
  it('accepts valid UUID v4', () => {
    expect(isValidUUID('550e8400-e29b-41d4-a716-446655440000')).toBe(true)
  })

  it('accepts uppercase UUID', () => {
    expect(isValidUUID('550E8400-E29B-41D4-A716-446655440000')).toBe(true)
  })

  it('rejects empty string', () => {
    expect(isValidUUID('')).toBe(false)
  })

  it('rejects invalid format', () => {
    expect(isValidUUID('not-a-uuid')).toBe(false)
    expect(isValidUUID('123')).toBe(false)
  })

  it('rejects UUID with wrong segment lengths', () => {
    expect(isValidUUID('550e8400-e29b-41d4-a716-44665544000')).toBe(false)
  })
})

describe('clampString', () => {
  it('returns string under limit unchanged', () => {
    expect(clampString('hello', 100)).toBe('hello')
  })

  it('truncates string over limit', () => {
    expect(clampString('hello world', 5)).toBe('hello')
  })

  it('handles empty string', () => {
    expect(clampString('', 10)).toBe('')
  })
})

describe('validateWebhookInput', () => {
  it('accepts valid name', () => {
    const result = validateWebhookInput('My Webhook')
    expect(result.ok).toBe(true)
  })

  it('rejects empty name', () => {
    const result = validateWebhookInput('')
    expect(result.ok).toBe(false)
    expect(result.code).toBe('NAME_REQUIRED')
  })

  it('rejects name over 100 chars', () => {
    const result = validateWebhookInput('a'.repeat(101))
    expect(result.ok).toBe(false)
    expect(result.code).toBe('NAME_TOO_LONG')
  })

  it('rejects description over 500 chars', () => {
    const result = validateWebhookInput('Valid', 'a'.repeat(501))
    expect(result.ok).toBe(false)
    expect(result.code).toBe('DESCRIPTION_TOO_LONG')
  })
})
