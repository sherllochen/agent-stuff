# Agent Stuff

Personal, version-controlled agent instructions and skills for global use and selected repositories.

The repository acts as the single source of truth and creates symbolic links where agent harnesses discover them. Repository links are excluded locally through `.git/info/exclude`, so they do not appear as changes or modify shared `.gitignore` files.

## Supported Harnesses

One authoring layout installs into the discovery paths used by:

| Harness | Instructions | Skills |
| --- | --- | --- |
| Cursor | `AGENTS.md` | `.agents/skills/`, `.cursor/skills/` |
| Claude Code | `CLAUDE.md` (imports `@AGENTS.md`) | `.claude/skills/` |
| GitHub Copilot | `AGENTS.md` and `.github/copilot-instructions.md` | `.agents/skills/`, `.github/skills/`, `.claude/skills/` |
| Antigravity | `AGENTS.md` | `.agents/skills/`, `~/.gemini/config/skills/` |

Global skills are also linked into `~/.agents/skills`, `~/.claude/skills`, `~/.cursor/skills`, `~/.copilot/skills`, and `~/.gemini/config/skills`.

`AGENTS.md` remains the shared source of truth. Harness-specific files either import it or point at it, and may append optional extras.

## Layout

```text
agent-stuff/
├── AGENTS.md                         # Global instructions (shared source of truth)
├── .agents/skills/<skill>/           # Global skills
├── <project>/
│   ├── AGENTS.md                     # Optional project instructions
│   ├── CLAUDE.md                     # Optional Claude Code extras
│   ├── .github/copilot-instructions.md  # Optional Copilot extras
│   └── .agents/skills/<skill>/       # Project skills
├── agent-stuff                       # Unified CLI wrapper
├── do-it.config                      # Reviewer model settings for do-it (linked to ~/.config/do-it/config)
├── install-custom-skills.sh          # Links skills & configures dev projects (symlink: install.sh)
└── global-sync.sh                    # Discovers & syncs global skills (symlink: adopt.sh)
```

Each `<project>` directory maps by name to `~/dev/<project>`. For example, `johanna-platform/` maps to `~/dev/johanna-platform`.

---

## Quick Start (Unified CLI: `agent-stuff`)

The `agent-stuff` script is a unified CLI wrapper for all operations:

```bash
# Configure dev projects (~/dev/*) and link custom skills
./agent-stuff install-custom-skills

# Interactively review and sync unmanaged skills across harnesses
./agent-stuff global-sync

# List status of all skills across all harnesses
./agent-stuff list
```

*(You can also invoke `./install-custom-skills.sh` or `./global-sync.sh` directly, or use their backward-compatible aliases `./install.sh` and `./adopt.sh`.)*

---

## Make `agent-stuff` Executable Globally

You can run `agent-stuff` from any directory in your terminal using any of the following methods:

### Method 1: Symlink into `~/.local/bin` (Recommended, no sudo needed)

1. Create a symlink in `~/.local/bin`:
   ```bash
   mkdir -p ~/.local/bin
   ln -sf "$HOME/dev/agent-stuff/main/agent-stuff" ~/.local/bin/agent-stuff
   ```

2. Ensure `~/.local/bin` is on your `$PATH` (if not already):
   ```bash
   echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   ```

### Method 2: Symlink into `/usr/local/bin` (System-wide)

```bash
sudo ln -sf "$HOME/dev/agent-stuff/main/agent-stuff" /usr/local/bin/agent-stuff
```

### Method 3: Add repo directory directly to `$PATH`

```bash
echo 'export PATH="$HOME/dev/agent-stuff/main:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Once configured, verify from any directory:
```bash
agent-stuff --help
```

---

## Commands

### 1. `install-custom-skills` (Setup & Project Sync)

Run this whenever you clone this repository, add new skills directly into `.agents/skills/`, or modify project instruction files:

```bash
agent-stuff install-custom-skills
# or: ./install-custom-skills.sh
```

What it does:
- Links global skills into each harness's user-level skills directory (`~/.agents`, `~/.claude`, `~/.cursor`, `~/.copilot`, `~/.gemini/config`).
- Links project skills into each harness's project-level skills directory.
- Combines the root `AGENTS.md` with an optional project `AGENTS.md`.
- Generates `CLAUDE.md` that imports `@AGENTS.md`, plus optional project Claude extras.
- Generates `.github/copilot-instructions.md` that points at `AGENTS.md`, plus optional Copilot extras.
- Links the generated instruction files into each configured repository under `~/dev/*`.
- Adds exact linked paths to each repository's local `.git/info/exclude`.
- Removes stale links that point into this repository.
- Leaves unrelated and third-party skills untouched.
- Generates the read-only `do-it-reviewer` Claude Code agent from `.agents/skills/do-it/reviewer-prompt.md` and links it to `~/.claude/agents/` (an existing unmanaged file with that name is left alone).
- Adds `.do-it/` to your global Git excludes file (`core.excludesFile`, or `~/.config/git/ignore` when unset), so task notes never show up in any repository.
- Links `do-it.config` to `~/.config/do-it/config`, so reviewer model settings kept in this repo apply in every repository (an existing unmanaged file there is left alone).

### 2. `global-sync` (Skill Discovery & Adoption)

If you install or author skills directly inside an agent harness (e.g. `~/.gemini/config/skills/`, `~/.claude/skills/`, etc.), `global-sync` discovers them and lets you adopt or delete them:

```bash
# Review discovered skills interactively (with description & adopt/delete/skip prompt)
agent-stuff global-sync

# List all discovered skills and their management status
agent-stuff list
# or: agent-stuff global-sync --list

# Adopt all unmanaged skills non-interactively
agent-stuff global-sync --all

# Delete a skill from all harness folders
agent-stuff global-sync --delete <skill-name>
```

When adopted, skills are moved into `.agents/skills/`, checked for valid YAML frontmatter, and automatically symlinked out to all supported harnesses.

### 3. `chat` and `do-it` (Plan, Implement, Review, Learn)

Two user-invoked skills for small daily tasks:

1. `/chat <task>`: grills you about the task and writes `.do-it/<date>-<slug>/plan.md`. It stops once you approve.
2. `/do-it .do-it/<date>-<slug>`: implements the plan test-first, then runs a review loop with a read-only reviewer sub-agent:
   - Each finding is accepted, rejected with evidence, or (for minor ones) declined.
   - A finding still disputed after two exchanges is escalated to you, and the loop stops after at most three rounds.
   - When the loop ends, it writes `report.md`, which records the decisions, a tick-off checklist of every debate, and verified further-reading links.

Nothing is committed. Everything stays in the Git-ignored `.do-it/` folder.

Reviewer model, configured per harness. Set it in [`do-it.config`](do-it.config) in this repo; `install-custom-skills` links that file to `~/.config/do-it/config`, so one edit applies to every repository and every harness. An exported environment variable with the same name overrides the file for that shell.

| Harness | Key | Values | Default |
| --- | --- | --- | --- |
| Copilot | `DO_IT_REVIEWER_MODEL_COPILOT` | any model ID | `gpt-5.3-codex` |
| Claude Code | `DO_IT_REVIEWER_MODEL_CLAUDE` | `opus`, `sonnet`, `haiku`, `fable` | `opus` |
| Antigravity | `DO_IT_REVIEWER_MODEL_ANTIGRAVITY` | `inherit`, `flash`, `pro` | `pro` |

`DO_IT_REVIEWER_MODEL` is a generic fallback, used only when its value is valid for the current harness. Only Copilot can review with a different vendor's model.

---

## Content Authoring

### Add Global Skills
Add a global skill directory:
```text
.agents/skills/<skill-name>/SKILL.md
```

### Add Project Instructions & Skills
Create a directory matching the target repository name in `~/dev/`:
```text
<project>/AGENTS.md
<project>/CLAUDE.md                         # optional Claude-only extras
<project>/.github/copilot-instructions.md   # optional Copilot-only extras
<project>/.agents/skills/<skill-name>/SKILL.md
```

Then run `agent-stuff install-custom-skills` to apply changes.

---

## Testing

Run the isolated test suites (tested with `/bin/bash` 3.2+ on macOS):

```bash
bash test/install_test.sh
bash test/adopt_test.sh
bash test/cli_test.sh
bash test/resolve_reviewer_model_test.sh
```
