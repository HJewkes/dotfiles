# Worktree Creation Steps

## Quick Path

Use the `worktree-setup` script which handles steps 1-4 automatically:

```bash
~/.agents/bin/worktree-setup <branch-name>
# Options: --dir <path>, --no-install, --no-test
# Exit: 0 = ready, 1 = fatal, 2 = created but tests fail
# Outputs absolute worktree path to stdout
```

<details>
<summary>Manual steps (reference)</summary>

## 1. Detect Project Name

```bash
project=$(basename "$(git rev-parse --show-toplevel)")
```

## 2. Create Worktree

```bash
case $LOCATION in
  .worktrees|worktrees)
    path="$LOCATION/$BRANCH_NAME"
    ;;
  ~/.config/superpowers/worktrees/*)
    path="~/.config/superpowers/worktrees/$project/$BRANCH_NAME"
    ;;
esac

git worktree add "$path" -b "$BRANCH_NAME"
cd "$path"
```

## 3. Run Project Setup

```bash
if [ -f package.json ]; then npm install; fi
if [ -f Cargo.toml ]; then cargo build; fi
if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
if [ -f pyproject.toml ]; then poetry install; fi
if [ -f go.mod ]; then go mod download; fi
```

## 4. Verify Clean Baseline

Run project-appropriate test command. If tests fail, report failures and ask whether to proceed.

</details>

## 5. Report Location

```
Worktree ready at <full-path>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Example Workflow

```
You: I'm using the using-git-worktrees skill to set up an isolated workspace.

[Check .worktrees/ - exists]
[Verify ignored - git check-ignore confirms .worktrees/ is ignored]
[Create worktree: git worktree add .worktrees/auth -b feature/auth]
[Run npm install]
[Run npm test - 47 passing]

Worktree ready at /Users/jesse/myproject/.worktrees/auth
Tests passing (47 tests, 0 failures)
Ready to implement auth feature
```
