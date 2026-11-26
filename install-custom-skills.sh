#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

resolve_source_root() {
  local target="${BASH_SOURCE[0]}"
  while [[ -L "$target" ]]; do
    local dir
    dir=$(cd "$(dirname "$target")" && pwd)
    target=$(readlink "$target")
    [[ "$target" != /* ]] && target="$dir/$target"
  done
  cd "$(dirname "$target")" && pwd
}

source_root=$(resolve_source_root)
dev_root=${DEV_ROOT:-"$HOME/dev"}
generated_root="$source_root/.generated"
global_skills_source="$source_root/.agents/skills"
reviewer_prompt_source="$global_skills_source/do-it/reviewer-prompt.md"
do_it_config_source="$source_root/do-it.config"

# Shared Agent Skills path plus native discovery paths for each harness.
# Source of truth in this repo remains `.agents/skills/`.
global_skill_destinations=(
  "$HOME/.agents/skills"
  "$HOME/.claude/skills"
  "$HOME/.cursor/skills"
  "$HOME/.copilot/skills"
  "$HOME/.gemini/config/skills"
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

# Git reads core.excludesFile for every repository; unset means the XDG default.
global_git_excludes_file() {
  local configured
  configured=$(git config --global --type=path --get core.excludesFile 2>/dev/null || true)
  if [[ -n "$configured" ]]; then
    printf '%s\n' "$configured"
  else
    printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/git/ignore"
  fi
}

ensure_global_git_exclude() {
  local pattern=$1 excludes_file

  command -v git > /dev/null 2>&1 || return 0
  excludes_file=$(global_git_excludes_file)
  mkdir -p "$(dirname "$excludes_file")"
  touch "$excludes_file"
  grep -Fxq -- "$pattern" "$excludes_file" && return 0

  if [[ -s "$excludes_file" && -n "$(tail -c 1 "$excludes_file")" ]]; then
    printf '\n' >> "$excludes_file"
  fi
  printf '%s\n' "$pattern" >> "$excludes_file"
  printf 'Added %s to global Git excludes %s\n' "$pattern" "$excludes_file"
}

write_claude_reviewer_agent() {
  local destination=$1

  {
    cat <<'EOF'
---
name: do-it-reviewer
description: Read-only reviewer for the do-it skill's review/debate loop. Invoke only from do-it.
tools: Read, Grep, Glob, Bash, WebFetch
disallowedTools: Write, Edit
model: opus
---

EOF
    cat "$reviewer_prompt_source"
  } > "$destination"
}

# Succeeds (and warns) when destination exists but is not our link to source.
is_unmanaged_destination() {
  local source=$1
  local destination=$2

  if [[ -e "$destination" || -L "$destination" ]] \
    && [[ "$(readlink "$destination" 2>/dev/null || true)" != "$source" ]]; then
    echo "Skipping $destination: existing file is not managed by agent-stuff" >&2
    return 0
  fi
  return 1
}

install_reviewer_agent() {
  local generated_agent="$generated_root/agents/claude/do-it-reviewer.md"
  local agent_link="$HOME/.claude/agents/do-it-reviewer.md"

  [[ -f "$reviewer_prompt_source" ]] || return 0
  is_unmanaged_destination "$generated_agent" "$agent_link" && return 0

  mkdir -p "$(dirname "$generated_agent")"
  write_claude_reviewer_agent "$generated_agent"
  replace_with_link "$generated_agent" "$agent_link"
}

# The resolver reads this user-level file in every repo; the repo copy is the source of truth.
install_do_it_config() {
  local config_link="${XDG_CONFIG_HOME:-$HOME/.config}/do-it/config"

  [[ -f "$do_it_config_source" ]] || return 0
  is_unmanaged_destination "$do_it_config_source" "$config_link" && return 0

  replace_with_link "$do_it_config_source" "$config_link"
}

remove_stale_links() {
  local directory=$1
  local entry target

  [[ -d "$directory" ]] || return 0

  for entry in "$directory"/*; do
    [[ -L "$entry" ]] || continue
    target=$(readlink "$entry")
    if [[ (! -e "$entry") && ("$target" == *"/agent-stuff/"* || "$target" == "$source_root/"*) ]]; then
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
install_reviewer_agent
install_do_it_config
ensure_global_git_exclude '.do-it/'

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

if [[ ${#project_sources[@]} -gt 0 ]]; then
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

    project_skill_destinations=()
    while IFS= read -r destination; do
      project_skill_destinations+=("$destination")
    done < <(project_skill_destinations_for "$project_destination")
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
fi

echo 'Agent files installed successfully'
