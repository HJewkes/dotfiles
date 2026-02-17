# PR Review Orchestrator

Provide an automated code review for a GitHub pull request.

**Tool constraints:** Only use `gh` commands: `gh issue view/search/list`, `gh pr comment/diff/view/list`.

Follow these steps precisely:

## Step 1: Eligibility Check
Use a Haiku agent to check if the pull request (a) is closed, (b) is a draft, (c) does not need a code review (eg. because it is an automated pull request, or is very simple and obviously ok), or (d) already has a code review from you from earlier. If so, do not proceed.

## Step 2: Gather CLAUDE.md Files
Use a Haiku agent to give you a list of file paths to (but not the contents of) any relevant CLAUDE.md files from the codebase: the root CLAUDE.md file (if one exists), as well as any CLAUDE.md files in the directories whose files the pull request modified.

## Step 3: Summarize Changes
Use a Haiku agent to view the pull request and return a summary of the change.

## Step 4: Parallel Review (5 Sonnet Agents)
Launch 5 parallel Sonnet agents to independently code review the change. Each returns a list of issues and the reason each was flagged (CLAUDE.md adherence, bug, historical git context, etc.):

a. **Agent #1**: Audit changes for CLAUDE.md compliance. Note that CLAUDE.md is guidance for Claude as it writes code, so not all instructions will be applicable during code review.
b. **Agent #2**: Read file changes, do a shallow scan for obvious bugs. Focus on changes only, not extra context. Focus on large bugs, avoid small issues and nitpicks. Ignore likely false positives.
c. **Agent #3**: Read git blame and history of modified code to identify bugs in light of historical context.
d. **Agent #4**: Read previous pull requests that touched these files, check for comments that may also apply to the current PR.
e. **Agent #5**: Read code comments in modified files, make sure changes comply with any guidance in comments.

## Step 5: Confidence Scoring
For each issue found, launch a parallel Haiku agent that takes the PR, issue description, and list of CLAUDE.md files (from step 2), and scores confidence 0-100:

- **0**: Not confident at all. False positive or pre-existing issue.
- **25**: Somewhat confident. Might be real, might be false positive. Stylistic issues not explicitly in CLAUDE.md.
- **50**: Moderately confident. Verified as real but might be a nitpick. Not very important relative to rest of PR.
- **75**: Highly confident. Double-checked, very likely real and hit in practice. Important, directly impacts functionality or directly mentioned in CLAUDE.md.
- **100**: Absolutely certain. Confirmed definitely real, happens frequently. Evidence directly confirms.

For CLAUDE.md issues, double check that the CLAUDE.md actually calls out that issue specifically.

## Step 6: Filter
Filter out issues with score less than 80. If no issues meet this criteria, do not proceed.

## Step 7: Re-check Eligibility
Use a Haiku agent to repeat the eligibility check from Step 1 to ensure the PR is still eligible.

## Step 8: Post Comment
Use `gh pr comment` to post the result. Keep in mind:
- Keep output brief
- Avoid emojis
- Link and cite relevant code, files, and URLs

## False Positive Examples (for Steps 4 and 5)

- Pre-existing issues
- Something that looks like a bug but is not actually a bug
- Pedantic nitpicks that a senior engineer wouldn't call out
- Issues a linter, typechecker, or compiler would catch (imports, type errors, formatting). Assume CI handles these.
- General code quality issues (test coverage, security, documentation) unless explicitly required in CLAUDE.md
- Issues called out in CLAUDE.md but explicitly silenced in code (lint ignore comments)
- Functionality changes that are likely intentional or related to the broader change
- Real issues on lines the user did not modify

## Output Format

Use this format precisely:

---

### Code review

Found N issues:

1. <brief description> (CLAUDE.md says "<...>" OR bug due to <explanation>)

<link to file and line with full sha1 + line range, eg. https://github.com/org/repo/blob/FULL_SHA/path/file.ext#L10-L15>

---

Or if no issues:

---

### Code review

No issues found. Checked for bugs and CLAUDE.md compliance.

🤖 Generated with [Claude Code](https://claude.ai/code)

---

## Link Format Requirements

Links MUST follow this exact format: `https://github.com/owner/repo/blob/[full-sha]/path/file.ext#L[start]-L[end]`
- Requires full git SHA (not abbreviated)
- Use `#L` notation for line ranges
- Provide at least 1 line of context before and after
- Do NOT use bash interpolation in links — provide the full SHA directly

## Notes

- Do not check build signal or attempt to build/typecheck. These run separately in CI.
- Use `gh` to interact with GitHub, not web fetch.
- Make a todo list first.
- Cite and link each issue (if referring to CLAUDE.md, link it).
