# Common Tailwind v4 Errors

8 documented errors with causes and solutions.

## 1. tw-animate-css Import Error

**Error**: "Cannot find module 'tailwindcss-animate'"

`tailwindcss-animate` is v3 only. Use `tw-animate-css` for v4:

```bash
pnpm add -D tw-animate-css
```
```css
@import "tailwindcss";
@import "tw-animate-css";
```

## 2. Utilities Not Working (`bg-primary` has no effect)

**Cause**: Missing `@theme inline` mapping.

```css
@theme inline {
  --color-primary: var(--primary);
  /* map ALL CSS variables */
}
```

## 3. Dark Mode Not Switching

**Cause**: Missing ThemeProvider or `.dark` class not toggling on `<html>`.

1. Create ThemeProvider (see `templates/theme-provider.tsx`)
2. Wrap app in `<ThemeProvider>`
3. Verify `.dark` class toggles on `<html>` element

## 4. Duplicate @layer base

**Cause**: shadcn init already adds `@layer base` — don't add another.

Keep a single `@layer base` block in your CSS.

## 5. Build Fails with tailwind.config.ts

v4 doesn't use `tailwind.config.ts`. Delete it:

```bash
rm tailwind.config.ts
```

## 6. @theme inline Breaks Multi-Theme Dark Mode

**Cause**: `@theme inline` bakes values at build time. Dark mode variable overrides don't take effect.

**When it happens**: Multi-theme systems with `data-mode` or `data-theme` attributes.

**Fix**: Use `@theme` (without `inline`) for multi-theme:

```css
@custom-variant dark (&:where([data-mode=dark], [data-mode=dark] *));

@theme {
  --color-text-primary: var(--color-slate-900);
  --color-bg-primary: var(--color-white);
}

@layer theme {
  [data-mode="dark"] {
    --color-text-primary: var(--color-white);
    --color-bg-primary: var(--color-slate-900);
  }
}
```

`@theme inline` is fine for single theme + light/dark toggle (shadcn default).

## 7. @apply with @layer Classes (v4 Breaking Change)

**Error**: `Cannot apply unknown utility class: custom-button`

v4 no longer lets `@apply` reference classes from `@layer base`/`@layer components`. Use `@utility`:

```css
/* v3 (broken in v4) */
@layer components {
  .custom-button { @apply px-4 py-2 bg-blue-500; }
}

/* v4 */
@utility custom-button {
  @apply px-4 py-2 bg-blue-500;
}
```

## 8. @layer base Styles Not Applying

**Cause**: v4 uses native CSS layers. Base styles can be overridden by utility layers.

**Fix**: Define styles at root level instead of in `@layer base`:

```css
@import "tailwindcss";

:root { --background: hsl(0 0% 100%); }

body {
  background-color: var(--background);  /* No @layer needed */
}
```
