# Tailwind Component Patterns

All patterns use semantic tokens for automatic dark mode support.

## Containers

```tsx
// Page container
<div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">

// Section with vertical spacing
<section className="py-16 sm:py-24">
  <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
```

Container widths: `max-w-4xl` (narrow/blog), `max-w-5xl` (medium), `max-w-6xl` (wide), `max-w-7xl` (full).

## Grids

```tsx
// Responsive columns
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">

// Auto-fit (dynamic columns)
<div className="grid grid-cols-[repeat(auto-fit,minmax(280px,1fr))] gap-6">

// Masonry-style
<div className="columns-1 md:columns-2 lg:columns-3 gap-6 space-y-6">
  <div className="break-inside-avoid">...</div>
</div>
```

## Cards

```tsx
// Basic
<div className="bg-card text-card-foreground rounded-lg border border-border p-6">
  <h3 className="text-lg font-semibold mb-2">Title</h3>
  <p className="text-muted-foreground">Description</p>
</div>

// Feature card with icon
<div className="bg-card text-card-foreground rounded-lg border border-border p-6 hover:shadow-lg transition-shadow">
  <div className="h-12 w-12 rounded-lg bg-primary/10 flex items-center justify-center mb-4">
    {/* icon */}
  </div>
  <h3 className="text-lg font-semibold mb-2">Feature</h3>
  <p className="text-muted-foreground">Description</p>
</div>

// Pricing card
<div className="bg-card text-card-foreground rounded-lg border-2 border-border p-8">
  <div className="text-sm font-semibold text-primary mb-2">Pro Plan</div>
  <div className="text-4xl font-bold mb-1">$29<span className="text-lg text-muted-foreground">/mo</span></div>
  <p className="text-muted-foreground mb-6">For growing teams</p>
  <button className="w-full bg-primary text-primary-foreground py-2 rounded-md hover:bg-primary/90">Get Started</button>
</div>
```

## Buttons

```tsx
// Primary
<button className="bg-primary text-primary-foreground px-4 py-2 rounded-md hover:bg-primary/90 transition-colors">

// Secondary
<button className="bg-secondary text-secondary-foreground px-4 py-2 rounded-md hover:bg-secondary/80">

// Outline
<button className="border border-border bg-transparent px-4 py-2 rounded-md hover:bg-accent">

// Ghost
<button className="bg-transparent px-4 py-2 rounded-md hover:bg-accent hover:text-accent-foreground">

// Destructive
<button className="bg-destructive text-destructive-foreground px-4 py-2 rounded-md hover:bg-destructive/90">
```

Sizes: `px-3 py-1.5 text-sm` (small), `px-4 py-2` (default), `px-6 py-3 text-lg` (large).

## CVA Components

```typescript
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@/lib/utils'

const buttonVariants = cva(
  'inline-flex items-center justify-center whitespace-nowrap rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50',
  {
    variants: {
      variant: {
        default: 'bg-primary text-primary-foreground hover:bg-primary/90',
        destructive: 'bg-destructive text-destructive-foreground hover:bg-destructive/90',
        outline: 'border border-border bg-background hover:bg-accent hover:text-accent-foreground',
        secondary: 'bg-secondary text-secondary-foreground hover:bg-secondary/80',
        ghost: 'hover:bg-accent hover:text-accent-foreground',
        link: 'text-primary underline-offset-4 hover:underline',
      },
      size: {
        default: 'h-10 px-4 py-2',
        sm: 'h-9 rounded-md px-3',
        lg: 'h-11 rounded-md px-8',
        icon: 'size-10',
      },
    },
    defaultVariants: { variant: 'default', size: 'default' },
  }
)
```

## Forms

```tsx
// Input with error state
<div className="space-y-2">
  <label htmlFor="email" className="text-sm font-medium">Email</label>
  <input
    id="email"
    type="email"
    className="w-full px-3 py-2 bg-background border border-border rounded-md focus:outline-none focus:ring-2 focus:ring-primary"
    placeholder="you@example.com"
  />
</div>

// Error state: replace border-border with border-destructive, add:
<p className="text-sm text-destructive">Error message</p>

// Checkbox
<div className="flex items-center space-x-2">
  <input id="terms" type="checkbox" className="h-4 w-4 rounded border-border text-primary focus:ring-2 focus:ring-primary" />
  <label htmlFor="terms" className="text-sm">I agree</label>
</div>
```

## Navigation

```tsx
// Sticky header
<header className="sticky top-0 z-50 w-full border-b border-border bg-background/95 backdrop-blur">
  <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
    <div className="flex h-16 items-center justify-between">
      <div className="flex items-center gap-8">
        <a href="/" className="font-bold text-xl">Brand</a>
        <nav className="hidden md:flex gap-6">
          <a href="#" className="text-sm hover:text-primary transition-colors">Link</a>
        </nav>
      </div>
      <button className="bg-primary text-primary-foreground px-4 py-2 rounded-md text-sm">CTA</button>
    </div>
  </div>
</header>
```

## Typography

```tsx
<h1 className="text-4xl sm:text-5xl lg:text-6xl font-bold">
<h2 className="text-3xl sm:text-4xl font-bold">
<h3 className="text-2xl sm:text-3xl font-semibold">
<p className="text-base text-muted-foreground">
<p className="text-sm text-muted-foreground">  // caption
```

## Spacing Scale

| Usage | Classes | Size |
|-------|---------|------|
| Tight | `gap-2 p-2` | 8px |
| Standard | `gap-4 p-4` | 16px |
| Comfortable | `gap-6 p-6` | 24px |
| Loose | `gap-8 p-8` | 32px |
| Section | `py-16 sm:py-24` | 64px/96px |

## Hover Effects

```tsx
<div className="transition-transform hover:scale-105">   // lift
<div className="transition-shadow hover:shadow-lg">       // shadow
<button className="transition-colors hover:bg-primary/90"> // color
```
