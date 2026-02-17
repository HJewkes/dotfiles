# v3 → v4 Migration

## Key Changes

| v3 | v4 |
|----|-----|
| `tailwind.config.ts` | `@theme` in CSS |
| `@tailwind base/components/utilities` | `@import "tailwindcss"` |
| `darkMode: "class"` | `@custom-variant dark (&:where(.dark, .dark *))` |
| `theme.extend.colors` | `@theme { --color-*: value }` |
| `require("tailwindcss-animate")` | `@import "tw-animate-css"` |
| `require("plugin")` in config | `@plugin "package"` in CSS |
| `@apply` with `@layer` classes | `@utility` directive |
| `h-10 w-10` | `size-10` |
| `forwardRef` | React 19 ref as prop |
| HSL colors | OKLCH colors (preferred) |
| `ring` (3px) | `ring` (1px) — use `ring-3` for v3 look |

## Checklist

- [ ] Delete `tailwind.config.ts`
- [ ] Replace `@tailwind` directives with `@import "tailwindcss"`
- [ ] Move color definitions to `@theme { --color-*: value }`
- [ ] Replace `darkMode: "class"` with `@custom-variant dark`
- [ ] Replace `tailwindcss-animate` with `tw-animate-css`
- [ ] Update plugin syntax: `require()` → `@plugin`
- [ ] Replace `@apply` on `@layer` classes with `@utility`
- [ ] Move `@keyframes` inside `@theme` blocks
- [ ] Update `h-X w-X` to `size-X` where applicable
- [ ] Remove `forwardRef` (React 19)
- [ ] Test `ring` width (now 1px, was 3px)

## Gotchas

**Automated migration tool often fails.** Don't rely on `@tailwindcss/upgrade` — follow manual steps.

**Default element styles removed.** Headings render at same size, lists lose padding. Fix with `@tailwindcss/typography` plugin or custom base styles.

**Use Vite plugin over PostCSS.** `@tailwindcss/vite` is simpler and recommended. PostCSS requires `@tailwindcss/postcss` (separate package) and has plugin compatibility issues.
