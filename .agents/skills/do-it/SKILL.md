---
name: do-it
description: Implement an approved chat plan, run an evidence-based review/debate loop with a reviewer sub-agent on a configurable model, and write a local learning report. Use when the user invokes /do-it.
disable-model-invocation: true
---

# Do It

You are the **implementer** and the **orchestrator**. A separate, read-only reviewer sub-agent reviews your work. All state lives in the task directory, so the loop survives context compaction and can be resumed.

Never commit, push, or open a PR. Never change `plan.md`, except through a `PLAN-DEVIATION` that the owner approves.

## 0. Preflight

1. Locate the task directory: the argument, or else the newest `.do-it/*/` at the repository root (`git rev-parse --show-toplevel`). Stop and point the owner to `/chat` if `plan.md` is missing or its `Approved:` line is `pending`.
2. Run `git status --porcelain`. If there are changes unrelated to this task, stop and ask the owner.
3. Record `BASE=$(git rev-parse HEAD)`.
4. Identify the harness from your tools: a `task` tool means `copilot`, an `Agent` tool means `claude`, and `invoke_subagent` means `antigravity`. If none is available, stop: this harness cannot run a separate reviewer.
5. Run `<this skill's directory>/scripts/resolve-reviewer-model.sh <harness>`. It prints `<model><TAB><source>`. Show any stderr warnings to the owner.
6. If `ledger.md` exists, resume: read it and continue after its last entry. Otherwise create it from [templates/ledger.md](templates/ledger.md) and fill in the header.

## 1. Implement

- Follow `plan.md`. Use the `tdd` skill at the plan's seams: for each acceptance criterion, write a failing test first.
- Follow the codebase's existing conventions, and keep the diff within the plan's scope.
- Run targeted tests and linters after each change, and the relevant full suite at the end.
- Log every non-obvious choice as a `D<n>` entry under **Decisions**: what you chose, your thinking, the rejected alternative, and a reference. Fetch a reference before citing it; if it does not load, mark it `(unverified)`.
- If the plan turns out to be wrong or infeasible, append a `PLAN-DEVIATION`, stop, and ask the owner. Resume only after the owner decides.
- Append a **Verification** table listing the commands you ran and their results.

## 2. Review loop (at most 3 rounds)

For `ROUND` = 1, 2, 3:

1. **Invoke the reviewer** as shown in the table below, using this task line: `Follow your reviewer instructions. TASK_DIR=<absolute path>. BASE=<sha>. ROUND=<n>.` Each round uses a fresh invocation; the ledger is the reviewer's memory.
2. **Record** its output verbatim in the ledger. If the output does not follow the required format, re-invoke once and ask for the format. If it fails again, or the call errors or times out twice, escalate to the owner with the partial ledger.
3. **Done?** If the verdict is `APPROVE` and no `blocker` or `major` finding is open, go to §3 Report.
4. **Respond** under `## Round <n> — implementer`, to every new finding and to every `MAINTAIN` or `ANSWER`:
   - `ACCEPT`: make the fix, then re-run the affected tests. Write `ACCEPT` only once the tests pass, and cite `file:line`.
   - `REJECT`: counter with evidence (a test result, `file:line`, or a primary-source URL). Without evidence, do not reject.
   - `CLARIFY`: ask the reviewer a question.
   - `DECLINE`: only for `minor` or `nit`, with a one-line reason. No further debate follows.
   A `REJECT` or `MAINTAIN` without evidence counts as conceded.
5. **Escalate a finding** after two full exchanges, meaning two of your `REJECT`s each answered by a `MAINTAIN`. Write an `Escalation` entry and give the owner a brief: the finding, each position in at most 3 lines, and the evidence links. Wait for the owner's ruling, record it as a `RULING`, apply it, and continue.
6. **Round cap.** If round 3 ends without `APPROVE`, escalate every open `blocker` or `major` finding in one brief, record and apply the rulings, then go to §3 Report.

### Invoking the reviewer

| Harness | How |
| --- | --- |
| `copilot` | Call the `task` tool with `agent_type: code-review`, `model: <model>`, and `mode: sync`. The prompt is the contents of [reviewer-prompt.md](reviewer-prompt.md) followed by the task line. The owner set this model through `DO_IT_REVIEWER_MODEL_*`, which counts as the owner explicitly naming the model. |
| `claude` | Call the `Agent` tool with `subagent_type: do-it-reviewer` and `model: <alias>`; the prompt is the task line. If `do-it-reviewer` does not exist, tell the owner to run `agent-stuff install-custom-skills` and stop. |
| `antigravity` | Once per session, call `define_subagent` with `Name: do-it-reviewer`, `Description: Read-only reviewer for do-it`, `SystemPrompt:` the contents of [reviewer-prompt.md](reviewer-prompt.md), and `EnableWriteTools`, `EnableMCPTools`, and `EnableSubagentTools` all `false`. Then each round, call `invoke_subagent` with `TypeName: do-it-reviewer`, `Model: <tier>`, `Workspace: inherit`, `Role: do-it reviewer`, and `Prompt:` the task line. Wait for its result message. |

## 3. Report

Write `report.md` from [templates/report.md](templates/report.md):

- **§1** maps every acceptance criterion to its status and evidence.
- **§2** comes from the Decisions entries. Explain the thinking, not just the outcome.
- **§3** has one `- [ ]` item per finding, in ID order, including declined findings. Each outcome is one of `ACCEPTED`, `CONCEDED` (the reviewer withdrew the finding), `DECLINED`, or `RULED` (decided by the owner).
- **§4** collects the deduplicated URLs from decisions, findings, and responses. Fetch each one. Keep the reachable ones, each with a one-line note on why it is relevant, and mark the rest `(unverified)`. Prefer primary sources.
- **§5** lists the final verification commands with their results. Run them again now.

End with a short message to the owner: the path to `report.md`, the finding counts, and any escalations and their rulings. Leave all changes uncommitted.
