---
name: migrate-to-path-aliases
description: Migrate TypeScript projects to use @/ path aliases with tsc-alias for clean imports. Use when the user wants to add @/ aliases, convert relative imports to @/ imports, set up tsc-alias, fix path aliases for npm publishing, or migrate a repo to use path aliases.
---

# Migrate to @/ Path Aliases with tsc-alias

Converts a TypeScript project from relative imports (`../../models/foo`) to `@/` path aliases (`@/models/foo`) and configures `tsc-alias` so compiled output remains consumable by npm consumers or bundlers.

## Why tsc-alias Is Required

TypeScript's `paths` config (`@/* -> src/*`) is a **compile-time only** feature. `tsc` does **not** rewrite import paths in emitted JS. Without `tsc-alias`, any consumer of the compiled output gets "module not found" errors because `@/models/foo` has no meaning outside your `tsconfig.json`.

`tsc-alias` runs after `tsc` and rewrites `@/*` imports in the compiled `.js` and `.d.ts` files to proper relative paths.

## Prerequisites

- TypeScript project with `tsc` builds (not just bundler-only like Vite/webpack where aliases are handled by the bundler)
- Node.js >= 18

## Step 1: Audit Current State

1. Check if `@/*` alias already exists in `tsconfig.json`:

```bash
grep -A2 '"paths"' tsconfig.json
```

2. Find all relative imports that could be converted (imports going up 2+ levels):

```bash
rg "from ['\"]\.\./" src/ --glob "*.ts" --glob "*.tsx" -l
```

3. Check if `tsc-alias` is already installed:

```bash
grep "tsc-alias" package.json
```

## Step 2: Configure tsconfig.json

Ensure the **base** `tsconfig.json` has `baseUrl` and `paths`:

```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    }
  }
}
```

**Important**: Any extended tsconfigs (e.g., `tsconfig.esm.json`, `tsconfig.cjs.json`) inherit `paths` automatically from the base config via `extends`. No need to duplicate.

If the project uses a `src/` directory, the mapping should be `"@/*": ["src/*"]`. If source files are at the root, use `"@/*": ["./*"]`. Match the project's existing `include` pattern.

## Step 3: Install tsc-alias

```bash
npm install --save-dev tsc-alias
```

## Step 4: Update Build Scripts

Add `tsc-alias` as a post-step to every `tsc` build command. It must use the **same tsconfig** as the corresponding `tsc` invocation.

### Single-build project

```json
{
  "scripts": {
    "build": "tsc && tsc-alias"
  }
}
```

### Dual ESM/CJS build (common for npm libraries)

```json
{
  "scripts": {
    "build": "npm run clean && npm run build:esm && npm run build:cjs",
    "build:esm": "tsc -p tsconfig.esm.json && tsc-alias -p tsconfig.esm.json",
    "build:cjs": "tsc -p tsconfig.cjs.json && tsc-alias -p tsconfig.cjs.json"
  }
}
```

### With declaration types in a separate dir

If declarations are emitted to a different directory (e.g., `dist/types`), `tsc-alias` handles them automatically when pointed at the correct tsconfig. No extra config needed.

## Step 5: Convert Relative Imports to @/

### Conversion rules

- Only convert imports that reference files within the `src/` directory
- Convert relative paths that go **up** from the current file (e.g., `../../models/foo`)
- Same-directory relative imports (`./sibling`) can optionally stay relative since they're equally readable
- **Never** convert imports of external packages or node_modules

### How to convert

For each file with relative imports:

1. Determine the file's path relative to `src/`
2. Resolve the relative import to an absolute path
3. If the target is under `src/`, convert to `@/` prefix

**Example**: In `src/analytics/session/metrics.ts`:

```typescript
// Before
import { Phase } from '../../models/phase';
import { Set } from '../../models/set';
import { calculateMean } from '../stats/descriptive';
import { localHelper } from './helpers';

// After
import { Phase } from '@/models/phase';
import { Set } from '@/models/set';
import { calculateMean } from '@/analytics/stats/descriptive';
import { localHelper } from './helpers';  // same-dir stays relative (optional)
```

### Systematic approach

1. Use `rg` to find all files with relative imports going up directories:

```bash
rg "from ['\"]\.\./" src/ --glob "*.ts" --glob "*.tsx" -l
```

2. For each file, resolve the relative path and replace with the `@/` equivalent.
3. Run `tsc --noEmit` after each batch of changes to verify no broken imports.

## Step 6: Verify

1. **Type-check passes**:

```bash
npx tsc --noEmit
```

2. **Build succeeds** and output has correct relative paths:

```bash
npm run build
```

3. **Spot-check compiled output** to confirm `@/` was rewritten:

```bash
# Should show relative paths like './models/phase', NOT '@/models/phase'
head -20 dist/esm/index.js
rg "@/" dist/ --glob "*.js" -l
# ^ This should return NO results if tsc-alias worked correctly
```

4. **Tests pass**:

```bash
npm test
```

## Troubleshooting

### `@/` still appears in compiled output

- Ensure `tsc-alias` runs **after** `tsc` in the build script
- Ensure `tsc-alias` uses the same `-p` tsconfig flag as `tsc`
- Run `npm run clean && npm run build` for a fresh build

### Module not found errors after conversion

- Verify `baseUrl` is `"."` and `paths` maps `"@/*"` to `"src/*"`
- Check that the import target file actually exists at the resolved path
- Run `npx tsc --noEmit` to get precise error locations

### IDE not resolving @/ imports

- Restart the TypeScript language server (in VS Code/Cursor: Cmd+Shift+P -> "TypeScript: Restart TS Server")
- Ensure the IDE is using the workspace TypeScript version, not a global one
