# Plan: Documentación Técnica Doctoral — WebhookPulse & ZEX v7.0

## Objetivo
Producir un documento técnico profesional de nivel doctoral que documente exhaustivamente todo el proyecto WebhookPulse (backend, frontend, base de datos, seguridad, webhooks dual Native/Discord) y la integración con ZEX v7.0 Roblox Admin Framework. El documento debe reflejar precisión quirúrgica, análisis arquitectónico profundo, y estándares de documentación de ingeniería de software de elite global.

## Metodología
- **Sin investigación web**: todo el material proviene del código fuente real del workspace y del informe `WebhookPulse_Technical_Audit.md`.
- **Estilo**: Técnico preciso, methodology-transparent, reproducción completa de cada decisión de diseño.
- **Idioma**: Español profesional, terminología técnica en inglés cuando sea el estándar de la industria.
- **Formato**: Markdown intermedio → .docx final.

## Stages

### Stage 1: Outline Design (este turno)
- Crear `webhookpulse_doc.agent.outline.md` con jerarquía 4 niveles (H1-H4).
- 12 capítulos + Resumen Ejecutivo + Referencias.
- Cada capítulo con: palabra objetivo, elementos requeridos (tablas, diagramas, esquemas).

### Stage 2: Content Creation (delegación a writers)
- 12 writers `coder` (uno por capítulo), lanzados en rounds según dependencias.
- Round 1: Capítulos 1-4 (independientes, arquitectura y base de datos)
- Round 2: Capítulos 5-8 (backend, seguridad, webhooks dual)
- Round 3: Capítulos 9-12 (Lua, testing, despliegue, conclusiones)
- Cada writer recibe: System Prompt con estilo técnico + Task Prompt con outline + contexto del archivo de auditoría.

### Stage 3: Review Pipeline
- section_editor: revisar cada capítulo (completitud, densidad, precisión).
- transition_editor: coherencia cross-chapter.
- intro_conclusion_reviewer: validar resumen y conclusiones.

### Stage 4: Assembly + .docx
- Ensamblar `_sec{NN}.md` en `webhookpulse_doc.agent.final.md`.
- Deduplicar footnotes por URL.
- Convertir a .docx usando skill `docx`.

## Archivos de Entrada
- `WebhookPulse_Technical_Audit.md` — fuente principal con todo el código y arquitectura.
- Código fuente en `webhookpulse/` (backend, frontend, Lua, SQL, tests, config).

## Archivos de Salida
- `webhookpulse_doc.agent.outline.md`
- `webhookpulse_doc_sec01.md` … `webhookpulse_doc_sec12.md`
- `webhookpulse_doc.agent.final.md`
- `webhookpulse_doc.docx` (entregable final)

## Skill Loading
- Stage 1: `report-writing` (outline.md ya leído)
- Stage 2: `report-writing` (content.md ya leído), estilo `technical.md`
- Stage 3: `report-writing` (review.md ya leído)
- Stage 4: `docx` (a cargar al inicio de Stage 4)
