# WebhookPulse — Guía de Deploy en Netlify

## Resumen del problema

Tu deploy actual tiene un archivo `_redirects` con comentarios mal formateados (`/* */` en lugar de `#`). Esto rompe el SPA fallback, haciendo que `/login`, `/register`, `/dashboard` devuelvan 404.

**Solución**: Eliminar `_redirects` y usar solo `netlify.toml`.

---

## Método 1: Push a GitHub (Recomendado)

### Paso 1: Crear repo en GitHub

1. Ve a [github.com/new](https://github.com/new)
2. Nombre del repo: `webhookpulse`
3. **NO** marques "Add a README" (ya lo tenemos)
4. Crea el repo

### Paso 2: Subir el proyecto

Opción A — Con el script (Git Bash):

```bash
cd webhookpulse
./push-to-github.sh TU_USUARIO webhookpulse
```

Opción B — Manual:

```bash
cd webhookpulse
git remote add origin https://github.com/TU_USUARIO/webhookpulse.git
git push -u origin main --force
```

### Paso 3: Conectar a Netlify

1. Ve a [app.netlify.com](https://app.netlify.com)
2. "Add new site" → "Import an existing project"
3. Selecciona GitHub → Autoriza → Elige `webhookpulse`
4. Configuración de build (Netlify la detecta automáticamente):
   - Build command: `npm run build`
   - Publish directory: `dist`
5. Deploy site

### Paso 4: Variables de entorno en Netlify

Ve a Site settings → Environment variables:

| Variable | Valor | Origen |
|---|---|---|
| `SUPABASE_URL` | `https://tu-proyecto.supabase.co` | Supabase Dashboard → Settings → API |
| `SUPABASE_SERVICE_KEY` | `service_role_...` | Supabase Dashboard → Settings → API → service_role key |
| `VITE_SUPABASE_URL` | Mismo que `SUPABASE_URL` | Copia del valor anterior |
| `VITE_SUPABASE_ANON_KEY` | `anon public` key | Supabase Dashboard → Settings → API → anon key |

**Importante**: Nunca expongas `SUPABASE_SERVICE_KEY` en el frontend. Solo se usa en Netlify Functions (backend).

### Paso 5: Supabase SQL

1. Ve a tu proyecto Supabase → SQL Editor
2. New query → Pega el contenido de `supabase/schema.sql`
3. Run

### Paso 6: Verificar deploy

En los logs de Netlify deberías ver:

```
Packaging Functions from netlify/functions directory:
  - webhook-receive.ts
  - webhook-list.ts
  - webhook-logs.ts
  - webhook-create.ts
  - webhook-delete.ts
```

Y **0 errores de redirect**.

---

## Método 2: Deploy manual (Drag & Drop)

Si no quieres usar GitHub:

1. Ejecuta `npm run build` en tu máquina local
2. Ve a [app.netlify.com/drop](https://app.netlify.com/drop)
3. Arrastra la carpeta `dist/`
4. Configura las variables de entorno (Paso 4 arriba)
5. **Re-deploy** después de cada cambio (no es automático)

**Nota**: El deploy manual **no soporta Netlify Functions**. Para funciones serverless necesitas Git + CI/CD.

---

## Método 3: Netlify CLI

```bash
# Instalar CLI
npm install -g netlify-cli

# Login
netlify login

# Link a sitio existente o crear nuevo
netlify link
# o
netlify init

# Deploy con functions
netlify deploy --prod --build
```

---

## Verificación post-deploy

1. Abre tu URL de Netlify (ej: `https://webhookpulse-abc123.netlify.app`)
2. Deberías ver la landing page (hero oscuro, logo lime)
3. Ve a `/login` — debería cargar el formulario de login (no 404)
4. Ve a `/register` — debería cargar el formulario de registro
5. Crea una cuenta → debería redirigir a `/dashboard`

Si ves 404 en `/login`, `/register`, `/dashboard` → el redirect de SPA no está funcionando. Verifica que `netlify.toml` esté presente y que no exista `_redirects`.

---

## Troubleshooting

### "Could not parse redirect line"

**Causa**: Archivo `_redirects` con comentarios `/*` en lugar de `#`.

**Solución**:
```bash
rm _redirects public/_redirects
git add .
git commit -m "fix: remove broken _redirects"
git push
```

### "Only 1 function bundled" (webhook.ts)

**Causa**: Tu repo no tiene las 5 funciones correctas.

**Solución**: Reemplaza todo el contenido del repo con el proyecto `webhookpulse.zip` que generamos.

### "Missing SUPABASE_URL"

**Causa**: Variables de entorno no configuradas en Netlify.

**Solución**: Ve a Site settings → Environment variables → Add variables.

### "Invalid login credentials" (Supabase Auth)

**Causa**: El trigger de perfil no se ejecutó.

**Solución**: Ejecuta `supabase/schema.sql` en el SQL Editor de Supabase.

---

## Archivos clave del proyecto

```
webhookpulse/
├── netlify.toml              ← Configuración de build + redirects (OBLIGATORIO)
├── netlify/functions/        ← 5 funciones serverless
│   ├── webhook-receive.ts    ← Endpoint público POST
│   ├── webhook-list.ts       ← GET autenticado: lista webhooks
│   ├── webhook-logs.ts       ← GET autenticado: logs de webhook
│   ├── webhook-create.ts     ← POST autenticado: crear webhook
│   └── webhook-delete.ts     ← DELETE autenticado: eliminar webhook
├── src/
│   ├── pages/
│   │   ├── LoginPage.tsx     ← Sign in con validación + rate limiting
│   │   ├── RegisterPage.tsx  ← Sign up con password strength
│   │   ├── ForgotPasswordPage.tsx  ← Reset password request
│   │   └── ResetPasswordPage.tsx   ← Set new password
│   └── ...
└── supabase/schema.sql       ← Database + RLS + triggers
```

---

## Estado actual del proyecto local

Ubicación: `C:\Users\khawa\Documents\kimi\workspace\webhookpulse`

- Git repo inicializado: `main` branch, commit `32adaa6`
- 5 funciones serverless: listas
- 0 errores TypeScript: `npm run build` exitoso
- 0 archivos `_redirects`: limpio
- ZIP de entrega: `webhookpulse.zip` (62 KB)

Todo listo para deploy.
