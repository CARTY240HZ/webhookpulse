import type { WebhookLog } from '../types'
import { Gamepad2, User, Globe, Smartphone } from 'lucide-react'

interface RobloxEmbedProps {
  log: WebhookLog
}

export default function RobloxEmbed({ log }: RobloxEmbedProps) {
  const p = log.payload as Record<string, unknown>
  const game = (p.game as Record<string, unknown>) || {}
  const device = (p.device as Record<string, unknown>) || {}

  const timestamp = p.timestamp
    ? new Date((p.timestamp as number) * 1000).toLocaleString('es-ES', {
        year: 'numeric',
        month: 'short',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
      })
    : new Date(log.created_at).toLocaleString('es-ES')

  const Field = ({ label, value }: { label: string; value: string }) => (
    <div className="flex flex-col gap-0.5">
      <span className="text-[10px] uppercase tracking-wider text-text-secondary font-semibold">
        {label}
      </span>
      <span className="text-sm text-text-primary font-mono">{value}</span>
    </div>
  )

  return (
    <div className="flex rounded-lg overflow-hidden bg-elevated border border-border">
      {/* Barra lateral estilo Discord embed */}
      <div className="w-1 shrink-0 bg-accent" />

      <div className="flex-1 p-4">
        {/* Header */}
        <div className="flex items-center gap-3 mb-4">
          <div className="w-10 h-10 rounded-full bg-accent/10 flex items-center justify-center">
            <Gamepad2 className="w-5 h-5 text-accent" />
          </div>
          <div>
            <div className="text-sm font-semibold text-text-primary">
              Roblox Profile Data
            </div>
            <div className="text-xs text-text-secondary">{timestamp}</div>
          </div>
        </div>

        {/* Campos principales */}
        <div className="grid grid-cols-2 gap-3 mb-4">
          <Field label="UserId" value={String(p.userid || '-')} />
          <Field label="Username" value={String(p.username || '-')} />
          <Field label="Display Name" value={String(p.displayname || '-')} />
          <Field label="Account Age" value={String(p.accountage || '-')} />
          <Field label="Membership" value={String(p.membership || '-')} />
          <Field label="Country" value={String(p.country || '-')} />
        </div>

        {/* Seccion Game */}
        {game.placeid && (
          <div className="mb-3">
            <div className="flex items-center gap-2 mb-2">
              <Globe className="w-3.5 h-3.5 text-accent" />
              <span className="text-xs font-semibold text-text-primary uppercase tracking-wider">
                Game
              </span>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <Field label="PlaceId" value={String(game.placeid)} />
              <Field label="JobId" value={String(game.jobid || '-').substring(0, 20) + (String(game.jobid || '').length > 20 ? '...' : '')} />
              <div className="col-span-2">
                <Field label="Game Name" value={String(game.gamename || '-')} />
              </div>
            </div>
          </div>
        )}

        {/* Seccion Device */}
        {device.os && (
          <div className="mb-3">
            <div className="flex items-center gap-2 mb-2">
              <Smartphone className="w-3.5 h-3.5 text-accent" />
              <span className="text-xs font-semibold text-text-primary uppercase tracking-wider">
                Device
              </span>
            </div>
            <Field label="Platform" value={String(device.os)} />
          </div>
        )}

        {/* Footer */}
        <div className="mt-3 pt-3 border-t border-border flex items-center justify-between">
          <div className="flex items-center gap-2">
            <User className="w-3 h-3 text-text-secondary" />
            <span className="text-xs text-text-secondary">
              Source: {String(p.source || 'unknown')}
            </span>
          </div>
          <span className="text-xs text-text-secondary">
            IP: {log.ip_address || 'Unknown'}
          </span>
        </div>
      </div>
    </div>
  )
}
