# Cómo usar Claude Code con WebhookPulse

## 1. Instalar Claude Code

```bash
# Windows (PowerShell como Admin)
npm install -g @anthropic-ai/claude-code

# Verificar instalación
claude --version
```

## 2. Iniciar Claude Code en el Proyecto

Abre una terminal en la carpeta del proyecto:

```bash
cd C:\Users\khawa\Documents\kimi\workspace\webhookpulse
claude
```

Claude Code leerá automáticamente el archivo `CLAUDE.md` y entenderá todo el proyecto.

## 3. Comandos útiles con Claude Code

```bash
# Preguntar sobre el proyecto
claude "explica la arquitectura de webhookpulse"

# Hacer cambios
claude "agrega un campo 'friends' al payload de Roblox"

# Revisar código
claude "revisa api/webhook-receive.ts por errores de seguridad"

# Debug
claude "por qué el embed no muestra los datos del player?"
```

## 4. Archivos Importantes para Claude

| Archivo | Qué contiene |
|---------|-------------|
| `CLAUDE.md` | Contexto completo del proyecto (stack, schema, diseño) |
| `api/*.ts` | Funciones serverless de Vercel |
| `src/components/` | Componentes React (frontend) |
| `src/pages/` | Páginas del dashboard |
| `roblox/*.lua` | Scripts para ejecutores de Roblox |
| `supabase/schema.sql` | Schema de PostgreSQL |
| `vercel.json` | Configuración de deploy |

## 5. Variables de Entorno (no compartir con Claude)

Claude Code puede ver las variables de entorno locales si están en `.env`. **Nunca** compartas:
- `SUPABASE_SERVICE_KEY`
- `VITE_SUPABASE_ANON_KEY`

## 6. Flujo de Trabajo con Claude

```bash
# 1. Entra al proyecto
cd C:\Users\khawa\Documents\kimi\workspace\webhookpulse

# 2. Abre Claude Code
claude

# 3. Claude leerá CLAUDE.md y entenderá el proyecto
# 4. Pregunta lo que necesites:
#    "agrega un botón de exportar logs a CSV"
#    "optimiza el payload de Roblox"
#    "arregla el error 404 en Vercel"
#    "mejora el diseño del embed"

# 5. Claude hará los cambios y tú los revisas
# 6. Git push cuando estén listos
git add . && git commit -m "feat: ..." && git push origin main
```

## 7. Ejemplos de Prompts

| Lo que quieres | Prompt para Claude |
|----------------|-------------------|
| Agregar más datos al script Lua | "Agrega campos de `friends count` y `robux balance` al payload de Roblox en `roblox/WebhookPulseSender_v2.lua`" |
| Mejorar el dashboard | "Crea un gráfico de barras en el dashboard que muestre logs por día usando los datos de Supabase" |
| Arreglar bug | "El embed muestra `unknown` para username. Revisa `src/components/RobloxEmbed.tsx` y asegúrate de que lea de `player.username`" |
| Nueva feature | "Agrega un endpoint `/api/webhook-export` que devuelva todos los logs de un webhook en formato CSV" |
| Seguridad | "Revisa todas las funciones en `api/` y asegúrate de que validen el JWT antes de acceder a Supabase" |

## 8. Tips

- Claude Code tiene acceso a todos los archivos del proyecto. Puede leer, editar y crear archivos.
- Usa `/commit` dentro de Claude para hacer git commit.
- Usa `/terminal` para ejecutar comandos de terminal.
- Si Claude no entiende algo, refiérete a `CLAUDE.md`.

---

**Archivo creado:** `C:\Users\khawa\Documents\kimi\workspace\webhookpulse\CLAUDE.md`

**Para empezar ahora:**
```bash
cd C:\Users\khawa\Documents\kimi\workspace\webhookpulse
claude
```
