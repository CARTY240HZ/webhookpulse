import type { WebhookLog } from '../types'
import { Gamepad2, User, Globe, Smartphone, Cpu, PersonStanding, Sun } from 'lucide-react'

interface RobloxEmbedProps {
  log: WebhookLog
}

export default function RobloxEmbed({ log }: RobloxEmbedProps) {
  const p = log.payload as Record<string, unknown>
  const player = (p.player as Record<string, unknown>) || {}
  const game = (p.game as Record<string, unknown>) || {}
  const device = (p.device as Record<string, unknown>) || {}
  const character = (p.character as Record<string, unknown>) || null
  const environment = (p.environment as Record<string, unknown>) || null
  const executor = (p.executor as Record<string, unknown>) || null

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

        {/* Executor */}
        {executor && executor.name && (
          <div className="mb-3">
            <div className="flex items-center gap-2 mb-2">
              <Cpu className="w-3.5 h-3.5 text-accent" />
              <span className="text-xs font-semibold text-text-primary uppercase tracking-wider">
                Executor
              </span>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <Field label="Name" value={String(executor.name)} />
            </div>
          </div>
        )}

        {/* Campos principales — Player */}
        <div className="grid grid-cols-2 gap-3 mb-4">
          <Field label="UserId" value={String(player.userid || '-')} />
          <Field label="Username" value={String(player.username || '-')} />
          <Field label="Display Name" value={String(player.displayname || '-')} />
          <Field label="Account Age" value={String(player.accountage || '-')} />
          <Field label="Membership" value={String(player.membership || '-')} />
          <Field label="Country" value={String(player.country || '-')} />
          {player.team && <Field label="Team" value={String(player.team)} />}
          {player.teamcolor && <Field label="Team Color" value={String(player.teamcolor)} />}
          {player.neutral !== undefined && <Field label="Neutral" value={String(player.neutral)} />}
        </div>

        {/* Character */}
        {character && (
          <div className="mb-3">
            <div className="flex items-center gap-2 mb-2">
              <PersonStanding className="w-3.5 h-3.5 text-accent" />
              <span className="text-xs font-semibold text-text-primary uppercase tracking-wider">
                Character
              </span>
            </div>
            <div className="grid grid-cols-2 gap-3">
              {character.health !== undefined && <Field label="Health" value={String(character.health)} />}
              {character.maxhealth !== undefined && <Field label="Max Health" value={String(character.maxhealth)} />}
              {character.walkspeed !== undefined && <Field label="Walk Speed" value={String(character.walkspeed)} />}
              {character.jumppower !== undefined && <Field label="Jump Power" value={String(character.jumppower)} />}
              {character.humanoidstate && <Field label="State" value={String(character.humanoidstate)} />}
              {character.rigtype && <Field label="Rig Type" value={String(character.rigtype)} />}
              {character.position && (
                <div className="col-span-2">
                  <Field
                    label="Position"
                    value={`X: ${(character.position as Record<string, number>).x || 0}, Y: ${(character.position as Record<string, number>).y || 0}, Z: ${(character.position as Record<string, number>).z || 0}`}
                  />
                </div>
              )}
            </div>
          </div>
        )}

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
              {game.maxplayers && <Field label="Max Players" value={String(game.maxplayers)} />}
              {game.numplayers !== undefined && <Field label="Players" value={String(game.numplayers)} />}
              {game.isloaded !== undefined && <Field label="Loaded" value={String(game.isloaded)} />}
            </div>
          </div>
        )}

        {/* Environment */}
        {environment && (
          <div className="mb-3">
            <div className="flex items-center gap-2 mb-2">
              <Sun className="w-3.5 h-3.5 text-accent" />
              <span className="text-xs font-semibold text-text-primary uppercase tracking-wider">
                Environment
              </span>
            </div>
            <div className="grid grid-cols-2 gap-3">
              {environment.timeofday && <Field label="Time of Day" value={String(environment.timeofday)} />}
              {environment.brightness !== undefined && <Field label="Brightness" value={String(environment.brightness)} />}
              {environment.camerapos && (
                <div className="col-span-2">
                  <Field
                    label="Camera Position"
                    value={`X: ${(environment.camerapos as Record<string, number>).x || 0}, Y: ${(environment.camerapos as Record<string, number>).y || 0}, Z: ${(environment.camerapos as Record<string, number>).z || 0}`}
                  />
                </div>
              )}
              {environment.camerafov !== undefined && <Field label="Camera FOV" value={String(environment.camerafov)} />}
              {environment.isstudio !== undefined && <Field label="Studio" value={String(environment.isstudio)} />}
              {environment.isclient !== undefined && <Field label="Client" value={String(environment.isclient)} />}
              {environment.isserver !== undefined && <Field label="Server" value={String(environment.isserver)} />}
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
            <div className="grid grid-cols-2 gap-3">
              <Field label="Platform" value={String(device.os)} />
              {device.touchenabled !== undefined && <Field label="Touch" value={String(device.touchenabled)} />}
              {device.mouseenabled !== undefined && <Field label="Mouse" value={String(device.mouseenabled)} />}
              {device.keyboardenabled !== undefined && <Field label="Keyboard" value={String(device.keyboardenabled)} />}
              {device.gamepadenabled !== undefined && <Field label="Gamepad" value={String(device.gamepadenabled)} />}
            </div>
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
