# WebhookPulse — AGENT_SPEC

## Contrato Compartido

### Stack Fijo
- React 18 + TypeScript + Vite
- Tailwind CSS (sin shadcn/ui — componentes custom para precisión visual)
- React Router DOM v6
- Lucide React (iconos vectoriales puros)
- Supabase JS client v2
- Netlify Functions (serverless)

### Colores Exactos (Tailwind extend)
```js
colors: {
  background: '#0C0C0E',
  surface: '#161618',
  elevated: '#1C1C1E',
  border: '#27272A',
  'text-primary': '#FAFAFA',
  'text-secondary': '#A1A1AA',
  accent: '#D4E83A',
  'accent-hover': '#E8F96A',
  danger: '#EF4444',
  success: '#22C55E',
}
```

### Supabase Config
- Usar variables de entorno: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`
- En Netlify Functions: `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`

### Estructura de Directorios
```
webhookpulse/
  netlify/functions/        → Backend serverless
  src/
    components/             → Componentes compartidos
    pages/                  → Páginas por ruta
    hooks/                  → Custom hooks (useAuth, useWebhooks, useRealtime)
    lib/                    → Supabase client, utils
    types/                  → TypeScript interfaces
  public/                   → Assets estáticos
  design/                   → Artefactos de diseño
```

### API Contracts

#### Webhook Receive (público)
```
POST /.netlify/functions/webhook-receive?path=<url_path>
Headers: { optional X-Webhook-Secret }
Body: <any JSON>
Response: { success: true, logId: string }
```

#### Webhook List (autenticado)
```
GET /.netlify/functions/webhook-list
Headers: { Authorization: Bearer <jwt> }
Response: { webhooks: Webhook[] }
```

#### Webhook Logs (autenticado)
```
GET /.netlify/functions/webhook-logs?webhookId=<id>
Headers: { Authorization: Bearer <jwt> }
Response: { logs: WebhookLog[] }
```

#### Webhook Create (autenticado)
```
POST /.netlify/functions/webhook-create
Headers: { Authorization: Bearer <jwt> }
Body: { name: string, description?: string, secret?: string }
Response: { webhook: Webhook }
```

#### Webhook Delete (autenticado)
```
DELETE /.netlify/functions/webhook-delete?id=<id>
Headers: { Authorization: Bearer <jwt> }
Response: { success: true }
```

### TypeScript Interfaces
```ts
interface Webhook {
  id: string;
  user_id: string;
  name: string;
  description?: string;
  url_path: string;
  secret?: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  log_count?: number;
}

interface WebhookLog {
  id: string;
  webhook_id: string;
  payload: Record<string, unknown>;
  headers?: Record<string, string>;
  ip_address?: string;
  created_at: string;
}

interface Profile {
  id: string;
  full_name?: string;
  avatar_url?: string;
  created_at: string;
}
```

### Reglas de Diseño AAA
- Sin gradientes de fondo.
- Sin sombras difusas grandes.
- Bordes de 1px `border` color.
- Hover: fondo se eleva ligeramente o acento lime aparece.
- Botones primarios: fondo `accent`, texto `background` (negro), hover `accent-hover`.
- Botones secundarios: fondo `surface`, borde `border`, texto `text-primary`, hover fondo `elevated`.
- Inputs: fondo `background`, borde `border`, focus borde `accent`.
- Tablas: header `surface`, filas alternadas sutilmente, hover fila `elevated`.
- Cards: fondo `surface`, borde `border`, radius `8px`, padding `24px`.
- Tipografía: Inter, sans-serif. H1 32px/700, H2 24px/600, body 14px/400, small 12px/400.
- Espaciado: base 4px, múltiplos de 4 (4, 8, 12, 16, 24, 32, 48, 64).
- Animaciones: `transition-all duration-150 ease-in-out`.
- No emojis en ningún texto de UI. Solo iconos Lucide.

### Forbidden
- No usar shadcn/ui (no da el control exacto de colores que necesitamos).
- No usar componentes genéricos de Bootstrap/Material.
- No emojis.
- No gradientes púrpura/azul.
- No sombras grandes difusas.

## Worker Assignments

### Designer (plan)
- Crear `design/design.md` con especificaciones exactas de cada página, componente, y flujo de interacción.
- No escribir código.

### Scaffold (main agent local)
- Inicializar Vite + React + TS.
- Instalar dependencias: tailwindcss, postcss, autoprefixer, react-router-dom, lucide-react, @supabase/supabase-js.
- Configurar `tailwind.config.js` con colores exactos.
- Configurar `index.css` con theme global, fuente Inter.
- Crear `src/lib/supabase.ts`.
- Crear `src/types/index.ts`.
- Crear layout base vacío (Sidebar, TopBar stubs).
- Crear `netlify.toml`.
- Commit baseline.

### Backend Worker (coder)
- Implementar 5 Netlify Functions en `netlify/functions/`.
- Crear `supabase/schema.sql`.
- Validar que cada función compile y tenga tipos correctos.

### Frontend Worker (coder)
- Implementar páginas y componentes según design.md.
- Implementar auth context con Supabase.
- Implementar hooks de datos.
- Implementar realtime subscription para logs.
- Validar build sin errores TS.

## Merge Order
1. Scaffold baseline → main
2. Backend worker → merge
3. Frontend worker → merge
4. Integration + fixes
5. Final build
