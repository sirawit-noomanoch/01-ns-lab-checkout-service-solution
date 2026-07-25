---
name: review-pr
description: Review a GitHub pull request using the team's review checklist.
allowed-tools: Read, Grep, Glob, Bash(gh pr diff:*)
argument-hint: <pr-number>
---

1. Read the team's checklist from @docs/review-checklist.md.
2. Run !`gh pr diff $1` to retrieve the diff for PR $1.
3. Review the changes against the checklist.
4. Report:
   - Summary
   - Issues found
   - Suggestions
   - Checklist results