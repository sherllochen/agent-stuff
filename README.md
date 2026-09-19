# Agent Stuff

Personal, version-controlled agent instructions and skills for global use and selected repositories.

The installer keeps this repository as the source of truth and creates symbolic links where agent tools discover them. Repository links are excluded locally through `.git/info/exclude`, so they do not appear as changes or modify shared `.gitignore` files.

## Supported harnesses

One authoring layout installs into the discovery paths used by:

| Harness | Instructions | Skills |
| --- | --- | --- |
| Cursor | `AGENTS.md` | `.agents/skills/`, `.cursor/skills/` |
| Claude Code | `CLAUDE.md` (imports `@AGENTS.md`) | `.claude/skills/` |
| GitHub Copilot | `AGENTS.md` and `.github/copilot-instructions.md` | `.agents/skills/`, `.github/skills/`, `.claude/skills/` |

Global skills are also linked into `~/.agents/skills`, `~/.claude/skills`, `~/.cursor/skills`, and `~/.copilot/skills`.

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
└── install.sh
```

Each `<project>` directory maps by name to `~/dev/<project>`. For example, `johanna-platform/` maps to `~/dev/johanna-platform`.

## Install

Run the installer after cloning this repository or changing its agent files:

```bash
cd ~/dev/agent-stuff
./install.sh
```

The installer:

- Links global skills into each harness's user-level skills directory.
- Links project skills into each harness's project-level skills directory.
- Combines the root `AGENTS.md` with an optional project `AGENTS.md`.
- Generates `CLAUDE.md` that imports `@AGENTS.md`, plus optional project Claude extras.
- Generates `.github/copilot-instructions.md` that points at `AGENTS.md`, plus optional Copilot extras.
- Links the generated instruction files into each configured repository.
- Adds exact linked paths to each repository's local `.git/info/exclude`.
- Removes stale links that point into this repository.
- Leaves unrelated and third-party skills untouched.

A configured project should already exist under `~/dev`. If its corresponding repository is missing, the installer prints a skip message and continues with the remaining projects.

### Run From Anywhere

Add this repository to `PATH` in `~/.zshrc`:

```bash
export PATH="$HOME/dev/agent-stuff:$PATH"
```

Reload the shell:

```bash
source ~/.zshrc
```

You can then run:

```bash
install.sh
```

Because `install.sh` is a generic name, consider exposing it under a more specific command name if other directories on your `PATH` contain a script with the same name.

## Add Global Content

Add a global skill at:

```text
.agents/skills/<skill-name>/SKILL.md
```

Edit the root `AGENTS.md` for instructions that should apply to every configured project.

## Add Project Content

Create a directory matching the target repository name:

```text
<project>/AGENTS.md
<project>/CLAUDE.md                         # optional Claude-only extras
<project>/.github/copilot-instructions.md   # optional Copilot-only extras
<project>/.agents/skills/<skill-name>/SKILL.md
```

The project `AGENTS.md` is optional. Without it, the generated shared file contains only the global instructions. `CLAUDE.md` and Copilot extras are also optional; without them, the generated harness files only import or point at `AGENTS.md`.

Run `install.sh` after adding, renaming, or removing content.

## Replacement Behavior

For names managed by this repository, installation replaces existing destination files, directories, or links. Unrelated destination entries are preserved.

Generated combined instruction files live under `.generated/` and are not committed.

## Configuration

The defaults can be overridden for testing or a different development directory:

```bash
DEV_ROOT="$HOME/projects" ./install.sh
```

`HOME` determines the global skills destinations. `LN_COMMAND` can provide an alternative command for creating symbolic links; otherwise the installer uses `ln` and falls back to Python when needed.

## Test

Run the isolated installer test:

```bash
bash test/install_test.sh
```

The test uses temporary home and development directories and does not modify real repositories.
