# Dark Mode

## ThemeProvider

```typescript
'use client'
import { createContext, useContext, useEffect, useState } from 'react'

type Theme = 'dark' | 'light' | 'system'

const ThemeContext = createContext<{ theme: Theme; setTheme: (t: Theme) => void; resolvedTheme: 'dark' | 'light' } | undefined>(undefined)

export function ThemeProvider({ children, defaultTheme = 'system', storageKey = 'theme' }: {
  children: React.ReactNode; defaultTheme?: Theme; storageKey?: string
}) {
  const [theme, setTheme] = useState<Theme>(defaultTheme)
  const [resolvedTheme, setResolvedTheme] = useState<'dark' | 'light'>('light')

  useEffect(() => {
    const stored = localStorage.getItem(storageKey) as Theme | null
    if (stored) setTheme(stored)
  }, [storageKey])

  useEffect(() => {
    const root = document.documentElement
    root.classList.remove('light', 'dark')
    const resolved = theme === 'system'
      ? (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light')
      : theme
    root.classList.add(resolved)
    setResolvedTheme(resolved)
  }, [theme])

  return (
    <ThemeContext.Provider value={{
      theme,
      setTheme: (t) => { localStorage.setItem(storageKey, t); setTheme(t) },
      resolvedTheme,
    }}>
      {children}
    </ThemeContext.Provider>
  )
}

export const useTheme = () => {
  const ctx = useContext(ThemeContext)
  if (!ctx) throw new Error('useTheme must be used within ThemeProvider')
  return ctx
}
```

## Theme Toggle

```typescript
import { Moon, Sun } from 'lucide-react'
import { useTheme } from '@/providers/ThemeProvider'

export function ThemeToggle() {
  const { resolvedTheme, setTheme } = useTheme()
  return (
    <button
      onClick={() => setTheme(resolvedTheme === 'dark' ? 'light' : 'dark')}
      className="bg-transparent p-2 rounded-md hover:bg-accent"
    >
      <Sun className="size-5 rotate-0 scale-100 transition-all dark:-rotate-90 dark:scale-0" />
      <Moon className="absolute size-5 rotate-90 scale-0 transition-all dark:rotate-0 dark:scale-100" />
      <span className="sr-only">Toggle theme</span>
    </button>
  )
}
```

## CSS Dark Mode Variant (v4)

```css
@custom-variant dark (&:where(.dark, .dark *));

.dark {
  --background: hsl(222.2 84% 4.9%);
  --foreground: hsl(210 40% 98%);
  /* override all color variables */
}
```

## OKLCH Colors

v4 defaults to OKLCH for better perceptual uniformity. Prefer for custom colors:

```css
@theme {
  --color-brand: oklch(0.7 0.15 250);  /* preferred */
  --color-brand: hsl(240 80% 60%);     /* still works */
}
```

Tailwind auto-generates sRGB fallbacks for older browsers (93%+ global support).

## Semantic Tokens

| Token | Light | Dark |
|-------|-------|------|
| `bg-background` | White | Dark gray |
| `text-foreground` | Dark | White |
| `bg-card` | White | Slightly lighter |
| `text-muted-foreground` | Gray | Light gray |
| `border-border` | Light gray | Dark gray |

Never use raw colors (`bg-blue-500`) — always semantic tokens.
