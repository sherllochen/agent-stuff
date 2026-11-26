# Ledger: <task title>

- Task dir: `.do-it/<YYYY-MM-DD>-<slug>/`
- Plan: `plan.md` (approved <timestamp>)
- Base: `<commit sha>`
- Implementer: <harness>/<model>
- Reviewer: <harness>/<model> (from <source>)
- Started: <timestamp>

<!--
Append-only: never edit or delete an earlier entry.
Only the orchestrator writes this file; reviewer output is pasted verbatim.
Entry formats follow.
-->

## Decisions

### D<n> — <title>
- Decision: <what was chosen>
- Thinking: <how you got there>
- Rejected alternative: <option> — <why not>
- Reference: <URL | (unverified) URL | none>

## Round <n> — reviewer
<verbatim reviewer output>

## Round <n> — implementer

#### F<id> — <ACCEPT | REJECT | CLARIFY | DECLINE>
<reasoning>
Evidence / change: <file:line | command → result | URL>

## Escalation — F<id>
- Reviewer position: <at most 3 lines>
- Implementer position: <at most 3 lines>
- Evidence: <links>

### RULING (owner, <timestamp>)
<owner's decision, quoted>

## PLAN-DEVIATION — <title>
- Plan says: <quote>
- Problem: <why it cannot be followed>
- Proposal: <change>
- Owner decision: <quote>

## Verification
| Command | Result |
| --- | --- |
