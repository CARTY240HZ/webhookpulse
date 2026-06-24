# WebhookPulse: Documentación Técnica de Arquitectura, Seguridad e Integración Roblox — Análisis de Ingeniería de Software de Nivel Elite

## Resumen Ejecutivo (~800 palabras, 1 tabla)
### Alcance y Propósito
#### El proyecto WebhookPulse es una plataforma de recepción, monitoreo y gestión de webhooks con arquitectura dual (Native + Discord-compatible), diseñada para interoperar con el framework ZEX v7.0 de administración Roblox.
#### Motivación operativa: proveer a desarrolladores de Roblox un sistema de telemetría remota con dashboard profesional, autenticación JWT, real-time logs, y compatibilidad total con el ecosistema de executors (Wave, KRNL, Synapse, Fluxus, Delta).
### Hallazgos Arquitectónicos Principales
#### Arquitectura serverless sobre Vercel con 8 módulos compartidos de infraestructura, 7 endpoints API, y una base de datos PostgreSQL con RLS granular y 4 políticas de seguridad a nivel fila.
#### Sistema de seguridad de 12 capas (S1-S12) incluyendo honeypot activo, rate limiting por IP con fail-open, HMAC-SHA256 preparado para migración de secrets, y filtrado de headers por whitelist.
#### Integración Roblox mediante 3 scripts Lua con 6 métodos de fallback HTTP, auto-detección de tipo de webhook (Native vs Discord), y generación de payloads con hasta 40 campos estructurados por categoría.
### Métricas de Complejidad y Alcance
#### Backend: 47 archivos de código, 8 módulos _lib, 7 endpoints, 3 tablas PostgreSQL, 4 índices, 5 triggers/políticas RLS. Frontend: 9 páginas, 9 componentes, 3 hooks. Lua: 3 scripts (2,595 líneas totales). Tests: 4 suites unitarias + 1 integración.

## 1. Fundamentos y Especificación de Requisitos (~1,500 palabras, 2 tablas)
### 1.1 Contexto del Problema
#### 1.1.1 El ecosistema Roblox carece de soluciones nativas de telemetría remota para administradores de servidores; los desarrolladores dependen de webhooks de Discord con payloads no estructurados y sin persistencia de logs.
#### 1.1.2 Necesidad de una plataforma con autenticación propia, persistencia de datos, dashboard profesional, y compatibilidad con múltiples ejecutores que tienen capacidades HTTP heterogéneas.
### 1.2 Requisitos Funcionales
#### 1.2.1 Recepción de webhooks JSON genéricos (Native) y compatibilidad con API Discord v10 (Discord-compatible), con almacenamiento persistente en PostgreSQL y broadcast en tiempo real vía Supabase Realtime.
#### 1.2.2 Gestión de webhooks: creación con selector de tipo (Native/Discord), generación automática de tokens criptográficos, limitación a 20 webhooks por usuario, y soporte para activación/desactivación y eliminación en cascada.
#### 1.2.3 Dashboard con autenticación JWT, listado de webhooks, visualización de logs con paginación (50/log), filtrado por webhook, batch delete, exportación CSV con cap de 10,000 filas, y estadísticas agregadas con gráficos.
#### 1.2.4 Scripts Lua con GUI AAA, 6 métodos de fallback HTTP, 4 modos de transmisión de datos (FULL, IDENTITY, CHARACTER, MINIMAL), y auto-detección de tipo de URL.
### 1.3 Requisitos No Funcionales
#### 1.3.1 Seguridad: rate limiting (10 req/min Native, 5 req/2s Discord), honeypot 200 para endpoints inválidos, CORS restrictivo en auth, validación de entrada con regex, cap de body 256KB, y filtrado de headers por whitelist.
#### 1.3.2 Rendimiento: respuesta < 500ms para recepción de webhook, carga de logs en < 1s, dashboard responsive con diseño oscuro premium (fondo #0C0C0E, acento lime #D4E83A).
#### 1.3.3 Disponibilidad: despliegue serverless en Vercel con maxDuration 10s en endpoint crítico, fail-open en rate limit para no bloquear legítimos, y monitoreo de errores vía Sentry.
### 1.4 Stack Tecnológico y Justificación
#### 1.4.1 Tabla comparativa de stack: React 18 + TypeScript + Vite + Tailwind (frontend), Vercel Serverless Functions (backend), Supabase PostgreSQL + Auth + Realtime (datos y autenticación), Sentry (monitoreo), Vitest (testing), Lua 5.1 (Roblox scripts).
#### 1.4.2 Justificación de cada elección: Vercel por serverless sin gestión de infraestructura, Supabase por RLS nativo y Realtime, React 18 por concurrent features y ecosistema, Tailwind por diseño atómico y personalización temática oscura, Vitest por compatibilidad con Vite.

## 2. Arquitectura del Sistema y Flujo de Datos (~2,500 palabras, 3 diagramas Mermaid, 2 tablas)
### 2.1 Visión General de la Arquitectura
#### 2.1.1 Diagrama de arquitectura de 3 capas: Cliente (Roblox Lua / Browser React) → Edge (Vercel Serverless Functions) → Data (Supabase PostgreSQL + Realtime), con flujo de retorno vía WebSocket para logs en tiempo real.
#### 2.1.2 Descripción de cada capa: Cliente (3 scripts Lua + 1 dashboard React), Edge (8 módulos _lib + 7 endpoints con lógica de seguridad compartida), Data (3 tablas, 4 índices, políticas RLS, triggers).
### 2.2 Flujo de Datos: Recepción Native
#### 2.2.1 Diagrama de secuencia Mermaid: Cliente HTTP POST → `webhook-receive.ts` → validación de path (`[a-zA-Z0-9_-]{1,64}`) → búsqueda en DB por url_path (fetch all + filter JS por bug de Supabase .eq) → validación de secreto (legacy plaintext, HMAC preparado) → rate limit (count logs último minuto) → filtrado de headers (whitelist de 7 headers) → INSERT en webhook_logs → respuesta 200 {success, logId}.
#### 2.2.2 Análisis de la decisión de bypass de `.eq()`: Supabase JavaScript client presenta un bug donde `.eq('url_path', path)` no retorna resultados en ciertos contextos serverless; la solución adoptada es fetch all + filter en memoria, con análisis de trade-offs (mayor uso de memoria vs fiabilidad de búsqueda).
#### 2.2.3 Honeypot S10: para cualquier path inválido o webhook inactivo, el sistema retorna HTTP 200 con `{received: true, reason: "..."}` en lugar de 404, evitando reconocimiento de endpoints válidos por fuerza bruta.
### 2.3 Flujo de Datos: Recepción Discord
#### 2.3.1 Diagrama de secuencia Mermaid: Cliente POST `/api/webhooks/{webhookId}/{token}` → validación de UUID v4 + token (≥32 chars, no legacy) → validación de payload según spec Discord v10 (content ≤2000, embeds ≤10, fields ≤25 por embed, etc.) → rate limit por webhook (5 req/2s, headers estilo Discord) → INSERT en webhook_logs → respuesta 204 No Content (o 200 con Message object si `?wait=true`).
#### 2.3.2 Análisis de fidelidad a Discord API v10: el endpoint replica exactamente los códigos de error (400 ERR_INVALID_FORM, 404 ERR_UNKNOWN_WEBHOOK, 429 ERR_RATE_LIMITED), headers de rate limit (X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset), y el comportamiento de respuesta 204 por defecto vs 200 con wait=true.
### 2.4 Flujo de Datos: Frontend Realtime
#### 2.4.1 Diagrama de flujo: Supabase Realtime broadcast INSERT en webhook_logs → `useRealtimeLogs.ts` suscribe a `postgres_changes` filtrado por webhook_id → actualización de estado React → re-renderizado de `LogRow` + `RobloxEmbed` si source === "roblox".
#### 2.4.2 Análisis de la arquitectura de suscripción: el frontend usa `supabase.channel()` con `postgres_changes` event, evitando polling y reduciendo latencia de visualización a < 100ms tras inserción en DB.
### 2.5 Módulos Compartidos de Infraestructura (_lib)
#### 2.5.1 Tabla de los 8 módulos _lib con propósito, dependencias, y punto de extensión: auth.ts (JWT Supabase), cors.ts (headers público/privado), errors.ts (apiError/apiSuccess + Sentry), hmac.ts (hashSecret/verifySecret con timingSafeEqual), ratelimit.ts (checkRateLimit con fail-open), sentry.ts (singleton + filtrado 4xx), supabase.ts (singleton service_role), validate.ts (isValidPath, isValidUUID, validateWebhookInput).
#### 2.5.2 Análisis de la decisión de diseño "fail-open" en rate limit: si la consulta de conteo de logs falla (DB timeout, error de conexión), el sistema permite el request en lugar de bloquearlo, priorizando disponibilidad sobre seguridad en escenarios de degradación.

## 3. Diseño de Base de Datos y Seguridad de Datos (~2,000 palabras, 3 tablas, 1 diagrama ER)
### 3.1 Esquema Relacional
#### 3.1.1 Diagrama entidad-relación Mermaid: `auth.users` (1:1) → `profiles` (1:N) → `webhooks` (1:N) → `webhook_logs`, con FK en cascada y ON DELETE CASCADE en todos los enlaces.
#### 3.1.2 Tabla `profiles`: id (uuid, PK, FK auth.users), full_name (text), avatar_url (text), created_at (timestamptz). Trigger `on_auth_user_created` auto-crea perfil en signup.
#### 3.1.3 Tabla `webhooks`: id (uuid, PK), user_id (uuid, FK profiles, NOT NULL), name (text, NOT NULL), description (text), url_path (text, UNIQUE, NOT NULL), secret (text, legacy), is_active (boolean, DEFAULT true), created_at/updated_at (timestamptz).
#### 3.1.4 Tabla `webhook_logs`: id (uuid, PK), webhook_id (uuid, FK webhooks, NOT NULL), payload (jsonb, NOT NULL), headers (jsonb, filtrado por whitelist), ip_address (inet, nullable), created_at (timestamptz).
### 3.2 Índices y Optimización
#### 3.2.1 Tabla de 4 índices con justificación: idx_webhooks_user_id (búsqueda por usuario), idx_webhook_logs_webhook_id (JOIN en detalle), idx_webhook_logs_created_at DESC (orden cronológico), idx_webhook_logs_ip (rate limit por IP en último minuto).
#### 3.2.2 Análisis de rendimiento: con 10,000 logs por webhook, el índice compuesto (ip_address, created_at DESC) reduce la consulta de rate limit de ~120ms a ~8ms (medición estimada por patrón de índice B-tree en PostgreSQL).
### 3.3 Row Level Security (RLS)
#### 3.3.1 Tabla de 5 políticas RLS: profiles (SELECT/UPDATE por auth.uid = id), webhooks (SELECT/INSERT/UPDATE/DELETE por auth.uid = user_id), webhook_logs (SELECT/DELETE/INSERT con EXISTS webhook propio).
#### 3.3.2 Análisis de la granularidad: cada usuario solo ve sus propios webhooks y logs; el backend usa `service_role` key para operaciones administrativas, mientras que el frontend usa anon key + JWT. La política de INSERT en webhook_logs permite que el endpoint público `webhook-receive` (sin auth) almacene logs validando la existencia del webhook por path.
### 3.4 Migraciones y Versionado
#### 3.4.1 Migration 001: creación de índice `idx_webhook_logs_ip` y optimización de seguridad. Estado de migración de `secret` a `secret_hash`: HMAC-SHA256 implementado en `hmac.ts`, pero columna `secret_hash` no existe aún en DB; el endpoint `migrate-secrets.ts` retorna 0 migraciones con nota explicativa.

## 4. API REST: Endpoints, Protocolos y Contratos (~2,500 palabras, 3 tablas, 1 diagrama de secuencia)
### 4.1 Endpoint `POST /api/webhook-receive`
#### 4.1.1 Contrato de entrada: query param `path` (string, regex `[a-zA-Z0-9_-]{1,64}`), body JSON (máx 256KB), header opcional `X-Webhook-Secret`. Proceso de validación en 5 pasos con decisiones de diseño documentadas.
#### 4.1.2 Contrato de salida: 200 OK `{success: true, logId: uuid}` para éxito; 200 honeypot `{received: true, reason: "..."}` para path inválido/inactivo; 405 METHOD_NOT_ALLOWED, 413 PAYLOAD_TOO_LARGE, 429 RATE_LIMIT_EXCEEDED, 500 INTERNAL_ERROR.
#### 4.1.3 Código de referencia del procesamiento de body: manejo de Buffer, string, y object según comportamiento de Vercel Functions.
### 4.2 Endpoint `GET /api/webhook-list`
#### 4.2.1 Autenticación JWT Bearer, respuesta enriquecida con `log_count`, `has_secret` (boolean calculado por longitud ≥32), `discord_url`, `native_url`. Crítico: no retorna campo `secret` crudo (S5).
### 4.3 Endpoint `POST /api/webhook-create`
#### 4.3.1 Body: `{name, description?, type: "native" | "discord"}`. Validaciones: name requerido 1-100 chars, description max 500, límite 20 webhooks por usuario (S9). Generación de `url_path`: slug del nombre + random 6 chars.
#### 4.3.2 Para tipo Discord: generación de token criptográfico con `crypto.randomBytes(48)` → base64url → filtrado de caracteres no válidos → slice a 68 chars. Análisis de entropía: 48 bytes = 384 bits, equivalente a ~57 caracteres base64url, proporcionando seguridad contra fuerza bruta superior a 2^256.
#### 4.3.3 Respuesta: 201 Created con `{webhook, native_url, discord_url?, token?}`.
### 4.4 Endpoints de Gestión
#### 4.4.1 `DELETE /api/webhook-delete`: validación UUID, verificación de ownership, eliminación en cascada (logs por FK). `GET /api/webhook-logs`: max 200 logs sin paginación backend; frontend pagina a 50. `DELETE` alternativo para batch delete con `{logIds: [...]}` o `{deleteAll: true}`.
#### 4.4.2 `GET /api/webhook-export`: CSV con cap 10,000 filas, header `X-Truncated: true` si excede. Columnas: id, created_at, source_ip, payload_json.
### 4.5 Endpoint Discord `POST /api/webhooks/{webhookId}/{token}`
#### 4.5.1 Tabla de validaciones de payload según spec Discord v10: content (≤2000 chars), embeds (≤10, cada uno con title ≤256, description ≤4096, fields ≤25 con name ≤256/value ≤1024), username (≤80), components (≤5), attachments (≤10).
#### 4.5.2 Rate limit por webhook: 5 requests/2 segundos. Headers de respuesta estilo Discord: X-RateLimit-Limit, X-RateLimit-Remaining, X-RateLimit-Reset, Retry-After.
#### 4.5.3 Respuestas: 204 No Content (default), 200 con Message object (si `?wait=true`), 400 ERR_INVALID_FORM/ERR_EMPTY_MESSAGE, 404 ERR_UNKNOWN_WEBHOOK, 429 ERR_RATE_LIMITED, 401 ERR_UNAUTHORIZED.

## 5. Sistema de Seguridad: Análisis de 12 Capas (~2,500 palabras, 2 tablas, 1 diagrama de flujo)
### 5.1 Taxonomía de Vulnerabilidades y Contramedidas
#### 5.1.1 Tabla de 12 fixes de seguridad (S1-S12) con severidad, descripción, ubicación en código, y análisis de impacto: CORS restrictivo (S1), HMAC-SHA256 (S2), no exposición de error.details (S3), filtrado de headers (S4), no retorno de secret (S5), índice IP para rate limit (S6), cap export 10K filas (S7), validación UUID (S8), límite 20 webhooks (S9), honeypot 200 (S10), singleton Supabase (S11), límites de input (S12).
#### 5.1.2 Análisis de la severidad por capa: S1-S3 críticas (exposición de credenciales, información sensible), S4-S8 altas (DoS, enumeración, escalada), S9-S12 medias (límites de recursos, validación de forma).
### 5.2 Honeypot Activo (S10)
#### 5.2.1 Diagrama de decisión del honeypot: path válido + activo → procesamiento normal; path inválido o inactivo → HTTP 200 con `{received: true, reason: "path_not_found" | "webhook_inactive"}`. Análisis de eficacia: un atacante que fuzzee endpoints no puede distinguir entre éxito real y honeypot basado únicamente en status code.
#### 5.2.2 Limitaciones del honeypot: el cuerpo de la respuesta difiere (`success` vs `received`), lo cual podría ser detectable si el atacante parsea JSON. Análisis de hardening futuro: respuesta de honeypot con delay artificial aleatorio para mitigar timing attacks.
### 5.3 Rate Limiting y Anti-DoS
#### 5.3.1 Implementación del rate limit Native: consulta `SELECT COUNT(*) FROM webhook_logs WHERE ip_address = $1 AND created_at > NOW() - INTERVAL '1 minute'`. Si count ≥ 10 → 429. Fail-open en error de DB.
#### 5.3.2 Implementación del rate limit Discord: misma lógica pero con ventana de 2 segundos y límite de 5 requests. Headers de respuesta estilo Discord para compatibilidad con clientes que esperan formato Discord.
### 5.4 Validación de Entrada y Sanitización
#### 5.4.1 `isValidPath`: regex `[a-zA-Z0-9_-]{1,64}` — evita path traversal (`../`), inyección de caracteres especiales, y paths excesivamente largos. Análisis de cobertura: permite alfanuméricos, guion, guion bajo; rechaza todo lo demás incluyendo espacios, puntos, y slashes.
#### 5.4.2 `validateWebhookInput`: name 1-100 chars, description max 500. `clampString`: trunca a límite sin lanzar excepción. Análisis de la decisión de diseño: evitar rechazo de input válido por límite técnico, en lugar truncar silenciosamente (trade-off: usabilidad vs integridad de datos).
### 5.5 HMAC-SHA256 y Gestión de Secretos
#### 5.5.1 Implementación de `hmac.ts`: `hashSecret()` usa `crypto.createHmac('sha256', WEBHOOK_SECRET_SALT).update(secret).digest('hex')`. `verifySecret()` usa `crypto.timingSafeEqual()` para comparación constante, mitigando timing attacks.
#### 5.5.2 Estado de migración: columna `secret_hash` no existe en DB. El sistema actual usa comparación plaintext legacy. Riesgo: secrets almacenados en texto plano. Mitigación: HMAC listo para migración, y tokens Discord son generados criptográficamente sin almacenar plaintext (el token en la URL es el único secreto).

## 6. Frontend: Arquitectura React, Estado y Diseño Visual (~2,000 palabras, 2 tablas, 1 diagrama de componentes)
### 6.1 Arquitectura de Componentes y Routing
#### 6.1.1 Diagrama de árbol de componentes: `App.tsx` (router) → `Layout.tsx` (shell) → [`Sidebar.tsx`, `TopBar.tsx`, `Outlet`]. Páginas: Landing, Login, Register, ForgotPassword, ResetPassword, Dashboard, WebhookDetail, Stats, Settings.
#### 6.1.2 Tabla de rutas con componente, requisito de auth, y redirect behavior. Análisis de la decisión de SPA routing: `vercel.json` reescribe todas las rutas no-API a `index.html`, permitiendo React Router DOM manejar navegación del lado del cliente sin configuración adicional del servidor.
### 6.2 Gestión de Estado y Autenticación
#### 6.2.1 `useAuth.tsx`: contexto global con `user`, `profile`, `loading`. Escucha `onAuthStateChange` de Supabase Auth. Flujo de registro: signUp → email confirmation → trigger `handle_new_user()` → perfil creado. Flujo de login: signInWithPassword → JWT almacenado en cookies/localStorage por Supabase client → estado global refrescado.
#### 6.2.2 Seguridad frontend: lockout de 30 segundos tras 5 intentos fallidos de login. Validación de email con regex. Indicador de fortaleza de contraseña (4 criterios: longitud, mayúscula, minúscula, número). Sentry frontend strips PII de `event.user`.
### 6.3 Hooks de Datos
#### 6.3.1 `useWebhooks.ts`: CRUD de webhooks. `fetchWebhooks` usa Supabase client directo (no backend API) para listado; `createWebhook` llama `POST /api/webhook-create`; `deleteWebhook` y `toggleWebhook` usan Supabase directo. Análisis de la decisión de arquitectura: listado directo a DB reduce latencia y carga de serverless functions; operaciones mutativas pasan por backend para validaciones complejas (límite de webhooks, generación de tokens).
#### 6.3.2 `useRealtimeLogs.ts`: paginación de 50 logs/página + suscripción realtime. Funciones: `loadMore`, `deleteLog`, `deleteSelectedLogs`, `deleteAllLogs`. Suscripción a `postgres_changes` INSERT filtrado por `webhook_id`.
### 6.4 Sistema de Diseño Visual
#### 6.4.1 Tabla de tokens de diseño: background (#0C0C0E), surface (#161618), elevated (#1C1C1E), border (#27272A), accent (#D4E83A), accent-hover (#E8F96A), danger (#EF4444), success (#22C55E). Análisis de la elección de paleta: bajo contraste para reducir fatiga visual en sesiones prolongadas, acento lime de alta saturación para llamar atención a elementos críticos sin usar azul-púrpura (rechazo explícito de diseño genérico).
#### 6.4.2 Componentes visuales clave: `WebhookCard` (estilo Discord embed con barra lime, estado, log_count, acciones copy/pause/delete), `CreateWebhookModal` (selector Native/Discord, URLs generadas con botones de copiar), `RobloxEmbed` (parseo de payload anidado por categorías: player, character, game, environment, device), `PayloadViewer` (syntax highlighting JSON con spans coloreados por tipo).

## 7. Sistema de Webhooks Dual: Native y Discord (~2,000 palabras, 2 tablas, 2 diagramas de secuencia)
### 7.1 Arquitectura Dual: Native vs Discord
#### 7.1.1 Diagrama comparativo de arquitectura: Native (path-based, payload genérico, secreto en header) vs Discord (UUID/token-based, payload con formato Discord, token en URL). Tabla comparativa de 8 dimensiones: identificación, autenticación, formato de payload, validación, rate limit, respuesta éxito, respuesta error, uso de caso.
#### 7.1.2 Análisis de la decisión de arquitectura dual: los usuarios necesitaban compatibilidad con Discord para integraciones existentes, pero también un formato nativo para payloads estructurados de Roblox. Implementar ambos en un solo sistema evita la fragmentación de herramientas.
### 7.2 Flujo Native: Protocolo y Payload
#### 7.2.1 Diagrama de secuencia de recepción native con 9 pasos detallados. Análisis de la estructura del payload: JSON arbitrario con límite de 256KB, almacenado como jsonb en PostgreSQL, visualizado como JSON raw en frontend.
#### 7.2.2 Integración con ZEX: payload nativo contiene hasta 40 campos estructurados en 5 categorías (player, character, game, environment, device). El frontend detecta `source === "roblox"` y renderiza `RobloxEmbed` con parseo anidado.
### 7.3 Flujo Discord: Fidelidad a API v10
#### 7.3.1 Diagrama de secuencia de recepción Discord con 8 pasos. Validación exhaustiva de estructura: content (string, max 2000), embeds (array max 10, cada embed con title, description, url, timestamp, color, footer, image, thumbnail, video, provider, author, fields array max 25).
#### 7.3.2 Análisis de la compatibilidad: el endpoint es intercambiable con cualquier URL de Discord webhook. Un cliente que envía a Discord puede cambiar la URL por `https://webhookpulse.com/api/webhooks/{id}/{token}` y obtener el mismo comportamiento, con la ventaja adicional de persistencia de logs en el dashboard.
#### 7.3.3 Generación de token Discord: análisis de la función `generateDiscordToken()` que usa `crypto.randomBytes(48)` → base64url → filtrado → slice 68 chars. Comparación con tokens de Discord reales: Discord usa tokens de 68 caracteres alfanuméricos; la implementación replica la longitud y el espacio de caracteres.

## 8. Scripts Lua: ZEX v7.0 y Ecosistema de Integración (~2,500 palabras, 3 tablas, 1 diagrama de componentes)
### 8.1 Arquitectura del Script ZEX v7.0
#### 8.1.1 Estructura general: 1,637 líneas de Lua, 7 tabs, sistema de animación AAA con TweenService, 6 métodos de fallback HTTP, auto-detección de tipo de webhook. Diagrama de componentes: GUI principal (ScreenGui) → MainFrame (Frame) → Sidebar (7 tabs) → ContentArea (dinámica por tab).
#### 8.1.2 Tabla de funciones principales: `corner()`, `stroke()`, `pad()` (helpers UI), `safeCall()` (pcall wrapper), `tween()` / `tweenSequence()` (sistema de animación con EasingStyle.Quint y Back), `parseResponse()` (parseo de respuestas HTTP en múltiples formatos: StatusCode/statusCode/status, Body/body).
### 8.2 Sistema de Animación AAA
#### 8.2.1 Fase 1: Main fade + scale + slide up (0.55s, EasingStyle.Back). Fase 2: Shadow fade in (0.6s, delay 0.15s). Fase 3: Sidebar tabs stagger reveal (0.04s por tab, delay 0.35s). Fase 4: Content reveal (0.4s, delay 0.55s). Análisis de la curva de easing: Back proporciona overshoot sutil que da sensación de elasticidad profesional; Quint proporciona aceleración suave sin sacudidas.
#### 8.2.2 Minimización y toggle: RightShift como keybind global. Al minimizar, el frame se reduce a un icono flotante con animación de escala inversa. Análisis de la decisión de diseño: minimización como icono preserva el estado del script sin ocupar pantalla completa, crítico para juegos donde el HUD debe ser minimalista.
### 8.3 Sistema de Transmisión de Datos
#### 8.3.1 Tabla de 4 modos de transmisión: FULL (40+ campos), IDENTITY (player data), CHARACTER (character stats), MINIMAL (userid + timestamp). Análisis de casos de uso: FULL para diagnóstico completo, MINIMAL para heartbeat silencioso.
#### 8.3.2 Auto-detección de tipo de URL: patrones `/api/webhooks/` → Discord, `/api/webhook-receive` → Native, cualquier otro → Genérico. Para Discord: construcción de embeds con colores específicos por categoría (Player lime #D4E83A, Character blue #3B82F6, Game green #22C55E, Environment amber #F59E0B, Device red #EF4444).
#### 8.3.3 Para Native: payload original con 5 objetos anidados: player (15 campos), character (8 campos), game (12 campos), environment (10 campos), device (9 campos). Campo adicional: `source: "roblox"`, `timestamp` (epoch), `executor.name`.
### 8.4 Métodos de Fallback HTTP
#### 8.4.1 Tabla de 6 métodos de fallback en orden de prioridad: `request()` (Wave, KRNL), `syn.request` (Synapse), `fluxus.request`, `delta.request`, `getgenv().request`, `HttpService:PostAsync`. Análisis de la compatibilidad: `HttpService:PostAsync` está bloqueado en clientes Roblox modernos; los executores de terceros proporcionan `request()` con soporte de headers y body completo.
#### 8.4.2 `parseResponse()`: normaliza respuestas de múltiples formatos. Wave `request()` retorna `{StatusCode, Body, Headers}` donde Body es string JSON. `HttpService:PostAsync` retorna string JSON crudo. La función parsea ambos y extrae: status code (200 vs 204), body JSON, y campo `success`/`received` para detección de honeypot.
### 8.5 Scripts Complementarios
#### 8.5.1 `WebhookPulseSender_v2.lua`: 712 líneas, script standalone simplificado. Drag de ventana, status dot (accent → success → danger), debug scroll. Mismos 6 fallbacks HTTP y payload completo.
#### 8.5.2 `WebhookPulseDiagnostic.lua`: 246 líneas, diagnóstico de entorno. Verifica: `identifyexecutor`, `gethui`, `request`, `syn.request`, servicios Roblox, test HTTP real contra `httpbin.org/post`. GUI con log coloreado (OK/Success/Danger).

## 9. Frontend: Visualización de Logs y Dashboard (~1,500 palabras, 2 tablas, 1 diagrama de flujo)
### 9.1 Visualización de Logs en Tiempo Real
#### 9.1.1 Flujo de datos: `useRealtimeLogs.ts` → estado React → `LogRow.tsx` → `RobloxEmbed.tsx` (condicional). Análisis de la decisión de renderizado condicional: si `payload.source === "roblox"`, se renderiza el embed visual sin necesidad de expandir; si es payload genérico, se muestra JSON raw con `PayloadViewer`.
#### 9.1.2 `RobloxEmbed.tsx`: parseo de payload anidado con compatibilidad dual (payload plano v1 y payload anidado v2). Categorías: Player (identidad), Character (estadísticas), Game (instancia), Environment (lighting), Device (hardware). Cada campo con etiqueta y valor, barra lateral lime para estilo visual.
### 9.2 Dashboard y Estadísticas
#### 9.2.1 `StatsPage.tsx`: 4 tarjetas resumen (total logs, webhooks activos, etc.) + 4 gráficos SVG. Tabla de gráficos: hourly activity (bar chart), logs per webhook (bar chart), top IPs (bar chart), sources (donut chart). Análisis de la decisión de usar SVG nativo: evita dependencia de librerías de charting (recharts, chart.js), reduciendo bundle size y manteniendo control total sobre la paleta de colores del tema oscuro.
#### 9.2.2 Operaciones batch: `WebhookDetailPage.tsx` soporta selección múltiple de logs vía checkbox, batch delete, delete all, y exportación CSV. Análisis de UX: paginación de 50 logs con "Load More" evita carga inicial masiva; batch operations reducen clicks para mantenimiento de logs.

## 10. Testing y Garantía de Calidad (~1,500 palabras, 2 tablas)
### 10.1 Estrategia de Testing
#### 10.1.1 Pirámide de testing: unit tests (4 suites) en la base, integration tests (1 suite) en el medio, sin E2E tests (decisión documentada: confianza en unit + integration para serverless functions). Análisis de la cobertura: unit tests cubren módulos críticos _lib (cors, hmac, validate); integration test cubre el endpoint más crítico (webhook-receive) con 3 escenarios: honeypot path inválido, honeypot webhook desconocido, y 413 body oversize.
### 10.2 Suite de Tests Unitarios
#### 10.2.1 Tabla de 4 suites unitarias: `cors.test.ts` (headers públicos vs privados, inclusión X-Webhook-Secret), `hmac.test.ts` (consistencia hash, verificación correcta/incorrecta, casos vacíos), `validate.test.ts` (paths válidos/inválidos, UUIDs, clamp, input webhook).
#### 10.2.2 Análisis de la decisión de no testear el frontend: el frontend es React estándar con hooks; la lógica de negocio crítica reside en el backend. Los tests del frontend se delegan a verificación manual en el despliegue de staging.
### 10.3 Suite de Tests de Integración
#### 10.3.1 `webhook-receive.test.ts`: 3 escenarios críticos. Honeypot para path inválido (verifica 200 + `{received: true}`), honeypot para webhook desconocido (verifica 200 + reason), 413 para body oversize (verifica 413 + PAYLOAD_TOO_LARGE). Análisis de la cobertura de edge cases: no se testean escenarios de rate limit (difícil de simular sin mockear DB), ni escenarios de CORS (probados manualmente).
### 10.4 Métricas de Calidad y Deuda Técnica
#### 10.4.1 Tabla de deuda técnica identificada: columna `secret_hash` no existe (HMAC preparado pero no migrado), Supabase `.eq()` bug requiere workaround de fetch all + filter, `HttpService:PostAsync` bloqueado en Roblox cliente (requiere executores), no hay tests de frontend ni E2E. Para cada ítem: severidad, impacto, y plan de remediación.

## 11. Despliegue, Operaciones y Monitoreo (~1,500 palabras, 2 tablas)
### 11.1 Pipeline de Despliegue
#### 11.1.1 Configuración de Vercel (`vercel.json`): buildCommand `npm run build`, outputDirectory `dist`, maxDuration 10s para `api/webhook-receive.ts`, rewrites para SPA routing (todas las rutas no-API a `index.html`) y API routes directas. Análisis de la decisión de maxDuration 10s: el endpoint de recepción de webhook debe ser rápido (< 500ms); 10s es un límite de guarda para edge cases de conectividad lenta a Supabase.
#### 11.1.2 Variables de entorno: tabla de 8 variables con scope (backend/frontend/both), descripción, y nivel de sensibilidad. Destacar: `SUPABASE_SERVICE_KEY` (backend only, secreto), `VITE_SUPABASE_ANON_KEY` (frontend build-time, público), `WEBHOOK_SECRET_SALT` (backend, secreto de HMAC).
### 11.2 Monitoreo y Observabilidad
#### 11.2.1 Sentry: backend (`@sentry/node`) y frontend (`@sentry/react`). Configuración: DSN único, filtrado de eventos HTTP 400-429 en `beforeSend` para no saturar quota, `setUserContext` para trazabilidad, `captureException` en `apiError`. Análisis de la decisión de filtrar 4xx: evita noise en Sentry de errores esperados (rate limit, payload inválido) y enfoca el monitoreo en excepciones reales del servidor (500s, errores de DB).
#### 11.2.2 Métricas de monitoreo: tabla de métricas clave (latencia de webhook-receive, tasa de honeypot, tasa de rate limit, logs por hora, webhooks activos por usuario) y cómo se obtienen (consultas SQL directas a PostgreSQL o dashboard de StatsPage).
### 11.3 Escalabilidad y Límites
#### 11.3.1 Límites del sistema documentados: 20 webhooks por usuario, 10,000 logs por export, 256KB por payload, 10 req/min por IP (Native), 5 req/2s por webhook (Discord). Análisis de la capacidad de escala: con Vercel Pro y Supabase Pro, el sistema puede manejar ~1,000 req/min en el endpoint de webhook-receive antes de que el rate limit por IP se convierta en cuello de botella.
#### 11.3.2 Plan de escalabilidad horizontal: si el conteo de logs para rate limit se vuelve lento, migrar a Redis o un contador en memoria por instancia serverless. Si PostgreSQL se satura, usar read replicas para consultas de listado y exportación.

## 12. Conclusiones, Limitaciones y Roadmap (~1,000 palabras, 1 tabla)
### 12.1 Síntesis de Logros
#### 12.1.1 Resumen de los 4 logros arquitectónicos principales: (1) sistema dual Native/Discord con fidelidad total a API v10, (2) seguridad de 12 capas con honeypot activo y rate limiting, (3) integración Roblox con GUI AAA y 6 fallbacks HTTP, (4) dashboard profesional con real-time logs y estadísticas.
### 12.2 Limitaciones Actuales
#### 12.2.1 Tabla de 5 limitaciones con impacto y plan de mitigación: secrets en plaintext (HMAC preparado pero no migrado), workaround de `.eq()` (overhead de memoria), sin E2E tests (riesgo de regresión en flujos críticos), dependencia de executores de terceros (fragilidad del ecosistema Roblox), sin notificaciones push (usuarios deben revisar dashboard manualmente).
### 12.3 Roadmap de Evolución
#### 12.3.1 Fase 1 (inmediata): migración de secrets a HMAC-SHA256 con columna `secret_hash`, fix del bug `.eq()` de Supabase, tests E2E con Playwright. Fase 2 (corto plazo): notificaciones push vía email/SMS para webhooks críticos, webhooks salientes (callback URLs), soporte para múltiples workspaces/teams. Fase 3 (medio plazo): integración con plataformas adicionales (Slack, Teams, Telegram), analytics avanzado con series temporales, y API pública documentada con OpenAPI/Swagger.

# Referencias
## WebhookPulse_Technical_Audit.md
- **Type**: Informe técnico exhaustivo de código fuente
- **Description**: Fuente principal con todo el código, arquitectura, esquema de base de datos, y flujos del proyecto WebhookPulse
- **Path**: {workspace}/WebhookPulse_Technical_Audit.md

## webhookpulse_doc.agent.outline.md
- **Type**: Outline de documentación técnica
- **Description**: Este archivo de outline que guía la escritura de cada capítulo
- **Path**: {workspace}/webhookpulse_doc.agent.outline.md

## Código Fuente del Proyecto
- **Type**: Código fuente real
- **Description**: Backend (api/), Frontend (src/), Lua (roblox/), SQL (supabase/), Tests (tests/)
- **Path**: {workspace}/webhookpulse/
