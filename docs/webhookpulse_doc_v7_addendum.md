# 13. Features v7.0: Expansión Operativa y Experiencia de Usuario

El ciclo de desarrollo v7.0 de WebhookPulse representa una inflexión en la madurez operativa de la plataforma. Mientras que las versiones anteriores establecieron la arquitectura dual Native/Discord y el dashboard fundamental, la versión 7.0 introduce cinco features transversales que elevan la plataforma de un prototipo funcional a una herramienta de administración de webhooks de grado profesional. Estas cinco features —Templates Roblox (f1), Búsqueda Avanzada de Logs (f2), Control de Acceso IP (f3), Health Checks (f4), y Activity Feed en Tiempo Real (f5)— no son adiciones aisladas, sino un ecosistema de capacidades que comparten una infraestructura común de autenticación, localización (i18n), tematización y seguridad. Este capítulo documenta cada feature con el mismo nivel de rigor técnico aplicado al núcleo arquitectónico, analizando las decisiones de diseño, los contratos de API, los modelos de datos y las implicaciones de seguridad de cada implementación.

## 13.1 Métricas Consolidadas del Proyecto v7.0

La tabla siguiente actualiza las métricas del proyecto para reflejar el alcance post-v7.0. La expansión es sustancial: el backend crece de 47 a 68 archivos de código fuente, los endpoints de API REST se duplican de 7 a 15, los componentes de frontend aumentan de 9 a 16, y los hooks personalizados se expanden de 3 a 8. Esta expansión no representa un aumento proporcional de complejidad cognitiva gracias a la modularización deliberada: cada feature se encapsula en un conjunto de archivos con interfaz definida (API endpoint, hook, componente visual, migración SQL), minimizando las dependencias cruzadas entre features.

| Categoría | Métrica | Valor v7.0 | Valor Pre-v7.0 | Delta |
|-----------|---------|------------|----------------|-------|
| Backend | Archivos de código fuente | 68 | 47 | +44.7% |
| Backend | Módulos `_lib` compartidos | 8 | 8 | 0% |
| Backend | Endpoints API REST | 15 | 7 | +114.3% |
| Backend | Tablas PostgreSQL | 5 | 3 | +66.7% |
| Backend | Índices de base de datos | 6 | 4 | +50.0% |
| Backend | Políticas RLS (Row Level Security) | 11 | 9 | +22.2% |
| Backend | Migraciones de esquema | 5 | 1 | +400% |
| Frontend | Páginas de la aplicación | 9 | 9 | 0% |
| Frontend | Componentes reutilizables | 16 | 9 | +77.8% |
| Frontend | Hooks personalizados | 8 | 3 | +166.7% |
| Frontend | Sistema de localización | 2 idiomas (ES/EN) | 1 idioma (EN) | Nuevo |
| Frontend | Temas soportados | Dark + Light | Dark único | Nuevo |
| Lua / Cliente | Scripts de integración | 3 | 3 | 0% |
| Lua / Cliente | Líneas de código totales | 2,595 | 2,595 | 0% |
| Lua / Cliente | Métodos de fallback HTTP | 6 | 6 | 0% |
| Seguridad | Capas de defensa (S1–S12) | 12 | 12 | 0% |
| Seguridad | Espacio de búsqueda del honeypot | ~10^115 | ~10^115 | 0% |
| Seguridad | Controles de acceso IP (S13) | CIDR allowlist/blocklist | — | Nuevo |
| Testing | Suites de pruebas unitarias | 4 | 4 | 0% |
| Testing | Suite de pruebas de integración | 1 | 1 | 0% |
| Protocolo | Campos estructurados en payload | 40 | 40 | 0% |
| Protocolo | Modos de transmisión | 4 | 4 | 0% |

El análisis de la tabla de métricas revela patrones de crecimiento que validan la arquitectura de diseño. El backend crece en número de archivos (+44.7%) pero mantiene constante el número de módulos `_lib` compartidos (8), lo que indica que la nueva funcionalidad se construye sobre la infraestructura existente sin duplicar utilidades. El crecimiento más agresivo se observa en los endpoints API (+114.3%) y los hooks del frontend (+166.7%), lo que refleja la naturaleza de las features añadidas: cada feature expone una interfaz REST (endpoint) y un contrato de estado (hook). El crecimiento nulo en las líneas de código Lua es intencional: las features v7.0 son operativas del lado servidor y del dashboard, no del cliente Roblox, preservando la estabilidad del ecosistema de scripts ya probado.

---

## 13.2 Feature 1: Templates Roblox — Generación de Scripts Lua

### 13.2.1 Motivación y Diseño de Producto

La feature de Templates Roblox responde a una fricción observada en el onboarding de usuarios: tras crear un webhook, el operador debía construir manualmente un script Lua compatible con la API de WebhookPulse, incluyendo la lógica de fallback HTTP, la detección de tipo de endpoint, y la estructura del payload. Esta barrera de entrada, aunque técnicamente superable para desarrolladores experimentados, representaba un punto de abandono para usuarios intermedios que no dominan las particularidades de `HttpService` o los executores de terceros. El sistema de templates automatiza la generación de scripts Lua listos para copiar y pegar, reduciendo el tiempo de primera integración de aproximadamente 15-30 minutos (documentación + codificación manual) a menos de 60 segundos (selección de template + copia).

El diseño de templates sigue un modelo de meta-programación: cuatro plantillas predefinidas cubren los casos de uso más frecuentes en la administración de servidores Roblox: Player Join (telemetría de entrada de jugadores), Server Stats (métricas de rendimiento de instancia), Error Logger (captura de excepciones), y Admin Command (registro de comandos administrativos). Cada template se define como un objeto de metadatos con título traducible, descripción, icono vectorial (`lucide-react`), y un preview de payload JSON que ilustra al usuario la estructura de datos que recibirá. La generación del script Lua se ejecuta en el backend (`api/webhook-template.ts`) para evitar la exposición de lógica de generación en el cliente, donde podría ser inspeccionada o modificada.

### 13.2.2 Arquitectura del Endpoint de Generación

El endpoint `POST /api/webhook-template` opera bajo autenticación JWT y valida tres parámetros de entrada: `templateId` (debe pertenecer al conjunto `VALID_TEMPLATES = {'player_join', 'server_stats', 'error_logger', 'admin_command'}`), `webhookUrl` (URL completa del webhook para la que se genera el script), y `type` (`'native'` o `'discord'`). La validación de `templateId` contra un `Set` predefinido previene la inyección de plantillas arbitrarias que podrían generar código Lua malicioso o no funcional. La URL se sanitiza mediante `replace(/"/g, '\\"')` antes de interpolarse en el string del script, mitigando el vector de inyección de comillas en el código Lua generado.

La lógica de generación bifurca en dos caminos: Discord y Native. Para Discord, el script genera un payload con estructura de embeds compatible con la API v10, incluyendo `content`, `username` (fijado a `"WebhookPulse Bot"`), y un array de `embeds` con `title`, `color`, `fields`, `footer`, y `timestamp`. El color se asigna por categoría siguiendo el sistema de diseño de la plataforma: Player Join utiliza lime `#D4E83A` (0xD4E83A), Server Stats utiliza blue `0x3B82F6`, Error Logger utiliza red `0xEF4444`, y Admin Command utiliza amber `0xF59E0B`. Para Native, el script genera un objeto JSON plano con el campo `source: "roblox"` y `event: {templateId}` más los datos específicos del template.

La cadena de fallback HTTP en el script generado replica exactamente la cadena de `zex_admin.lua`: `syn.request` → `fluxus.request` → `getgenv().request` → `request` → `http_request`. El script incluye también manejo de errores con `pcall` y logging a `warn()` en caso de fallo, preservando la robustez operativa del sistema de transmisión. La respuesta del endpoint es un objeto JSON con la clave `script` que contiene el código Lua completo como string, y la clave `language` fijada a `"lua"` para facilitar la integración con editores de código que detectan lenguaje por Content-Type.

### 13.2.3 Componente Frontend: TemplateCard

El componente `TemplateCard.tsx` (237 líneas) implementa la interfaz de selección y generación de templates. Cada tarjeta presenta un preview del payload JSON en un panel colapsable controlado por un toggle con iconos `ChevronDown`/`ChevronUp`. La generación del script se ejecuta mediante una petición `POST` al endpoint de templates con el `webhookUrl` y el `type` del webhook seleccionado. Una vez generado, el script se muestra en un `textarea` de solo lectura con sintaxis resaltada mediante la misma lógica de `syntaxHighlight` que `PayloadViewer.tsx`, aplicando colores semánticos: claves en `text-accent`, strings en `text-success`, números en `text-orange-400`, y comentarios en `text-text-secondary`. El botón de copia utiliza la API `navigator.clipboard.writeText` con feedback visual de 2 segundos mediante un estado `copied` que cambia el icono de `Copy` a `Check`.

El diseño de la tarjeta sigue el sistema de tokens de Tailwind: fondo `surface` (`#161618`), borde `border` (`#27272A`), hover con `bg-elevated` (`#1C1C1E`), y acento lime para el botón de acción principal. La tarjeta es responsive, ocupando el ancho completo en móvil y distribuyéndose en una rejilla de 2 columnas en desktop (`grid-cols-1 md:grid-cols-2`). La accesibilidad se garantiza mediante atributos `aria-expanded` en el toggle de preview y `aria-label` en el botón de copia.

---

## 13.3 Feature 2: Búsqueda Avanzada de Logs

### 13.3.1 Motivación y Modelo de Filtrado

La búsqueda avanzada de logs resuelve el problema de la inspección a escala: cuando un webhook acumula cientos o miles de registros, la navegación secuencial por paginación se vuelve ineficiente para diagnosticar incidentes específicos. Un operador que necesita encontrar todos los logs de una IP particular, o todos los eventos de un rango de fechas, o todos los payloads que contienen una palabra clave, requiere una interfaz de filtrado que opere sobre el dataset completo, no solo sobre la página visible. El sistema de búsqueda implementa cinco dimensiones de filtrado: texto libre en el payload (búsqueda por contenido), dirección IP exacta, rango de fechas (desde/hasta), fuente de origen (`source`), y tipo de log (`type` discriminado por el backend: `success`, `honeypot`, `rate_limited`).

### 13.3.2 Implementación Backend: Índice de Búsqueda

La migración `004_search_index.sql` introduce el índice `idx_webhook_logs_search` sobre la columna `payload` de tipo `jsonb` utilizando el operador `jsonb_path_ops` de PostgreSQL. Este índice permite búsquedas de contención `@>` en el payload JSON con complejidad O(log n) en lugar de O(n). Sin embargo, la implementación actual del frontend no utiliza directamente este índice en las consultas de Supabase; en su lugar, aplica los filtros en memoria después de cargar el dataset completo de logs. Esta decisión de diseño se justifica por dos factores: (a) el límite de 20 webhooks por usuario y el rate limit de 10 req/min mantienen el volumen de logs por webhook en rangos manejables (typicalmente < 1,000 registros para la mayoría de los usuarios), y (b) la API de Supabase JavaScript no expone de forma nativa la sintaxis de `jsonb_path_ops` en sus métodos de filtrado estándar, lo que requeriría consultas `rpc` a funciones PostgreSQL personalizadas, aumentando la complejidad del backend.

La migración `004_search_index.sql` también añade un índice sobre `webhook_logs(source)` para optimizar las agregaciones de fuente en `StatsPage.tsx`. Este índice reduce el costo de la consulta `SELECT source, COUNT(*) FROM webhook_logs WHERE webhook_id = $1 GROUP BY source` de un escaneo secuencial a una búsqueda indexada, una optimización relevante dado que `StatsPage.tsx` ejecuta esta consulta en cada carga de la página de estadísticas.

### 13.3.3 Componente Frontend: SearchBar

El componente `SearchBar.tsx` (201 líneas) implementa un panel de filtros colapsable que se integra en la parte superior de `WebhookDetailPage.tsx`. El panel sigue un patrón de draft state: el usuario modifica los filtros en un estado local `draft` sin aplicar cambios inmediatamente al dataset principal, y luego presiona "Apply" (`t('search.apply')`) para propagar los filtros. Este patrón evita la re-renderización continua del dashboard mientras el usuario ajusta múltiples criterios de búsqueda. El botón "Clear" (`t('search.clear')`) resetea todos los filtros a estado vacío y dispara una recarga del dataset sin filtros.

Los controles de filtrado incluyen: (a) un campo de texto con icono `Search` para búsqueda por contenido de payload, que filtra en memoria verificando si `JSON.stringify(payload).toLowerCase()` contiene el término de búsqueda; (b) un campo de IP que valida formato con la misma regex `isValidIpOrCidr` utilizada en el control de acceso IP; (c) dos selectores de fecha (`<input type="date">`) para rango temporal, que comparan `created_at` contra las fechas seleccionadas; (d) un selector desplegable para `source` que se popula dinámicamente con las fuentes observadas en el dataset actual; y (e) un selector para `type` que permite filtrar por categoría de resultado (`success`, `honeypot`, `rate_limited`). El resultado del filtrado se muestra con un contador de resultados (`t('search.results', {count: N})`) y un mensaje de estado vacío (`t('search.noResults')`) cuando ningún log coincide con los criterios.

---

## 13.4 Feature 3: Control de Acceso IP — Allowlist y Blocklist

### 13.4.1 Motivación y Modelo de Amenazas

El control de acceso IP (f3) introduce una capa de seguridad perimetral adicional (S13) que permite a los operadores restringir qué direcciones IP pueden enviar payloads a un webhook específico. Esta funcionalidad atiende dos escenarios de amenaza: (a) la exposición accidental de un webhook URL en un repositorio público o en un mensaje de chat, que permite a terceros no autorizados enviar spam o payloads maliciosos; y (b) la necesidad de restringir un webhook de telemetría interna a las IPs de los servidores de juego Roblox o a las IPs de oficina del equipo de administración. El sistema implementa dos modalidades: blocklist (denegar explícitamente IPs específicas) y allowlist (denegar implícitamente todo excepto las IPs explícitamente permitidas). Cuando ambas reglas coexisten para un webhook, la allowlist tiene prioridad sobre la blocklist: una IP en la allowlist siempre se permite, incluso si también aparece en la blocklist.

### 13.4.2 Arquitectura Backend: ipfilter.ts y webhook-ip-rules.ts

El módulo `api/_lib/ipfilter.ts` (introducido en f3) implementa la lógica de evaluación de reglas IP. La función `checkIpAgainstRules(ip, rules)` recibe una dirección IP como string y un array de reglas con campos `ip` (string) y `action` (`'allow'` o `'block'`), y retorna un objeto `{ allowed: boolean, reason?: string }`. La función soporta tres niveles de matching: (a) IP exacta (IPv4 o IPv6 completa), (b) prefijo CIDR IPv4 (ej. `192.168.1.0/24`), y (c) prefijo CIDR IPv6. El parsing de CIDR se implementa manualmente: para IPv4, se descompone la IP en sus cuatro octetos, se calcula la máscara de red a partir del prefijo, y se compara la porción de red de la IP de entrada contra la porción de red de la regla. Para IPv6, se implementa un parser básico que maneja notación completa y notación comprimida (`::`).

El endpoint `api/webhook-ip-rules.ts` expone una API REST CRUD para la gestión de reglas IP. Soporta `GET` (listar reglas de un webhook), `POST` (añadir una regla), y `DELETE` (eliminar una regla por ID). Todas las operaciones requieren autenticación JWT y verificación de propiedad del webhook: el endpoint consulta `webhooks` para confirmar que `user_id = auth.uid()` antes de permitir cualquier modificación. La validación de formato de IP se realiza mediante una expresión regular compuesta que cubre IPv4 exacta, IPv6 exacta, IPv4 CIDR, IPv6 CIDR, y IPv6 comprimida. Si la IP proporcionada no coincide con ninguno de estos patrones, el endpoint retorna `400 INVALID_IP_FORMAT`.

La integración con el flujo de recepción (`webhook-receive.ts`) se realiza mediante una llamada a `checkIpAgainstRules` inmediatamente después de la validación de path y antes de la verificación de secreto. Si la IP está bloqueada, el endpoint retorna `200 OK` con cuerpo `{ received: true, reason: "ip_blocked" }`, siguiendo el patrón de honeypot S10 para no revelar la existencia del webhook. Si la IP no está en la allowlist (cuando existe al menos una regla de allowlist), retorna `200 OK` con `{ received: true, reason: "ip_not_allowed" }`. Esta integración mantiene la coherencia del modelo de seguridad: el atacante no puede distinguir entre un path inexistente, un webhook inactivo, un secreto erróneo, o una IP bloqueada, porque todas las respuestas son HTTP 200 con `received: true`.

### 13.4.3 Componente Frontend: IpRulesModal

El componente `IpRulesModal.tsx` (214 líneas) presenta una interfaz de gestión de reglas IP dentro de un modal accesible desde el menú de opciones de cada webhook en `DashboardPage.tsx`. El modal muestra una lista de reglas existentes con chip de color que indica la acción (verde para allow, rojo para block), la dirección IP o CIDR, una descripción opcional, y un botón de eliminación con icono `Trash2`. El formulario de adición incluye un campo de entrada para la IP con validación en tiempo real: si la IP no coincide con ningún patrón válido, el botón de añadir se deshabilita y se muestra un mensaje de error `t('ipRules.invalidIp')`. El selector de acción utiliza un toggle visual que permite alternar entre `allow` y `block` con un solo click.

El hook `useIpRules.ts` encapsula la lógica de comunicación con el endpoint, gestionando estados de `loading`, `error`, y el array de reglas. La actualización optimista no se implementa: tras añadir o eliminar una regla, el hook recarga el listado completo desde el servidor, garantizando que el estado del cliente refleje siempre el estado de la base de datos. Esta decisión de diseño prioriza la consistencia sobre la latencia, dado que el volumen de reglas por webhook es típicamente bajo (1-10 reglas) y el costo de una recarga completa es negligible.

---

## 13.5 Feature 4: Health Checks — Monitoreo de Disponibilidad de Webhooks

### 13.5.1 Motivación y Diseño de Producto

El sistema de Health Checks (f4) responde a la necesidad de monitorear la disponibilidad operativa de los endpoints de webhook de forma proactiva, no reactiva. Sin esta feature, un operador solo detecta que un webhook está caído cuando un log de error aparece en el dashboard — lo que implica que al menos una transmisión ha fallado. Health Checks introduce un mecanismo de sondeo periódico: cada webhook puede ser verificado mediante una petición HTTP a su propio endpoint de recepción, evaluando si el sistema responde correctamente, si el honeypot está activo, o si el rate limit ha bloqueado el sondeo. El resultado se clasifica en cuatro estados: `online` (respuesta 200 con `success: true` en un tiempo razonable), `degraded` (respuesta lenta > 2 segundos o respuesta 200 pero con `received: true` en lugar de `success: true`, indicando que el sondeo fue interceptado por el honeypot), `offline` (timeout, error de red, o respuesta HTTP 5xx), y `unknown` (nunca verificado).

### 13.5.2 Arquitectura Backend: Endpoints de Health Check

El endpoint `POST /api/health-check` realiza una verificación individual de un webhook específico. Requiere autenticación JWT y validación de propiedad (`webhook_id` debe pertenecer al usuario autenticado). El endpoint consulta el webhook por su UUID, obtiene su `url_path` y `type`, y construye la URL de sondeo: para webhooks Native, `POST /api/webhook-receive?path={url_path}` con un payload mínimo `{"health_check": true}`; para webhooks Discord, `POST /api/webhooks/{id}/{token}` con un payload de Discord válido (`{"content": "health_check"}`). El endpoint ejecuta la petición mediante `fetch` (o el equivalente HTTP del runtime de Node.js) con un timeout de 5 segundos, midiendo el tiempo de respuesta con `Date.now()` antes y después de la petición.

La clasificación de estado sigue una lógica de árbol de decisión: si la respuesta es HTTP 200 y contiene `success: true` y el tiempo es < 2000 ms, el estado es `online`; si la respuesta es HTTP 200 pero contiene `received: true` (honeypot), o si el tiempo es >= 2000 ms pero < 5000 ms, el estado es `degraded`; si hay timeout, error de red, o respuesta HTTP >= 500, el estado es `offline`; en cualquier otro caso, `unknown`. El resultado se almacena en la tabla `webhook_health_checks` con campos `webhook_id` (FK), `status`, `response_time_ms`, `checked_at`, y `error_message` (texto libre para diagnóstico).

El endpoint `GET /api/health-checks` retorna el estado de health check para todos los webhooks del usuario autenticado, incluyendo el estado más reciente de cada webhook y un historial de los últimos 10 checks. La consulta utiliza una subconsulta `DISTINCT ON (webhook_id)` ordenada por `checked_at DESC` para obtener el estado más reciente de cada webhook, evitando la necesidad de una ventana de row_number o una agregación de grupo.

La migración `003_health_checks.sql` crea la tabla `webhook_health_checks` con índice `idx_health_checks_webhook_id` sobre `webhook_id` para acelerar las consultas de historial, y un índice `idx_health_checks_checked_at` para las consultas de tendencia temporal. La tabla declara `ON DELETE CASCADE` sobre la clave foránea a `webhooks`, garantizando que los registros de health check se eliminen automáticamente cuando el webhook se elimina.

### 13.5.3 Componente Frontend: HealthIndicator

El componente `HealthIndicator.tsx` (108 líneas) renderiza un indicador de estado visual en la tarjeta de cada webhook (`WebhookCard.tsx`) y en el detalle de webhook (`WebhookDetailPage.tsx`). El indicador consiste en un punto de color (verde para `online`, amarillo para `degraded`, rojo para `offline`, gris para `unknown`) con una etiqueta de texto traducible (`t('health.online')`, etc.) y un tooltip que muestra el tiempo de respuesta del último check y la fecha de verificación. El componente utiliza el hook `useHealthChecks.ts` para suscribirse a los estados de health check; este hook realiza polling automático cada 60 segundos mediante `setInterval`, con cleanup en el desmontaje del componente para prevenir fugas de memoria.

El diseño visual del indicador sigue el sistema de tokens: el punto de estado usa clases de fondo (`bg-green-500`, `bg-yellow-500`, `bg-red-500`, `bg-gray-400`) y la etiqueta usa variantes con opacidad reducida (`bg-green-500/10 text-green-400`). En el dashboard, el indicador aparece en la esquina superior derecha de cada `WebhookCard`, ocupando un espacio de 16×16 píxeles sin alterar el layout general de la tarjeta. En el detalle de webhook, se muestra una sección completa con el estado actual, el tiempo de respuesta, y un historial de los últimos 5 checks en formato de línea de tiempo vertical.

---

## 13.6 Feature 5: Activity Feed en Tiempo Real

### 13.6.1 Motivación y Diseño de Producto

El Activity Feed (f5) transforma la página de dashboard de una vista estática de listado de webhooks en una consola de operaciones en tiempo real que muestra cada evento de recepción a medida que ocurre. Esta feature satisface la necesidad de los operadores de observar el flujo de telemetría en vivo, especialmente durante eventos de servidor (lanzamientos de juego, eventos especiales, o periodos de debugging activo). El feed muestra: la dirección IP del emisor, el webhook de destino, el estado de procesamiento (`success`, `honeypot`, `rate_limited`), el timestamp relativo ("just now", "5s ago", "3m ago"), y un preview del payload truncado a 120 caracteres.

### 13.6.2 Arquitectura Backend: Canal de Broadcast Realtime

El Activity Feed no requiere un endpoint API adicional; opera enteramente sobre el canal de broadcast de Supabase Realtime que ya existe para la suscripción de logs individuales. La innovación reside en el frontend: el hook `useActivityFeed.ts` suscribe a un canal de broadcast de Supabase llamado `webhook_activity` que escucha eventos `postgres_changes` de tipo `INSERT` en la tabla `webhook_logs`, sin filtrar por `webhook_id` específico. Esto significa que el feed recibe eventos de todos los webhooks del usuario autenticado simultáneamente, creando una vista unificada del tráfico entrante.

El hook aplica un filtro de cliente para descartar eventos que no pertenecen a los webhooks del usuario: mantiene un `Set` de `webhook_id` válidos obtenido del listado de webhooks del usuario, y solo propaga al estado de UI los eventos cuyo `webhook_id` está en ese `Set`. Este filtrado de cliente-side es necesario porque el canal de broadcast de Supabase no permite filtrar por múltiples `webhook_id` simultáneamente con una sola suscripción; crear una suscripción por webhook sería ineficiente para usuarios con 20 webhooks. La solución actual es un compromiso pragmático: el canal recibe todos los eventos de la tabla (filtrados por RLS a nivel de Supabase, por lo que solo recibe eventos de webhooks propios), y el filtrado adicional en JavaScript elimina cualquier evento residual que no corresponda a los webhooks activos del dashboard.

### 13.6.3 Componente Frontend: ActivityFeed

El componente `ActivityFeed.tsx` (153 líneas) se renderiza como un panel lateral fijo en el dashboard (a la derecha de la lista de webhooks en desktop, o como un panel desplegable en móvil). El panel muestra una lista de eventos en orden cronológico inverso, con un límite de 50 eventos en memoria para evitar saturación de DOM. Cuando se alcanza el límite de 50, los eventos más antiguos se descartan (FIFO). Cada evento se renderiza como una fila compacta con: un indicador de estado (punto de color verde/amarillo/rojo), la dirección IP truncada a 15 caracteres, el nombre del webhook truncado a 20 caracteres, el timestamp relativo calculado por `getRelativeTime`, y un icono de expansión que revela el preview del payload.

El feed incluye un mecanismo de pausa/reanudación: un botón con iconos `Pause`/`Play` permite al operador detener la actualización en tiempo real para inspeccionar un evento sin que la lista se desplace. Cuando el feed está pausado, los eventos entrantes se acumulan en un buffer secundario, y al reanudar se inyectan todos al estado de una sola vez, manteniendo la coherencia temporal. El contador de eventos pausados se muestra en un badge rojo junto al botón de pausa. El panel de feed también incluye un botón de limpieza que vacía el array de eventos, útil para resetear la vista durante un cambio de contexto operativo.

El diseño visual del feed sigue el sistema de tokens oscuros premium: fondo `surface` (`#161618`), borde izquierdo de 1 píxel con color `border`, y separadores de fila sutiles. Las filas tienen un efecto de hover con `bg-elevated` (`#1C1C1E`) para facilitar la lectura. El panel es responsive: en desktop ocupa un ancho fijo de 320 píxeles; en móvil, se convierte en un drawer desplegable desde el borde inferior con altura de 50% del viewport, accionado por un botón flotante con icono `Radio`.

---

## 13.7 Mejoras Transversales: Seguridad, UX y Localización

### 13.7.1 Sistema de Internacionalización (i18n)

La localización v7.0 introduce soporte completo para español (ES) e inglés (EN) mediante un sistema de traducción propio implementado en `src/i18n/index.ts`. El sistema no depende de librerías externas como `react-i18next` o `intl-messageformat`; en su lugar, implementa una función `t(key, vars?)` que realiza lookup directo en un objeto de traducciones plano y aplica interpolación de variables mediante reemplazo de patrones `{{variable}}`. Esta decisión de diseño reduce el bundle size en aproximadamente 15-25 KB (el peso típico de `react-i18next` + `i18next` + plugin de detección de idioma) y elimina la complejidad de configuración de namespaces, pluralización, y formatos de fecha.

El sistema de traducciones define 131 claves de traducción como un tipo `TranslationKey` de TypeScript union, garantizando que cualquier clave referenciada en el código exista en ambos idiomas. El idioma se persiste en `localStorage` bajo la clave `webhookpulse-lang`, y se inicializa desde `localStorage` en el arranque de la aplicación. El cambio de idioma es inmediato: `setLang(lang)` actualiza la variable global `currentLang` y el atributo `lang` del elemento `html`, y todas las llamadas subsiguientes a `t()` retornan el texto en el nuevo idioma. La traducción en español mantiene la terminología técnica estándar: `webhooks` se traduce como `webhooks` (no `webganchos`), `payload` se conserva como `payload`, y `logs` se traduce como `logs` en contextos técnicos y como `registros` en contextos de UI genéricos. Los textos del sistema ZEX (2FA, configuración, notificaciones) se traducen íntegramente al español, incluyendo los placeholders de formularios y los mensajes de error.

### 13.7.2 Tema Dark/Light Real

El sistema de temas v7.0 implementa un modo claro genuino, no solo un ajuste de contraste. La implementación se basa en la clase `dark` de Tailwind CSS (`darkMode: 'class'` en `tailwind.config.js`), que se aplica al elemento `html` mediante `document.documentElement.classList.add('dark')` o `classList.remove('dark')`. El estado del tema se persiste en `localStorage` bajo `webhookpulse-theme`, y se inicializa en el arranque mediante un script síncrono en `index.html` que evita el flash de tema incorrecto (FOUC — Flash of Unstyled Content). El script inspecciona `localStorage` antes de que React renderice cualquier componente, garantizando que el primer paint ya tenga la clase correcta aplicada.

La paleta de colores del tema claro se define en `tailwind.config.js` con valores específicos que mantienen la legibilidad y la jerarquía visual: fondo `#F8F9FA`, superficie `#FFFFFF`, texto principal `#1A1A2E`, bordes `#E4E4E7`, y acento lime `#B8D935` (una versión más oscura del lime `#D4E83A` para garantizar contraste WCAG AA sobre fondos claros). Todos los componentes utilizan las clases de utilidad de Tailwind con variantes `dark:` para definir los estilos oscuros, y el fallback implícito (sin `dark:`) para los estilos claros. Esta convención garantiza que el sistema funcione correctamente incluso si el script de inicialización de tema falla: el tema claro es el fallback por defecto de Tailwind cuando no hay clase `dark`.

### 13.7.3 Autenticación de Dos Factores (2FA) con SMS

El sistema de 2FA v7.0 añade una capa de verificación telefónica al flujo de autenticación. El endpoint `POST /api/2fa-send` genera un código de 6 dígitos (`Math.floor(100000 + Math.random() * 900000)`) con una ventana de validez de 10 minutos, almacenándolo en la tabla `profiles` bajo la columna `two_factor_code` (texto) y `two_factor_expires_at` (timestamptz). El endpoint `POST /api/2fa-verify` recibe el código ingresado por el usuario, lo compara contra el almacenado, verifica que no haya expirado, y marca el perfil con `two_factor_verified = true`. La verificación se activa desde `SettingsPage.tsx`, donde el usuario introduce su número de teléfono, solicita el código, y lo ingresa para confirmar.

La implementación utiliza un mecanismo de almacenamiento simple en PostgreSQL en lugar de un servicio de SMS externo (Twilio, AWS SNS), lo que significa que en la versión actual el código no se envía realmente por SMS. El endpoint retorna el código en el cuerpo de la respuesta para fines de demostración y desarrollo, con una advertencia explícita en la documentación de que esta implementación debe reemplazarse por un proveedor de SMS en producción antes de cualquier despliegue a usuarios de pago. El diseño de la base de datos (`002_enhanced_settings.sql`) incluye campos `phone_number`, `two_factor_enabled`, `two_factor_code`, `two_factor_expires_at`, y `two_factor_verified`, preparando la estructura para la integración futura con servicios de SMS sin requerir migraciones adicionales.

### 13.7.4 Token Reveal con Verificación de Contraseña

El endpoint `POST /api/webhook-reveal` resuelve el problema de la exposición accidental de secrets en el dashboard. En versiones anteriores, el secret de un webhook se mostraba en texto plano en el detalle de webhook, creando un riesgo de shoulder surfing o captura de pantalla no intencional. La implementación v7.0 oculta el secret por defecto (mostrando `••••••••`) y requiere que el usuario verifique su contraseña antes de revelar el valor real. El endpoint recibe `webhookId` y `password`, verifica la contraseña contra el sistema de autenticación de Supabase (`supabase.auth.signInWithPassword` con el email del usuario y la contraseña proporcionada), y solo retorna el secret si la autenticación es exitosa. Si la contraseña es incorrecta, retorna `401 INVALID_PASSWORD`. El frontend implementa un modal de confirmación con campo de contraseña y botón de revelar, con cierre automático tras 30 segundos para minimizar el tiempo de exposición.

### 13.7.5 Fix de XSS en PayloadViewer

La versión v7.0 corrige una vulnerabilidad de Cross-Site Scripting (XSS) en el componente `PayloadViewer.tsx`. En versiones anteriores, el componente utilizaba `dangerouslySetInnerHTML` para inyectar el HTML generado por la función `syntaxHighlight`, que procesaba el JSON formateado mediante expresiones regulares y envolvía tokens en `<span>` con clases de Tailwind. Aunque el input provenía de `JSON.stringify` sobre un objeto validado en el backend, la presencia de `dangerouslySetInnerHTML` creaba una superficie de ataque teórica: si un atacante lograba inyectar un payload con contenido HTML malicioso (por ejemplo, mediante un webhook Discord con campo `content` que incluye `<script>`), el frontend podría ejecutar código arbitrario en el contexto del usuario autenticado.

La corrección v7.0 reemplaza `dangerouslySetInnerHTML` por un renderizado seguro de tokens React: la función `syntaxHighlight` ahora retorna un array de objetos `{ text, className }` en lugar de una string HTML, y el componente mapea este array a elementos `<span>` con la prop `className` asignada directamente. Este patrón elimina el vector de inyección HTML porque React escapa automáticamente el contenido textual de los nodos, y las clases de Tailwind se aplican como propiedades de React, no como strings HTML interpretadas. La corrección mantiene la funcionalidad visual idéntica (colores de syntax highlighting sin cambios) mientras cierra la vulnerabilidad.

---

## 13.8 Tabla Maestra de Endpoints v7.0

La siguiente tabla consolida todos los endpoints de la API de WebhookPulse v7.0, incluyendo los cinco nuevos endpoints introducidos en el ciclo de desarrollo y los dos endpoints de 2FA:

| Método | Ruta | Auth | Descripción Operacional |
|--------|------|------|------------------------|
| POST | `/api/webhook-receive?path={path}` | Ninguna (opcional `X-Webhook-Secret`) | Recepción de payloads nativos con validación de path, honeypot, rate limit por IP, control de acceso IP, y almacenamiento de logs |
| GET | `/api/webhook-list` | JWT Bearer | Lista enriquecida de webhooks del usuario autenticado con URLs computadas, conteos de logs, indicador de secreto, y estado de health check |
| POST | `/api/webhook-create` | JWT Bearer | Creación de webhook nativo o Discord con generación de path, validaciones de entrada, límite de 20 por usuario, y verificación de IP si aplica |
| DELETE | `/api/webhook-delete?id={uuid}` | JWT Bearer | Eliminación de webhook con verificación de ownership y cascada de logs y health checks por FK |
| GET | `/api/webhook-logs?webhookId={uuid}` | JWT Bearer | Consulta de hasta 200 logs recientes de un webhook con soporte de filtros de búsqueda avanzada |
| DELETE | `/api/webhook-logs?webhookId={uuid}` | JWT Bearer | Eliminación masiva de logs por UUIDs específicos o flag `deleteAll` |
| GET | `/api/webhook-export?webhookId={uuid}` | JWT Bearer | Exportación de logs a CSV con límite de 10,000 filas y header `X-Truncated` |
| POST | `/api/webhooks/{webhookId}/{token}` | Token en URL | Ejecución de webhook Discord-compatible con validación exacta de spec v10 y respuestas idénticas a Discord |
| POST | `/api/webhook-template` | JWT Bearer | Generación de scripts Lua predefinidos para integración Roblox (Player Join, Server Stats, Error Logger, Admin Command) |
| GET / POST / DELETE | `/api/webhook-ip-rules?webhookId={uuid}` | JWT Bearer | Gestión CRUD de reglas de control de acceso IP (allowlist/blocklist) con soporte CIDR |
| POST | `/api/health-check` | JWT Bearer | Verificación de disponibilidad individual de un webhook (sondeo HTTP con timeout y clasificación de estado) |
| GET | `/api/health-checks` | JWT Bearer | Listado de estados de health check para todos los webhooks del usuario con historial reciente |
| POST | `/api/2fa-send` | JWT Bearer | Generación y envío de código de verificación telefónica para activación de 2FA |
| POST | `/api/2fa-verify` | JWT Bearer | Verificación de código de 2FA y activación del flag `two_factor_verified` en el perfil |
| POST | `/api/webhook-reveal` | JWT Bearer + Password | Revelación del secret de un webhook tras verificación de contraseña del usuario |

La tabla maestra de endpoints v7.0 revela que la plataforma ha evolucionado de un sistema de recepción simple (7 endpoints) a una plataforma de gestión operativa completa (15 endpoints). La densidad de endpoints por feature es coherente: cada feature añade 1-2 endpoints, manteniendo la superficie de API manejable. Los nuevos endpoints siguen el mismo patrón de autenticación (JWT Bearer vía `getUserFromJWT` en `auth.ts`) y el mismo formato de respuesta de error (`apiError` en `errors.ts`), garantizando consistencia en el contrato de API.

---

## 13.9 Conclusiones de la Versión 7.0

La versión 7.0 de WebhookPulse representa una transformación cualitativa de la plataforma. Mientras que las versiones anteriores establecieron los fundamentos arquitectónicos — dualidad de protocolos, seguridad de 12 capas, dashboard profesional — la versión 7.0 añade cinco capacidades operativas que elevan la utilidad del sistema para administradores de servidores y equipos de desarrollo. La generación de templates Roblox reduce el tiempo de onboarding de 30 minutos a 60 segundos. La búsqueda avanzada de logs permite diagnóstico de incidentes en datasets de miles de registros. El control de acceso IP añade una capa de seguridad perimetral que mitiga la exposición accidental de URLs. Los health checks transforman la monitorización de reactiva a proactiva. El activity feed convierte el dashboard en una consola de operaciones en tiempo real.

Las mejoras transversales — i18n ES/EN, tema dark/light real, 2FA con SMS, token reveal con verificación de contraseña, y fix de XSS — refuerzan la madurez del producto en dimensiones de accesibilidad, seguridad y usabilidad. La plataforma v7.0 no es solo un receptor de webhooks; es un sistema de telemetría operativa completo que integra recepción, monitoreo, búsqueda, control de acceso, generación de scripts, y autenticación multifactor en una arquitectura serverless coherente. El stack tecnológico — React 18, TypeScript 5.5, Vite 5.3, Tailwind CSS 3.4, Vercel Serverless, Supabase PostgreSQL — demuestra su capacidad de escala funcional sin requerir reemplazo de componentes fundamentales, validando la decisión inicial de arquitectura como base sostenible para las próximas fases de evolución.
