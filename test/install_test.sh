#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT

source_root="$sandbox/agent-stuff"
home_root="$sandbox/home"
dev_root="$sandbox/dev"
ln_command="$sandbox/ln-command"

cat > "$ln_command" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $1 == '-s' ]]
python3 - "$2" "$3" <<'PYTHON'
import os
import sys

os.symlink(sys.argv[1], sys.argv[2])
PYTHON
EOF
chmod +x "$ln_command"

make_link() {
  python3 - "$1" "$2" <<'PYTHON'
import os
import sys

os.symlink(sys.argv[1], sys.argv[2])
PYTHON
}

mkdir -p \
  "$source_root/.agents/skills/global-skill" \
  "$source_root/project-a/.agents/skills/project-skill" \
  "$source_root/project-a/.github" \
  "$source_root/project-b/.agents/skills" \
  "$home_root/.agents/skills/global-skill" \
  "$home_root/.agents/skills/third-party-skill" \
  "$home_root/.claude/skills" \
  "$home_root/.cursor/skills" \
  "$home_root/.copilot/skills" \
  "$dev_root/project-a/.agents/skills/project-skill" \
  "$dev_root/project-a/.claude/skills" \
  "$dev_root/project-a/.git/info" \
  "$dev_root/project-b/.git/info" \
  "$dev_root/project-b" \
  "$dev_root/unmanaged-project"

cp "$repo_root/install.sh" "$source_root/install.sh"
printf '# Global instructions\n' > "$source_root/AGENTS.md"
printf '# Project A instructions\n' > "$source_root/project-a/AGENTS.md"
printf '# Project A Claude extras\n' > "$source_root/project-a/CLAUDE.md"
printf '# Project A Copilot extras\n' > "$source_root/project-a/.github/copilot-instructions.md"
printf '%s\n' 'global skill' > "$source_root/.agents/skills/global-skill/SKILL.md"
printf '%s\n' 'project skill' > "$source_root/project-a/.agents/skills/project-skill/SKILL.md"
printf '%s\n' 'keep me' > "$home_root/.agents/skills/third-party-skill/SKILL.md"
printf '%s\n' 'replace me' > "$dev_root/project-a/AGENTS.md"
printf '%s\n' '# keep this exclusion' > "$dev_root/project-a/.git/info/exclude"
touch "$dev_root/project-b/.git/info/exclude"

make_link "$source_root/.agents/skills/removed-skill" "$home_root/.agents/skills/stale-skill"
make_link "$source_root/.agents/skills/removed-skill" "$home_root/.claude/skills/stale-skill"
make_link "$source_root/project-a/.agents/skills/removed-skill" \
  "$dev_root/project-a/.agents/skills/stale-skill"
make_link "$source_root/project-a/.agents/skills/removed-skill" \
  "$dev_root/project-a/.claude/skills/stale-skill"
make_link "$sandbox/unrelated-missing-skill" "$home_root/.agents/skills/unrelated-link"

HOME="$home_root" DEV_ROOT="$dev_root" "$source_root/install.sh"

for global_destination in \
  "$home_root/.agents/skills/global-skill" \
  "$home_root/.claude/skills/global-skill" \
  "$home_root/.cursor/skills/global-skill" \
  "$home_root/.copilot/skills/global-skill"; do
  test "$(readlink "$global_destination")" = \
    "$source_root/.agents/skills/global-skill"
done

for project_destination in \
  "$dev_root/project-a/.agents/skills/project-skill" \
  "$dev_root/project-a/.claude/skills/project-skill" \
  "$dev_root/project-a/.cursor/skills/project-skill" \
  "$dev_root/project-a/.github/skills/project-skill"; do
  test "$(readlink "$project_destination")" = \
    "$source_root/project-a/.agents/skills/project-skill"
done

test -f "$home_root/.agents/skills/third-party-skill/SKILL.md"
test -L "$home_root/.agents/skills/unrelated-link"
test ! -e "$home_root/.agents/skills/stale-skill"
test ! -L "$home_root/.agents/skills/stale-skill"
test ! -e "$home_root/.claude/skills/stale-skill"
test ! -e "$dev_root/project-a/.agents/skills/stale-skill"
test ! -L "$dev_root/project-a/.agents/skills/stale-skill"
test ! -e "$dev_root/project-a/.claude/skills/stale-skill"

test "$(readlink "$dev_root/project-a/AGENTS.md")" = \
  "$source_root/.generated/project-a/AGENTS.md"
test "$(readlink "$dev_root/project-a/CLAUDE.md")" = \
  "$source_root/.generated/project-a/CLAUDE.md"
test "$(readlink "$dev_root/project-a/.github/copilot-instructions.md")" = \
  "$source_root/.generated/project-a/copilot-instructions.md"
test "$(readlink "$dev_root/project-b/AGENTS.md")" = \
  "$source_root/.generated/project-b/AGENTS.md"
test "$(readlink "$dev_root/project-b/CLAUDE.md")" = \
  "$source_root/.generated/project-b/CLAUDE.md"
test "$(readlink "$dev_root/project-b/.github/copilot-instructions.md")" = \
  "$source_root/.generated/project-b/copilot-instructions.md"

cat > "$sandbox/expected-project-a.md" <<'EOF'
# Global instructions

<!-- Project-specific instructions: project-a -->

# Project A instructions
EOF
cmp "$sandbox/expected-project-a.md" "$source_root/.generated/project-a/AGENTS.md"
cmp "$source_root/AGENTS.md" "$source_root/.generated/project-b/AGENTS.md"

cat > "$sandbox/expected-project-a-claude.md" <<'EOF'
@AGENTS.md

<!-- Project-specific Claude Code instructions: project-a -->

# Project A Claude extras
EOF
cmp "$sandbox/expected-project-a-claude.md" "$source_root/.generated/project-a/CLAUDE.md"

cat > "$sandbox/expected-project-b-claude.md" <<'EOF'
@AGENTS.md
EOF
cmp "$sandbox/expected-project-b-claude.md" "$source_root/.generated/project-b/CLAUDE.md"

cat > "$sandbox/expected-project-a-copilot.md" <<'EOF'
# GitHub Copilot instructions

Follow `AGENTS.md` in the repository root. That file is the shared source of truth for coding agents in this project.

<!-- Project-specific Copilot instructions: project-a -->

# Project A Copilot extras
EOF
cmp "$sandbox/expected-project-a-copilot.md" \
  "$source_root/.generated/project-a/copilot-instructions.md"

grep -Fx '# keep this exclusion' "$dev_root/project-a/.git/info/exclude"
grep -Fx '/AGENTS.md' "$dev_root/project-a/.git/info/exclude"
grep -Fx '/CLAUDE.md' "$dev_root/project-a/.git/info/exclude"
grep -Fx '/.github/copilot-instructions.md' "$dev_root/project-a/.git/info/exclude"
grep -Fx '/.agents/skills/project-skill' "$dev_root/project-a/.git/info/exclude"
grep -Fx '/.claude/skills/project-skill' "$dev_root/project-a/.git/info/exclude"
grep -Fx '/.cursor/skills/project-skill' "$dev_root/project-a/.git/info/exclude"
grep -Fx '/.github/skills/project-skill' "$dev_root/project-a/.git/info/exclude"
grep -Fx '/AGENTS.md' "$dev_root/project-b/.git/info/exclude"
grep -Fx '/CLAUDE.md' "$dev_root/project-b/.git/info/exclude"

HOME="$home_root" DEV_ROOT="$dev_root" LN_COMMAND="$ln_command" \
  "$source_root/install.sh" > /dev/null
test "$(grep -Fc '# BEGIN agent-stuff managed exclusions' \
  "$dev_root/project-a/.git/info/exclude")" -eq 1

mkdir -p "$source_root/missing-project/.agents/skills"
HOME="$home_root" DEV_ROOT="$dev_root" LN_COMMAND="$ln_command" \
  "$source_root/install.sh" \
  > "$sandbox/missing.out" 2>&1
grep -F "Skipping missing-project: repository directory does not exist: $dev_root/missing-project" \
  "$sandbox/missing.out"
test "$(readlink "$dev_root/project-a/AGENTS.md")" = \
  "$source_root/.generated/project-a/AGENTS.md"
test "$(readlink "$dev_root/project-b/AGENTS.md")" = \
  "$source_root/.generated/project-b/AGENTS.md"
test ! -e "$dev_root/missing-project"

echo 'Installer tests passed'
