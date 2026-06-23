# Plan de Trabajo — WebhookPulse (Vercel + Supabase)

## Contexto

WebhookPulse esta en produccion en Vercel. El ultimo deploy (commit `941f824`) limpio archivos obsoletos y dejo solo:
- Backend: `api/*.ts` (5 endpoints Vercel)
- Frontend: React + Vite + Tailwind en `src/`
- Script Lua: `roblox/WebhookPulseSender_v2.lua` (unico)
- Supabase: PostgreSQL + Auth + Realtime

## Tareas Pendientes (por prioridad)

---

### Tarea 1: Verificar que el embed muestra datos correctos (CRITICO)

**Objetivo:** Confirmar que el embed en `WebhookDetailPage` ya no muestra "unknown" ni payload vacio.

**Pasos:**
1. Abrir dashboard, entrar al webhook "AXE", revisar los 6 logs existentes.
2. Si el embed muestra datos correctos → esta tarea esta lista.
3. Si sigue mostrando "unknown" o "Payload vacio" → investigar:
   - Revisar tabla `webhook_logs` en Supabase SQL Editor: `SELECT payload FROM webhook_logs WHERE webhook_id = '...' ORDER BY created_at DESC LIMIT 5;`
   - Si `payload` es `{}` o `null` → problema en backend (`api/webhook-receive.ts` no parsea Buffer).
   - Si `payload` tiene datos → problema en frontend (`src/components/RobloxEmbed.tsx` no lee campos).

**Archivos:**
- `api/webhook-receive.ts` (backend)
- `src/components/RobloxEmbed.tsx` (frontend)
- `src/pages/WebhookDetailPage.tsx` (frontend)

---

### Tarea 2: Endpoint CSV Export (`api/webhook-export.ts`)

**Objetivo:** Permitir al usuario descargar los logs de un webhook como archivo CSV.

**Requisitos:**
- GET `/api/webhook-export?webhookId=xxx` con JWT Bearer
- Devuelve CSV con headers: `id,created_at,source_ip,payload_json`
- `payload_json`: JSON.stringify del payload escapado para CSV
- Headers respuesta: `Content-Type: text/csv`, `Content-Disposition: attachment; filename="webhook-logs-{webhookId}.csv"`
- Si no hay logs → CSV con solo headers
- Manejar OPTIONS preflight (CORS)

**Archivo a crear:** `api/webhook-export.ts`
**Pattern a copiar:** `api/webhook-logs.ts` para Supabase, JWT, CORS.

---

### Tarea 3: Boton Export CSV en Frontend

**Objetivo:** Agregar boton "Export CSV" en `WebhookDetailPage`.

**Requisitos:**
- Boton en barra de acciones de logs (junto a "Delete all")
- Llama a `/api/webhook-export?webhookId=xxx`
- Descarga automatica del archivo (blob + URL.createObjectURL + a.click())
- Mostrar spinner mientras se genera

**Archivo a modificar:** `src/pages/WebhookDetailPage.tsx`

---

### Tarea 4: Security Audit + Rate Limiting

**Objetivo:** Proteger endpoints de abuso.

**Requisitos para `api/webhook-receive.ts`:**
1. **Body size limit**: Si body > 256 KB → retornar `413 Payload Too Large`.
2. **Rate limiting por IP**: 10 requests/minuto por IP. Usar tabla `rate_limits` en Supabase o contador en memoria.
3. **Validacion de path**: `url_path` debe ser `[a-zA-Z0-9_-]{1,64}`.
4. **CORS restrictivo**: `Access-Control-Allow-Origin` solo para el dominio de produccion.

**Archivo a modificar:** `api/webhook-receive.ts`

---

### Tarea 5: Paginacion de Logs

**Objetivo:** Actualmente `useRealtimeLogs` limita a 200 logs. Implementar paginacion.

**Requisitos:**
- `useRealtimeLogs` acepta `page` y `pageSize` (default 50)
- Boton "Load more" en `WebhookDetailPage`
- Nuevos logs por realtime se anaden al top

**Archivos:** `src/hooks/useRealtimeLogs.ts`, `src/pages/WebhookDetailPage.tsx`

---

### Tarea 6: Stats Dashboard (Graficos)

**Objetivo:** Pagina de estadisticas con graficos de actividad.

**Requisitos:**
- Nueva ruta: `/dashboard/stats`
- Graficos: Logs por hora (24h), logs por webhook, top IPs, top sources
- Estilo oscuro premium con acento lime

**Archivos:** `src/pages/StatsPage.tsx` (nuevo), `src/App.tsx`, `src/components/Sidebar.tsx`

---

## Reglas de Commit

- Mensajes en ingles: `feat:`, `fix:`, `security:`, `docs:`
- Ejemplo: `feat: CSV export endpoint`, `security: rate limiting and body size cap`
- Siempre `git push origin main` para deploy Vercel automatico

## Reglas de Diseno Visual (NUNCA ROMPER)

- Background: `#0C0C0E`, Surface: `#161618`, Elevated: `#1C1C1E`, Border: `#27272A`
- Acento UNICO: `#D4E83A` (lime)
- NO emojis, iconos Lucide React
- NO degradados, colores solidos oscuros
- Barra lateral lime en embeds estilo Discord
- NUNCA ser generico, siempre premium

## Notas para Claude Code

- El usuario quiere precision extrema, no generico, nivel profesional elite global.
- Siempre leer archivos antes de modificarlos. Nunca modificar de memoria.
- Para Lua: siempre usar `pcall` para llamadas a servicios de Roblox.
- Para backend: siempre manejar OPTIONS preflight, siempre setear CORS headers.
- Para frontend: mantener consistencia visual con el tema oscuro lime.
- Si el usuario pide "mas informacion", referirse a la estructura de payload Roblox.
- Si el usuario reporta errores 404/500, verificar `vercel.json` y variables de entorno.
