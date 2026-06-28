# WebhookPulse Design System v2
## Inspired by VengenceUI — TIER S

---

### Philosophy
- **Dark premium**: No black puro, fondos profundos con tinte azul (#08080A → #0F0F12)
- **Glassmorphism**: Capas translúcidas con backdrop-blur(12px) + bordes sutilísimos
- **Displacement hover**: Cards y botones se desplazan suavemente al hover
- **Motion kernel**: Micro-animaciones en cada interacción
- **Glow acentos**: Lime (#D4E83A) con box-shadow glow controlado
- **No gradients**: Colores sólidos únicamente (sólido ≠ plano)

---

### Palette

| Token | Value | Usage |
|-------|-------|-------|
| `--bg` | `#08080A` | Background root |
| `--bg-secondary` | `#0F0F12` | Surface |
| `--bg-elevated` | `#16161A` | Elevated cards |
| `--bg-card` | `#1A1A1F` | Cards |
| `--bg-glass` | `rgba(255,255,255,0.03)` | Glassmorphism base |
| `--border` | `rgba(255,255,255,0.06)` | Default borders |
| `--border-hover` | `rgba(255,255,255,0.12)` | Hover borders |
| `--accent` | `#D4E83A` | Primary accent (lime) |
| `--accent-hover` | `#E0F050` | Lighter lime |
| `--accent-glow` | `rgba(212,232,58,0.15)` | Glow shadow |
| `--text-primary` | `#F0F0F5` | Headings |
| `--text-secondary` | `#8A8A95` | Body, labels |
| `--text-muted` | `#5A5A65` | Muted text |
| `--success` | `#4ADE80` | Green |
| `--danger` | `#F87171` | Red |
| `--warning` | `#FBBF24` | Amber |
| `--info` | `#60A5FA` | Blue |

---

### Typography

| Level | Size | Weight | Line-height | Letter-spacing |
|-------|------|--------|-------------|----------------|
| Hero | 56px | 700 | 1.1 | -0.02em |
| H1 | 40px | 700 | 1.2 | -0.01em |
| H2 | 28px | 600 | 1.3 | -0.005em |
| H3 | 20px | 600 | 1.4 | 0 |
| Body | 15px | 400 | 1.6 | 0 |
| Label | 12px | 500 | 1.4 | 0.05em |
| Mono | 13px | 400 | 1.5 | 0 |

Font: **Inter** (ya en uso) + **Geist Mono** para código

---

### Spacing
- Base: 4px
- Scale: 4, 8, 12, 16, 20, 24, 32, 40, 48, 64, 96
- Border radius: 8px (sm), 12px (md), 16px (lg), 24px (xl), 9999px (pill)

---

### Effects

#### Glass Card
```css
.glass-card {
  background: rgba(255,255,255,0.03);
  backdrop-filter: blur(12px) saturate(140%);
  -webkit-backdrop-filter: blur(12px) saturate(140%);
  border: 1px solid rgba(255,255,255,0.06);
  border-radius: 12px;
  box-shadow: 0 4px 24px rgba(0,0,0,0.4), inset 0 1px 0 rgba(255,255,255,0.04);
}
```

#### Displacement Hover
```css
.card-hover {
  transition: transform 0.3s cubic-bezier(0.23, 1, 0.32, 1),
              box-shadow 0.3s ease,
              border-color 0.3s ease;
}
.card-hover:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 32px rgba(212,232,58,0.08), 0 4px 16px rgba(0,0,0,0.3);
  border-color: rgba(255,255,255,0.12);
}
```

#### Accent Glow Button
```css
.btn-glow {
  background: #D4E83A;
  color: #08080A;
  font-weight: 600;
  transition: all 0.25s cubic-bezier(0.23, 1, 0.32, 1);
  box-shadow: 0 0 0 rgba(212,232,58,0);
}
.btn-glow:hover {
  background: #E0F050;
  box-shadow: 0 0 24px rgba(212,232,58,0.25), 0 4px 12px rgba(0,0,0,0.2);
  transform: translateY(-1px);
}
.btn-glow:active {
  transform: translateY(0) scale(0.98);
}
```

#### Animated Gradient Border (subtle)
```css
.animated-border {
  position: relative;
  border-radius: 12px;
  overflow: hidden;
}
.animated-border::before {
  content: '';
  position: absolute;
  inset: 0;
  border-radius: inherit;
  padding: 1px;
  background: linear-gradient(135deg, rgba(212,232,58,0.3), transparent, rgba(212,232,58,0.1));
  -webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
  -webkit-mask-composite: xor;
  mask-composite: exclude;
  pointer-events: none;
}
```

---

### Scroll Animations
- Cards: fadeInUp + stagger 0.1s
- Hero: fadeIn + scale 0.95→1
- Stats: countUp animation
- IntersectionObserver threshold: 0.15

---

### Component Patterns

#### Card
- Glassmorphism base
- Border sutil 1px rgba(255,255,255,0.06)
- Hover: translateY(-2px) + border brighter + lime glow shadow
- Inner top highlight: inset 0 1px 0 rgba(255,255,255,0.04)

#### Button Primary
- bg-accent, text-background-dark
- rounded-full (pill) o rounded-lg
- hover: glow + translateY(-1px)
- active: scale(0.98)

#### Button Secondary
- bg-transparent, border border-border
- hover: bg-glass + border brighter
- text text-primary

#### Badge
- px-2 py-0.5
- rounded-full
- font-medium text-xs
- accent: bg-accent/10 text-accent
- success: bg-success/10 text-success
- danger: bg-danger/10 text-danger

#### Input
- bg-transparent
- border border-border
- focus: border-accent + ring-1 ring-accent/20
- placeholder: text-muted

---

### Layout
- Sidebar: 64px icon-only, 240px expanded
- TopBar: 56px, glassmorphism blur
- Content: p-6, max-w-7xl
- ActivityFeed: 300px, border-l border-border

---

### Motion Tokens
```css
--ease-out-expo: cubic-bezier(0.16, 1, 0.3, 1);
--ease-out-back: cubic-bezier(0.34, 1.56, 0.64, 1);
--ease-smooth: cubic-bezier(0.23, 1, 0.32, 1);
--duration-fast: 0.15s;
--duration-normal: 0.25s;
--duration-slow: 0.4s;
```
