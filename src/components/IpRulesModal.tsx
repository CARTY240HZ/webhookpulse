import { useState, useEffect } from 'react'
import { Trash2, Plus } from 'lucide-react'
import { t } from '../i18n'
import { useIpRules } from '../hooks/useIpRules'
import { Button, Badge, Modal } from '../components/ui'

interface IpRulesModalProps {
  webhookId: string
  onClose: () => void
}

function isValidIpOrCidr(ip: string): boolean {
  if (!ip || typeof ip !== 'string') return false

  // Exact IPv4
  const ipv4 = /^((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)$/
  // Exact IPv6 (basic)
  const ipv6 = /^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$/
  // IPv4 CIDR
  const ipv4Cidr = /^((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\/([0-9]|[1-2][0-9]|3[0-2])$/
  // IPv6 CIDR
  const ipv6Cidr = /^([0-9a-fA-F]{1,4}:){1,7}[0-9a-fA-F]{1,4}\/([0-9]|[1-9][0-9]|1[0-1][0-9]|12[0-8])$/
  // IPv6 with ::
  const ipv6Compressed = /^([0-9a-fA-F]{1,4}:){0,6}:[0-9a-fA-F]{1,4}$|^([0-9a-fA-F]{1,4}:){0,5}::([0-9a-fA-F]{1,4}:){0,1}[0-9a-fA-F]{1,4}$/i

  return ipv4.test(ip) || ipv6.test(ip) || ipv4Cidr.test(ip) || ipv6Cidr.test(ip) || ipv6Compressed.test(ip)
}

export default function IpRulesModal({ webhookId, onClose }: IpRulesModalProps) {
  const { rules, loading, error, fetchRules, addRule, deleteRule } = useIpRules(webhookId)
  const [ip, setIp] = useState('')
  const [action, setAction] = useState<'allow' | 'block'>('block')
  const [description, setDescription] = useState('')
  const [adding, setAdding] = useState(false)
  const [ipValid, setIpValid] = useState<boolean | null>(null)

  useEffect(() => {
    fetchRules()
  }, [fetchRules])

  useEffect(() => {
    if (ip.trim() === '') {
      setIpValid(null)
    } else {
      setIpValid(isValidIpOrCidr(ip.trim()))
    }
  }, [ip])

  const handleAdd = async () => {
    const trimmed = ip.trim()
    if (!trimmed || !isValidIpOrCidr(trimmed)) return
    setAdding(true)
    const ok = await addRule(trimmed, action, description.trim() || undefined)
    if (ok) {
      setIp('')
      setDescription('')
      setAction('block')
      setIpValid(null)
    }
    setAdding(false)
  }

  const handleDelete = async (ruleId: string) => {
    if (!confirm(t('ipRules.delete') + '?')) return
    await deleteRule(ruleId)
  }

  const isEnabled = rules.length > 0

  return (
    <Modal isOpen={true} onClose={onClose} title={t('ipRules.title')} className="max-w-lg w-full max-h-[80vh] flex flex-col">
        {/* Content */}
        <div className="flex-1 overflow-y-auto px-5 py-4 space-y-4">
          {/* Status */}
          <div className="flex items-center justify-between">
            <span className="text-sm text-text-secondary">{t('ipRules.enabled')}</span>
            <Badge variant={isEnabled ? 'success' : 'ghost'}>
              {isEnabled ? 'ON' : 'OFF'}
            </Badge>
          </div>

          {error && (
            <div className="rounded px-3 py-2 text-sm bg-danger/10 text-danger">{error}</div>
          )}

          {/* Add Rule Form */}
          <div className="bg-background border border-border rounded p-4 space-y-3">
            <h3 className="text-sm font-medium text-text-primary">{t('ipRules.addRule')}</h3>

            <div>
              <label className="block text-xs text-text-secondary mb-1">{t('ipRules.ip')}</label>
              <input
                type="text"
                value={ip}
                onChange={(e) => setIp(e.target.value)}
                placeholder="192.168.1.0/24"
                className={`w-full px-3 py-2 bg-surface border rounded text-sm text-text-primary focus:border-accent transition-colors ${
                  ipValid === false ? 'border-danger' : ipValid === true ? 'border-success' : 'border-border'
                }`}
              />
              <p className="text-[10px] text-text-secondary mt-1">{t('ipRules.cidr')}</p>
              {ipValid === false && (
                <p className="text-[10px] text-danger mt-1">{t('ipRules.invalidIp')}</p>
              )}
            </div>

            <div>
              <label className="block text-xs text-text-secondary mb-1">{t('ipRules.action')}</label>
              <select
                value={action}
                onChange={(e) => setAction(e.target.value as 'allow' | 'block')}
                className="w-full px-3 py-2 bg-surface border border-border rounded text-sm text-text-primary focus:border-accent transition-colors"
              >
                <option value="allow">{t('ipRules.allow')}</option>
                <option value="block">{t('ipRules.block')}</option>
              </select>
            </div>

            <div>
              <label className="block text-xs text-text-secondary mb-1">{t('ipRules.description')}</label>
              <input
                type="text"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                className="w-full px-3 py-2 bg-surface border border-border rounded text-sm text-text-primary focus:border-accent transition-colors"
              />
            </div>

            <Button onClick={handleAdd} disabled={adding || !ipValid} isLoading={adding} className="w-full" leftIcon={<Plus className="w-4 h-4" />}>
              {adding ? '...' : t('ipRules.addRule')}
            </Button>
          </div>

          {/* Rules Table */}
          <div>
            <h3 className="text-sm font-medium text-text-primary mb-2">
              {t('ipRules.addRule')}
            </h3>
            {loading ? (
              <div className="text-sm text-text-secondary text-center py-4">{t('common.loading')}</div>
            ) : rules.length === 0 ? (
              <div className="text-sm text-text-secondary text-center py-4 bg-background border border-border rounded">
                {t('ipRules.noRules')}
              </div>
            ) : (
              <div className="border border-border rounded overflow-hidden">
                <table className="w-full text-sm">
                  <thead className="bg-background border-b border-border">
                    <tr>
                      <th className="px-3 py-2 text-left text-xs text-text-secondary font-medium">{t('ipRules.ip')}</th>
                      <th className="px-3 py-2 text-left text-xs text-text-secondary font-medium">{t('ipRules.action')}</th>
                      <th className="px-3 py-2 text-right text-xs text-text-secondary font-medium"></th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border">
                    {rules.map((rule) => (
                      <tr key={rule.id} className="hover:bg-elevated transition-colors">
                        <td className="px-3 py-2 text-text-primary font-mono text-xs">{rule.ip}</td>
                        <td className="px-3 py-2">
                          <Badge variant={rule.action === 'allow' ? 'success' : 'danger'}>
                            {rule.action === 'allow' ? t('ipRules.allow') : t('ipRules.block')}
                          </Badge>
                        </td>
                        <td className="px-3 py-2 text-right">
                          <Button onClick={() => handleDelete(rule.id)} variant="ghost" size="sm" className="text-text-secondary hover:text-danger p-1"
                            title={t('ipRules.delete')}>
                            <Trash2 className="w-4 h-4" />
                          </Button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
    </Modal>
  )
}
