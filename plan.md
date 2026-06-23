# WebhookPulse — Plan de Ejecución

## Objetivo
Dashboard profesional para recibir, inspeccionar y gestionar webhooks de Discord (y genéricos). Publicado en Netlify. Diseño AAA oscuro premium.

## Stack
- **Frontend**: React 18 + TypeScript + Vite + Tailwind CSS + React Router DOM + Lucide React
- **Backend**: Netlify Functions (Node.js/TypeScript)
- **Database + Auth**: Supabase (PostgreSQL + Auth + Realtime)
- **Hosting**: Netlify (static + functions)

## Diseño Visual (NO genérico)
- Fondo: `#0C0C0E`
- Surface: `#161618`
- Elevated: `#1C1C1E`
- Border: `#27272A`
- Text primary: `#FAFAFA`
- Text secondary: `#A1A1AA`
- Acento: `#D4E83A`
- Acento hover: `#E8F96A`
- Danger: `#EF4444`
- Success: `#22C55E`
- Font: Inter (Google Fonts)
- Border radius: `8px`
- Sombras: ninguna o muy sutiles (`0 1px 2px rgba(0,0,0,0.3)`)
- Transiciones: `150ms ease`
- Sin emojis. Iconos: Lucide React (vectoriales puros).

## Arquitectura de Datos (Supabase)

### Tablas
```sql
profiles:
  id uuid PK (refs auth.users)
  full_name text
  avatar_url text
  created_at timestamp

webhooks:
  id uuid PK default gen_random_uuid()
  user_id uuid FK profiles.id
  name text not null
  description text
  url_path text not null unique
  secret text
  is_active boolean default true
  created_at timestamp
  updated_at timestamp

webhook_logs:
  id uuid PK default gen_random_uuid()
  webhook_id uuid FK webhooks.id
  payload jsonb not null
  headers jsonb
  ip_address inet
  created_at timestamp
```

### RLS
- Todos los SELECT/INSERT/UPDATE/DELETE protegidos por `auth.uid() = user_id`.
- `webhook_logs` accesible solo a través de `webhook_id` cuyo `user_id` coincide.

## Netlify Functions

| Ruta | Método | Auth | Descripción |
|------|--------|------|-------------|
| `/.netlify/functions/webhook-receive` | POST | Ninguna (valida secret opcional) | Recibe payload, headers, IP. Inserta en `webhook_logs`. |
| `/.netlify/functions/webhook-list` | GET | Supabase JWT | Lista webhooks del usuario. |
| `/.netlify/functions/webhook-logs` | GET | Supabase JWT | Lista logs de un webhook. |
| `/.netlify/functions/webhook-create` | POST | Supabase JWT | Crea nuevo webhook. |
| `/.netlify/functions/webhook-delete` | DELETE | Supabase JWT | Elimina webhook + logs. |

Nota: el endpoint público de recepción usa `url_path` como identificador único (ej: `https://webhookpulse.netlify.app/.netlify/functions/webhook-receive?path=<url_path>`).

## Rutas Frontend

| Ruta | Descripción |
|------|-------------|
| `/` | Landing page (hero + features + CTA) |
| `/login` | Login con Supabase Auth |
| `/register` | Registro con Supabase Auth |
| `/dashboard` | Dashboard principal: lista de webhooks, estado, contadores |
| `/dashboard/webhooks/:id` | Detalle de webhook: configuración + logs en tiempo real |
| `/dashboard/settings` | Configuración de perfil |

## Componentes Compartidos (Layout)
- `Sidebar` — navegación principal, colapsable en móvil
- `TopBar` — usuario, logout, indicador de conexión realtime
- `WebhookCard` — tarjeta de webhook con estado, URL copiable, contador de logs
- `LogRow` — fila de log con payload colapsable, timestamp, IP
- `PayloadViewer` — JSON viewer con syntax highlighting básico

## Etapas de Ejecución
1. Designer: crear `design/design.md` con especificaciones visuales exactas
2. Scaffold: inicializar Vite + React + TS + Tailwind, instalar deps, configurar theme global
3. Backend worker: implementar Netlify Functions + schema SQL + Supabase client
4. Frontend worker: implementar páginas, componentes, auth context, hooks de Supabase
5. Integración: merge, config `netlify.toml`, build, verificar

## Validación Final
- `npm run build` exitoso
- Login/registro funcional
- Crear webhook → generar URL única
- Enviar POST a URL → aparece en dashboard en tiempo real
- Sin errores de TypeScript
- Sin emojis en UI
- Diseño fiel al sistema de colores especificado
