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
  "$source_root/project-b/.agents/skills" \
  "$home_root/.agents/skills/global-skill" \
  "$home_root/.agents/skills/third-party-skill" \
  "$dev_root/project-a/.agents/skills/project-skill" \
  "$dev_root/project-a/.git/info" \
  "$dev_root/project-b/.git/info" \
  "$dev_root/project-b" \
  "$dev_root/unmanaged-project"

cp "$repo_root/install.sh" "$source_root/install.sh"
printf '# Global instructions\n' > "$source_root/AGENTS.md"
printf '# Project A instructions\n' > "$source_root/project-a/AGENTS.md"
printf '%s\n' 'global skill' > "$source_root/.agents/skills/global-skill/SKILL.md"
printf '%s\n' 'project skill' > "$source_root/project-a/.agents/skills/project-skill/SKILL.md"
printf '%s\n' 'keep me' > "$home_root/.agents/skills/third-party-skill/SKILL.md"
printf '%s\n' 'replace me' > "$dev_root/project-a/AGENTS.md"
printf '%s\n' '# keep this exclusion' > "$dev_root/project-a/.git/info/exclude"
touch "$dev_root/project-b/.git/info/exclude"

make_link "$source_root/.agents/skills/removed-skill" "$home_root/.agents/skills/stale-skill"
make_link "$source_root/project-a/.agents/skills/removed-skill" \
  "$dev_root/project-a/.agents/skills/stale-skill"
make_link "$sandbox/unrelated-missing-skill" "$home_root/.agents/skills/unrelated-link"

HOME="$home_root" DEV_ROOT="$dev_root" "$source_root/install.sh"

test "$(readlink "$home_root/.agents/skills/global-skill")" = \
  "$source_root/.agents/skills/global-skill"
test "$(readlink "$dev_root/project-a/.agents/skills/project-skill")" = \
  "$source_root/project-a/.agents/skills/project-skill"
test -f "$home_root/.agents/skills/third-party-skill/SKILL.md"
test -L "$home_root/.agents/skills/unrelated-link"
test ! -e "$home_root/.agents/skills/stale-skill"
test ! -L "$home_root/.agents/skills/stale-skill"
test ! -e "$dev_root/project-a/.agents/skills/stale-skill"
test ! -L "$dev_root/project-a/.agents/skills/stale-skill"

test "$(readlink "$dev_root/project-a/AGENTS.md")" = \
  "$source_root/.generated/project-a/AGENTS.md"
test "$(readlink "$dev_root/project-b/AGENTS.md")" = \
  "$source_root/.generated/project-b/AGENTS.md"

cat > "$sandbox/expected-project-a.md" <<'EOF'
# Global instructions

<!-- Project-specific instructions: project-a -->

# Project A instructions
EOF
cmp "$sandbox/expected-project-a.md" "$source_root/.generated/project-a/AGENTS.md"
cmp "$source_root/AGENTS.md" "$source_root/.generated/project-b/AGENTS.md"

grep -Fx '# keep this exclusion' "$dev_root/project-a/.git/info/exclude"
grep -Fx '/AGENTS.md' "$dev_root/project-a/.git/info/exclude"
grep -Fx '/.agents/skills/project-skill' "$dev_root/project-a/.git/info/exclude"
grep -Fx '/AGENTS.md' "$dev_root/project-b/.git/info/exclude"

HOME="$home_root" DEV_ROOT="$dev_root" LN_COMMAND="$ln_command" \
  "$source_root/install.sh" > /dev/null
test "$(grep -Fc '# BEGIN agent-stuff managed exclusions' \
  "$dev_root/project-a/.git/info/exclude")" -eq 1

mkdir -p "$source_root/missing-project/.agents/skills"
if HOME="$home_root" DEV_ROOT="$dev_root" LN_COMMAND="$ln_command" \
  "$source_root/install.sh" \
  > "$sandbox/missing.out" 2>&1; then
  echo 'Expected missing repository validation to fail' >&2
  exit 1
fi
grep -F "Repository directory does not exist: $dev_root/missing-project" \
  "$sandbox/missing.out"

echo 'Installer tests passed'