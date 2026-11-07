#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
sandbox=$(mktemp -d)

trap 'rm -rf "$sandbox"' EXIT

source_root="$sandbox/agent-stuff"
home_root="$sandbox/home"
dev_root="$sandbox/dev"
bin_dir="$sandbox/bin"

mkdir -p "$source_root" "$home_root" "$dev_root" "$bin_dir"

cp -R "$repo_root/." "$source_root"
chmod +x "$source_root/agent-stuff" "$source_root/install-custom-skills.sh" "$source_root/global-sync.sh"

# Test symlinked binary resolution (e.g. symlink in /usr/local/bin or ~/.local/bin)
ln -s "$source_root/agent-stuff" "$bin_dir/agent-stuff"

# 1. Test --help
"$bin_dir/agent-stuff" --help > "$sandbox/help.out"
grep -F "agent-stuff: Unified CLI" "$sandbox/help.out"
grep -F "install-custom-skills" "$sandbox/help.out"
grep -F "global-sync" "$sandbox/help.out"

# 2. Test unknown command error
set +e
"$bin_dir/agent-stuff" invalid-cmd > "$sandbox/invalid.out" 2>&1
status=$?
set -e
test "$status" -ne 0
grep -F "unknown command 'invalid-cmd'" "$sandbox/invalid.out"

# 3. Test list subcommand
HOME="$home_root" DEV_ROOT="$dev_root" "$bin_dir/agent-stuff" list > "$sandbox/list.out"

# 4. Test install alias
HOME="$home_root" DEV_ROOT="$dev_root" "$bin_dir/agent-stuff" install > "$sandbox/install.out"
grep -F "Agent files installed successfully" "$sandbox/install.out"

echo "CLI tests passed!"
