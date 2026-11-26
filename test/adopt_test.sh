#!/usr/bin/env bash

set -euo pipefail

# The installer edits the global Git excludes file; keep it inside the sandbox HOME.
unset XDG_CONFIG_HOME GIT_CONFIG_GLOBAL
export GIT_CONFIG_NOSYSTEM=1

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT

source_root="$sandbox/agent-stuff"
home_root="$sandbox/home"
dev_root="$sandbox/dev"

mkdir -p \
  "$source_root/.agents/skills" \
  "$home_root/.agents/skills" \
  "$home_root/.claude/skills" \
  "$home_root/.cursor/skills" \
  "$home_root/.copilot/skills" \
  "$home_root/.gemini/config/skills/unmanaged-skill-a" \
  "$home_root/.claude/skills/unmanaged-skill-b" \
  "$home_root/.cursor/skills/no-frontmatter-skill" \
  "$home_root/.copilot/skills/trash-skill" \
  "$home_root/.gemini/config/skills/trash-skill"

cp "$repo_root/install.sh" "$source_root/install.sh"
cp "$repo_root/adopt.sh" "$source_root/adopt.sh"
chmod +x "$source_root/install.sh" "$source_root/adopt.sh"

printf '# Global instructions\n' > "$source_root/AGENTS.md"

cat > "$home_root/.gemini/config/skills/unmanaged-skill-a/SKILL.md" <<'EOF'
---
name: unmanaged-skill-a
description: Skill A description
---

# Skill A
EOF

cat > "$home_root/.claude/skills/unmanaged-skill-b/SKILL.md" <<'EOF'
---
name: unmanaged-skill-b
description: >-
  Skill B multiline
  description for test
---

# Skill B
EOF

cat > "$home_root/.cursor/skills/no-frontmatter-skill/SKILL.md" <<'EOF'
# Plain Skill

Instructions without frontmatter.
EOF

cat > "$home_root/.copilot/skills/trash-skill/SKILL.md" <<'EOF'
---
name: trash-skill
description: Skill to be deleted
---

# Trash Skill
EOF

# 1. Test --list
list_output=$(HOME="$home_root" DEV_ROOT="$dev_root" "$source_root/adopt.sh" --list)
echo "$list_output" | grep -F "unmanaged-skill-a"
echo "$list_output" | grep -F "unmanaged-skill-b"
echo "$list_output" | grep -F "no-frontmatter-skill"
echo "$list_output" | grep -F "trash-skill"

# 2. Test --dry-run
dry_output=$(HOME="$home_root" DEV_ROOT="$dev_root" "$source_root/adopt.sh" --dry-run)
echo "$dry_output" | grep -F "Dry run: would adopt"
echo "$dry_output" | grep -F "unmanaged-skill-a"
test ! -d "$source_root/.agents/skills/unmanaged-skill-a"

# 3. Test interactive prompt displaying description and deleting a skill (trash-skill)
# We test piped interactive input for trash-skill: send 'd' then 'y'
delete_output=$(printf 'd\ny\n' | HOME="$home_root" DEV_ROOT="$dev_root" "$source_root/adopt.sh" trash-skill)
echo "$delete_output" | grep -F "Description: Skill to be deleted"
echo "$delete_output" | grep -F "Action: [y] adopt, [n] skip, [d] delete from all folders, [a] all, [q] quit:"
# Verify trash-skill is deleted from BOTH copilot and gemini
test ! -e "$home_root/.copilot/skills/trash-skill"
test ! -e "$home_root/.gemini/config/skills/trash-skill"

# 4. Test adopting a specific skill
HOME="$home_root" DEV_ROOT="$dev_root" "$source_root/adopt.sh" --all unmanaged-skill-a
test -d "$source_root/.agents/skills/unmanaged-skill-a"
test ! -d "$source_root/.agents/skills/unmanaged-skill-b"

# Verify unmanaged-skill-a is now symlinked across all destinations
test -L "$home_root/.gemini/config/skills/unmanaged-skill-a"
test -L "$home_root/.claude/skills/unmanaged-skill-a"
test -L "$home_root/.cursor/skills/unmanaged-skill-a"
test -L "$home_root/.copilot/skills/unmanaged-skill-a"
test -L "$home_root/.agents/skills/unmanaged-skill-a"
test "$(readlink "$home_root/.gemini/config/skills/unmanaged-skill-a")" = \
  "$source_root/.agents/skills/unmanaged-skill-a"

# 5. Test adopting all remaining unmanaged skills (including fixing frontmatter)
HOME="$home_root" DEV_ROOT="$dev_root" "$source_root/adopt.sh" --all
test -d "$source_root/.agents/skills/unmanaged-skill-b"
test -d "$source_root/.agents/skills/no-frontmatter-skill"

# Check that frontmatter was added to no-frontmatter-skill
head -n 1 "$source_root/.agents/skills/no-frontmatter-skill/SKILL.md" | grep -Fx -- "---"

# Verify all harnesses now have symlinks
test -L "$home_root/.cursor/skills/no-frontmatter-skill"
test -L "$home_root/.claude/skills/unmanaged-skill-b"
test -L "$home_root/.gemini/config/skills/unmanaged-skill-b"

# 6. Test CLI --delete option on an already adopted/managed skill
HOME="$home_root" DEV_ROOT="$dev_root" "$source_root/adopt.sh" --delete unmanaged-skill-b
test ! -e "$source_root/.agents/skills/unmanaged-skill-b"
test ! -e "$home_root/.claude/skills/unmanaged-skill-b"
test ! -e "$home_root/.gemini/config/skills/unmanaged-skill-b"

# 7. Test running adopt when no unmanaged skills remain
final_output=$(HOME="$home_root" DEV_ROOT="$dev_root" "$source_root/adopt.sh" --all)
echo "$final_output" | grep -F "No unmanaged skills found to adopt."

echo "All adopt tests passed!"
