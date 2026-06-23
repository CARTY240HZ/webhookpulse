# FIX URGENTE — Eliminar archivos basura del repo

## Problema

Tu repo de GitHub tiene estos archivos que NO están en nuestro proyecto y rompen el build:

1. `netlify/functions/webhook.ts` → usa `@upstash/redis` (no instalado) → BUILD FALLA
2. `/_redirects` → comentarios `/*` en lugar de `#` → Netlify no puede parsear → warnings de redirect

## Solución (copia y pega en terminal)

Abre Git Bash o PowerShell en la carpeta de tu repo:

```bash
cd webhookpulse
git rm netlify/functions/webhook.ts
git rm _redirects
git commit -m "fix: remove webhook.ts and broken _redirects"
git push
```

## Si no tienes el repo local

1. Ve a tu repo en GitHub: `https://github.com/TU_USUARIO/webhookpulse`
2. Ve a la carpeta `netlify/functions/`
3. Haz click en `webhook.ts` → botón de basura (Delete) → Commit changes
4. Ve a la raíz del repo
5. Si existe `_redirects`, haz click en él → Delete → Commit changes
6. Netlify re-deployará automáticamente

## Verificación

Tras el push, el log de Netlify debe mostrar:

```
Packaging Functions from netlify/functions directory:
  - webhook-create.ts
  - webhook-delete.ts
  - webhook-list.ts
  - webhook-logs.ts
  - webhook-receive.ts
```

**SIN** `webhook.ts` y **SIN** warnings de redirect.

El build pasará y el login aparecerá en `/login`.
