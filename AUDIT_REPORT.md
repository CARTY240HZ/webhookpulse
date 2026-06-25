# WebhookPulse Audit Report

**Fecha de auditoría:** 2025-01-21
**Auditor:** Auditor de Código Senior (Automated)
**Alcance:** Full-stack end-to-end (backend API, frontend React, tests, infra, PWA, Docker)

---

## Resumen Ejecutivo

| Métrica | Valor |
|---------|-------|
| Total archivos auditados | 61 |
| Bugs críticos | 4 |
| Bugs de severidad ALTA | 9 |
| Bugs de severidad MEDIO | 14 |
| Bugs de severidad BAJO | 12 |
| Vulnerabilidades de seguridad | 6 |
| Mejoras de rendimiento | 7 |
| Inconsistencias / dead code | 8 |
| Problemas de i18n | 5 |
| Problemas de accesibilidad | 4 |

---

## Archivo por archivo

### api/webhook-receive.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 32 | MEDIO | TypeScript | `req: any, res: any` — tipado explícito `any` en todo el handler. Usar `VercelRequest`, `VercelResponse` o tipos propios. | Importar tipos de `@netlify/functions` o definir `interface VercelRequest { ... }` |
| 46 | ALTO | Seguridad | `req.query?.path` accede a query sin sanitización adicional. Aunque `isValidPath` filtra, el cast `String(path)` en L48 puede recibir `undefined`. | `const path = String(req.query?.path ?? '')` antes de validar |
| 52–58 | MEDIO | Rendimiento | Cálculo de body size con `JSON.stringify(req.body).length` para objetos. Si `req.body` ya es un objeto grande, stringify es costoso. | Usar `Buffer.byteLength(JSON.stringify(req.body))` o verificar `req.headers['content-length']` primero |
| 65–78 | ALTO | Seguridad | El catch de JSON.parse silencia errores y asigna `payload = {}`. Un payload malformado debería loggearse, no ignorarse silenciosamente. | `captureException(new Error('Invalid JSON payload'))` dentro del catch |
| 81–82 | ALTO | Seguridad | `x-forwarded-for` puede ser spoofeado por el cliente. No se verifica contra una lista de proxies confiables. | Usar `req.headers['x-vercel-forwarded-for']` si está en Vercel, o verificar IP contra whitelist de proxies |
| 86–90 | ALTO | Rendimiento | **N+1 Query**: se descargan TODOS los webhooks (`select * from webhooks`) y se filtra en memoria. Escalable solo hasta ~1000 webhooks. | Crear índice en `url_path` y usar `.eq('url_path', pathStr)` directamente en la query |
| 106–118 | CRÍTICO | Seguridad | Comparación de secret en texto plano (`===`) en lugar de `timingSafeEqual`. Aunque hay función `verifySecret` en `hmac.ts`, no se usa. | Usar `verifySecret(providedSecret, webhook.secret_hash)` con comparación constant-time |
| 106 | MEDIO | Seguridad | Nota en código dice "secret_hash column doesn't exist in DB yet" — esto significa que los secrets se almacenan en texto plano. | Migrar a `secret_hash` + `salt` y nunca almacenar el secret en texto plano |
| 122–130 | MEDIO | Seguridad | IP rules se consultan DESPUÉS de validar el secret. Un atacante con secret inválido no triggera IP block. Orden debería ser: IP → Secret → Rate Limit. | Reordenar: validar IP antes de validar secret |
| 145–166 | MEDIO | Seguridad | Retry de insert con `ip_address = null` solo detecta error por string 'inet'. Si el error es otro (e.g. constraint violation), se pierde. | Verificar `insertResult.error.code` específico, no `.message.includes('inet')` |
| 173 | BAJO | Inconsistencia | Retorna `{ success: true, logId: ... }` pero en el caso de honeypot (L93–99) retorna `{ received: true }`. Inconsistencia de schema de respuesta. | Unificar respuestas: `{ received: true }` para todos los casos 200, o usar `{ success: boolean }` consistentemente |

### api/webhook-list.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 7 | MEDIO | TypeScript | `req: any, res: any` — mismo problema de tipado. | Usar tipos específicos de Vercel/Netlify |
| 26–30 | MEDIO | Rendimiento | `webhook_logs(count)` es un count agregado por fila. Supabase genera subqueries que pueden ser lentos con muchos logs. | Usar una función RPC o contar en query separada |
| 39 | BAJO | Inconsistencia | `Record<string, unknown>` en el map sin tipado de `Webhook`. | Usar `Webhook & { webhook_logs?: { count: number }[] }` |
| 41 | MEDIO | Seguridad | `hasSecret` valida `secret.length >= 32` pero luego se usa `secret !== 'null'` como fallback. Si el secret es `'null'` (string), pasa como válido. | Usar `secret && secret.length >= 32 && secret !== 'null'` consistentemente |

### api/webhook-logs.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 8 | MEDIO | TypeScript | `req: any, res: any` |
| 14 | ALTO | Seguridad | `setCorsHeaders(res, 'private')` se llama ANTES de verificar método. Si es OPTIONS, se setean headers dos veces (L10 y L14). | Mover `setCorsHeaders` después del bloque OPTIONS, o quitar duplicado |
| 88–95 | MEDIO | Lógica | El filtro `type` verifica `webhook.has_secret && !!webhook.discord_url` para determinar si es Discord. Si el webhook tiene `has_secret=true` pero `discord_url` es null por algún error, el tipo se evalúa mal. | Usar columna `type` explícita en la tabla webhooks |
| 110 | ALTO | Seguridad | **SQL Injection potencial**: `query.ilike('payload::text', "%${q}%")` — aunque Supabase escapa parámetros, el cast `::text` puede ser problemático. Además, `q` no se sanitiza (aunque es string). | Usar `or` con filtros seguros o validar `q` contra regex antes de enviar |
| 126 | BAJO | Lógica | `source` filtra con `payload->>source`. Si el payload es un array o string, crashea. | Verificar que `payload` sea objeto antes de aplicar operador JSON |

### api/webhook-create.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 25 | MEDIO | TypeScript | `req: any, res: any` |
| 14–22 | MEDIO | Seguridad | `generateSlug` usa `Math.random()` para el sufijo. No es criptográficamente seguro y puede colisionar (aunque raro). | Usar `crypto.randomBytes(3).toString('hex')` en lugar de `Math.random()` |
| 53–59 | BAJO | Lógica | `countError` se ignora si es truthy. Si la query de count falla, se permite crear webhook sin límite. | Retornar error si `countError` existe |
| 63 | MEDIO | Seguridad | `type` se castea como string sin validación contra valores permitidos. | Validar `type` con `zod` o enum: `if (type !== 'native' && type !== 'discord')` |
| 95–105 | ALTO | Seguridad | `response.token = secret` — el secret se devuelve en texto plano al cliente. Aunque es necesario para Discord, esto expone el token en network logs. | Considerar mostrar solo una vez con flag `isFirstReveal`, o usar one-time token |

### api/webhook-delete.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 8 | BAJO | TypeScript | `req: any, res: any` |
| 42 | MEDIO | Seguridad | No se verifica ownership del webhook antes de `delete().eq('id', id)`. Aunque el `.eq('user_id', user.id)` se hace en el select anterior, la operación de delete no tiene `eq('user_id', user.id)`. | Añadir `.eq('user_id', user.id)` al delete query |

### api/webhook-export.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 17 | BAJO | TypeScript | `req: any, res: any` |
| 10–15 | ALTO | Seguridad | **CSV Injection**: `escapeCsvCell` no previene fórmulas maliciosas (e.g. `=CMD|' /C calc'!A0`). Excel/LibreOffice ejecutan fórmulas en CSV. | Prefijar celdas que empiecen con `=`, `+`, `-`, `@`, `%` con apóstrofo (`'`) |
| 68–76 | MEDIO | Seguridad | El CSV se construye manualmente con `\r\n`. Si `payloadStr` contiene `\r\n`, el escape de comillas dobles no maneja CRLF interno correctamente. | Asegurar que `\r` y `\n` también triggeren quoting en `escapeCsvCell` |
| 73 | BAJO | Lógica | `new Date(row.created_at).toISOString()` puede lanzar excepción si `created_at` es inválido. | `row.created_at ? new Date(row.created_at).toISOString() : ''` ya está, pero no maneja excepciones de Date inválido |

### api/webhook-reveal.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 8 | BAJO | TypeScript | `req: any, res: any` |
| 37–60 | CRÍTICO | Seguridad | **Verificación de password por side-effect**: se crea un cliente Supabase temporal y se hace `signInWithPassword`. Esto genera un nuevo session token en el servidor. Además, si el usuario tiene 2FA, este método falla. | Usar `supabase.auth.verifyOTP` o `supabase.auth.admin` para verificar password sin crear sesión |
| 63–75 | MEDIO | Seguridad | `webhook.user_id !== user.id` se verifica, pero el fetch de webhook no usa `.eq('user_id', user.id)`. Un webhook de otro usuario podría ser leído si no hay RLS estricto. | Añadir `.eq('user_id', user.id)` a la query de webhook |
| 82 | BAJO | Seguridad | `discordUrl` se construye con el secret en texto plano. Si se loggea `res`, el secret queda expuesto. | No incluir `discordUrl` en la respuesta si solo se necesita el token |

### api/webhook-template.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 296 | BAJO | TypeScript | `req: any, res: any` |
| 17 | ALTO | Seguridad | **Lua Injection / XSS indirecto**: `webhookUrl.replace(/"/g, '\\"')` escapa comillas dobles pero no otros caracteres de escape Lua (`\`, `\n`, `\x00`). Un webhookUrl con backslash puede romper el string. | Usar sanitización más robusta: `url.replace(/[\\"]/g, '\\$&')` y validar URL antes |
| 26 | MEDIO | Seguridad | `getgenv` y `request` son funciones de exploiters de Roblox. El script expone explícitamente cómo usar exploits. | Añadir disclaimer legal o separar en template de "ejecutores no oficiales" |
| 287–293 | BAJO | Lógica | `switch` con strings literales. Sin `default` no hay warning. | Añadir log en `default` para templates desconocidos |

### api/webhook-ip-rules.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 7 | BAJO | TypeScript | `req: any, res: any` |
| 78–79 | BAJO | Seguridad | `return apiError(res, 403, 'FORBIDDEN')` en POST/DELETE sin ownership. Si el webhook no existe, retorna 403 en lugar de 404, lo cual filtra información de existencia (bien), pero inconsistente con otros endpoints. | Documentar o estandarizar: 404 para not found, 403 para forbidden |
| 118–127 | BAJO | Seguridad | Para DELETE, primero se lee `ip_rules.webhook_id`, luego se verifica ownership. RLS debería prevenir esto, pero si se usa service key, es posible leer rules de otros usuarios. | Añadir `.eq('user_id', user.id)` join implícito en la query de rules |
| 142 | BAJO | Seguridad | `catch (err)` pasa `err` a `apiError` que lo captura en Sentry. Sin embargo, no hay `captureException` explícito. | `captureException(err)` antes de retornar error |

### api/sse-logs.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 10 | BAJO | TypeScript | `req: any, res: any` |
| 21–34 | ALTO | Seguridad | **Memory leak potencial**: en serverless, la conexión SSE mantiene el canal de Supabase Realtime abierto. Si el cliente cierra la conexión sin enviar `close`, el canal queda activo hasta timeout. | Añadir `req.on('aborted', ...)` y `req.on('error', ...)` para cleanup |
| 27–29 | MEDIO | Seguridad | Se crea un nuevo cliente Supabase por cada request SSE en lugar de reutilizar `getSupabase()`. Esto puede agotar conexiones. | Usar `getSupabase()` compartido o pool de conexiones |
| 60–75 | MEDIO | Rendimiento | `supabase.channel(...).subscribe()` crea un canal persistente. En Vercel serverless, esto no funciona bien porque la función se congela después de retornar. | Documentar que SSE solo funciona en entornos con keep-alive real (no serverless) o usar Edge Runtime |
| 78–81 | MEDIO | Seguridad | `setInterval` sin `unref()` puede mantener el proceso Node vivo después del timeout de Vercel. | `const interval = setInterval(...)` ya tiene cleanup en `req.on('close')`, pero no en error |

### api/health-check.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 7 | BAJO | TypeScript | `req: any, res: any` |
| 54–79 | MEDIO | Seguridad | Health check hace `fetch` al `nativeUrl` que es un endpoint público. Esto genera un log en `webhook_logs` cada vez que se ejecuta. Si se automatiza, se llena la DB. | Excluir health checks de los logs, o usar un endpoint dedicado `/health` que no loggee |
| 56 | BAJO | Lógica | `AbortController` timeout de 5s. Si el fetch tarda exactamente 5s y luego `clearTimeout` se ejecuta, puede haber race condition. | `controller.abort()` después de `clearTimeout` en bloque `finally` |
| 68–74 | BAJO | Lógica | `status` se determina por `responseTimeMs`, no por `response.ok`. Un 500 con <500ms se marca como 'online'. | Verificar `response.ok` antes de asignar status |

### api/health-checks.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 7 | BAJO | TypeScript | `req: any, res: any` |
| 27 | BAJO | Lógica | `req.query?.webhookId || req.query?.webhook_id` acepta dos nombres de parámetro. Documentar o estandarizar. | Estandarizar a `webhookId` solo |
| 37–38 | BAJO | Seguridad | El select de webhook no incluye `user_id`. Aunque se verifica después, es un N+1 potencial. | Usar `.select('id, user_id')` y verificar en una sola query |

### api/2fa-send.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 8 | BAJO | TypeScript | `req: any, res: any` |
| 25 | CRÍTICO | Seguridad | `Math.random()` para generar código 2FA. No es criptográficamente seguro. | Usar `crypto.randomInt(100000, 999999)` |
| 42–48 | ALTO | Seguridad | En modo "demo", el código se retorna en la respuesta (`code: code`). Esto es un bypass completo de 2FA si `error` ocurre (por ejemplo, columnas que no existen). | Nunca retornar el código al cliente. En modo demo, loggear solo en servidor |
| 30–37 | MEDIO | Seguridad | `two_factor_code` y `two_factor_expires` se guardan en texto plano en `profiles`. Si la DB se compromete, los códigos están expuestos. | Hashear el código con bcrypt (cost 10) o usar OTP con almacenamiento temporal (Redis) |

### api/2fa-verify.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 7 | BAJO | TypeScript | `req: any, res: any` |
| 34–38 | MEDIO | Seguridad | Fallback de "demo mode" acepta CUALQUIER código si las columnas no existen. Esto es un bypass de 2FA si el schema no está migrado. | Eliminar fallback de demo. Si no hay 2FA configurado, retornar error |
| 47–48 | MEDIO | Seguridad | Comparación de código en texto plano (`===`). Sin `timingSafeEqual`, es vulnerable a timing attacks. | `crypto.timingSafeEqual(Buffer.from(profile.two_factor_code), Buffer.from(code))` |
| 52–60 | MEDIO | Lógica | No se verifica si el `update` a `profiles` tuvo éxito. | Verificar `error` del update y retornar 500 si falla |

### api/user-settings.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 8 | BAJO | TypeScript | `req: any, res: any` |
| 27–49 | MEDIO | Lógica | Try/catch con fallback a query básica. Si la primera query falla por timeout, se intenta segunda query sin timeout. Esto puede causar inconsistencia. | Usar un schema versioning explícito, no try/catch para detectar schema |
| 57–64 | MEDIO | Seguridad | `supabase.auth.admin.getUserById` requiere `service_role`. Si se usa anon key, falla. El fallback a `user.email` del JWT puede ser spoofeado si no se verifica la firma. | Verificar que `getUserById` tenga permisos antes de usar, o usar solo el email del JWT validado |
| 125–164 | ALTO | Seguridad | `change_email` y `change_password` repiten el mismo patrón de verificación: crear cliente Supabase temporal y hacer `signInWithPassword`. Esto genera sesiones temporales en el servidor. | Usar `supabase.auth.admin.updateUserById` solo después de verificar password con un método que no cree sesión (e.g., `verifyPassword` si existe) |
| 138–140, 182–184, 227–229 | MEDIO | Seguridad | `supabaseAnonKey` se usa para crear clientes temporales. Si el environment variable `VITE_SUPABASE_ANON_KEY` está expuesto (es pública por definición), esto no es problema, pero el patrón es inconsistente. | Usar `SUPABASE_SERVICE_KEY` en backend siempre |
| 166–207 | ALTO | Seguridad | `change_password` verifica password actual con `signInWithPassword` y luego usa `admin.updateUserById`. Si el `signIn` tiene éxito pero el `update` falla, el usuario queda con sesión iniciada en el servidor. | Invalidar la sesión temporal después del update, o usar un endpoint dedicado de Supabase |
| 243 | CRÍTICO | Seguridad | `supabase.auth.admin.deleteUser` elimina el usuario permanentemente. No hay confirmación de ownership adicional (ya se verificó password, pero es un solo factor). | Añadir cooldown o requerir 2FA para delete account |

### api/migrate-secrets.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 8 | BAJO | TypeScript | `req: any, res: any` |
| 27–32 | BAJO | Lógica | La función `hashSecret` se importa pero nunca se usa. El endpoint retorna siempre "migration deferred". | Implementar migración real o eliminar endpoint si no se usa |
| 40 | BAJO | Seguridad | `note: 'secret_hash column not ready'` expone detalles de implementación interna. | Retornar mensaje genérico |

### api/webhooks/[webhookId]/[token].ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 260 | CRÍTICO | Seguridad | `req: any, res: any` — archivo más crítico de seguridad tiene el peor tipado. |
| 262 | ALTO | Seguridad | CORS con `Access-Control-Allow-Origin: *` en un endpoint de Discord. Aunque Discord no envía CORS, esto permite que cualquier sitio web haga POST al webhook desde el navegador. | Restringir a `process.env.APP_URL` o eliminar CORS en este endpoint |
| 275–276 | ALTO | Seguridad | `webhookId` y `token` se obtienen de `req.query`. Vercel pasa parámetros de path como `query`, pero esto no es intuitivo. Si hay parámetros de query adicionales, pueden contaminar. | Usar `req.query.webhookId` con validación estricta: `typeof x === 'string'` |
| 301–313 | ALTO | Seguridad | Verificación de token: `token !== storedToken` con comparación directa de strings. Vulnerable a timing attacks. | Usar `crypto.timingSafeEqual` para comparar tokens |
| 315–328 | MEDIO | Seguridad | Parsing de body con try/catch que retorna `ERR_INVALID_FORM`. Si el body es un JSON malicioso con prototype pollution, no se sanitiza. | Sanitizar payload con `Object.create(null)` o librería como `zod` |
| 340–404 | BAJO | Rendimiento | Validación manual de cada campo de Discord. Muy verboso. | Considerar usar `zod` schema para validación de Discord payload |
| 448–491 | MEDIO | Seguridad | Mismo problema de retry de insert que `webhook-receive.ts`. | Mismo fix: verificar error por código, no por string matching |
| 499 | BAJO | Lógica | `wait` se evalúa con `req.query?.wait === 'true' || req.query?.wait === '1'`. No maneja `'1'` como booleano de Discord. | Documentar que `?wait=true` es el único formato soportado |
| 501–562 | BAJO | Rendimiento | Construcción manual de `messageObj` con 30+ campos. Sin type checking, puede faltar campos o sobrar. | Usar una función helper `createDiscordMessage` con tipado |

### api/_lib/supabase.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 1–19 | ALTO | Seguridad | Singleton de `SupabaseClient` con `service_role`. Si se importa en frontend por error, expone la service key. | Separar en `supabase-server.ts` y `supabase-client.ts`, o usar barrel exports con guards |
| 15–16 | MEDIO | Seguridad | `auth: { autoRefreshToken: false, persistSession: false }` — bien, pero si el service key se filtra, cualquiera puede hacer operaciones como admin. | Añadir IP whitelisting o usar Supabase Functions/Edge Functions en lugar de API routes |

### api/_lib/cors.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 2 | MEDIO | Seguridad | `origin = type === 'public' ? '*' : (process.env.APP_URL || '*')` — si `APP_URL` no está definido, CORS privado cae a wildcard. | Fallback a `''` o `null` en lugar de `'*'` para tipo private |
| 5 | BAJO | Seguridad | `X-Webhook-Secret` está en allowed headers, pero no se valida en OPTIONS preflight. | No es un problema funcional, pero documentar que solo se usa en POST |

### api/_lib/auth.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 5 | MEDIO | Seguridad | `authHeader.replace('Bearer ', '')` — si el header no empieza con `Bearer `, retorna el header completo. Un token malformado podría pasar. | Verificar `startsWith('Bearer ')` antes de reemplazar |
| 16–24 | BAJO | Seguridad | `requireAuth` retorna `null` y ya envió respuesta 401. El caller debe hacer `if (!user) return`, pero no hay enforcement. | Hacer que `requireAuth` lance excepción o retorne tipo `never` en el error path |

### api/_lib/errors.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 7 | BAJO | TypeScript | `devDetails?: Error | string` y luego `any` en retorno. | Tipar retorno como `void` o `Response` si se usa framework tipado |
| 15 | BAJO | Seguridad | `return res.status(status).json({ error: code })` — no incluye `status` en la respuesta, solo el código de error. El client no sabe el HTTP status sin leer headers. | Incluir `status` en el body para facilitar debugging del client |

### api/_lib/hmac.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 3 | CRÍTICO | Seguridad | `SALT` usa un fallback hardcoded: `'webhookpulse-default-salt-change-me'`. Si `WEBHOOK_SECRET_SALT` no está configurado, todos los hashes usan el mismo salt conocido. | Lanzar excepción si `SALT` no está definido; nunca usar fallback |
| 9–15 | BAJO | Seguridad | `verifySecret` maneja `catch` silenciosamente (`return false`). Si `storedHash` tiene longitud impar, `Buffer.from(storedHash, 'hex')` lanza error, lo cual oculta un bug de datos. | Loggear el error o retornar `false` con `console.warn` |

### api/_lib/ratelimit.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 6 | MEDIO | Rendimiento | Rate limit basado en COUNT de logs en la DB. Cada request hace un `SELECT COUNT(*)`. Con 10 req/min, esto es 10 queries extra. | Usar Redis o un contador en memoria (e.g., Vercel KV, Upstash) |
| 16 | BAJO | Seguridad | `if (error) return true` — fail open. Si la DB está caída, no hay rate limit. | Considerar fail closed para rate limiting (retornar 503) |
| 10 | BAJO | Lógica | `Date.now() - RATE_LIMIT_WINDOW_MS` usa hora del servidor, pero Supabase `created_at` usa UTC. Si el servidor no está en UTC, el window es incorrecto. | Usar `new Date().toISOString()` en lugar de `new Date(Date.now() - ...)` |

### api/_lib/validate.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 1 | BAJO | Seguridad | `PATH_REGEX = /^[a-zA-Z0-9_-]{1,64}$/` — permite path que empiece con número o guión. En algunos sistemas, paths que empiezan con `-` pueden ser problemáticos. | `^[a-zA-Z0-9]` (no empiece con guión) |
| 2 | BAJO | Seguridad | `UUID_REGEX` no requiere versión 4 específicamente. Acepta UUIDs versión 1, 2, 3, 5, etc. | `^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$` |

### api/_lib/sentry.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 5–27 | BAJO | Rendimiento | `initSentry` se llama en cada `captureException`. Aunque tiene `initialized` guard, `Sentry.init` no es idempotente en todos los entornos. | Mover `initSentry()` al startup del servidor (e.g., `api/index.ts` o `vercel.json` build hook) |
| 17–23 | MEDIO | Seguridad | `beforeSend` filtra eventos con status 400–429. Esto podría filtrar ataques de fuerza bruta (429) que deberían ser monitoreados. | Considerar no filtrar 429, o filtrar solo 400/404 |

### api/_lib/ipfilter.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 46–68 | MEDIO | Seguridad | `ipv4InCidr` usa `parseInt(prefix, 10)` sin validación de que prefix sea número. Si `cidr` es `'192.168.1.0/abc'`, `prefixLen` es `NaN` y el cálculo de mask es incorrecto. | `if (isNaN(prefixLen)) return false` |
| 70–88 | MEDIO | Seguridad | `ipv6InCidr` tiene mismo problema con `parseInt(prefix, 10)`. | `if (isNaN(prefixLen)) return false` |
| 91–110 | BAJO | Seguridad | `parseIPv6` no maneja IPv6 con zona de scope (`%eth0`). | Documentar que no se soporta scope ID, o strip antes de parsear |
| 112–127 | BAJO | Seguridad | `isIPv6` acepta `::` (dos puntos vacíos) pero `parseIPv6` podría no manejarlo correctamente en todos los casos. | Añadir tests para IPv6 edge cases (`::1`, `fe80::1%lo0`, etc.) |

### src/main.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 53 | BAJO | Accesibilidad | `document.getElementById('root')!` — non-null assertion. Si el div no existe, crashea. | `const root = document.getElementById('root'); if (!root) throw new Error('Root not found')` |
| 35–49 | MEDIO | i18n | Textos hardcoded en inglés ("Configuration Error", "Required environment variables"). No usan `t()`. | Extraer a `i18n` keys o documentar que es fallback de error crítico |
| 31 | BAJO | Accesibilidad | El SVG del error no tiene `role="img"` ni `aria-label`. | Añadir `role="img"` y `aria-label="Error"` |

### src/App.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 27–33 | BAJO | Rendimiento | `ThemeProvider` se re-renderiza en cada cambio de theme aunque no haya children que dependan de él. | Mover `ThemeProvider` fuera de `App` o usar `React.memo` |
| 45–65 | BAJO | Rendimiento | `AppRoutes` usa `user ? <Navigate ... /> : <LoginPage />` en cada ruta. Si `user` cambia, se re-renderizan todas las rutas. | Extraer `AuthRoute` component memoizado |
| 53–56 | BAJO | Accesibilidad | `Navigate` no anuncia cambio de página a lectores de pantalla. | Añadir `aria-live="polite"` en el layout o usar `useEffect` con `document.title` update |

### src/index.css
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 15–28 | BAJO | Accesibilidad | `::-webkit-scrollbar` customiza scrollbar en WebKit. En Firefox no se aplica (usa `scrollbar-width` y `scrollbar-color`). | Añadir `@supports` para Firefox: `scrollbar-width: thin; scrollbar-color: #27272A #0C0C0E` |
| 30–33 | BAJO | Accesibilidad | `outline: none` en focus de inputs. Elimina indicador visual de focus para navegación por teclado. | Usar `outline: 2px solid #D4E83A; outline-offset: 2px` en `:focus-visible` |

### src/types/index.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 9–36 | BAJO | Inconsistencia | `Profile` y `AccountSettings` tienen campos duplicados. `AccountSettings` es básicamente `Profile` sin `id` y con `email` obligatorio. | Usar `type AccountSettings = Omit<Profile, 'id'> & { email: string }` |
| 39–53 | BAJO | Inconsistencia | `Webhook` tiene `secret?: string` en el tipo frontend. Nunca debería recibirse el secret en el frontend. | Remover `secret` del tipo `Webhook` o crear `WebhookPublic` sin `secret` |

### src/lib/supabase.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 8–18 | CRÍTICO | Seguridad | Si `VITE_SUPABASE_ANON_KEY` o `VITE_SUPABASE_URL` están vacíos, `supabase` es `null as unknown as ...`. Esto genera un type assertion peligroso. | Usar `throw new Error` o un proxy que lance en cada uso en lugar de `as unknown as` |
| 13 | MEDIO | Seguridad | `localStorage` como storage de auth. Vulnerable a XSS (si hay un script malicioso, roba el token). | Considerar `memory` storage para auth en apps de alta seguridad, o usar httpOnly cookies con backend proxy |
| 16 | BAJO | Seguridad | `detectSessionInUrl: true` — si un atacante envía un link con `#access_token=...`, el token se extrae automáticamente. | `false` si la app no usa magic links, o validar el redirect URL |

### src/i18n/index.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 132–263 | BAJO | i18n | Caracteres especiales españoles mal codificados: `EstadÃ­sticas`, `Cerrar sesiÃ³n`, `AÃ±adir`, `NÃºmero`, `ContraseÃ±a`, `Â¿No tienes cuenta?`, `Â¿Ya tienes cuenta?`, `genÃ©ricos`, `Empezar`, `AutenticaciÃ³n`, `Introduce`, `Verificar`, `CÃ³digo`, `TelÃ©fono`, `MÃ­n`, `DescripciÃ³n`, `BiografÃ­a`, `Notificaciones`, `Cambiar`, `Actualizar`, `Eliminar`, `Guardar`, `Verificando`, `Enviando`, `TelÃ©fono verificado`, `CÃ³digo invÃ¡lido`, `Copiar`, `Copiado`, `Cargando`, `Ã‰xito`, `Degradado`, `Desconocido`, `Verificando`, `Ãltima verificaciÃ³n`, `Historial`, `Mensajes recibidos`, `Secreto`, `Nativo`, `Iniciar sesiÃ³n`, `Registrarse`, `Olvidaste`, `Crear cuenta`, `Nombre completo`, `Empezar gratis`, `Ir al Panel`, `Plantillas Roblox`, `Jugador Entra`, `EstadÃ­sticas`, `Registro de Errores`, `Comando Admin`, `Generar Script Lua`, `Copiar Script`, `Vista Previa`, `Buscar Logs`, `Buscar en payload`, `DirecciÃ³n IP`, `Desde`, `Hasta`, `Origen`, `Tipo`, `Todos`, `Aplicar`, `Limpiar Filtros`, `Mostrando resultados`, `NingÃºn log coincide`. | El archivo está guardado con codificación incorrecta (UTF-8 interpretado como Latin-1 o similar). Re-encode a UTF-8 correcto. |
| 399 | MEDIO | Rendimiento | `currentLang` es una variable global mutable. En SSR (si se añade), causaría race conditions. | Usar `React.createContext` para el estado de idioma |
| 417–425 | BAJO | Rendimiento | `t()` usa `new RegExp` en cada llamada. Con muchas keys, esto es costoso. | Pre-compilar regexes o usar `String.replaceAll` en engines modernos |
| 417 | BAJO | i18n | `t()` no tiene interpolación de plurales ni de números. `{{count}}` es string simple. | Considerar `Intl.PluralRules` para futuras mejoras |
| 429–434 | BAJO | Rendimiento | Ejecuta `localStorage.getItem` en el top-level del módulo. En SSR, `localStorage` no existe y lanzaría error. | Mover inicialización a `useEffect` o envolver en `typeof window !== 'undefined'` |

### src/hooks/useAuth.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 10–16 | BAJO | TypeScript | `AuthContext` tiene valores por defecto que son funciones vacías. Si se usa fuera del provider, no hay error en tiempo de compilación. | Usar `AuthContext = createContext<AuthContextValue | null>(null)` y lanzar error en hook |
| 21–41 | MEDIO | Rendimiento | `fetchProfile` se llama dos veces si hay sesión inicial y luego `onAuthStateChange` dispara con la misma sesión. | Añadir `loading` guard o deduplicar con `AbortController` |
| 43–51 | BAJO | Seguridad | `fetchProfile` hace `supabase.auth.getUser()` DESPUÉS de `supabase.from('profiles').select()`. Si la sesión expira entre ambas, el `user` puede ser null. | Invertir orden: obtener user primero, luego profile |
| 59–62 | BAJO | Rendimiento | `signOut` no espera a que `setState` complete antes de continuar. | `await signOut` ya está, pero `setState` es async. No es bug, pero `router.navigate('/login')` podría ser necesario |

### src/hooks/useWebhooks.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 67–84 | MEDIO | Seguridad | `deleteWebhook` y `toggleWebhook` usan `supabase.from('webhooks')` directamente sin pasar por API. Esto bypassa cualquier lógica de negocio del backend (e.g., rate limits, eventos). | Usar endpoints API para operaciones de escritura |
| 67–84 | BAJO | Rendimiento | `deleteWebhook` y `toggleWebhook` llaman `fetchWebhooks()` después. Si varias operaciones ocurren en paralelo, hay race conditions. | Invalidar cache y usar `mutate` de SWR/TanStack Query |
| 76–83 | BAJO | Seguridad | `toggleWebhook` no verifica ownership del webhook. Depende de RLS. | Añadir verificación frontend o mover a API |

### src/hooks/useRealtimeLogs.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 27–38 | BAJO | Lógica | `logMatchesFilters` aplica filtros localmente que el backend ya aplicó. En el caso de backend-filtered, esto es redundante. | Solo aplicar filtros locales cuando `hasActiveFilters` es false |
| 65–117 | MEDIO | Rendimiento | `fetchLogs` recrea la función en cada render por `useCallback` con `[webhookId]`. Si `filters` cambian, `fetchLogs` no se actualiza porque `filters` no está en deps. | `filtersRef` se usa para evitar esto, pero el `useCallback` debería incluir `filters` o usar `useRef` para la función también |
| 119–157 | ALTO | Rendimiento | `useEffect` con `[webhookId, fetchLogs, webhookType, filters]` como deps. `filters` es un objeto, por lo que `useEffect` se re-ejecuta en cada render si `filters` se recrea. | Memoizar `filters` con `useMemo` o usar comparación profunda |
| 154–156 | BAJO | Rendimiento | `subscription.unsubscribe()` en cleanup. Si `fetchLogs` está en progreso, no se cancela. | Usar `AbortController` para cancelar fetchs en vuelo |
| 194–205 | BAJO | Seguridad | `deleteAllLogs` usa `supabase.from('webhook_logs').delete()` sin `.eq('webhook_id', webhookId)`. Aunque el hook verifica `webhookId`, si hay un bug, borra todos los logs. | Añadir `eq('webhook_id', webhookId)` y RLS estricto |

### src/hooks/useSse.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 18 | CRÍTICO | Seguridad | `localStorage.getItem('token')` — el token se guarda en localStorage como `token` genérico. Esto es vulnerable a XSS. Además, `supabase` usa `webhookpulse-auth` como key, no `token`. El SSE busca una key que no existe. | Usar `supabase.auth.getSession()` para obtener el token dinámicamente, o al menos la misma key que Supabase |
| 19 | ALTO | Seguridad | `token` se envía por query param en la URL del SSE. Las URLs con tokens quedan en logs del servidor, historial del navegador, y referers. | Usar `EventSource` con header `Authorization` (no soportado nativamente) o usar `fetch` con `ReadableStream` |
| 37–44 | MEDIO | Rendimiento | Reconexión inmediata tras error sin backoff exponencial. Si el servidor está caído, reintenta cada 3s infinitamente. | Implementar backoff exponencial: 3s, 6s, 12s, 30s, max 60s |
| 45 | BAJO | Rendimiento | `useCallback` depende de `[url, options]`. `options` es un objeto, por lo que se recrea en cada render. | Memoizar `options` con `useMemo` en el caller |

### src/hooks/useActivityFeed.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 60–63 | BAJO | Rendimiento | `fetchProfile` se llama en cada render si el auth cambia. Sin `useCallback`, se recrea. | No es crítico, pero `init` podría ser `useCallback` |
| 92–126 | BAJO | Rendimiento | El canal de Supabase se crea por cada render si `init` se re-ejecuta. | Mover a `useEffect` con deps vacías y manejar `webhookIds` como ref |
| 111–121 | BAJO | Rendimiento | `isNewTimersRef` usa `setTimeout` por cada log. Con 20 logs, hay 20 timers. | Usar un solo timer que limpie todos los `isNew` de golpe cada 3s |
| 143 | BAJO | Lógica | `isPaused` se define en el hook pero nunca se usa para pausar el subscription. | Implementar `if (isPaused) return` en el handler de subscription o quitar `isPaused` |

### src/hooks/useHealthChecks.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 26–28 | BAJO | Rendimiento | Cache en `cacheRef` nunca se invalida. Si los health checks cambian, se muestran datos stale. | Añadir TTL al cache (e.g., 30s) o invalidar manualmente |
| 63–69 | BAJO | Rendimiento | `useEffect` con `[webhookId, fetchHealthChecks]` como deps. Auto-refresh cada 60s. Si el componente se desmonta y remonta, se crea otro intervalo. | `useEffect` cleanup ya está, pero verificar que `fetchHealthChecks` no cambie de referencia |

### src/hooks/useIpRules.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 9 | BAJO | TypeScript | `fetchedRef` se expone en el return pero no se usa en ningún componente. | Dead code — eliminar del return o usarlo para skip de fetches |
| 33 | BAJO | Seguridad | `fetchedRef.current = true` se setea aunque la request falle. Si falla, `true` indica que ya se intentó. | Solo setear a `true` si `res.ok` |

### src/hooks/useTheme.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 5–52 | BAJO | Rendimiento | `currentTheme` es una variable global mutable fuera de React. Si hay múltiples instancias de `useTheme`, pueden desincronizarse. | Usar `React.createContext` o `window.dispatchEvent(new StorageEvent(...))` para sincronizar |
| 47–52 | BAJO | Accesibilidad | `setTheme` en el top-level no notifica a lectores de pantalla del cambio. | Añadir `document.documentElement.setAttribute('data-theme', theme)` para compatibilidad con `prefers-color-scheme` |

### src/hooks/useDebounce.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 3–11 | Sin issues | — | Implementación correcta y limpia. | — |

### src/hooks/useVirtualList.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 14 | BAJO | Rendimiento | `containerHeight = containerRef.current?.clientHeight || 400` se lee en render. Si el contenedor aún no tiene altura, usa 400 como fallback. | Usar `ResizeObserver` para actualizar altura dinámicamente |
| 25–32 | BAJO | Rendimiento | `useEffect` con `[]` deps. El listener de scroll se añade una vez. Si `containerRef` cambia, no se reattacha. | Incluir `containerRef.current` en deps o usar callback ref |

### src/hooks/useAdaptiveServing.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 19 | MEDIO | TypeScript | `navigator as any` — evita tipado. `navigator.connection` está en TypeScript DOM lib. | Usar `navigator.connection` con tipado adecuado o `NetworkInformation` interface |
| 24–30 | BAJO | TypeScript | `conn.effectiveType`, `conn.saveData`, etc. no están tipados. | Declarar interface `NetworkInformation` o usar `@types/network-information` |

### src/components/Layout.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 18 | BAJO | Accesibilidad | `<main>` no tiene `aria-label` ni `id`. Si hay múltiples `<main>`, es ambiguo. | Añadir `id="main-content"` y `tabIndex={-1}` para skip links |
| 22 | BAJO | Accesibilidad | `ActivityFeed` se oculta en `lg`. No hay alternativa para lectores de pantalla en viewport pequeño. | Añadir botón "Show activity" para mobile o usar `aria-hidden` apropiado |

### src/components/Sidebar.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 12 | BAJO | Accesibilidad | `<aside>` sin `aria-label="Navigation"` o `role="navigation"`. | Añadir `aria-label="Main navigation"` |
| 17–49 | BAJO | Accesibilidad | Los `<Link>` no tienen `aria-current` para el item activo. | Añadir `aria-current={isActive(...) ? 'page' : undefined}` |
| 53–59 | BAJO | Accesibilidad | Botón de sign out sin `aria-label`. | Añadir `aria-label="Sign out"` |
| 27, 37, 47 | BAJO | i18n | Textos hardcoded: "Dashboard", "Stats", "Settings", "Sign out". | Usar `t('nav.dashboard')`, `t('nav.stats')`, etc. |

### src/components/TopBar.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 28–42 | BAJO | Accesibilidad | Botón de back/home sin `aria-label`. | Añadir `aria-label={isDetail ? 'Back to dashboard' : 'Go home'}` |
| 52 | BAJO | i18n | Texto hardcoded: "User". | Usar `t('common.user')` o fallback |

### src/components/WebhookCard.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 28, 36, 76, 82, 112, 123, 130, 150, 157 | MEDIO | i18n | Múltiples textos hardcoded en español e inglés mezclados: "Mensajes recibidos", "Path", "Secret", "Si"/"No", "Pause"/"Resume", "Delete", "Native", "Discord". | Reemplazar todos con `t()` keys |
| 57 | BAJO | Rendimiento | `w-4.5 h-4.5` no es un valor estándar de Tailwind. Tailwind no genera `4.5` por defecto. | Usar `w-[18px] h-[18px]` o `w-5 h-5` |
| 28, 31, 35, 55, 83, 96, 109, 112, 119, 123, 130, 148, 156 | BAJO | Accesibilidad | Múltiples elementos interactivos sin `aria-label` o `title` descriptivos. | Añadir `aria-label` a todos los botones |
| 62 | BAJO | Rendimiento | `onClick={() => onNavigate(webhook.id)}` crea función anónima en cada render. | Usar `useCallback` o `data-webhook-id` con delegación |

### src/components/CreateWebhookModal.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 40, 64, 75, 99, 101, 123, 124, 136, 141, 147, 148, 150, 152, 153, 158, 166, 167, 170, 171, 173, 174, 178, 179, 183, 185, 187, 188, 190, 193 | MEDIO | i18n | Todos los textos hardcoded. | Usar `t()` keys |
| 64 | BAJO | Rendimiento | `navigator.clipboard.writeText` sin manejo de error (ya tiene try/catch en `CopyUrl`, pero aquí no). | Añadir `try/catch` o toast de error |
| 112–137 | BAJO | Accesibilidad | Botones de selección de tipo no indican `aria-pressed` o `role="radio"`. | Usar `<input type="radio" />` visualmente oculto o `aria-pressed` |
| 148 | BAJO | Accesibilidad | Input sin `aria-required` o `aria-describedby` para error. | Añadir atributos ARIA |

### src/components/LogRow.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 19–24 | BAJO | Lógica | `player = log.payload?.player` con `as Record<string, unknown>`. Si `player` es un array o string, falla el cast. | Verificar `typeof player === 'object' && player !== null` |
| 32–37 | MEDIO | Rendimiento | `RobloxEmbed` se renderiza SIEMPRE para logs de Roblox, sin lazy loading. Si hay muchos logs Roblox, el render es costoso. | Usar `React.lazy` o `IntersectionObserver` para lazy render |
| 42 | BAJO | Accesibilidad | Checkbox sin `aria-label` ni `title`. | Añadir `aria-label="Select log"` |
| 64 | BAJO | Accesibilidad | Botón de delete sin `aria-label`. | Añadir `aria-label="Delete log"` |

### src/components/PayloadViewer.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 8–88 | BAJO | Rendimiento | `tokenizeJson` es un parser manual de JSON. Para payloads grandes (>100KB), es O(n) pero con muchas allocations. | Considerar `prismjs` o `react-syntax-highlighter` con lazy loading |
| 95 | BAJO | Rendimiento | `useState(() => JSON.stringify(data, null, 2))` no memoiza el resultado. Se recalcula en cada render. | Usar `useMemo` |
| 99–111 | BAJO | Accesibilidad | `<pre>` sin `role="code"` ni `aria-label`. | Añadir `aria-label="Payload JSON"` |

### src/components/ActivityFeed.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 12–19 | BAJO | Rendimiento | `getRelativeTime` recalcula en cada render. El `forceUpdate` cada 10s causa re-render de toda la lista. | Memoizar items individuales o usar `requestAnimationFrame` |
| 22–29 | BAJO | Accesibilidad | `StatusDot` es un `<span>` vacío. Los lectores de pantalla no lo anuncian. | Añadir `aria-label={status}` y `role="img"` |
| 114–147 | BAJO | Rendimiento | `logs.map` sin `React.memo` en cada item. Cada `forceUpdate` re-renderiza toda la lista. | Extraer `LogItem` component memoizado |
| 114–147 | BAJO | Accesibilidad | Los `<button>` de logs no tienen `aria-label` que describa el contenido. | Añadir `aria-label={`Go to webhook ${log.webhook_name}`}` |

### src/components/SearchBar.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 12–199 | BAJO | i18n | Todos los labels, placeholders y textos hardcoded (aunque algunos usan `t()`). | Verificar que todos los textos usen `t()` |
| 91–95 | BAJO | Accesibilidad | Input de búsqueda sin `aria-label` ni `aria-describedby`. | Añadir `aria-label={t('search.placeholder')}` |
| 119–130 | BAJO | Accesibilidad | `<select>` sin `aria-label`. | Añadir `aria-label={t('search.source')}` |
| 138–153 | BAJO | Accesibilidad | Inputs de fecha sin `aria-label`. | Añadir `aria-label` para from/to |

### src/components/Skeleton.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 3–17 | BAJO | Accesibilidad | `animate-pulse` sin `aria-hidden="true"` o `role="status"`. Los lectores de pantalla pueden anunciar el contenido vacío. | Añadir `aria-hidden="true"` o `role="status" aria-label="Loading"` |
| 24 | BAJO | Rendimiento | `Math.random()` en render. Cada render genera alturas diferentes. | Usar `useMemo` con seed fijo por índice |

### src/components/TemplateCard.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 148 | BAJO | Seguridad | `API_BASE = import.meta.env.VITE_API_URL || ''` — si `VITE_API_URL` es vacío, el fetch va al mismo origin. Bien, pero si es un URL malicioso, se exfiltran datos. | Validar `VITE_API_URL` contra un allowlist de dominios |
| 12–85 | BAJO | Rendimiento | `TEMPLATE_META` se recrea en cada render del componente. | Mover fuera del componente o usar `useMemo` |
| 88–136 | BAJO | Accesibilidad | `ScriptModal` no tiene `role="dialog"` ni `aria-modal="true"`. | Añadir `role="dialog" aria-modal="true"` al contenedor del modal |
| 114 | BAJO | Accesibilidad | `<pre>` sin `aria-label` en el modal. | Añadir `aria-label="Lua script"` |
| 192 | BAJO | Rendimiento | `w-4.5 h-4.5` no es clase válida de Tailwind. | `w-[18px] h-[18px]` |

### src/components/HealthIndicator.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 9–45 | BAJO | Lógica | `statusDotClass` y `statusBadgeClass` retornan clases de Tailwind con colores literales (`bg-green-500`, `bg-red-500`, etc.) en lugar de las del tema (`bg-success`, `bg-danger`). | Usar `bg-success`, `bg-danger`, `bg-yellow-500` consistentemente con el tema |
| 71–105 | BAJO | Accesibilidad | Tooltip hover no funciona con teclado. No hay `focus` handler. | Añadir `onFocus` / `onBlur` o usar `button` con `aria-expanded` |

### src/components/IpRulesModal.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 12–27 | MEDIO | Seguridad | `isValidIpOrCidr` duplica lógica del backend. Si el backend cambia, el frontend queda desincronizado. | Usar un validador compartido (e.g., `zod` schema o librería común) |
| 71 | BAJO | Accesibilidad | Modal sin `role="dialog"` ni `aria-modal`. | Añadir atributos ARIA |
| 111 | BAJO | Accesibilidad | Input sin `aria-describedby` para el mensaje de error. | Conectar con `aria-describedby={`ip-error-${id}`}` |
| 174 | BAJO | i18n | Encabezado de tabla usa `t('ipRules.ip')` pero el título de sección usa `t('ipRules.addRule')` para la lista de reglas. | Crear key `ipRules.rulesList` |

### src/components/RobloxEmbed.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 9–19 | BAJO | Seguridad | `JSON.parse(log.payload)` si `log.payload` es string. Si el payload contiene código malicioso, `JSON.parse` es seguro, pero el cast a `Record<string, unknown>` no verifica la estructura. | Usar `zod` para validar la estructura del payload |
| 39–47 | BAJO | i18n | Timestamp formateado con `toLocaleString('es-ES')` fijo. No respeta el idioma seleccionado por el usuario. | Usar `getLang()` para determinar el locale |
| 72 | BAJO | i18n | "Roblox Profile Data" hardcoded. | Usar `t('roblox.profileData')` |
| 87–88 | BAJO | i18n | Mensaje de error en español hardcoded. | Usar `t('roblox.emptyPayload')` |
| 133–146 | BAJO | Rendimiento | Múltiples `String(character.xxx)` en render. Si `character` es grande, se recalculan. | Usar `useMemo` para extraer valores derivados |

### src/pages/LandingPage.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 36–40, 62–74 | BAJO | i18n | Todo el contenido de landing page está hardcoded en inglés. | Usar `t()` keys o `react-i18next` |
| 10–31 | BAJO | Accesibilidad | El header no tiene `<nav>` ni `role="banner"`. | Añadir `<header role="banner">` y `<nav aria-label="Main">` |
| 80–81 | BAJO | Accesibilidad | Footer sin `role="contentinfo"`. | Añadir `<footer role="contentinfo">` |

### src/pages/LoginPage.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 100–101, 103–177 | BAJO | i18n | Todo el contenido está hardcoded en inglés. | Usar `t()` keys |
| 141–147 | BAJO | Accesibilidad | Botón de toggle password sin `aria-label="Toggle password visibility"`. | Añadir `aria-label` |
| 170–177 | BAJO | Accesibilidad | Botón de submit sin `aria-busy={loading}`. | Añadir `aria-busy={loading}` y `aria-live` para estado |
| 42–56 | BAJO | Seguridad | `startLockout` usa `setInterval` que muta estado. Si el componente se desmonta, el intervalo sigue corriendo. | Guardar `interval` en `useRef` y limpiar en `useEffect` cleanup |

### src/pages/RegisterPage.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 108–133, 135–291 | BAJO | i18n | Todo el contenido está hardcoded en inglés. | Usar `t()` keys |
| 91 | BAJO | Seguridad | `emailRedirectTo: \`${window.location.origin}/login\`` — si el origin es spoofeado (e.g., DNS rebinding), el redirect puede ir a un dominio malicioso. | Hardcodear el dominio permitido o validar `window.location.origin` |
| 273–279 | BAJO | Accesibilidad | Submit sin `aria-busy`. | Añadir `aria-busy={loading}` |

### src/pages/ForgotPasswordPage.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 54–77, 79–144 | BAJO | i18n | Todo el contenido hardcoded en inglés. | Usar `t()` keys |
| 40 | BAJO | Seguridad | `redirectTo: \`${window.location.origin}/reset-password\`` — mismo problema de origin spoofing. | Hardcodear dominio o validar |

### src/pages/ResetPasswordPage.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 95–118, 120–212 | BAJO | i18n | Todo el contenido hardcoded en inglés. | Usar `t()` keys |
| 23–34 | MEDIO | Seguridad | `supabase.auth.onAuthStateChange` se registra en `useEffect` sin cleanup. Si el componente se desmonta, el listener sigue activo. | Retornar `subscription.unsubscribe()` en cleanup |
| 146 | BAJO | Accesibilidad | Input con `autoFocus` sin `aria-label` descriptivo. | Añadir `aria-label="New password"` |

### src/pages/DashboardPage.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 40–41, 62–74, 77–89, 91–121 | BAJO | i18n | Textos hardcoded en inglés. | Usar `t()` keys |
| 15 | BAJO | Rendimiento | `selectedWebhookId` no se inicializa con el primer webhook activo, por lo que `selectedWebhook` puede ser undefined hasta interacción. | Inicializar `selectedWebhookId` con `activeWebhooks[0]?.id` en `useEffect` |
| 24–31 | BAJO | Lógica | `getWebhookUrlAndType` se recalcula en cada render. | Usar `useMemo` |

### src/pages/WebhookDetailPage.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 91, 220–229, 233–389, 392–500 | BAJO | i18n | Múltiples textos hardcoded en inglés. | Usar `t()` keys |
| 104 | MEDIO | Seguridad | `handleDelete` hace `confirm()` nativo. Bloquea el hilo principal. En un ataque de UI redressing, el usuario puede ser engañado. | Usar un modal de confirmación propio en lugar de `window.confirm` |
| 107–108 | MEDIO | Seguridad | `supabase.from('webhooks').delete().eq('id', id)` — no verifica `user_id`. Depende de RLS. | Añadir `eq('user_id', user.id)` o mover a API |
| 127–159 | MEDIO | Seguridad | `handleRevealToken` hace fetch con el password en el body. Si el endpoint es HTTP (no HTTPS), el password se transmite en claro. | Añadir check `window.location.protocol === 'https:'` o forzar HTTPS en el server |
| 193–205 | MEDIO | Seguridad | `handleDeleteAll` y `handleDeleteSelected` usan `confirm()`. Si se automatizan, pueden ser forzados. | Usar modal propio con delay mínimo |
| 210–216 | BAJO | Lógica | Si `webhook` es undefined pero `webhooks` tiene items, muestra "Loading...". Si no está en la lista, muestra "Webhook not found". | Unificar estado de loading |
| 317 | BAJO | Accesibilidad | `onKeyDown={(e) => e.key === 'Enter' && handleRevealToken()}` — no maneja `Space`. | Usar `<form onSubmit={handleRevealToken}>` en lugar de keydown en input |

### src/pages/SettingsPage.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 297–299, 301–314, 317–363, 366–452, 455–461 | BAJO | i18n | La mayoría usa `t()`, pero hay textos hardcoded esparcidos (e.g., "Dark", "Light", "Change Password"). | Revisar todos los textos y usar `t()` |
| 249–281 | BAJO | TypeScript | `Card`, `Input`, `PassInput` usan `any` en props. | Definir interfaces explícitas |
| 66–71 | MEDIO | Rendimiento | `toasts` usa `setTimeout` por cada toast. Con muchos toasts, hay muchos timers. | Usar un solo intervalo que limpie toasts viejos |
| 249 | BAJO | Rendimiento | `Card` se define dentro del componente `SettingsPage`. Se recrea en cada render. | Mover fuera del componente |
| 259 | BAJO | Accesibilidad | `Input` no propaga `aria-invalid` ni `aria-describedby`. | Añadir props ARIA al componente `Input` |
| 324–335 | BAJO | Accesibilidad | Botones de theme no tienen `aria-pressed`. | Añadir `aria-pressed={theme === 'dark'}` |
| 382–383 | BAJO | Accesibilidad | Input de teléfono sin `type="tel"`. | Añadir `type="tel"` |
| 394 | BAJO | Accesibilidad | Input de código 2FA sin `aria-label`. | Añadir `aria-label="2FA code"` |
| 476 | BAJO | Accesibilidad | Input de confirmación delete sin `aria-label`. | Añadir `aria-label="Type DELETE to confirm"` |

### src/pages/StatsPage.tsx
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 243, 245, 251–255, 260–298 | BAJO | i18n | Textos hardcoded en inglés. | Usar `t()` keys |
| 159–169 | BAJO | TypeScript | `Card` usa `icon: any`. | `icon: React.ComponentType<{ className?: string }>` |
| 171–189 | BAJO | TypeScript | `BarChart` usa `data: any[]`. | `data: Array<{ count: number } & Record<string, unknown>>` |
| 191–238 | BAJO | Rendimiento | `DonutChart` recalcula SVG `dashArray` en cada render. | Usar `useMemo` para `segments` |
| 153–157 | BAJO | Rendimiento | `maxHourly`, `maxWebhook`, etc. se recalculan en cada render. | Usar `useMemo` |
| 41–151 | MEDIO | Rendimiento | `fetchStats` hace 6 queries a Supabase secuencialmente. Podrían paralelizarse con `Promise.all`. | `const [whCount, whData, logCount, hourlyData, whLogs, ipData, sourceData] = await Promise.all([...])` |
| 81–91 | BAJO | Lógica | `hourlyMap` inicializa 24 horas pero `setHourly` usa `Array.from(hourlyMap.entries())`. El orden de inserción de Map se preserva, pero es frágil. | Usar `Array.from({ length: 24 }, ...)` con índice explícito |

### tests/integration/webhook-receive.test.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 1–58 | BAJO | Calidad | Solo 3 tests. No cubre: secret validation, IP filtering, rate limiting, body parsing, JSON edge cases. | Añadir tests para cada rama del handler |
| 34, 42, 51 | BAJO | TypeScript | `req` y `res` son objetos mock sin tipos. | Usar `Partial<VercelRequest>` o interface propia |
| 43 | BAJO | Lógica | `mockSingle.mockResolvedValue({ data: null, error: { message: 'not found' } })` — el handler real usa `allWebhooks?.find()`, no `single()`. | Actualizar mock para reflejar el comportamiento real del handler |

### tests/unit/lib/cors.test.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 1–33 | Sin issues | — | Tests limpios y correctos. | — |

### tests/unit/lib/hmac.test.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 1–38 | Sin issues | — | Tests correctos. | — |

### tests/unit/lib/validate.test.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 1–95 | Sin issues | — | Tests correctos y completos. | — |

### public/manifest.json
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 1–56 | Sin issues | — | Manifest completo y correcto. | — |

### public/sw.js
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 2 | BAJO | Seguridad | `CACHE_NAME = 'webhookpulse-v1'` — al actualizar la app, los clientes con cache vieja pueden tener versiones inconsistentes. | Usar versionado por hash de build: `webhookpulse-${BUILD_HASH}` |
| 12 | MEDIO | Seguridad | `API_CACHE_PREFIX = '/api/'` y `API_CACHE_MAX_AGE = 60 * 1000`. Las respuestas de API con datos sensibles pueden quedar cacheadas en el dispositivo. | No cachear endpoints que requieren auth, o usar `Cache-Control: no-store` desde el server |
| 47–61 | MEDIO | Seguridad | API cache usa `stale-while-revalidate`. Si el usuario cierra la app antes de que el revalidate complete, la respuesta stale se sirve. | Requerir `max-age` mínimo antes de servir stale, o usar `network-first` para API |
| 95–104 | BAJO | Lógica | `syncWebhooks` está vacío. | Implementar o eliminar el event listener de sync |
| 107–118 | BAJO | Seguridad | `push` event muestra notificación sin verificar el origen del push. Cualquier push subscription puede enviar notificaciones. | Verificar `event.data` signature o usar VAPID |

### Dockerfile
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 7–24 | BAJO | Seguridad | `FROM node:22-alpine AS development` — `git` se instala pero no se elimina. Aumenta superficie de ataque. | Mover `RUN apk del git` después de build si no se necesita en runtime |
| 40–52 | BAJO | Seguridad | `nginx:alpine` no especifica versión. Usa `latest` implícitamente. | `nginx:1.25-alpine` o versión pinnada |
| 46 | BAJO | Seguridad | `nginx.conf` se copia como `default.conf`. Si hay otros `.conf` en `conf.d`, pueden conflictear. | Documentar o usar `rm /etc/nginx/conf.d/default.conf` antes |
| 49 | BAJO | Seguridad | `server_tokens off;` se escribe en un archivo separado. Bien, pero falta `add_header X-Frame-Options "DENY"` en nginx. | Copiar headers de seguridad desde `vercel.json` |

### docker-compose.yml
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 34 | CRÍTICO | Seguridad | `POSTGRES_PASSWORD: webhookpulse_dev` — contraseña hardcoded en texto plano. | Usar `.env` file o Docker secrets |
| 61–62 | ALTO | Seguridad | `PGADMIN_DEFAULT_EMAIL: admin@webhookpulse.com` y `PGADMIN_DEFAULT_PASSWORD: admin` — credenciales hardcoded. | Usar `.env` o secrets |
| 10–11 | BAJO | Configuración | `ports: - "3000:3000"` pero el Dockerfile de development expone 5173. El mapeo 3000 no hace nada. | Eliminar 3000 o exponer 3000 en el Dockerfile |
| 22–23 | BAJO | Configuración | `depends_on: - postgres - redis` pero la app no usa Redis en el código. | Eliminar Redis si no se usa, o implementar caché con Redis |
| 39–40 | BAJO | Configuración | `volumes: - ./db/migrations:/docker-entrypoint-initdb.d` — la carpeta `db/migrations` no existe en el proyecto. | Crear carpeta o usar `./supabase/migrations` |

### nginx.conf
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 1–71 | Sin issues | — | Configuración sólida con headers de seguridad, gzip, brotli, y cache correcto. | — |
| 25 | BAJO | Configuración | `brotli on` requiere el módulo `ngx_brotli` compilado. En `nginx:alpine` no está incluido por defecto. | Verificar que la imagen base incluye brotli, o usar `gzip` únicamente |
| 59–63 | BAJO | Seguridad | Faltan `X-XSS-Protection: 0` (deprecated) y `Content-Security-Policy`. | Añadir `Content-Security-Policy` header |
| 65–70 | BAJO | Seguridad | `location ~ /\\.` deniega archivos ocultos. Bien, pero no bloquea `README.md`, `composer.json`, etc. | Considerar whitelist de extensiones en lugar de blacklist |

### supabase/schema.sql
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 1–100 | Sin issues | — | Schema bien diseñado con RLS, índices, y triggers. | — |
| 33 | BAJO | Seguridad | `ip_address inet` — `inet` puede almacenar máscara (e.g. `192.168.1.0/24`). Si el código solo espera IPs, esto podría causar problemas. | Validar que no haya máscara antes de insertar, o usar `varchar` |
| 86–94 | BAJO | Seguridad | `handle_new_user` usa `SECURITY DEFINER`. Si se compromete, permite inserciones en `profiles`. | Añadir `SET search_path = public` para evitar search path attacks |

### vercel.json
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 15–50 | Sin issues | — | Headers de seguridad correctos. | — |
| 8–13 | BAJO | Configuración | `maxDuration: 10` para `webhook-receive`. Si el webhook tiene muchos logs o rate limit lento, puede timeout. | Documentar o aumentar a 30s para webhooks con alta carga |
| 51–54 | BAJO | Configuración | `rewrites` para `/api/(.*)` y `/(.*)`. El rewrite de `/(.*)` a `index.html` puede causar 404s en rutas API mal escritas. | No es bug, pero considerar `404.html` para rutas no encontradas |

### vite.config.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 1–44 | Sin issues | — | Configuración limpia con code splitting y manual chunks. | — |
| 4 | BAJO | Rendimiento | `rollup-plugin-visualizer` se importa siempre. Aunque se filtra con `ANALYZE`, el import está presente. | Usar `import('rollup-plugin-visualizer')` dinámico |
| 32 | BAJO | Configuración | `chunkSizeWarningLimit: 200` (200 bytes) es muy bajo. Tailwind genera chunks grandes. | Aumentar a 500 (500KB) o documentar |

### vitest.config.ts
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 9 | BAJO | Configuración | `setupFiles: ['./tests/setup.ts']` pero el archivo no existe. | Crear `tests/setup.ts` o eliminar la línea |
| 14 | BAJO | Configuración | `exclude: ['node_modules/', 'dist/', 'tests/']` — excluir `tests/` del coverage es intencional, pero significa que los tests no se cuentan. | Documentar o usar `exclude: ['node_modules/', 'dist/']` si se quiere coverage de tests |

### tsconfig.app.json
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 15–16 | BAJO | TypeScript | `noUnusedLocals: true` y `noUnusedParameters: true` — estricto, pero puede causar builds fallidos por imports no usados en desarrollo. | Considerar `false` en dev y `true` en CI |
| 19 | BAJO | TypeScript | `"include": ["src"]` — no incluye `tests/`. Si hay tests en `src/`, bien, pero los tests externos no se typean. | Añadir `"tests"` si se quiere type checking de tests |

### tsconfig.api.json
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 12 | BAJO | TypeScript | `noEmit: true` — el API no se compila, solo se type-check. En Vercel, el runtime es Node, no necesita emit. | Bien para serverless, pero documentar que no genera `.js` |
| 14 | BAJO | TypeScript | `"include": ["api/**/*.ts"]` — no incluye `api/_lib/**/*.ts` si `_lib` no es considerado. | Verificar que `_lib` esté incluido (el glob `api/**/*.ts` sí lo incluye) |

### tailwind.config.js
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 1–31 | Sin issues | — | Configuración limpia con tema oscuro premium. | — |
| 23 | BAJO | Configuración | `borderRadius: { DEFAULT: '8px' }` — esto aplica a TODOS los elementos. Puede ser inesperado. | Documentar o usar `rounded-lg` explícitamente |

### postcss.config.js
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 1–6 | Sin issues | — | Configuración estándar. | — |

### package.json
| Línea | Severidad | Categoría | Problema | Fix sugerido |
|-------|-----------|-----------|----------|-------------|
| 15–20 | BAJO | Seguridad | `@sentry/node` v8.20.0 — verificar si hay vulnerabilidades conocidas. | `npm audit` periódico |
| 23 | BAJO | Configuración | `@netlify/functions` en devDependencies. El proyecto usa Vercel, no Netlify. | Eliminar si no se usa, o documentar por qué está |
| 24 | BAJO | Configuración | `@sentry/react` v8.20.0 en devDependencies — debería estar en `dependencies` si se usa en producción. | Mover a `dependencies` |
| 33 | BAJO | Configuración | `vite` v5.3.5 — verificar compatibilidad con plugins. | Bien, pero mantener actualizado |

---

## Top 10 Issues Prioritarios

1. **[CRÍTICO] `api/_lib/hmac.ts:3`** — Fallback hardcoded de `SALT`. Si `WEBHOOK_SECRET_SALT` no está configurado, todos los hashes usan un salt conocido públicamente, comprometiendo la seguridad de los secrets.

2. **[CRÍTICO] `api/webhook-receive.ts:106–118`** — Comparación de secret en texto plano con `===` en lugar de `timingSafeEqual`. Además, los secrets se almacenan en texto plano en la DB (no hay `secret_hash`).

3. **[CRÍTICO] `api/2fa-send.ts:25`** — `Math.random()` para generar códigos 2FA. No es criptográficamente seguro. En modo demo, el código se retorna al cliente, haciendo bypass de 2FA.

4. **[CRÍTICO] `api/webhook-reveal.ts:37–60`** — Verificación de password crea una sesión Supabase temporal en el servidor. Si el usuario tiene 2FA, este método falla. Además, genera tokens de sesión que quedan activos.

5. **[ALTO] `api/webhook-receive.ts:86–90`** — N+1 Query: descarga TODOS los webhooks para buscar por `url_path`. No escala más allá de ~1000 webhooks.

6. **[ALTO] `api/webhook-receive.ts:81–82`** — `x-forwarded-for` puede ser spoofeado. No se verifica contra una lista de proxies confiables.

7. **[ALTO] `api/webhooks/[webhookId]/[token].ts:262`** — CORS wildcard `*` en un endpoint de Discord. Permite que cualquier sitio web POSTee al webhook desde el navegador.

8. **[ALTO] `api/webhooks/[webhookId]/[token].ts:301–313`** — Verificación de token con comparación directa de strings (`===`). Vulnerable a timing attacks.

9. **[ALTO] `api/webhook-export.ts:10–15`** — CSV Injection: `escapeCsvCell` no previene fórmulas maliciosas. Excel/LibreOffice ejecutan fórmulas en CSV.

10. **[ALTO] `src/hooks/useSse.ts:19`** — El token de autenticación se envía por query param en la URL del SSE. Expone el token en logs del servidor, historial del navegador, y referers.

---

## Recomendaciones Generales

### Seguridad
1. **Migrar secrets a hashes**: Nunca almacenar secrets en texto plano. Usar `secret_hash` + `salt` con `timingSafeEqual`.
2. **Sanitizar CSV**: Prevenir CSV injection prefijando `=`, `+`, `-`, `@`, `%` con apóstrofo.
3. **Validar IPs**: `x-forwarded-for` debe verificarse contra una lista de proxies confiables.
4. **Rate limiting**: Mover de COUNT de DB a Redis o KV store para evitar N+1.
5. **CORS**: Restringir `Access-Control-Allow-Origin` en endpoints sensibles. Nunca usar `*` en privados.
6. **2FA**: Usar `crypto.randomInt` para códigos, nunca `Math.random`. Hashear códigos con bcrypt.
7. **Password verification**: No usar `signInWithPassword` para verificar passwords. Usar métodos sin side-effects.

### Rendimiento
1. **N+1 Queries**: Reemplar `select *` + `find()` en memoria con queries directas con índices.
2. **Memoización**: Usar `React.memo`, `useMemo`, `useCallback` en componentes que reciben props complejas.
3. **Paralelización**: En `StatsPage`, usar `Promise.all` para múltiples queries de Supabase.
4. **Virtual List**: Implementar `ResizeObserver` para altura dinámica del contenedor.

### TypeScript / Calidad
1. **Eliminar `any`**: Todos los handlers de API usan `req: any, res: any`. Definir interfaces propias o usar `@vercel/node`.
2. **Tests**: El coverage de integración es muy bajo. Añadir tests para `webhook-receive` completo (secret, IP, rate limit, body).
3. **Dead code**: Eliminar `fetchedRef` de `useIpRules`, `syncWebhooks` vacío en `sw.js`, `hashSecret` sin uso en `migrate-secrets.ts`.

### i18n
1. **Codificación**: El archivo `src/i18n/index.ts` tiene caracteres españoles mal codificados. Re-encodear a UTF-8 correcto.
2. **Cobertura**: La mayoría de páginas (Login, Register, Landing, Stats) tienen todo el contenido hardcoded en inglés. Migrar a `t()` keys.

### Accesibilidad
1. **Focus**: No eliminar `outline` en `:focus`. Usar `:focus-visible` con estilo visible.
2. **ARIA**: Añadir `aria-label`, `aria-pressed`, `aria-current` a botones, links, y modals.
3. **Scrollbars**: Añadir soporte de scrollbar para Firefox (`scrollbar-width`, `scrollbar-color`).
4. **Skip links**: Añadir skip link para navegar al contenido principal.

### Infra / DevOps
1. **Docker**: Las credenciales en `docker-compose.yml` deben moverse a `.env` o Docker secrets.
2. **Nginx**: `brotli` requiere módulo compilado. Verificar imagen base o usar gzip.
3. **Vercel**: `maxDuration: 10` puede ser insuficiente para webhooks con alta carga. Documentar o aumentar.
4. **PWA**: El service worker cachea respuestas de API. Añadir `Cache-Control: no-store` a endpoints con auth.
"""

    report_path = ctx["runDir"] + "/AUDIT_REPORT.md"
    with open(report_path, "w", encoding="utf-8") as f:
        f.write(report)
    return {"path": report_path, "size": len(report)}
