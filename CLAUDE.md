# WebhookPulse — Contexto para Claude Code

## Qué es WebhookPulse

WebhookPulse es una plataforma de recepción y monitoreo de webhooks. Diseño AAA oscuro premium con acento lime (`#D4E83A`). No uses emojis, no seas genérico.

## Stack Tecnológico

| Capa | Tecnología |
|------|------------|
| **Frontend** | React 18 + TypeScript + Vite + Tailwind CSS (custom dark theme) |
| **Backend** | Vercel Serverless Functions (`api/*.ts`) |
| **Database** | Supabase (PostgreSQL + Auth + Realtime) |
| **Auth** | Supabase Auth (email/password, JWT) |
| **Deploy** | Vercel (conectado a GitHub `CARTY240HZ/webhookpulse`) |
| **Roblox Script** | Lua para ejecutores (Wave, KRNL, Synapse) |

## Estructura de Directorios

```
webhookpulse/
├── api/                          # Vercel serverless functions
│   ├── webhook-receive.ts        # POST /api/webhook-receive?path=xxx
│   ├── webhook-list.ts           # GET /api/webhook-list
│   ├── webhook-create.ts         # POST /api/webhook-create
│   ├── webhook-delete.ts         # DELETE /api/webhook-delete
│   └── webhook-logs.ts           # GET/DELETE /api/webhook-logs
├── src/
│   ├── components/               # React components
│   │   ├── WebhookCard.tsx       # Card embed estilo Discord
│   │   ├── LogRow.tsx            # Fila de log con checkbox
│   │   ├── RobloxEmbed.tsx       # Embed visual para datos Roblox
│   │   ├── PayloadViewer.tsx     # JSON syntax highlight
│   │   └── LogRow.tsx            # Checkbox + expand + delete
│   ├── pages/                    # Rutas de React Router
│   │   ├── DashboardPage.tsx     # Lista de webhooks
│   │   ├── WebhookDetailPage.tsx # Logs + batch delete
│   │   ├── LoginPage.tsx         # Auth login
│   │   ├── RegisterPage.tsx      # Auth register
│   │   └── SettingsPage.tsx      # Perfil de usuario
│   ├── hooks/
│   │   ├── useWebhooks.ts        # CRUD de webhooks vía Supabase
│   │   └── useRealtimeLogs.ts    # Logs en tiempo real + delete
│   ├── lib/
│   │   └── supabase.ts           # Cliente Supabase (anon key)
│   └── types/
│       └── index.ts              # Tipos TypeScript
├── roblox/                       # Scripts Lua para ejecutores
│   └── WebhookPulseSender_v2.lua # Script completo con 25+ campos
├── supabase/
│   └── schema.sql                # Schema de PostgreSQL + RLS + triggers
├── vercel.json                   # Config de Vercel (SPA + API)
└── package.json                 # Vite + React + Tailwind
```

## Variables de Entorno (Vercel)

| Variable | Value |
|----------|-------|
| `SUPABASE_URL` | `https://mcaegcbghyuxpfzxkioq.supabase.co` |
| `SUPABASE_SERVICE_KEY` | service_role key (backend) |
| `VITE_SUPABASE_URL` | `https://mcaegcbghyuxpfzxkioq.supabase.co` |
| `VITE_SUPABASE_ANON_KEY` | anon key (frontend) |

## Database Schema (Supabase)

### Tablas

- `profiles` (extends `auth.users`): id, full_name, avatar_url, created_at
- `webhooks`: id, user_id, name, description, url_path, secret, is_active, created_at, updated_at
- `webhook_logs`: id, webhook_id, payload (jsonb), headers (jsonb), ip_address (inet), created_at

### RLS Policies

- `webhooks`: SELECT/INSERT/UPDATE/DELETE solo por `auth.uid() = user_id`
- `webhook_logs`: INSERT público (vía webhook-receive), SELECT solo por owner del webhook
- `profiles`: SELECT público, INSERT/UPDATE solo por owner

### Triggers

- `on_auth_user_created`: Auto-crea perfil en `profiles` cuando un usuario se registra.

## API Endpoints

| Endpoint | Método | Auth | Descripción |
|----------|--------|------|-------------|
| `/api/webhook-receive?path=xxx` | POST | No (opcional secret) | Recibe payload, guarda en webhook_logs |
| `/api/webhook-list` | GET | JWT Bearer | Lista webhooks del usuario con log_count |
| `/api/webhook-create` | POST | JWT Bearer | Crea nuevo webhook |
| `/api/webhook-delete?id=xxx` | DELETE | JWT Bearer | Elimina webhook + logs |
| `/api/webhook-logs?webhookId=xxx` | GET | JWT Bearer | Lista logs de un webhook |
| `/api/webhook-logs?webhookId=xxx` | DELETE | JWT Bearer | Batch delete logs (all o selected) |

## Payload Roblox (Estructura Anidada)

```json
{
  "source": "roblox",
  "timestamp": 1234567890,
  "executor": { "name": "Wave" },
  "player": {
    "userid": 2503068534,
    "username": "Focusjutsu",
    "displayname": "Focusjutsu",
    "accountage": 365,
    "membership": "None",
    "country": "ES",
    "team": "TeamName",
    "teamcolor": "Bright red",
    "neutral": false
  },
  "character": {
    "health": 100,
    "maxhealth": 100,
    "walkspeed": 16,
    "jumppower": 50,
    "position": { "x": 123, "y": 45, "z": 67 }
  },
  "game": {
    "placeid": 95746849517424,
    "jobid": "uuid",
    "gamename": "Aura",
    "maxplayers": 10,
    "numplayers": 5
  },
  "environment": {
    "timeofday": "14:30:00",
    "brightness": 2,
    "camerapos": { "x": 0, "y": 10, "z": 0 }
  },
  "device": {
    "os": "Enum.Platform.Windows"
  }
}
```

## Diseño Visual (CRÍTICO)

- **Background**: `#0C0C0E` (Color3.fromRGB(12,12,14))
- **Surface**: `#161618`
- **Elevated**: `#1C1C1E`
- **Border**: `#27272A`
- **Accent**: `#D4E83A` (lime)
- **Accent Hover**: `#E8F96A`
- **Text Primary**: `#FAFAFA`
- **Text Secondary**: `#A1A1AA`
- **Danger**: `#EF4444`
- **Success**: `#22C55E`
- **Font**: Inter (Gotham en Roblox)
- **NO emojis**, iconos vectoriales puros (Lucide React)
- **NO degradados**, colores sólidos oscuros
- **Barra lateral lime** en embeds estilo Discord

## Reglas de Desarrollo

1. **Nunca uses `url:trim()` en Lua** — Lua no tiene `trim()`. Usa `url:match("^%s*(.-)%s*$")`.
2. **HTTP en Roblox**: Usa `request()` (Wave/KRNL) o `syn.request` (Synapse), no `HttpService:PostAsync` (bloqueado en clientes).
3. **IP en PostgreSQL**: `x-forwarded-for` puede traer múltiples IPs separadas por coma. Extraer solo la primera.
4. **RLS**: Siempre insertar `user_id` en `webhooks` para que RLS funcione.
5. **SPA**: `vercel.json` debe tener rewrites para que React Router funcione.

## Comandos Útiles

```bash
# Desarrollo local
npm run dev

# Build
npm run build

# Git
git add . && git commit -m "mensaje" && git push origin main

# Vercel (si tienes CLI de Vercel)
vercel --prod
```

## Estado Actual (último deploy)

- [x] Frontend React con auth completo
- [x] Backend Vercel functions (5 endpoints)
- [x] Supabase schema con RLS
- [x] Roblox script v2 con payload extendido
- [x] Embed visual estilo Discord para logs Roblox
- [x] Batch delete logs (select all / selected / all)
- [x] Webhook cards con estilo embed (barra lime)
- [ ] Vercel deploy: verificar que `vercel.json` funcione correctamente

## Notas para Claude

- Si el usuario pide "más información", referirse a la estructura de payload Roblox y sugerir qué campos adicionales pueden ser útiles (ej: friends list, inventory, etc.).
- Si el usuario pide "mejorar el embed", mantener el estilo oscuro premium con acento lime.
- Si el usuario reporta errores 404/500, verificar `vercel.json` y las variables de entorno.
- Si el usuario pide integración con Discord webhooks, crear un endpoint separado que reenvíe los datos.
