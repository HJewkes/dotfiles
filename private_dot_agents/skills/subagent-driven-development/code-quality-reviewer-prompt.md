# Code Quality Reviewer Prompt Template

Use this template when dispatching a code quality reviewer subagent.

**Purpose:** Verify implementation is well-built (clean, tested, maintainable)

**Only dispatch after spec compliance review passes.**

```
Task tool (superpowers:code-reviewer):
  Use template at code-review/references/deep-reviewer.md

  WHAT_WAS_IMPLEMENTED: [from implementer's report]
  PLAN_OR_REQUIREMENTS: Task N from [plan-file]
  BASE_SHA: [commit before task]
  HEAD_SHA: [current commit]
  DESCRIPTION: [task summary]
```

**Code reviewer returns:** Strengths, Issues (Critical/Important/Minor), Assessment

Keep report under 1000 tokens. Lead with verdict (APPROVED/NEEDS_CHANGES). Skip strengths unless exceptional — focus on actionable issues.

**Common agent mistakes to watch for:**
- Non-import statements placed between import statements (causes `import/first` lint errors)
- Removing npm packages that are peer dependencies of other active packages (verify with `node -e "console.log(require('<pkg>/package.json').peerDependencies)"` before approving removals)
