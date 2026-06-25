# AGENT_SPEC: WebhookPulse Mejoras Élite

## Objetivo
Implementar 5 mejoras de élite en WebhookPulse que elevan el producto a nivel de plataforma profesional de recepción y monitoreo de webhooks.

## Stack Actual
- Frontend: React 18 + TypeScript + Vite + Tailwind CSS
- Backend: Vercel Serverless Functions (Node.js + TypeScript)
- DB: Supabase PostgreSQL + Auth + Realtime
- Auth: JWT Supabase (migrando a bcrypt propio en roadmap)
- i18n: Sistema ES/EN propio (`src/i18n/`)
- Tema: Dark/Light real con Tailwind class strategy

## Vulnerabilidad a Arreglar (bloqueante)
- `src/components/PayloadViewer.tsx:27` — `dangerouslySetInnerHTML` sin sanitización. Reemplazar por renderizado seguro con `dompurify` o función de escape.

## Mejoras (orden de implementación)

### Feature 1: Webhook Templates para Roblox (Élite)
- **Backend**: Nuevo endpoint `POST /api/webhook-template` que genera scripts Lua preconfigurados según el tipo de template.
- **Frontend**: Nueva sección en Dashboard "Templates" con cards de templates predefinidos:
  - **Player Join** → payload con datos de jugador que entra al juego
  - **Server Stats** → payload con estadísticas de instancia (players, FPS, memoria)
  - **Error Logger** → payload con error + stack trace + contexto
  - **Admin Command** → payload con comando ejecutado + args + ejecutor
- **Acción**: Click en template → genera script Lua listo para copiar y pegar en ZEX
- **UI**: Cards con icono, descripción, preview del payload, botón "Generate Lua Script"

### Feature 2: Búsqueda Avanzada en Logs (Élite)
- **Backend**: Extender `GET /api/webhook-logs` con query params: `q` (search en payload), `ip`, `type` (native/discord), `from`, `to` (fechas), `source` (roblox/etc)
- **Frontend**: Barra de búsqueda en WebhookDetailPage con:
  - Input de texto libre (busca en payload JSON)
  - Filtro de fecha (rango)
  - Filtro de IP
  - Filtro de tipo de webhook
  - Botón "Clear filters"
- **DB**: Agregar índice GIN en `webhook_logs.payload` para búsqueda JSONB eficiente

### Feature 3: IP Allowlist / Blocklist (Seguridad Élite)
- **Backend**: Nuevo endpoint `POST /api/webhook-ip-rules` para CRUD de reglas por webhook:
  - `action`: 'allow' | 'block'
  - `ip`: IP o CIDR (ej: `192.168.1.0/24`)
  - `description`: opcional
- **Frontend**: Modal en WebhookDetailPage para gestionar reglas IP:
  - Tabla de reglas con IP, acción, descripción, delete
  - Formulario para agregar nueva regla
  - Toggle para activar/desactivar el filtrado global
- **Integración**: En `webhook-receive.ts` y el endpoint Discord, ANTES de procesar, verificar IP contra la lista de reglas. Si la IP está en blocklist → 403. Si allowlist está activa y la IP no está en allowlist → 403.
- **DB**: Nueva tabla `ip_rules` (webhook_id FK, ip text, action text, description text, created_at)

### Feature 4: Health Check Automático (Profesional)
- **Backend**: Nuevo endpoint `GET /api/health-check` que recibe `webhookId` y hace un ping a la URL del webhook con un payload especial `{type: "health_check", timestamp: ...}`.
- **Frontend**: En cada WebhookCard, mostrar un indicador de estado:
  - 🟢 Online (respondió < 500ms en último check)
  - 🟡 Degraded (respondió 500ms-2s)
  - 🔴 Offline (no respondió o error)
- **Automatización**: Configurar `cron` job en Daimon (ya que Vercel no soporta cron nativo sin cron jobs) que verifique cada webhook cada 5 minutos y guarde el resultado en la tabla `health_checks`.
- **DB**: Nueva tabla `health_checks` (webhook_id, status: online|degraded|offline, response_time_ms, checked_at)
- **UI**: Tooltip con historial de últimos 10 checks al hacer hover en el indicador

### Feature 5: Feed de Actividad en Tiempo Real (Élite)
- **Frontend**: Panel lateral fijo en Dashboard (tipo "Activity Feed") que muestra los últimos 20 webhooks recibidos en tiempo real, con:
  - Timestamp relativo ("2s ago", "1m ago")
  - Nombre del webhook
  - Tipo (Native/Discord)
  - Source (si es roblox)
  - IP de origen
  - Badge de estado (success/honeypot/rate_limited)
  - Click para navegar al webhook detail
- **Tecnología**: Usar Supabase Realtime canal global `postgres_changes` en `webhook_logs` SIN filtrar por webhook_id, mostrando solo los del usuario actual.
- **UX**: Animación de entrada (fade + slide) cuando llega un nuevo log. Auto-scroll suave. Botón "Pause" para detener el auto-scroll.
- **Diseño**: Barra lateral de 320px, sticky, con header "Live Activity" y el badge de conexión WebSocket (verde = conectado, rojo = desconectado)

## Contratos Compartidos
- **Tablas nuevas**: `ip_rules`, `health_checks`, `webhook_templates`
- **Endpoints nuevos**: `POST /api/webhook-template`, `GET /api/webhook-logs?q=...`, `POST /api/webhook-ip-rules`, `GET /api/health-check`, `GET /api/health-checks`
- **Componentes nuevos**: `ActivityFeed.tsx`, `IpRulesModal.tsx`, `TemplateCard.tsx`, `SearchBar.tsx`, `HealthIndicator.tsx`
- **Hooks nuevos**: `useActivityFeed.ts`, `useHealthChecks.ts`, `useIpRules.ts`
- **i18n**: Todas las strings nuevas deben usar `t()` del sistema `src/i18n/`

## Validación
- Build debe pasar (`tsc && vite build`)
- Todos los endpoints nuevos deben responder con los códigos de error estándar del sistema
- No romper funcionalidades existentes
- UI consistente con el tema oscuro/lime #D4E83A
