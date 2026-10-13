---
name: commit
description: Write a conventional-commit message for staged changes and commit them. Use when asked to commit, write a commit message, or wrap up a change.
---

# Commit

1. Run `git status -sb` and `git diff --staged`. If nothing is staged, show what's
   unstaged and ask what to include; don't `git add -A` by default.
2. Write the message:
   - Subject: `<type>(<optional scope>): <summary>`, imperative, ≤ 72 chars, no period.
     Types: feat, fix, refactor, perf, test, docs, build, ci, chore.
   - Body (only if the why isn't obvious): wrap at 72, explain *why*, not *what*.
   - Breaking change: add `!` after the type and a `BREAKING CHANGE:` footer.
3. If the staged diff mixes unrelated changes, suggest splitting it instead.
4. Commit with `git commit -m "<subject>" [-m "<body>"]`. Never push.
