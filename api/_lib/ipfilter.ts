interface IpRule {
  ip: string
  action: string
}

export function checkIpAgainstRules(ip: string, rules: IpRule[]): { allowed: boolean; reason?: string } {
  if (!rules || rules.length === 0) {
    return { allowed: true }
  }

  const blockRules = rules.filter((r) => r.action === 'block')
  const allowRules = rules.filter((r) => r.action === 'allow')

  // Check blocklist first
  for (const rule of blockRules) {
    if (matchesIp(ip, rule.ip)) {
      return { allowed: false, reason: 'IP_BLOCKED' }
    }
  }

  // If allowlist exists, IP must be in it
  if (allowRules.length > 0) {
    for (const rule of allowRules) {
      if (matchesIp(ip, rule.ip)) {
        return { allowed: true }
      }
    }
    return { allowed: false, reason: 'IP_NOT_ALLOWED' }
  }

  return { allowed: true }
}

function matchesIp(ip: string, ruleIp: string): boolean {
  // Exact match
  if (ip === ruleIp) return true

  // CIDR match
  if (ruleIp.includes('/')) {
    return isIpInCidr(ip, ruleIp)
  }

  return false
}

function isIpInCidr(ip: string, cidr: string): boolean {
  if (isIPv4(ip) && isIPv4CIDR(cidr)) {
    return ipv4InCidr(ip, cidr)
  }
  if (isIPv6(ip) && isIPv6CIDR(cidr)) {
    return ipv6InCidr(ip, cidr)
  }
  return false
}

function ipv4ToInt(ip: string): number {
  const parts = ip.split('.').map(Number)
  return (parts[0] * 16777216) + (parts[1] * 65536) + (parts[2] * 256) + parts[3]
}

function ipv4InCidr(ip: string, cidr: string): boolean {
  const [subnet, prefix] = cidr.split('/')
  const prefixLen = parseInt(prefix, 10)
  const mask = prefixLen === 0 ? 0 : (0xffffffff ^ (0xffffffff >>> prefixLen))
  const ipInt = ipv4ToInt(ip)
  const subnetInt = ipv4ToInt(subnet)
  return (ipInt & mask) === (subnetInt & mask)
}

function ipv6InCidr(ip: string, cidr: string): boolean {
  const [subnet, prefix] = cidr.split('/')
  const prefixLen = parseInt(prefix, 10)
  const ipBytes = parseIPv6(ip)
  const subnetBytes = parseIPv6(subnet)

  const fullBytes = Math.floor(prefixLen / 8)
  const partialBits = prefixLen % 8

  for (let i = 0; i < fullBytes; i++) {
    if (ipBytes[i] !== subnetBytes[i]) return false
  }

  if (partialBits > 0) {
    const mask = 0xff << (8 - partialBits)
    return (ipBytes[fullBytes] & mask) === (subnetBytes[fullBytes] & mask)
  }

  return true
}

function parseIPv6(ip: string): number[] {
  // Expand :: notation
  let expanded = ip
  if (expanded.includes('::')) {
    const parts = expanded.split('::')
    const left = parts[0] ? parts[0].split(':') : []
    const right = parts[1] ? parts[1].split(':') : []
    const missing = 8 - left.length - right.length
    const zeros = Array(missing).fill('0')
    expanded = [...left, ...zeros, ...right].join(':')
  }

  const groups = expanded.split(':')
  const bytes: number[] = []
  for (const group of groups) {
    const val = parseInt(group || '0', 16)
    bytes.push((val >> 8) & 0xff, val & 0xff)
  }
  return bytes
}

function isIPv4(ip: string): boolean {
  const parts = ip.split('.')
  if (parts.length !== 4) return false
  return parts.every((p) => {
    const n = parseInt(p, 10)
    return String(n) === p && n >= 0 && n <= 255
  })
}

function isIPv6(ip: string): boolean {
  // Basic IPv6 validation
  if (!ip.includes(':')) return false
  const parts = ip.split(':')
  if (parts.length < 2 || parts.length > 8) return false
  return parts.every((p) => p === '' || (/^[0-9a-fA-F]{1,4}$/.test(p)))
}

function isIPv4CIDR(cidr: string): boolean {
  const [ip, prefix] = cidr.split('/')
  if (!prefix) return false
  const p = parseInt(prefix, 10)
  return isIPv4(ip) && p >= 0 && p <= 32
}

function isIPv6CIDR(cidr: string): boolean {
  const [ip, prefix] = cidr.split('/')
  if (!prefix) return false
  const p = parseInt(prefix, 10)
  return isIPv6(ip) && p >= 0 && p <= 128
}

export function isValidIpOrCidr(ip: string): boolean {
  if (!ip || typeof ip !== 'string') return false
  if (ip.includes('/')) {
    return isIPv4CIDR(ip) || isIPv6CIDR(ip)
  }
  return isIPv4(ip) || isIPv6(ip)
}
