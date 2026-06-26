import type { WebhookLog } from '../types'
import { Gamepad2, User, Globe, Smartphone, Cpu, PersonStanding, Sun, Clock, AlertTriangle } from 'lucide-react'
import { getLang } from '../i18n'

interface RobloxEmbedProps {
  log: WebhookLog
}

export default function RobloxEmbed({ log }: RobloxEmbedProps) {
  // Robust payload parsing: handle string, null, or object
  let p: Record<string, unknown> = {}
  try {
    if (typeof log.payload === 'string') {
      p = JSON.parse(log.payload) as Record<string, unknown>
    } else if (log.payload && typeof log.payload === 'object') {
      p = log.payload as Record<string, unknown>
    }
  } catch {
    p = {}
  }

  // Compatibilidad: datos antiguos (planos) y nuevos (anidados en player.*)
  const player = (p.player as Record<string, unknown>) || {}
  const game = (p.game as Record<string, unknown>) || {}
  const device = (p.device as Record<string, unknown>) || {}
  const character = (p.character as Record<string, unknown>) || null
  const environment = (p.environment as Record<string, unknown>) || null
  const executor = (p.executor as Record<string, unknown>) || null

  // Leer de player.* (nuevo) o directamente de p.* (viejo) para compatibilidad
  const getPlayerField = (key: string): unknown => {
    return player[key] !== undefined ? player[key] : p[key]
  }

  const hasAnyData =
    Object.keys(p).length > 0 &&
    (p.source === 'roblox' || getPlayerField('userid') !== undefined || getPlayerField('username') !== undefined)

  const timestamp = p.timestamp
    ? new Date((p.timestamp as number) * 1000).toLocaleString(getLang() === 'es' ? 'es-ES' : 'en-US', {
        year: 'numeric',
        month: 'short',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
      })
    : new Date(log.created_at).toLocaleString(getLang() === 'es' ? 'es-ES' : 'en-US')

  const Field = ({ label, value }: { label: string; value: string }) => (
    <div className="flex flex-col gap-0.5">
      <span className="text-[10px] uppercase tracking-wider text-text-secondary font-semibold">
        {label}
      </span>
      <span className="text-sm text-text-primary font-mono">{value}</span>
    </div>
  )

  return (
    <div className="flex rounded-lg overflow-hidden bg-elevated border border-border my-2">
      {/* Barra lateral estilo Discord embed - lime */}
      <div className="w-1 shrink-0 bg-accent" />

      <div className="flex-1 p-4">
        {/* Header con icono y timestamp */}
        <div className="flex items-center gap-3 mb-4">
          <div className="w-10 h-10 rounded-full bg-accent/10 flex items-center justify-center">
            <Gamepad2 className="w-5 h-5 text-accent" />
          </div>
          <div className="flex-1">
            <div className="text-sm font-semibold text-text-primary">
              Roblox Profile Data
            </div>
            <div className="flex items-center gap-1.5 text-xs text-text-secondary mt-0.5">
              <Clock className="w-3 h-3" />
              {timestamp}
            </div>
          </div>
          <div className="text-xs text-text-secondary">
            IP: {log.ip_address || 'Unknown'}
          </div>
        </div>

        {!hasAnyData && (
          <div className="flex items-center gap-2 p-3 bg-danger/10 border border-danger/20 rounded mb-4">
            <AlertTriangle className="w-4 h-4 text-danger shrink-0" />
            <span className="text-sm text-danger">
              Payload vacio o corrupto. El webhook recibio la peticion pero los datos no se guardaron correctamente.
            </span>
          </div>
        )}

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

        {/* Player - Compatibilidad: player.* o directo */}
        <div className="grid grid-cols-2 gap-3 mb-4">
          <Field label="UserId" value={String(getPlayerField('userid') || '-')} />
          <Field label="Username" value={String(getPlayerField('username') || '-')} />
          <Field label="Display Name" value={String(getPlayerField('displayname') || '-')} />
          <Field label="Account Age" value={String(getPlayerField('accountage') || '-')} />
          <Field label="Membership" value={String(getPlayerField('membership') || '-')} />
          <Field label="Country" value={String(getPlayerField('country') || '-')} />
          {getPlayerField('team') && <Field label="Team" value={String(getPlayerField('team'))} />}
          {getPlayerField('teamcolor') && <Field label="Team Color" value={String(getPlayerField('teamcolor'))} />}
          {getPlayerField('neutral') !== undefined && <Field label="Neutral" value={String(getPlayerField('neutral'))} />}
          {getPlayerField('characterappearanceid') && (
            <Field label="Appearance ID" value={String(getPlayerField('characterappearanceid'))} />
          )}
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

        {/* Game */}
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
              {game.gameid && <Field label="Game ID" value={String(game.gameid)} />}
              {game.creatorid && <Field label="Creator ID" value={String(game.creatorid)} />}
              {game.creatortype && <Field label="Creator Type" value={String(game.creatortype)} />}
              {game.placeversion && <Field label="Place Version" value={String(game.placeversion)} />}
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
              {environment.clocktime !== undefined && <Field label="Clock Time" value={String(environment.clocktime)} />}
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

        {/* Device */}
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
              {device.accelerometerenabled !== undefined && <Field label="Accelerometer" value={String(device.accelerometerenabled)} />}
              {device.gyroscopeenabled !== undefined && <Field label="Gyroscope" value={String(device.gyroscopeenabled)} />}
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
        </div>
      </div>
    </div>
  )
}
