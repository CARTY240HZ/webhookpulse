# WebhookPulse — Contexto para Claude Code

## Qué es WebhookPulse

WebhookPulse es una plataforma de recepción y monitoreo de webhooks. Diseño AAA oscuro premium con acento lime (`#D4E83A`). No uses emojis, no seas genérico. Nivel profesional elite global.

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
│   ├── webhook-logs.ts           # GET/DELETE /api/webhook-logs
│   └── webhook-export.ts         # (PENDIENTE) GET /api/webhook-export?webhookId=xxx
├── src/
│   ├── components/
│   │   ├── WebhookCard.tsx       # Card embed estilo Discord (barra lime)
│   │   ├── LogRow.tsx            # Fila de log con checkbox + expand
│   │   ├── RobloxEmbed.tsx       # Embed visual para datos Roblox (se muestra siempre)
│   │   ├── PayloadViewer.tsx     # JSON syntax highlight
│   │   ├── CreateWebhookModal.tsx
│   │   ├── Layout.tsx, Sidebar.tsx, TopBar.tsx
│   ├── pages/
│   │   ├── DashboardPage.tsx     # Lista de webhooks (cards con embed)
│   │   ├── WebhookDetailPage.tsx # Logs + batch delete (select all / selected / all)
│   │   ├── LoginPage.tsx, RegisterPage.tsx, ForgotPasswordPage.tsx, ResetPasswordPage.tsx
│   │   ├── LandingPage.tsx
│   │   └── SettingsPage.tsx
│   ├── hooks/
│   │   ├── useAuth.tsx
│   │   ├── useWebhooks.ts        # CRUD de webhooks vía Supabase
│   │   └── useRealtimeLogs.ts    # Logs en tiempo real + delete batch
│   ├── lib/
│   │   └── supabase.ts           # Cliente Supabase (anon key)
│   ├── types/                    # Tipos TypeScript (interface WebhookLog, Webhook, etc.)
│   ├── App.tsx                   # React Router
│   ├── main.tsx
│   └── index.css
├── roblox/                       # Scripts Lua para ejecutores
│   ├── WebhookPulseSender_v2.lua # Script completo con 30+ campos (USAR ESTE)
│   ├── WebhookPulseSender_v2-Diagnostic.lua
│   ├── WebhookPulseSender.lua    # v1 obsoleto
│   └── WebhookPulse_ULTRA_MINIMAL.lua
├── supabase/
│   └── schema.sql                # Schema de PostgreSQL + RLS + triggers + policies
├── vercel.json                   # Config de Vercel (SPA + API routing)
├── package.json
├── vite.config.ts
├── tailwind.config.js
└── tsconfig.json
```

## Variables de Entorno (Vercel)

| Variable | Value | Scope |
|----------|-------|-------|
| `SUPABASE_URL` | `https://mcaegcbghyuxpfzxkioq.supabase.co` | Backend |
| `SUPABASE_SERVICE_KEY` | service_role key (secreto) | Backend |
| `VITE_SUPABASE_URL` | `https://mcaegcbghyuxpfzxkioq.supabase.co` | Frontend (build-time) |
| `VITE_SUPABASE_ANON_KEY` | anon key (público) | Frontend (build-time) |

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

## API Endpoints (Backend Vercel)

| Endpoint | Método | Auth | Descripción |
|----------|--------|------|-------------|
| `/api/webhook-receive?path=xxx` | POST | No (opcional `X-Webhook-Secret`) | Recibe payload JSON, parsea Buffer si es necesario, guarda en webhook_logs con IP |
| `/api/webhook-list` | GET | JWT Bearer | Lista webhooks del usuario con log_count |
| `/api/webhook-create` | POST | JWT Bearer | Crea nuevo webhook con url_path aleatorio |
| `/api/webhook-delete?id=xxx` | DELETE | JWT Bearer | Elimina webhook + sus logs |
| `/api/webhook-logs?webhookId=xxx` | GET | JWT Bearer | Lista logs de un webhook (usado por frontend, pero frontend usa Supabase directamente) |
| `/api/webhook-logs?webhookId=xxx` | DELETE | JWT Bearer | Batch delete logs (all o selected por body) |

> **Nota:** El frontend usa `useRealtimeLogs` que lee directamente de Supabase (no del backend), pero el backend tiene endpoints para operaciones que requieren auth.

## Payload Roblox (Estructura Anidada — v2)

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
    "neutral": false,
    "premium": false,
    "verified": false,
    "friends": ["Friend1", "Friend2"],
    "locale": "es-ES",
    "characterappearanceid": 0,
    "avatarheadshot": "https://..."
  },
  "character": {
    "health": 100,
    "maxhealth": 100,
    "walkspeed": 16,
    "jumppower": 50,
    "humanoidstate": "Running",
    "rigtype": "R15",
    "position": { "x": 123, "y": 45, "z": 67 },
    "velocity": { "x": 0, "y": 0, "z": 0 }
  },
  "game": {
    "placeid": 95746849517424,
    "jobid": "uuid",
    "gameid": 0,
    "creatorid": 0,
    "creatortype": "User",
    "placeversion": 0,
    "gamename": "Aura",
    "maxplayers": 10,
    "numplayers": 5,
    "isloaded": true,
    "privateserverid": null,
    "privateserverownerid": null,
    "vipserverid": null,
    "vipserverownerid": null,
    "genre": "All"
  },
  "environment": {
    "timeofday": "14:30:00",
    "brightness": 2,
    "clocktime": 14.5,
    "geographiclatitude": 23,
    "ambient": "0, 0, 0",
    "outdoorambient": "0, 0, 0",
    "camerapos": { "x": 0, "y": 10, "z": 0 },
    "camerafov": 70,
    "isstudio": false,
    "isclient": true,
    "isserver": false
  },
  "device": {
    "os": "Enum.Platform.Windows",
    "touchenabled": false,
    "mouseenabled": true,
    "keyboardenabled": true,
    "gamepadenabled": false,
    "accelerometerenabled": false,
    "gyroscopeenabled": false,
    "screenresolution": "1920x1080"
  }
}
```

## Diseño Visual (CRÍTICO — Nunca romper esto)

- **Background**: `#0C0C0E` (Color3.fromRGB(12,12,14))
- **Surface**: `#161618`
- **Elevated**: `#1C1C1E`
- **Border**: `#27272A`
- **Accent**: `#D4E83A` (lime) — ÚNICO color de acento permitido
- **Accent Hover**: `#E8F96A`
- **Danger**: `#EF4444`
- **Success**: `#22C55E`
- **Text Primary**: `#FAFAFA`
- **Text Secondary**: `#A1A1AA`
- **Font**: Inter (Gotham en Roblox GUI)
- **NO emojis**, iconos vectoriales puros (Lucide React)
- **NO degradados**, colores sólidos oscuros
- **Barra lateral lime** (`w-1 bg-accent`) en embeds estilo Discord
- **NO ser genérico**: cada componente debe sentirse premium, no bootstrap

## Reglas de Desarrollo (Pitfalls conocidos)

1. **Lua `trim()` no existe**: Usa `url:match("^%s*(.-)%s*$")`. Nunca `url:trim()`.
2. **HTTP en Roblox cliente**: `HttpService:PostAsync` está bloqueado. Usar `request()` (Wave/KRNL) o `syn.request` (Synapse).
3. **Vercel `req.body`**: Siempre puede ser `Buffer`. Verificar con `Buffer.isBuffer(req.body)` y convertir con `req.body.toString('utf-8')` antes de `JSON.parse`.
4. **IP en PostgreSQL**: `x-forwarded-for` puede ser `"79.117.192.163, 3.126.42.106"`. Extraer `String(rawIp).split(',')[0].trim()`. Si falla la inserción por `inet`, retry con `null`.
5. **RLS**: `webhooks` insert requiere `user_id` para que RLS permita la inserción.
6. **SPA Routing**: `vercel.json` debe reescribir rutas a `index.html` para React Router.
7. **Supabase Realtime**: Usa `supabase.channel().on('postgres_changes', ...).subscribe()` para logs en tiempo real.
8. **TypeScript types**: Los tipos están en `src/types/index.ts` (no en `src/types.ts` como algunos proyectos).

## Comandos Útiles

```bash
# Desarrollo local
npm run dev

# Build (para Vercel)
npm run build

# Git push (Vercel auto-deploy)
git add . && git commit -m "mensaje" && git push origin main

# Vercel CLI (si lo tienes instalado)
vercel --prod
```

## Estado Actual (último deploy: 14e7248)

- [x] Frontend React con auth completo (login, register, forgot, reset)
- [x] Backend Vercel functions (5 endpoints)
- [x] Supabase schema con RLS + triggers
- [x] Roblox script v2 con payload extendido (30+ campos)
- [x] Embed visual estilo Discord para logs Roblox (se muestra SIEMPRE sin expandir)
- [x] Batch delete logs (select all / selected / all) con checkbox
- [x] Webhook cards con estilo embed (barra lime + mensajes recibidos + path + secret)
- [x] Fix Buffer body parsing en Vercel (req.body puede ser Buffer, string, u objeto)
- [x] Fix RobloxEmbed robusto (parsea string payload, muestra error si vacío)
- [x] Fix delete individual en LogRow (onDelete pasado desde WebhookDetailPage)
- [x] vercel.json configurado con SPA routing + API rewrites
- [x] Script Lua validación URL menos restrictiva (acepta cualquier dominio con `webhook-receive`)
- [ ] Verificar que el deploy Vercel renderiza el embed con datos correctos (no "unknown")
- [ ] Endpoint CSV export (`api/webhook-export.ts`)
- [ ] Endpoint Discord reenvío (`api/webhook-discord.ts`)
- [ ] Rate limiting en backend
- [ ] Body size limit en backend
- [ ] Pagination en logs (solo 200 por ahora)
- [ ] Filtros/search en logs
- [ ] Stats dashboard (gráficos de actividad)

## Notas para Claude Code

- El usuario quiere **precisión extrema**, **no genérico**, **nivel profesional elite global**.
- Si el usuario pide "más información", referirse a la estructura de payload Roblox y sugerir qué campos adicionales pueden ser útiles.
- Si el usuario pide "mejorar el embed", mantener el estilo oscuro premium con acento lime. Nunca añadir emojis.
- Si el usuario reporta errores 404/500, verificar `vercel.json` y las variables de entorno primero.
- Si el usuario pide integración con Discord webhooks, crear un endpoint separado que reenvíe los datos a un webhook de Discord externo.
- Si el usuario dice que "no funciona", verificar: (1) payload se parsea correctamente en backend, (2) Supabase guarda el JSON, (3) frontend lee el payload correctamente.
- Siempre leer el archivo real antes de modificarlo. Nunca modificar de memoria.
- Para Lua: siempre usar `pcall` para llamadas a servicios de Roblox (MarketplaceService, LocalizationService, etc.).
- Para frontend: siempre mantener la consistencia visual con el diseño definido arriba.
- Para backend: siempre manejar `OPTIONS` preflight, siempre setear CORS headers.
