# Guía de Integración: Agente IA en WebhookPulse

## Índice
1. [Arquitectura](#arquitectura)
2. [Paso 1: Instalar SDK](#paso-1-instalar-sdk)
3. [Paso 2: Variables de entorno](#paso-2-variables-de-entorno)
4. [Paso 3: Crear utilidades compartidas](#paso-3-crear-utilidades-compartidas)
5. [Paso 4: Crear endpoint de API](#paso-4-crear-endpoint-de-api)
6. [Paso 5: Crear hook de React](#paso-5-crear-hook-de-react)
7. [Paso 6: Crear componente de UI](#paso-6-crear-componente-de-ui)
8. [Paso 7: Integrar en el frontend](#paso-7-integrar-en-el-frontend)
9. [Paso 8: Flujo completo de trabajo](#paso-8-flujo-completo-de-trabajo)
10. [Casos de uso](#casos-de-uso)
11. [Consideraciones de seguridad](#consideraciones-de-seguridad)
12. [Límites de Vercel Hobby](#limites-de-vercel-hobby)

---

## Arquitectura

```
Usuario → Frontend (React)
            ↓
      POST /api/ai-agent
            ↓
      Backend (Vercel Function)
            ↓
      Anthropic Claude API / OpenAI GPT
            ↓
      Respuesta JSON → Frontend
```

El agente IA actúa como un intermediario entre el usuario y los datos de webhooks. Recibe comandos en lenguaje natural, analiza logs/payloads, y responde con acciones o información útil.

---

## Paso 1: Instalar SDK

### Opción A: Anthropic Claude (recomendado)

```bash
cd C:\Users\khawa\Documents\kimi\workspace\webhookpulse
npm install @anthropic-ai/sdk
```

### Opción B: OpenAI GPT

```bash
npm install openai
```

### Opción C: Google Gemini

```bash
npm install @google/generative-ai
```

---

## Paso 2: Variables de entorno

Añade al archivo `.env` en la raíz del proyecto:

```env
# Anthropic Claude
ANTHROPIC_API_KEY=sk-ant-api03-xxxxxxxxxxxx

# O OpenAI
OPENAI_API_KEY=sk-proj-xxxxxxxxxxxx

# O Google Gemini
GEMINI_API_KEY=AIxxxxxxxxxxxx

# Configuración del agente
AI_AGENT_MAX_TOKENS=4096
AI_AGENT_MODEL=claude-3-5-sonnet-20241022
```

**Para obtener la API key de Claude:**
1. Ve a [console.anthropic.com](https://console.anthropic.com)
2. Crea una cuenta o inicia sesión
3. Ve a "API Keys" → "Create Key"
4. Copia la key y pégala en `.env`

---

## Paso 3: Crear utilidades compartidas

Crea el archivo `api/_lib/ai-client.ts`:

```typescript
import Anthropic from '@anthropic-ai/sdk'

const apiKey = process.env.ANTHROPIC_API_KEY

if (!apiKey) {
  console.warn('ANTHROPIC_API_KEY not set. AI agent will not function.')
}

export const anthropic = apiKey ? new Anthropic({ apiKey }) : null

export const AI_MODEL = process.env.AI_AGENT_MODEL || 'claude-3-5-sonnet-20241022'
export const MAX_TOKENS = parseInt(process.env.AI_AGENT_MAX_TOKENS || '4096', 10)

interface AiMessage {
  role: 'user' | 'assistant'
  content: string
}

export async function sendToAi(messages: AiMessage[]): Promise<string> {
  if (!anthropic) {
    throw new Error('AI client not configured. Set ANTHROPIC_API_KEY.')
  }

  const response = await anthropic.messages.create({
    model: AI_MODEL,
    max_tokens: MAX_TOKENS,
    messages: messages.map(m => ({
      role: m.role,
      content: m.content,
    })),
  })

  const content = response.content[0]
  if (content.type === 'text') {
    return content.text
  }
  throw new Error('Unexpected response type from AI')
}
```

---

## Paso 4: Crear endpoint de API

Crea el archivo `api/ai-agent.ts`:

```typescript
import { createClient } from '@supabase/supabase-js'
import { sendToAi } from './_lib/ai-client'
import { cors } from './_lib/cors'

const supabaseUrl = process.env.SUPABASE_URL || ''
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY || ''

interface AiAgentRequest {
  action: 'analyze' | 'generate_lua' | 'summarize' | 'explain' | 'ask'
  webhookId?: string
  query?: string
  logs?: any[]
  context?: string
}

export default async function handler(req: any, res: any) {
  // CORS
  cors(req, res)
  if (req.method === 'OPTIONS') return res.status(200).end()
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' })

  // Auth
  const authHeader = req.headers.authorization || ''
  const token = authHeader.replace('Bearer ', '')
  if (!token) return res.status(401).json({ error: 'Unauthorized' })

  const supabase = createClient(supabaseUrl, supabaseServiceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  const { data: { user }, error: authError } = await supabase.auth.getUser(token)
  if (authError || !user) return res.status(401).json({ error: 'Unauthorized' })

  const { action, webhookId, query, logs, context } = req.body as AiAgentRequest

  try {
    let systemPrompt = `Eres un agente de análisis de webhooks especializado en Roblox. 
Tu trabajo es analizar payloads, detectar anomalías, generar scripts Lua, y responder preguntas sobre los datos recibidos.
Responde siempre en español o inglés según el contexto del usuario.
Sé conciso pero preciso. No inventes datos que no estén en los logs.`

    let userPrompt = ''

    switch (action) {
      case 'analyze': {
        if (!logs || logs.length === 0) {
          return res.status(400).json({ error: 'No logs provided for analysis' })
        }
        userPrompt = `Analiza estos logs de webhook y dime si hay algo sospechoso, anomalías, o patrones interesantes:\n\n${JSON.stringify(logs, null, 2)}`
        break
      }

      case 'generate_lua': {
        if (!context) {
          return res.status(400).json({ error: 'No context provided for Lua generation' })
        }
        userPrompt = `Genera un script Lua para Roblox que ${context}. 
El script debe usar el formato de webhook de WebhookPulse.
Incluye manejo de errores y reintentos.
\nFormato esperado:\nlocal HttpService = game:GetService("HttpService")\nlocal webhookUrl = "URL_DEL_WEBHOOK"\n-- ... código ...`
        break
      }

      case 'summarize': {
        if (!logs || logs.length === 0) {
          return res.status(400).json({ error: 'No logs to summarize' })
        }
        userPrompt = `Resume estos logs de webhook en 3-5 puntos clave:\n\n${JSON.stringify(logs, null, 2)}`
        break
      }

      case 'explain': {
        if (!context) {
          return res.status(400).json({ error: 'No payload to explain' })
        }
        userPrompt = `Explica qué significa este payload de webhook y qué acciones debería tomar el sistema:\n\n${context}`
        break
      }

      case 'ask': {
        if (!query) {
          return res.status(400).json({ error: 'No query provided' })
        }
        userPrompt = query
        break
      }

      default:
        return res.status(400).json({ error: 'Unknown action' })
    }

    const aiResponse = await sendToAi([
      { role: 'assistant', content: systemPrompt },
      { role: 'user', content: userPrompt },
    ])

    return res.status(200).json({
      success: true,
      action,
      response: aiResponse,
      timestamp: new Date().toISOString(),
    })

  } catch (error: any) {
    console.error('[AI Agent Error]', error)
    return res.status(500).json({
      error: 'AI processing failed',
      details: error.message,
    })
  }
}
```

---

## Paso 5: Crear hook de React

Crea el archivo `src/hooks/useAiAgent.ts`:

```typescript
import { useState, useCallback } from 'react'
import { supabase } from '../lib/supabase'

interface AiAgentOptions {
  action: 'analyze' | 'generate_lua' | 'summarize' | 'explain' | 'ask'
  webhookId?: string
  query?: string
  logs?: any[]
  context?: string
}

interface AiAgentResponse {
  success: boolean
  response: string
  timestamp: string
}

export function useAiAgent() {
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [result, setResult] = useState<AiAgentResponse | null>(null)

  const askAi = useCallback(async (options: AiAgentOptions): Promise<AiAgentResponse | null> => {
    setLoading(true)
    setError(null)
    setResult(null)

    try {
      const { data: sessionData } = await supabase.auth.getSession()
      const token = sessionData.session?.access_token
      if (!token) {
        setError('Session expired. Please log in.')
        return null
      }

      const baseUrl = typeof window !== 'undefined' ? window.location.origin : ''
      const res = await fetch(`${baseUrl}/api/ai-agent`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
        },
        body: JSON.stringify(options),
      })

      const data = await res.json()
      if (!res.ok) {
        setError(data.error || 'AI request failed')
        return null
      }

      setResult(data)
      return data
    } catch (err: any) {
      setError(err.message || 'Network error')
      return null
    } finally {
      setLoading(false)
    }
  }, [])

  const clear = useCallback(() => {
    setLoading(false)
    setError(null)
    setResult(null)
  }, [])

  return { askAi, loading, error, result, clear }
}
```

---

## Paso 6: Crear componente de UI

Crea el archivo `src/components/AiAgentPanel.tsx`:

```tsx
import { useState } from 'react'
import { Bot, Send, X, Sparkles, Loader2, Code, FileText, Search } from 'lucide-react'
import { useAiAgent } from '../hooks/useAiAgent'
import type { WebhookLog } from '../types'

interface AiAgentPanelProps {
  webhookId?: string
  logs?: WebhookLog[]
}

type ActionType = 'analyze' | 'generate_lua' | 'summarize' | 'explain' | 'ask'

export default function AiAgentPanel({ webhookId, logs }: AiAgentPanelProps) {
  const { askAi, loading, error, result, clear } = useAiAgent()
  const [query, setQuery] = useState('')
  const [selectedAction, setSelectedAction] = useState<ActionType>('ask')
  const [isOpen, setIsOpen] = useState(false)

  const actions: { id: ActionType; label: string; icon: React.ReactNode }[] = [
    { id: 'ask', label: 'Ask', icon: <Search className="w-4 h-4" /> },
    { id: 'analyze', label: 'Analyze', icon: <Sparkles className="w-4 h-4" /> },
    { id: 'summarize', label: 'Summarize', icon: <FileText className="w-4 h-4" /> },
    { id: 'generate_lua', label: 'Lua Script', icon: <Code className="w-4 h-4" /> },
  ]

  const handleSubmit = async () => {
    if (!query.trim() && selectedAction !== 'analyze') return

    const options: any = { action: selectedAction }

    if (webhookId) options.webhookId = webhookId
    if (logs && logs.length > 0) options.logs = logs
    if (query.trim()) {
      if (selectedAction === 'ask') options.query = query
      else options.context = query
    }

    await askAi(options)
  }

  if (!isOpen) {
    return (
      <button
        onClick={() => setIsOpen(true)}
        className="fixed bottom-6 right-6 w-14 h-14 rounded-full bg-accent text-background flex items-center justify-center shadow-lg hover:bg-accent-hover transition-colors z-50"
        title="AI Agent"
      >
        <Bot className="w-6 h-6" />
      </button>
    )
  }

  return (
    <div className="fixed bottom-6 right-6 w-96 max-h-[80vh] bg-surface border border-border rounded-lg shadow-xl flex flex-col z-50 overflow-hidden">
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 border-b border-border">
        <div className="flex items-center gap-2">
          <Bot className="w-5 h-5 text-accent" />
          <span className="font-semibold text-text-primary">AI Agent</span>
        </div>
        <button
          onClick={() => { setIsOpen(false); clear() }}
          className="text-text-secondary hover:text-text-primary transition-colors"
        >
          <X className="w-4 h-4" />
        </button>
      </div>

      {/* Action selector */}
      <div className="flex items-center gap-1 px-3 py-2 border-b border-border overflow-x-auto">
        {actions.map((action) => (
          <button
            key={action.id}
            onClick={() => setSelectedAction(action.id)}
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded text-xs font-medium transition-colors shrink-0 ${
              selectedAction === action.id
                ? 'bg-accent text-background'
                : 'bg-background text-text-secondary hover:text-text-primary'
            }`}
          >
            {action.icon}
            {action.label}
          </button>
        ))}
      </div>

      {/* Result area */}
      <div className="flex-1 overflow-y-auto p-4 space-y-3 min-h-[200px]">
        {loading && (
          <div className="flex items-center gap-2 text-text-secondary">
            <Loader2 className="w-4 h-4 animate-spin" />
            <span className="text-sm">Thinking...</span>
          </div>
        )}

        {error && (
          <div className="bg-danger/10 border border-danger/20 rounded p-3 text-sm text-danger">
            {error}
          </div>
        )}

        {result && (
          <div className="bg-background border border-border rounded p-3">
            <div className="text-xs text-text-secondary uppercase tracking-wider font-semibold mb-2">
              {selectedAction === 'generate_lua' ? 'Generated Lua' : 'Response'}
            </div>
            <pre className="text-sm text-text-primary whitespace-pre-wrap font-mono overflow-x-auto">
              {result.response}
            </pre>
          </div>
        )}

        {!loading && !error && !result && (
          <div className="text-sm text-text-secondary text-center py-8">
            {selectedAction === 'analyze' && logs
              ? 'Click Send to analyze the current logs.'
              : selectedAction === 'summarize' && logs
              ? 'Click Send to summarize the current logs.'
              : 'Type your question or command and click Send.'}
          </div>
        )}
      </div>

      {/* Input area */}
      <div className="px-3 py-2 border-t border-border">
        <div className="flex items-center gap-2">
          <input
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && handleSubmit()}
            placeholder={
              selectedAction === 'generate_lua'
                ? 'Describe what the Lua script should do...'
                : selectedAction === 'ask'
                ? 'Ask anything about your webhooks...'
                : 'Enter context or query...'
            }
            className="flex-1 px-3 py-2 bg-background border border-border rounded text-sm text-text-primary placeholder-text-secondary focus:border-accent focus:outline-none transition-colors"
          />
          <button
            onClick={handleSubmit}
            disabled={loading || (!query.trim() && selectedAction !== 'analyze' && selectedAction !== 'summarize')}
            className="flex items-center gap-1.5 px-3 py-2 rounded text-sm font-medium bg-accent text-background hover:bg-accent-hover transition-colors disabled:opacity-50"
          >
            <Send className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  )
}
```

---

## Paso 7: Integrar en el frontend

### Añadir al `WebhookDetailPage.tsx`:

Busca la línea donde importas otros componentes y añade:

```tsx
import AiAgentPanel from '../components/AiAgentPanel'
```

Luego, al final del return del componente (antes del cierre final `</div>`), añade:

```tsx
{/* AI Agent floating panel */}
<AiAgentPanel webhookId={id} logs={logs} />
```

### Añadir al `DashboardPage.tsx`:

```tsx
import AiAgentPanel from '../components/AiAgentPanel'
```

Y al final del return:

```tsx
{/* AI Agent floating panel */}
<AiAgentPanel />
```

---

## Paso 8: Flujo completo de trabajo

### 1. Usuario abre el panel AI
- Hace clic en el botón flotante (esquina inferior derecha)
- Se abre el panel con 4 acciones disponibles

### 2. Usuario selecciona una acción
- **Ask**: Pregunta general sobre webhooks
- **Analyze**: El agente analiza los logs actuales en busca de anomalías
- **Summarize**: Resume los logs en puntos clave
- **Lua Script**: Genera código Lua para Roblox basado en la descripción del usuario

### 3. El frontend envía la petición
- El hook `useAiAgent` hace POST a `/api/ai-agent`
- Incluye JWT token de Supabase para autenticación

### 4. El backend procesa
- Valida autenticación
- Construye el prompt según la acción
- Llama a la API de Claude/OpenAI
- Retorna la respuesta en JSON

### 5. El frontend muestra el resultado
- Aparece en el panel con formato adecuado
- Lua scripts se muestran en bloque de código con scroll

---

## Casos de uso

### Caso 1: Análisis de seguridad
```
Acción: Analyze
Logs: [array de logs sospechosos]
→ AI detecta: "3 requests desde IPs no listadas en allowlist con payloads malformados"
```

### Caso 2: Generación de scripts Lua
```
Acción: Lua Script
Query: "envía un mensaje cuando un jugador se une al servidor con su nombre y nivel"
→ AI genera: Script Lua completo con HttpService, manejo de errores, formato de payload
```

### Caso 3: Resumen ejecutivo
```
Acción: Summarize
Logs: [1000 logs de las últimas 24h]
→ AI retorna: 5 bullet points con tendencias clave
```

### Caso 4: Explicación de payload
```
Acción: Explain
Context: {player: {name: "xX_Noob_Xx", level: 5, coins: 999999}}
→ AI explica: "Este payload indica un jugador nuevo con monedas sospechosamente altas. Posible exploit."
```

---

## Consideraciones de seguridad

1. **La API key nunca va al frontend** — solo existe en el backend (`process.env`)
2. **Autenticación JWT obligatoria** — el endpoint rechaza requests sin token válido
3. **Rate limiting** — implementa en `api/_lib/ratelimit.ts` si es necesario
4. **No envíes secrets en el prompt** — filtra `secret`, `token`, `password` de los logs antes de enviarlos al AI
5. **Validación de inputs** — el endpoint valida que `action` sea uno de los permitidos

---

## Límites de Vercel Hobby

Con el endpoint `ai-agent.ts` añadido, tendrás **11 funciones** (límite: 12).

| Function | Estado |
|----------|--------|
| 2fa.ts | ✅ |
| health-check.ts | ✅ |
| sse-logs.ts | ✅ |
| user-settings.ts | ✅ |
| webhook-ip-rules.ts | ✅ |
| webhook-logs.ts | ✅ |
| webhook-receive.ts | ✅ |
| webhook-reveal.ts | ✅ |
| webhooks.ts | ✅ |
| webhooks/[webhookId]/[token].ts | ✅ |
| **ai-agent.ts** | **✅ NUEVO** |

Quedan **1 slot libre** para futuras funciones.

---

## Notas finales

- El agente IA consume tokens de la API de Claude/OpenAI. Monitorea el uso en el dashboard de tu proveedor.
- Para reducir costos, implementa caché de respuestas frecuentes en el frontend.
- Considera añadir un toggle en Settings para desactivar el agente IA por usuario.
- El panel flotante es responsive y se adapta a móvil (ancho reducido).
