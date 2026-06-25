# WebhookPulse v7.0: Documento de Rendimiento, SLO y Optimización
## Análisis de Producción contra Métricas de Clase Mundial — 2026

---

## 1. Resumen Ejecutivo del Rendimiento Actual

WebhookPulse v7.0 opera sobre **Vercel Serverless Functions** (Edge + Node.js) con **Supabase PostgreSQL** como backend de datos. El frontend es una **SPA React 18 + TypeScript + Vite 5 + Tailwind CSS 3.4**. Esta arquitectura define un perfil de rendimiento con ventajas inherentes (edge compute, CDN global, Vite bundling optimizado) y limitaciones estructurales (cold starts de serverless, serialización de estado en SPA, dependencia de Supabase para datos). El presente documento establece **SLO contractuales defendibles** y un **plan de optimización de 12 fases** que eleva WebhookPulse de un "buen" nivel de rendimiento a un **élite realista**, alineado con las métricas de Google Core Web Vitals 2026 y los estándares de infraestructura del top 5% de la web.

---

## 2. SLO Contractuales — WebhookPulse Production v7.0

| Métrica | Umbral p75 | Umbral p95 | Método de Verificación | Frecuencia |
|---------|------------|------------|----------------------|------------|
| **LCP** | < 2.0s | < 3.0s | Lighthouse CI + CrUX field data | Por deploy |
| **INP** | < 150ms | < 300ms | Chrome DevTools > Performance > Interaction trace | Por deploy |
| **CLS** | < 0.05 | < 0.1 | Lighthouse + Layout Instability API | Por deploy |
| **TTFB** | < 400ms | < 800ms | WebPageTest + Vercel Analytics | Por petición |
| **Uptime mensual** | ≥ 99.95% | — | UptimeRobot + Vercel Status | Continua |
| **Error rate 5xx** | < 0.1% | — | Sentry + Vercel Logs | Continua |
| **Cold start p95** | < 100ms | — | Vercel Function Logs | Por función |
| **Page weight inicial** | < 1MB | < 1.5MB | Lighthouse > Network | Por deploy |
| **JS inicial (gzip)** | < 200KB | < 250KB | Bundle Analyzer | Por build |
| **Hit rate caché edge** | > 90% | — | Vercel Analytics Caching | Diaria |
| **Latencia API p95** | < 300ms | < 500ms | Custom timing en endpoints | Por petición |
| **RTO (recuperación)** | < 15 min | — | Simulación de failover | Trimestral |
| **RPO (pérdida datos)** | < 1 min | — | Supabase PITR (Point-in-Time Recovery) | Continua |

---

## 3. Análisis de Rendimiento por Capa

### 3.1 Core Web Vitals — Estado Actual vs. Objetivo

#### LCP (Largest Contentful Paint)

**Estado actual estimado:** ~1.5s - 2.8s (variación por región y caché)

WebhookPulse utiliza un **tema oscuro premium** con fondo `#0C0C0E` y una SPA React que carga un bundle JavaScript. El LCP está dominado por:
1. **Hero content**: El landing page tiene un título principal y un CTA; en el dashboard, el LCP es la tabla de webhooks o el gráfico SVG.
2. **Vite bundling**: El build de Vite genera assets optimizados con code splitting por ruta, lo que mantiene el JS inicial razonable.
3. **Tailwind CSS**: La configuración `content` apunta a los archivos fuente, generando un CSS purgado que no incluye clases no utilizadas.

**Optimización requerida:**
- Preload del recurso LCP: `<link rel="preload" as="image" href="..." fetchpriority="high">` en el landing page.
- El dashboard no tiene una imagen hero; el LCP es probablemente el texto del título o el primer SVG. Asegurar que el CSS crítico se cargue inline en `index.html`.
- `font-display: swap` para las fuentes de Google Fonts (si se usan).

**Estimación post-optimización:** LCP p75 < 1.5s en 4G, < 1.0s en WiFi/edge.

#### INP (Interaction to Next Paint)

**Estado actual estimado:** ~80ms - 200ms

El dashboard tiene interacciones complejas: toggles de webhooks, expansión de logs, modales de creación, batch delete, filtros de búsqueda. El INP está dominado por:
1. **Re-renderizados React**: El estado de logs se actualiza en tiempo real (Supabase Realtime), lo que puede provocar re-renderizados masivos si no se memoiza.
2. **Listas grandes**: La lista de logs en `WebhookDetailPage.tsx` puede crecer hasta 200 registros (carga inicial) con paginación de 50. Sin virtualización, el INP de scroll y expansión de filas puede degradarse.
3. **Animaciones**: Las transiciones de Tailwind (`transition-all duration-500`) en los SVG de `StatsPage.tsx` son suaves, pero pueden bloquear el hilo principal si el DOM es grande.

**Optimización requerida:**
- Memoización con `React.memo` en `LogRow.tsx`, `WebhookCard.tsx`, `StatsPage.tsx`.
- Virtualización de listas: `react-window` o `react-virtualized` para el log viewer cuando hay > 50 registros visibles.
- `scheduler.yield()` (Chromium 129+) para ceder el hilo entre tareas de filtrado de logs.
- Defer de `RobloxEmbed.tsx`: renderizar el embed solo cuando la fila está expandida, no en el primer paint.

**Estimación post-optimización:** INP p75 < 120ms, p95 < 250ms.

#### CLS (Cumulative Layout Shift)

**Estado actual estimado:** < 0.05 (bueno)

WebhookPulse tiene un diseño robusto: las dimensiones de los contenedores son fijas, el sidebar tiene ancho fijo (`w-64`), y los modales se renderizan con posición absoluta centrada. No hay anuncios ni inyección de contenido tardío. Las tablas de logs y webhooks reservan espacio antes de cargar los datos (skeleton o estado vacío).

**Optimización requerida:**
- Asegurar `aspect-ratio` en las imágenes de avatar/landing (si se añaden imágenes).
- Verificar que `CreateWebhookModal.tsx` no cause CLS al abrirse (ya usa `position: fixed` con overlay, lo cual es correcto).
- Confirmar que `StatsPage.tsx` reserva espacio para los SVG antes de que los datos lleguen (usando skeleton rectangles con dimensiones fijas).

**Estimación post-optimización:** CLS p75 < 0.03 (élite).

#### TTFB (Time to First Byte)

**Estado actual estimado:** ~200ms - 600ms (depende de región y caché)

Vercel despliega el frontend desde su edge network global (CDN con 100+ PoPs). El `index.html` se sirve con caché agresiva. Las API calls a Vercel Functions tienen cold starts potenciales (~50-200ms en tier hobby), pero el edge network de Vercel mitiga parte de esto.

**Optimización requerida:**
- HTTP/3 (QUIC): Vercel lo soporta automáticamente; verificar que las conexiones del cliente usan HTTP/3.
- Early Hints (103): Vercel soporta Early Hints; asegurar que se envían para preloads de assets críticos.
- Cache-Control para assets estáticos: `max-age=31536000, immutable` para chunks con hash de Vite.
- Supabase connection pooling: utilizar el pooler de Supabase (`connection_string` con `pgbouncer`) para reducir la latencia de DB en los endpoints.

**Estimación post-optimización:** TTFB p75 < 300ms, p95 < 500ms.

---

### 3.2 Infraestructura y Red

#### Latencia (RTT)

Vercel opera sobre Cloudflare-like edge network. Los usuarios en Norteamérica y Europa experimentan RTT < 50ms al edge. Los usuarios en LATAM y Asia pueden experimentar RTT 80-150ms.

**Optimización:**
- Considerar Vercel Pro ($20/mes) para edge functions con mejor distribución global y cold starts más rápidos.
- Supabase: utilizar la región más cercana al edge de Vercel (si Vercel usa `us-east-1`, usar Supabase `us-east-1`).

#### Uptime

**Estado actual:** 99.95% (Vercel Hobby SLA implícita + Supabase gratis SLA)

Vercel tiene downtime ocasional en el tier gratuito (mantenimiento de infraestructura, colas de build). Supabase tiene outages documentados en su status page. Para alcanzar 99.99%, se requiere:
- Vercel Pro (mejor SLA)
- Supabase Pro (mejor uptime guarantee)
- Multi-region fallback: si Supabase falla, el endpoint `webhook-receive.ts` debe operar en modo fail-open (ya lo hace: si DB falla, permite el request y loguea a Sentry).

#### Throughput y Escalado

Vercel Functions escalan horizontalmente automáticamente. Sin embargo, el tier Hobby tiene límites de:
- 10 concurrent serverless functions
- 100 GB-hrs de ejecución al mes
- 10s maxDuration

WebhookPulse con 15 endpoints + frontend es factible en el tier Hobby para < 1,000 usuarios activos. Para escalar a 10,000+:
- Vercel Pro ($20/mes) o Enterprise ($custom)
- Supabase Pro ($25/mes) para conexiones concurrentes ilimitadas
- Considerar migración de funciones críticas a Vercel Edge Functions (Runtime Edge, no Node.js) para cold starts casi instantáneos

---

### 3.3 Cómputo y Procesamiento

#### Hilo Principal (Main Thread)

**Estado actual:** El dashboard tiene tareas de JavaScript que pueden bloquear el hilo:
1. Parsing de payloads JSON en `PayloadViewer.tsx` (sin virtualización, payloads de 3,000+ bytes).
2. Agregación de datos en `StatsPage.tsx` (suma, conteo, ordenamiento en memoria de hasta 5,000 registros).
3. Filtros de búsqueda en `SearchBar.tsx` (búsqueda en texto completo de payloads).

**Optimización:**
- Mover el parsing de JSON a un Web Worker para payloads > 1,000 bytes.
- Fragmentar la agregación de `StatsPage.tsx` en chunks de 100 registros usando `setTimeout(0)` o `requestIdleCallback`.
- Implementar debounce de 300ms en el campo de búsqueda de `SearchBar.tsx` para evitar re-filtrado en cada keystroke.
- Utilizar `React.useMemo` para las agregaciones de `StatsPage.tsx` (logs, IPs, fuentes) para evitar recálculos en cada render.

#### WebAssembly (WASM)

**No aplicable a WebhookPulse actualmente.** El dashboard no realiza tareas de cómputo intensivo (criptografía, codecs, simulación 3D). El parsing de JSON y la agregación de datos son dominadas por el tiempo de acceso a la base de datos, no por el cómputo del cliente. Si en el futuro se añade procesamiento de imágenes (previews de avatares Roblox) o cifrado de logs, WASM sería relevante.

---

### 3.4 Peso de Página y Recursos

#### Presupuesto de Rendimiento Actual (Estimado)

| Recurso | Estimación Actual | Objetivo Élite | Límite Duro |
|---------|-------------------|----------------|-------------|
| HTML (index.html) | ~2-3 KB | < 30 KB | 50 KB |
| CSS (Tailwind purgado) | ~15-25 KB gzip | < 50 KB | 70 KB |
| JS inicial (React + Vite) | ~120-180 KB gzip | < 150 KB | 250 KB |
| JS lazy-loaded (routes) | ~50-100 KB gzip | < 100 KB | 150 KB |
| Total inicial | ~140-210 KB | < 1 MB | 1.5 MB |
| Imágenes (landing) | ~50-100 KB (si hero) | < 500 KB | 1 MB |
| Fuentes web | ~30-50 KB | < 100 KB | 150 KB |

**Análisis:** WebhookPulse está dentro del presupuesto élite. El bundle de Vite con code splitting por ruta mantiene el JS inicial bajo. Tailwind CSS purgado es eficiente. No hay imágenes pesadas en el dashboard (solo iconos SVG de `lucide-react`, que son ~5 KB en total). El riesgo principal es el crecimiento futuro del bundle si se añaden librerías pesadas (ej. librerías de gráficos como `recharts` o `chart.js`). La decisión de usar SVG nativo en `StatsPage.tsx` en lugar de librerías externas es correcta y debe mantenerse.

**Optimización:**
- Tree shaking agresivo: auditar el bundle con `vite-bundle-visualizer` para detectar librerías no utilizadas.
- Preload de rutas críticas: `<link rel="prefetch" href="/dashboard">` en el landing page para usuarios autenticados.
- Lazy loading de componentes: `React.lazy()` para `SettingsPage.tsx`, `StatsPage.tsx`, `WebhookDetailPage.tsx` si no son rutas críticas del primer paint.

#### Imágenes

WebhookPulse actualmente no utiliza imágenes rasterizadas (solo iconos SVG de `lucide-react`). Si se añade un hero image en el landing page:
- **Formato:** AVIF con WebP fallback.
- **Dimensiones:** `srcset` + `sizes` para responsive.
- **Lazy loading:** `loading="lazy"` excepto para el hero image.
- **Placeholder:** LQIP (Low Quality Image Placeholder) o blur-up CSS para evitar CLS.

---

### 3.5 Móvil y Redes Lentas

#### Objetivos en 3G/4G

| Condición | Métrica | Objetivo | Estado Actual |
|-----------|---------|----------|---------------|
| 3G lento (400 Kbps) | LCP | < 3.0s | ~2.5-3.5s |
| 4G medio | LCP | < 2.0s | ~1.5-2.0s |
| CPU móvil baja | INP | < 200ms | ~150-250ms |
| Modo ahorro de datos | Peso | < 500 KB | ~200-300 KB |

**Optimización para móvil:**
- Critical CSS inline: extraer el CSS crítico del primer paint y embeberlo en `index.html` (< 14 KB). Vite no hace esto por defecto; requiere plugin `vite-plugin-critical`.
- Adaptive serving: si `navigator.connection.effectiveType === '2g'`, desactivar el Activity Feed en tiempo real y mostrar un botón de "Refrescar manualmente".
- Skeleton screens: en lugar de spinners de carga, mostrar esqueletos de las tarjetas de webhook y las filas de logs para mejorar la percepción de velocidad.

---

## 4. Plan de Optimización de 12 Fases

| Fase | Tarea | Impacto | Esfuerzo | Prioridad |
|------|-------|---------|----------|-----------|
| 1 | **Critical CSS inline** en `index.html` para landing y dashboard | LCP -0.3s | Media | Alta |
| 2 | **Preload LCP** + `fetchpriority="high"` en landing page | LCP -0.2s | Baja | Alta |
| 3 | **React.memo + useMemo** en `LogRow`, `WebhookCard`, `StatsPage` | INP -50ms | Media | Alta |
| 4 | **Virtualización de listas** (`react-window`) para logs > 50 | INP -80ms | Alta | Media |
| 5 | **Debounce 300ms** en `SearchBar.tsx` y filtros | INP -30ms | Baja | Alta |
| 6 | **Web Worker** para parsing de payloads JSON > 1KB | INP -40ms | Media | Media |
| 7 | **Cache-Control headers** optimizados en `vercel.json` | TTFB -100ms | Baja | Alta |
| 8 | **Supabase connection pooling** (`pgbouncer`) | Latencia API -50ms | Baja | Alta |
| 9 | **Bundle audit** con `vite-bundle-visualizer` | JS -20KB | Media | Media |
| 10 | **Lazy load de rutas** con `React.lazy()` + `Suspense` | JS inicial -30KB | Media | Media |
| 11 | **Adaptive serving** según `effectiveType` | UX móvil | Media | Baja |
| 12 | **Skeleton screens** para dashboard y landing | Percepción | Media | Baja |

---

## 5. Seguridad que Impacta Rendimiento

| Práctica | Estado en WebhookPulse | Impacto Rendimiento |
|----------|----------------------|-------------------|
| HTTPS obligatorio | ✅ (Vercel auto-SSL) | Necesario para HTTP/2+ |
| TLS 1.3 + 0-RTT | ✅ (Vercel edge) | Reduce 1 RTT |
| HSTS + preload | ⚠️ No configurado | Evita redirect HTTP→HTTPS |
| CSP estricta | ⚠️ No configurada | Previene inyección, pero requiere `nonce` |
| SRI (Subresource Integrity) | ⚠️ No configurado | Validación de integridad de assets |

**Acciones:**
- Añadir `Strict-Transport-Security: max-age=63072000; includeSubDomains; preload` en `vercel.json`.
- Implementar CSP con `nonce` para scripts inline (si hay critical CSS inline).

---

## 6. Observabilidad y Monitorización

### 6.1 RUM (Real User Monitoring)

**Herramientas recomendadas:**
- **Vercel Analytics**: incluido en Vercel Pro; mide LCP, FID, CLS, TTFB en field data.
- **Sentry Performance**: monitoreo de transacciones con distributed tracing (ya integrado en el stack).
- **Google CrUX**: datos de campo reales de Chrome; accesible vía PageSpeed Insights o BigQuery.

**Configuración:**
- Muestreo del 10% de sesiones para RUM (costo vs. precisión balanceado).
- Segmentación por dispositivo, región, red, y versión de la app.

### 6.2 Lab Testing (Sintético)

| Herramienta | Uso | Frecuencia |
|-------------|-----|------------|
| Lighthouse CI | Auditoría automatizada en CI/CD | Por PR |
| WebPageTest | Waterfall detallado y filmstrip | Semanal |
| PageSpeed Insights | Field + Lab combinado | Por release |
| GTmetrix | Métricas de carga desde múltiples regiones | Semanal |

### 6.3 Alertas

| Evento | Umbral | Ventana | Canal |
|--------|--------|---------|-------|
| LCP degradado | p75 > 2.5s | > 15 min | Sentry + Email |
| INP degradado | p75 > 200ms | > 15 min | Sentry + Email |
| TTFB alto | p75 > 800ms | > 10 min | Sentry + Email |
| Error rate 5xx | > 1% | > 5 min | Sentry + PagerDuty |
| Uptime | < 99.9% mensual | Trimestre | UptimeRobot |

---

## 7. Checklist de Optimización A-Z

| Letra | Acción | Estado | Notas |
|-------|--------|--------|-------|
| A | AVIF/WebP en todas las imágenes | N/A | No hay imágenes rasterizadas actualmente |
| B | Budget de rendimiento definido | ✅ | JS < 200KB, Total < 1MB |
| C | Critical CSS inline (< 14KB) | ⚠️ Pendiente | Fase 1 del plan |
| D | Defer de JS no crítico | ✅ | Vite code splitting ya lo hace |
| E | Edge compute para TTFB < 400ms | ✅ | Vercel edge network |
| F | fetchpriority="high" en LCP | ⚠️ Pendiente | Fase 2 del plan |
| G | Gzip/Brotli en todas las respuestas | ✅ | Vercel lo hace automáticamente |
| H | HTTP/3 + Early Hints | ✅ | Vercel lo soporta |
| I | INP < 150ms (p75) | ⚠️ ~120-200ms | Requiere Fase 3-6 |
| J | JS inicial < 200KB gzip | ✅ | ~120-180 KB actual |
| K | Kubernetes/Serverless autoescalado | ✅ | Vercel Functions |
| L | Lazy loading en imágenes below-the-fold | N/A | No hay imágenes |
| M | Minificación de HTML/CSS/JS | ✅ | Vite build |
| N | Network-first para datos críticos | ⚠️ | Considerar para offline mode |
| O | Observabilidad con RUM + Lab | ⚠️ | Requiere Vercel Pro + Sentry Performance |
| P | Preload del recurso LCP | ⚠️ Pendiente | Fase 2 del plan |
| Q | QUIC (HTTP/3) activo | ✅ | Vercel edge |
| R | RUM con muestreo 1-10% | ⚠️ | Configurar Sentry sampling |
| S | SWR para contenido semi-dinámico | ⚠️ | Considerar `stale-while-revalidate` en API |
| T | TLS 1.3 + 0-RTT | ✅ | Vercel edge |
| U | Uptime ≥ 99.95% | ⚠️ | Vercel Hobby ~99.9%; Pro para 99.95% |
| V | Virtualización de listas largas | ⚠️ Pendiente | Fase 4 del plan |
| W | Web Workers para cómputo pesado | ⚠️ Pendiente | Fase 6 del plan |
| X | JSON comprimido (Brotli) | ✅ | Vercel edge compression |
| Y | scheduler.yield() entre tareas largas | ⚠️ | Aplicar en filtros de búsqueda |
| Z | Zero CLS | ✅ | Diseño con dimensiones fijas |

---

## 8. Conclusiones

WebhookPulse v7.0 ya está en un **nivel "bueno" de rendimiento** para una aplicación React + Vercel + Supabase. El bundle es ligero, el diseño no genera CLS, y la arquitectura serverless permite escalado automático. Sin embargo, para alcanzar el **nivel élite** (top 5% de la web), se requieren las 12 fases de optimización documentadas, con énfasis en:

1. **Critical CSS inline** (Fase 1) — el impacto más alto en LCP con esfuerzo medio.
2. **Memoización y virtualización** (Fases 3-4) — el impacto más alto en INP.
3. **Cache-Control y connection pooling** (Fases 7-8) — el impacto más alto en TTFB y latencia de API.

El stack tecnológico actual (React 18, Vite, Tailwind, Vercel, Supabase) es **sostenible para escalar** hasta el nivel élite sin requerir reemplazo de componentes fundamentales. La inversión requerida es principalmente en tiempo de ingeniería (20-30 horas para implementar las 12 fases) y en Vercel Pro ($20/mes) para mejorar el SLA de uptime y el rendimiento de edge.

El SLO contractual propuesto es **defendible en producción** y alineado con las expectativas de usuarios de una plataforma de telemetría profesional: LCP < 2.0s, INP < 150ms, uptime ≥ 99.95%, y latencia de API < 300ms en p95.
