import { describe, it, expect } from 'vitest'
import { hashSecret, verifySecret } from '../../../api/_lib/hmac'

describe('hashSecret', () => {
  it('produces consistent hash for same input', () => {
    const h1 = hashSecret('mysecret')
    const h2 = hashSecret('mysecret')
    expect(h1).toBe(h2)
    expect(h1).toHaveLength(64) // SHA-256 hex
  })

  it('produces different hash for different inputs', () => {
    const h1 = hashSecret('secret1')
    const h2 = hashSecret('secret2')
    expect(h1).not.toBe(h2)
  })
})

describe('verifySecret', () => {
  it('returns true for correct secret', () => {
    const hash = hashSecret('correct')
    expect(verifySecret('correct', hash)).toBe(true)
  })

  it('returns false for incorrect secret', () => {
    const hash = hashSecret('correct')
    expect(verifySecret('wrong', hash)).toBe(false)
  })

  it('returns false for empty provided secret', () => {
    const hash = hashSecret('correct')
    expect(verifySecret('', hash)).toBe(false)
  })

  it('returns false for empty stored hash', () => {
    expect(verifySecret('secret', '')).toBe(false)
  })
})
