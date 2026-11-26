---
name: chat
description: Plan a small development task together with the owner and write an approved plan.md for do-it. Use when the user invokes /chat.
disable-model-invocation: true
---

# Chat

Turn a small task into an approved, testable plan. Never implement.

1. **Name the task.** Pick a short kebab-case slug. The task directory is `.do-it/<YYYY-MM-DD>-<slug>/` at the repository root (`git rev-parse --show-toplevel`). If a directory for this task already has a `plan.md`, resume from it.
2. **Check the ignore rule.** Run `git check-ignore -q .do-it/probe`. If `.do-it/` is not ignored, tell the owner to run `agent-stuff install-custom-skills`, which adds it to the global Git excludes file, and then continue. Never add `.do-it/` to the project's `.gitignore`.
3. **Grill.** Use the `grilling` skill on the task and codebase. Look up facts yourself; put decisions to the owner. If the task needs more than one plan, say so and propose a split.
4. **Write `plan.md`** from [templates/plan.md](templates/plan.md):
   - Acceptance criteria must be observable and testable; the reviewer checks each one.
   - Each rejected alternative gets a one-line reason.
   - Only cite references you have fetched. Prefer primary sources.
   - Leave `Approved: pending`.
5. **Get approval.** Show the plan's path and a short summary. Revise it until the owner approves explicitly, then set `Approved: <YYYY-MM-DD HH:MM> by owner`.
6. **Stop.** Tell the owner the next step is `/do-it .do-it/<YYYY-MM-DD>-<slug>`. Do not write code, create branches, or start `do-it` yourself.
