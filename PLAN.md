# Plan de Trabajo — WebhookPulse (Vercel + Supabase)

## Contexto

WebhookPulse esta en produccion en Vercel. El ultimo deploy (commit `09962af`) agrego:
- **CSV Export**: `api/webhook-export.ts` + boton en frontend
- **Security**: rate limiting (10 req/min por IP), body size cap (256 KB), path validation
- Cleanup: archivos obsoletos de Netlify/Redis borrados
- Script Lua unico: `roblox/WebhookPulseSender_v2.lua`

## Estado de Tareas

| # | Tarea | Estado | Commit |
|---|-------|--------|--------|
| 1 | Verificar embed (no "unknown") | ✅ Hecho | `14e7248` (Buffer fix + RobloxEmbed robusto) |
| 2 | Endpoint CSV Export | ✅ Hecho | `97e3c61` (`api/webhook-export.ts`) |
| 3 | Boton Export CSV en frontend | ✅ Hecho | `97e3c61` (`WebhookDetailPage.tsx`) |
| 4 | Security + Rate Limiting | ✅ Hecho | `09962af` (body cap, rate limit, path validation) |
| 5 | Paginacion de Logs | ✅ Hecho | `b92b4e9` (`useRealtimeLogs` + `Load more`) |
| 6 | Stats Dashboard (Graficos) | ✅ Hecho | `ffd14d9` (`StatsPage.tsx` + SVG charts) |

---

### Tarea 1: Verificar que el embed muestra datos correctos (CRITICO) — ✅ HECHO

**Implementado en:** `14e7248`

- Buffer body parsing fix en `api/webhook-receive.ts`
- `RobloxEmbed.tsx` robusto con deteccion de payload vacio/corrupto
- Compatibilidad con payload anidado (`player.*`) y plano (`p.*`)

---

### Tarea 2: Endpoint CSV Export (`api/webhook-export.ts`) — ✅ HECHO

**Implementado en:** `97e3c61`

- `api/webhook-export.ts` creado con Supabase, JWT, CORS
- Devuelve CSV con `id,created_at,source_ip,payload_json`
- `Content-Disposition: attachment` para descarga automatica

---

### Tarea 3: Boton Export CSV en Frontend — ✅ HECHO

**Implementado en:** `97e3c61`

- Boton "Export CSV" con icono `Download` en barra de acciones de logs
- Descarga automatica via blob + `URL.createObjectURL`
- Spinner "Exporting..." mientras se genera

---

### Tarea 4: Security Audit + Rate Limiting — ✅ HECHO

**Implementado en:** `09962af`

- **Body size cap**: 256 KB maximo → retorna `413 Payload Too Large`
- **Rate limit**: 10 requests/minuto por IP, usando `webhook_logs` tabla para contar
- **Path validation**: regex `^[a-zA-Z0-9_-]{1,64}$` previene inyeccion/DoS
- **IP safe**: fallback a `null` si PostgreSQL `inet` rechaza el formato

---

### Tarea 5: Paginacion de Logs — ✅ HECHO

**Implementado en:** `b92b4e9`

- `useRealtimeLogs` ahora usa paginacion con `.range()` (50 logs por pagina)
- Boton "Load more" en `WebhookDetailPage` para cargar mas logs
- Nuevos logs por realtime se anaden al top correctamente
- Estado `loadingMore` + `hasMore` para controlar la carga

---

### Tarea 6: Stats Dashboard (Graficos) — ✅ HECHO

**Implementado en:** `ffd14d9`

- Nueva ruta `/dashboard/stats` con navegacion en Sidebar
- 4 tarjetas de resumen: Total logs, Webhooks, Unique IPs, Sources
- Grafico de barras: Logs por hora (ultimas 24h)
- Grafico de barras: Logs por webhook
- Grafico de barras horizontal: Top 10 IPs
- Donut chart SVG: Distribucion de sources (roblox vs otros)
- Todos los graficos en tema oscuro premium con acento lime
- Sin librerias externas (CSS puro + SVG)

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
