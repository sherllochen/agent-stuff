#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

source_root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
dev_root=${DEV_ROOT:-"$HOME/dev"}
generated_root="$source_root/.generated"
global_skills_source="$source_root/.agents/skills"

# Shared Agent Skills path plus native discovery paths for each harness.
# Source of truth in this repo remains `.agents/skills/`.
global_skill_destinations=(
  "$HOME/.agents/skills"
  "$HOME/.claude/skills"
  "$HOME/.cursor/skills"
  "$HOME/.copilot/skills"
)

project_skill_relative_destinations=(
  '.agents/skills'
  '.claude/skills'
  '.cursor/skills'
  '.github/skills'
)

create_link() {
  local source=$1
  local destination=$2

  if [[ -n "${LN_COMMAND:-}" ]]; then
    "$LN_COMMAND" -s "$source" "$destination"
  elif command -v ln > /dev/null 2>&1; then
    ln -s "$source" "$destination"
  elif command -v python3 > /dev/null 2>&1; then
    python3 - "$source" "$destination" <<'PYTHON'
import os
import sys

os.symlink(sys.argv[1], sys.argv[2])
PYTHON
  else
    echo 'Cannot create symlinks: neither ln nor python3 is available' >&2
    return 1
  fi
}

replace_with_link() {
  local source=$1
  local destination=$2

  mkdir -p "$(dirname "$destination")"
  rm -rf "$destination"
  create_link "$source" "$destination"
  printf 'Linked %s -> %s\n' "$destination" "$source"
}

remove_stale_links() {
  local directory=$1
  local entry target

  [[ -d "$directory" ]] || return 0

  for entry in "$directory"/*; do
    [[ -L "$entry" ]] || continue
    target=$(readlink "$entry")
    if [[ "$target" == "$source_root/"* && ! -e "$target" ]]; then
      rm "$entry"
      printf 'Removed stale link %s\n' "$entry"
    fi
  done
}

link_skills() {
  local source_directory=$1
  shift
  local destination_directory skill

  [[ -d "$source_directory" ]] || return 0

  for destination_directory in "$@"; do
    mkdir -p "$destination_directory"
    for skill in "$source_directory"/*; do
      [[ -d "$skill" ]] || continue
      replace_with_link "$skill" "$destination_directory/$(basename "$skill")"
    done
  done
}

append_optional_section() {
  local destination=$1
  local source_file=$2
  local heading=$3

  if [[ -f "$source_file" ]]; then
    printf '\n<!-- %s -->\n\n' "$heading" >> "$destination"
    cat "$source_file" >> "$destination"
  fi
}

write_combined_agents() {
  local generated_agents=$1
  local project_name=$2
  local project_source=$3

  cp "$source_root/AGENTS.md" "$generated_agents"
  append_optional_section \
    "$generated_agents" \
    "$project_source/AGENTS.md" \
    "Project-specific instructions: $project_name"
}

write_claude_instructions() {
  local generated_claude=$1
  local project_name=$2
  local project_source=$3

  # Claude Code reads CLAUDE.md natively and can import AGENTS.md.
  cat > "$generated_claude" <<'EOF'
@AGENTS.md
EOF
  append_optional_section \
    "$generated_claude" \
    "$project_source/CLAUDE.md" \
    "Project-specific Claude Code instructions: $project_name"
}

write_copilot_instructions() {
  local generated_copilot=$1
  local project_name=$2
  local project_source=$3
  local project_copilot=$project_source/.github/copilot-instructions.md

  cat > "$generated_copilot" <<'EOF'
# GitHub Copilot instructions

Follow `AGENTS.md` in the repository root. That file is the shared source of truth for coding agents in this project.
EOF
  append_optional_section \
    "$generated_copilot" \
    "$project_copilot" \
    "Project-specific Copilot instructions: $project_name"
}

update_git_excludes() {
  local repository=$1
  local skills_source=$2
  local git_directory exclude_file temporary_file skill relative_destination line
  local in_managed_block=false
  local begin_marker='# BEGIN agent-stuff managed exclusions'
  local end_marker='# END agent-stuff managed exclusions'

  if [[ -d "$repository/.git" ]]; then
    git_directory="$repository/.git"
  elif git_directory=$(git -C "$repository" rev-parse --absolute-git-dir 2>/dev/null); then
    :
  else
    return 0
  fi

  exclude_file="$git_directory/info/exclude"
  mkdir -p "$(dirname "$exclude_file")"
  touch "$exclude_file"
  temporary_file=$(mktemp)

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "$begin_marker" ]]; then
      in_managed_block=true
      continue
    fi
    if [[ "$line" == "$end_marker" ]]; then
      in_managed_block=false
      continue
    fi
    if [[ "$in_managed_block" == false ]]; then
      printf '%s\n' "$line"
    fi
  done < "$exclude_file" > "$temporary_file"

  {
    cat "$temporary_file"
    printf '%s\n' "$begin_marker"
    printf '%s\n' '/AGENTS.md' '/CLAUDE.md' '/.github/copilot-instructions.md'
    if [[ -d "$skills_source" ]]; then
      for skill in "$skills_source"/*; do
        [[ -d "$skill" ]] || continue
        for relative_destination in "${project_skill_relative_destinations[@]}"; do
          printf '/%s/%s\n' "$relative_destination" "$(basename "$skill")"
        done
      done
    fi
    printf '%s\n' "$end_marker"
  } > "$exclude_file"

  rm "$temporary_file"
  printf 'Updated local Git exclusions in %s\n' "$exclude_file"
}

project_skill_destinations_for() {
  local project_destination=$1
  local relative_destination

  for relative_destination in "${project_skill_relative_destinations[@]}"; do
    printf '%s/%s\n' "$project_destination" "$relative_destination"
  done
}

project_sources=()
for candidate in "$source_root"/*; do
  [[ -d "$candidate" ]] || continue
  if [[ -d "$candidate/.agents" || -f "$candidate/AGENTS.md" || -f "$candidate/CLAUDE.md" ]]; then
    project_sources+=("$candidate")
  fi
done

[[ -f "$source_root/AGENTS.md" ]] || {
  echo "Global instructions do not exist: $source_root/AGENTS.md" >&2
  exit 1
}

mkdir -p "$generated_root"
for destination in "${global_skill_destinations[@]}"; do
  mkdir -p "$destination"
  remove_stale_links "$destination"
done
link_skills "$global_skills_source" "${global_skill_destinations[@]}"

for repository in "$dev_root"/*; do
  [[ -d "$repository" ]] || continue

  while IFS= read -r destination; do
    remove_stale_links "$destination"
  done < <(project_skill_destinations_for "$repository")

  for instruction_file in \
    "$repository/AGENTS.md" \
    "$repository/CLAUDE.md" \
    "$repository/.github/copilot-instructions.md"; do
    if [[ -L "$instruction_file" ]]; then
      instruction_target=$(readlink "$instruction_file")
      if [[ "$instruction_target" == "$generated_root/"* && ! -e "$instruction_target" ]]; then
        rm "$instruction_file"
        printf 'Removed stale link %s\n' "$instruction_file"
      fi
    fi
  done
done

for project_source in "${project_sources[@]}"; do
  project_name=$(basename "$project_source")
  project_destination="$dev_root/$project_name"
  if [[ ! -d "$project_destination" ]]; then
    echo "Skipping $project_name: repository directory does not exist: $project_destination" >&2
    continue
  fi

  project_skills_source="$project_source/.agents/skills"
  generated_directory="$generated_root/$project_name"
  generated_agents="$generated_directory/AGENTS.md"
  generated_claude="$generated_directory/CLAUDE.md"
  generated_copilot="$generated_directory/copilot-instructions.md"

  mapfile -t project_skill_destinations < <(project_skill_destinations_for "$project_destination")
  link_skills "$project_skills_source" "${project_skill_destinations[@]}"
  update_git_excludes "$project_destination" "$project_skills_source"

  mkdir -p "$generated_directory"
  write_combined_agents "$generated_agents" "$project_name" "$project_source"
  write_claude_instructions "$generated_claude" "$project_name" "$project_source"
  write_copilot_instructions "$generated_copilot" "$project_name" "$project_source"

  replace_with_link "$generated_agents" "$project_destination/AGENTS.md"
  replace_with_link "$generated_claude" "$project_destination/CLAUDE.md"
  replace_with_link \
    "$generated_copilot" \
    "$project_destination/.github/copilot-instructions.md"
done

echo 'Agent files installed successfully'
