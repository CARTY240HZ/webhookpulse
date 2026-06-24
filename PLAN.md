# Plan de Trabajo — WebhookPulse (Vercel + Supabase)

## Contexto

WebhookPulse esta en produccion en Vercel. El ultimo deploy (commit `70d2f06`) agrego:
- **Sentry**: Backend (`@sentry/node`) + Frontend (`@sentry/react`) con captura de errores
- **Tests**: Vitest + unit tests para `_lib/` (validate, cors, hmac) + integration test para `webhook-receive`
- **Shared Infrastructure**: `api/_lib/` con 8 modulos reutilizables (supabase, cors, auth, validate, ratelimit, hmac, errors, sentry)
- **Security Hardening**: 12 fixes completos (HMAC secrets, rate limit, body cap, CORS, headers filter, UUID validation, honeypot, webhook limit, DB index)
- **CSV Export**: `api/webhook-export.ts` + boton en frontend
- **Paginacion**: "Load more" en logs (50 por pagina)
- **Stats Dashboard**: 4 graficos + tarjetas resumen
- Cleanup: archivos obsoletos de Netlify/Redis borrados
- Script Lua unico: `roblox/WebhookPulseSender_v2.lua`

## Estado de Tareas

| # | Tarea | Estado | Commit |
|---|-------|--------|--------|
| 1 | Verificar embed (no "unknown") | ✅ Hecho | `14e7248` |
| 2 | Endpoint CSV Export | ✅ Hecho | `97e3c61` |
| 3 | Boton Export CSV en frontend | ✅ Hecho | `97e3c61` |
| 4 | Security Audit + Rate Limiting | ✅ Hecho | `09962af` |
| 5 | Paginacion de Logs | ✅ Hecho | `b92b4e9` |
| 6 | Stats Dashboard (Graficos) | ✅ Hecho | `ffd14d9` |
| 7 | Shared Infrastructure (`api/_lib/`) | ✅ Hecho | `251dcf0` |
| 8 | Security Hardening (12 fixes) | ✅ Hecho | `251dcf0` + `872cbed` |
| 9 | Tests (Vitest) | ✅ Hecho | `c5d0bed` |
| 10 | Sentry (backend + frontend) | ✅ Hecho | `70d2f06` |

---

## Security Fixes (12/12 completos)

| ID | Severidad | Fix | Commit |
|----|-----------|-----|--------|
| S1 | Critico | CORS restrictivo en auth endpoints (`getCorsHeaders('private')`) | `251dcf0` |
| S2 | Critico | HMAC-SHA256 para secrets (`_lib/hmac.ts`) | `872cbed` |
| S3 | Critico | No exponer `error.details` al cliente (`apiError()`) | `251dcf0` |
| S4 | Critico | Filtrar headers (whitelist) antes de guardar en DB | `251dcf0` |
| S5 | Alto | No devolver `secret` en `webhook-list` | `251dcf0` |
| S6 | Alto | DB index `idx_webhook_logs_ip` para rate limit | `872cbed` (SQL) |
| S7 | Alto | Cap 10,000 filas en export + `X-Truncated` header | `251dcf0` |
| S8 | Alto | Validacion UUID en `webhook-delete`, `webhook-logs`, `webhook-export` | `251dcf0` |
| S9 | Medio | Limite 20 webhooks por usuario (`MAX_WEBHOOKS_PER_USER`) | `872cbed` |
| S10 | Medio | Honeypot 200 siempre en `webhook-receive` | `251dcf0` |
| S11 | Medio | Singleton Supabase (`_lib/supabase.ts`) | `251dcf0` |
| S12 | Medio | Limite name (100) / description (500) chars | `251dcf0` |

---

## Fases de Implementacion

| Fase | Scope | Estado | Commit |
|------|-------|--------|--------|
| 1+2 | `api/_lib/` + refactor 6 endpoints + S1/S3/S4/S5/S7/S8/S10/S11/S12 | ✅ Hecho | `251dcf0` |
| 3 | S2 (HMAC secrets) + S6 (index) + migracion SQL + endpoint `migrate-secrets` | ✅ Hecho | `872cbed` |
| 4 | S7 (export cap) + S9 (webhook limit) | ✅ Hecho | `872cbed` |
| 5 | Tests (vitest + unit + integration) | ✅ Hecho | `c5d0bed` |
| 6 | Sentry (backend + frontend) | ✅ Hecho | `70d2f06` |

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
