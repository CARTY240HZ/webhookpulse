#!/bin/bash
# WebhookPulse — Deploy Script
# Uso: ./push-to-github.sh <github-username> <repo-name>
# Ejemplo: ./push-to-github.sh miusuario webhookpulse

set -e

USERNAME="${1:-}"
REPO="${2:-}"

if [ -z "$USERNAME" ] || [ -z "$REPO" ]; then
  echo "Uso: ./push-to-github.sh <github-username> <repo-name>"
  echo "Ejemplo: ./push-to-github.sh miusuario webhookpulse"
  exit 1
fi

REMOTE_URL="https://github.com/$USERNAME/$REPO.git"

echo "=== WebhookPulse Deploy Script ==="
echo "Target: $REMOTE_URL"

# Verificar que estamos en el repo
if [ ! -d ".git" ]; then
  echo "Error: No se encontró .git. Ejecuta este script desde la raíz del proyecto."
  exit 1
fi

# Verificar que no existe _redirects
if [ -f "_redirects" ] || [ -f "public/_redirects" ]; then
  echo "Error: _redirects encontrado. Elimínalo antes de continuar."
  echo "Solo netlify.toml debe manejar los redirects."
  exit 1
fi

# Verificar funciones
FUNCTION_COUNT=$(ls netlify/functions/*.ts 2>/dev/null | wc -l)
if [ "$FUNCTION_COUNT" -ne 5 ]; then
  echo "Error: Se esperaban 5 funciones, se encontraron $FUNCTION_COUNT"
  ls netlify/functions/
  exit 1
fi

echo "Funciones encontradas: $FUNCTION_COUNT ✓"
echo "Redirects OK (sin _redirects) ✓"

# Configurar remote
git remote remove origin 2>/dev/null || true
git remote add origin "$REMOTE_URL"

echo "Remote configurado: $REMOTE_URL"

# Push
echo "Pushing to GitHub..."
git push -u origin main --force

echo ""
echo "=== DEPLOY COMPLETADO ==="
echo "Ve a Netlify y conecta el repo: $REMOTE_URL"
echo "Asegúrate de configurar las variables de entorno en Netlify:"
echo "  - SUPABASE_URL"
echo "  - SUPABASE_SERVICE_KEY"
echo "  - VITE_SUPABASE_URL (mismo valor que SUPABASE_URL)"
echo "  - VITE_SUPABASE_ANON_KEY"
echo ""
echo "Para ejecutar en Supabase SQL Editor:"
echo "  supabase/schema.sql"
