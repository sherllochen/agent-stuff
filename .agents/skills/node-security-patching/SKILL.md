---
name: node-security-patching
description: Investigate and remediate npm Dependabot CVEs reproducibly. Use when asked to patch, review, triage, or verify Node.js dependency security alerts.
compatibility: Requires Node.js, Corepack with Yarn 4, GitHub CLI authentication and API access, and a runtime that supports read-only subagents.
---

# Node Security Patching

Use this skill for npm ecosystem security alerts reported by GitHub Dependabot. Work from the current dependency graph and do not use existing pull requests as implementation input.

## Scope Confirmation

Before discovery or subagent dispatch, inspect the request for project and severity exclusions. Do not infer missing exclusions. If either is absent, ask the user to select exclusions for that category.

- Project exclusions: offer `remix`, `connect`, `connective`, `whitelabel`, `white_label`, and `None`; accept additional manifest-path patterns case-insensitively.
- Severity exclusions: offer `Critical`, `High`, `Medium`, `Low`, and `None`.
- `None` cannot be combined with another selection. Do not continue until both categories are explicitly supplied or confirmed as `None`.

Apply exclusions only to the current run. Record them as evidence and in the final report.

## Scope And Success Criteria

- Include only open alerts where `dependency.package.ecosystem` is `npm`.
- Exclude alerts whose `dependency.manifest_path` matches a selected project exclusion and selected severities. Process remaining alerts from Critical through Low.
- Ignore non-Node ecosystems. Do not inspect, copy, or rely on existing remediation pull requests.
- Never manually edit a Yarn lockfile; regenerate it with Yarn.

Success requires every in-scope alert to have its package, CVE/GHSA, affected project, dependency chain, and patched version documented; a minimal package-manager-generated remediation; no resolved version in its vulnerable range; deterministic local verification; relevant compatibility checks; and, after push, collected GitHub CI status where available.

## Discovery

Run the bundled tools from the skill's `scripts/` directory, not from the target project. First verify that Corepack can select Yarn 4, then install their pinned dependency:

```bash
node <skill-directory>/scripts/preflight.mjs
corepack yarn --cwd <skill-directory>/scripts install --immutable
```

Use the alert inventory rather than manually reconstructing filters:

```bash
node <skill-directory>/scripts/alerts.mjs \
  --exclude-project <selected-project-pattern> \
  --exclude-severity <selected-severity>
```

Pass every selected exclusion as a separate flag. Omit flags for categories confirmed as `None`. The JSON result includes `included` and `excluded`; excluded alerts state the matching rule. Record it as evidence. Determine the repository rather than hard-coding it:

```bash
gh repo view --json nameWithOwner --jq .nameWithOwner
```

## Subagent Analysis

The primary agent owns all mutations, lockfile regeneration, installs, tests, deterministic verification, and reporting. Before remediation, group alerts by `(nearest lockfile/project root, package)`, retaining every alert number and manifest path.

For each non-trivial group, dispatch a read-only subagent with the complete prompt in [references/node-security-analyst.md](references/node-security-analyst.md). Give it the repository, project root, lockfile, package, alert numbers, manifest paths, and either `initial analysis` or `blocked-remediation triage` mode. Prioritize Critical through Low, dispatch at most five at once, and wait for a batch before dispatching another. Do not run compatibility checks concurrently with mutations in the same project root.

The report must identify its assigned scope, advisories and ranges, `yarn why -R` paths and installed versions, minimal recommendation or blocker, compatibility risks, and commands used. Triage reports must also meet every requirement in [Triaging](#triaging).

## Map The Dependency Graph

The alert manifest path determines the project root. Use its directory or nearest lockfile directory for remediation, immutable installs, `yarn why`, and assertions. Read that project's `package.json`, `.yarnrc.yml`, and lockfile before choosing a fix; identify direct dependencies, `resolutions`, patches, runtime/development scope, and scripts.

```bash
yarn why -R <package-name>
```

Prefer fixes in this order:

1. Upgrade a direct parent to a compatible release without the vulnerable dependency.
2. Run `yarn up -R <package-name>` when all requesting ranges accept the patched release.
3. Add the narrowest necessary `resolutions` entry when replacing the parent is disproportionate.
4. Upgrade or replace the parent when a resolution introduces an incompatible module format, runtime requirement, or API change.

Never cross a major-version or module-system boundary without a compatibility check. Do not add broad speculative resolutions. If the smallest safe remediation requires a major upgrade, report that exact requirement.

## Triaging

Triage only after a normal remediation is blocked by a real version conflict, incompatible API or module-system change, unavailable patched release, or failed compatibility check. Never dismiss merely because a dependency is transitive, development-only, not directly imported, or current tests pass.

Read the complete GitHub advisory and upstream references. Record the vulnerable function or behavior, attacker capability, required input, and impact. If needed inspect the upstream patch. Start with every installed path:

```bash
gh api "repos/<owner>/<repo>/dependabot/alerts/<alert-number>" --jq '{number, dependency, security_advisory, security_vulnerability}'
yarn why -R --json <package-name>
```

For every parent, inspect its installed source and manifest to learn how it invokes the vulnerable package. Search all first-party source, tests, build configuration, scripts, and relevant workspace packages for the package and import forms, vulnerable functions and aliases, each parent, and every application-controlled input reaching a callsite. Search installed `node_modules` only to understand third-party parents; never modify it.

Trace external inputs to trust boundaries, recording validation, size limits, normalization, authentication, and production access. Treat uncertainty as reachable. Recommend dismissal only when all installed paths to the vulnerable function are proven unreachable under the advisory preconditions, or a documented control makes exploitation impossible. Do not dismiss unless explicitly asked.

The triage report must cover failed options and exact conflicts; exploit preconditions; complete dependency paths and parent usage; every searched callsite and input-flow result including negatives; production reachability and residual risk; and a proposed dismissal reason.

## Make And Verify A Patch

Make the smallest manifest change, then regenerate and inspect the affected graph from its project root:

```bash
yarn up -R <package-name>
yarn install
yarn install --immutable
yarn why -R <package-name>
```

For every in-scope alert, run the bundled deterministic verifier:

```bash
corepack yarn --cwd <skill-directory>/scripts node verify-alert.mjs --alert <alert-number>
```

It obtains the authoritative alert, locates the nearest `yarn.lock`, performs an immutable install, and fails if a resolved version is vulnerable, absent, incomplete, or a required command fails. Do not replace it with an ad hoc assertion or treat an absent package as success.

`yarn npm audit --recursive --json` is an optional independent cross-check. Filter it to the alert GHSA and report it separately because its advisory feed can differ from GitHub's.

## Compatibility Verification

Run scripts declared by each changed project's `package.json` and the closest matching CI steps. Attempt applicable formatting, lint, typecheck, unit tests, and relevant build or bundle smoke tests. Run native platform tests when the dependency affects mobile runtime behavior and the environment is available; otherwise report them as not run.

Immutable installation and deterministic verification are mandatory resolution proof. Report generated-artifact, platform, or configuration blockers precisely. Call a failure pre-existing only with a recorded pre-change baseline. Do not claim resolution until every affected project passes immutable installation and deterministic verification. After push, confirm GitHub closes each alert, allowing for asynchronous Dependabot rescans.

## Final Report

For each in-scope alert report its number, CVE/GHSA, severity, URL, project and lockfile, scope, full dependency chain, vulnerable/installed/patched versions, remediation, changed manifest and lockfile, verification commands and outcomes, and CI attribution/status. Also report every excluded alert and matching exclusion rule.
