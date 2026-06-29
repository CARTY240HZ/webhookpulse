# Full Sweep Plan — Token Unification + Primitive Migration

## State Audit (Current)

- **Tailwind config** (`tailwind.config.js`) has hardcoded hex values that conflict with `index.css` CSS vars
  - `background: '#0C0C0E'` vs `index.css` `--bg: #08080A`
  - `surface: '#161618'` vs `index.css` `--bg-elevated: #16161A`
  - `border: '#27272A'` vs `index.css` `--border: rgba(255,255,255,0.06)`
  - `text-primary: '#FAFAFA'` vs `index.css` `--text-primary: #F0F0F5`
  - `danger: '#EF4444'` vs `index.css` `--danger: #F87171`
  - `success: '#22C55E'` vs `index.css` `--success: #4ADE80`
- **Mix of dialects**: some files use `var(--*)`, some use Tailwind classes like `bg-surface`, some use raw Tailwind like `blue-500`, `green-400`
- **No UI primitives exist** (Button, Card, Badge, Modal were never created in this workspace)

## Goal

1. **Unify tailwind.config.js** to consume CSS vars from `index.css` as single source of truth
2. **Create minimal UI primitives** (Button, Card, Badge, Modal) in `src/components/ui/` — composition-based, forwardRef, no Singleton
3. **Migrate all 19 page/component files** to use unified tokens and/or primitives
4. **Preserve all existing behavior** — no logic changes, only styling unification

## Files to Touch

### Stage 1 — Foundation (single agent)
- `tailwind.config.js` — rewrite to consume CSS vars
- `src/index.css` — add RGB channels for opacity, display type, motion tokens, primitive base classes
- `src/components/ui/` — create Button, Card, Badge, Modal, index.ts barrel

### Stage 2 — Parallel Migration (4 agents)

**Agent A — Dashboard + Layout**
- `src/pages/DashboardPage.tsx`
- `src/components/Layout.tsx`
- `src/components/TopBar.tsx`
- `src/components/Sidebar.tsx`
- `src/components/ActivityFeed.tsx`

**Agent B — Auth + Settings**
- `src/pages/LoginPage.tsx`
- `src/pages/RegisterPage.tsx`
- `src/pages/SettingsPage.tsx`
- `src/pages/ForgotPasswordPage.tsx`
- `src/pages/ResetPasswordPage.tsx`
- `src/components/IpRulesModal.tsx`

**Agent C — Webhook Detail + Logs**
- `src/pages/WebhookDetailPage.tsx`
- `src/components/LogRow.tsx`
- `src/components/HealthIndicator.tsx`
- `src/components/SearchBar.tsx`
- `src/components/PayloadViewer.tsx`

**Agent D — Modals + Misc**
- `src/components/CreateWebhookModal.tsx` (partial — already partially migrated)
- `src/components/RevealWebhookUrlModal.tsx`
- `src/components/TemplateCard.tsx`
- `src/components/Skeleton.tsx`
- `src/components/SseStatus.tsx`
- `src/components/ScrollToTop.tsx`
- `src/components/ErrorBoundary.tsx`
- `src/components/RobloxEmbed.tsx`

### Stage 3 — Stats + Landing (already partially done, verify)
- `src/pages/StatsPage.tsx`
- `src/pages/LandingPage.tsx` (already uses var(--*) heavily)

### Stage 4 — Verification
- `npm run typecheck` (tsc --noEmit)
- `npm run build` (vite build)
- Visual smoke test on dev server

## Token Map (CSS vars → Tailwind classes)

| CSS Var | Tailwind Class (after config rewrite) |
|---------|----------------------------------------|
| `--bg` | `bg-background` |
| `--bg-secondary` | `bg-surface` |
| `--bg-elevated` | `bg-elevated` |
| `--bg-card` | `bg-card` |
| `--text-primary` | `text-text-primary` |
| `--text-secondary` | `text-text-secondary` |
| `--text-muted` | `text-text-muted` |
| `--accent` | `text-accent` / `bg-accent` |
| `--accent-hover` | `text-accent-hover` / `bg-accent-hover` |
| `--danger` | `text-danger` / `bg-danger` |
| `--success` | `text-success` / `bg-success` |
| `--warning` | `text-warning` / `bg-warning` |
| `--info` | `text-info` / `bg-info` |
| `--border` | `border-border` |
| `--border-hover` | `border-border-hover` |

## Rules for Agents

1. **Never change logic** — only className, style, and token usage
2. **Replace all raw Tailwind colors** (`blue-500`, `green-400`, `red-500`, etc.) with unified tokens
3. **Replace `var(--*)` with Tailwind classes** where the config now supports it (optional but preferred for consistency)
4. **Keep `var(--*)` for dynamic values** (e.g., `style={{ background: 'var(--bg-glass)' }}` where no Tailwind class exists)
5. **Button primitive**: replace all `<button>` with `<Button>` where possible
6. **Card primitive**: replace repeated glass-card patterns with `<Card>`
7. **Modal primitive**: replace all modal divs with `<Modal>`
8. **Badge primitive**: replace inline status badges with `<Badge>`
