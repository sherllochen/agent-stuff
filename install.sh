#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

source_root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
dev_root=${DEV_ROOT:-"$HOME/dev"}
global_skills_source="$source_root/.agents/skills"
global_skills_destination="$HOME/.agents/skills"
generated_root="$source_root/.generated"

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
  local destination_directory=$2
  local skill

  [[ -d "$source_directory" ]] || return 0
  mkdir -p "$destination_directory"

  for skill in "$source_directory"/*; do
    [[ -d "$skill" ]] || continue
    replace_with_link "$skill" "$destination_directory/$(basename "$skill")"
  done
}

update_git_excludes() {
  local repository=$1
  local skills_source=$2
  local git_directory exclude_file temporary_file skill line in_managed_block=false
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
    printf '%s\n' "$begin_marker" '/AGENTS.md'
    if [[ -d "$skills_source" ]]; then
      for skill in "$skills_source"/*; do
        [[ -d "$skill" ]] || continue
        printf '/.agents/skills/%s\n' "$(basename "$skill")"
      done
    fi
    printf '%s\n' "$end_marker"
  } > "$exclude_file"

  rm "$temporary_file"
  printf 'Updated local Git exclusions in %s\n' "$exclude_file"
}

project_sources=()
for candidate in "$source_root"/*; do
  [[ -d "$candidate" ]] || continue
  if [[ -d "$candidate/.agents" || -f "$candidate/AGENTS.md" ]]; then
    project_sources+=("$candidate")
  fi
done

[[ -f "$source_root/AGENTS.md" ]] || {
  echo "Global instructions do not exist: $source_root/AGENTS.md" >&2
  exit 1
}

for project_source in "${project_sources[@]}"; do
  project_name=$(basename "$project_source")
  project_destination="$dev_root/$project_name"
  if [[ ! -d "$project_destination" ]]; then
    echo "Repository directory does not exist: $project_destination" >&2
    exit 1
  fi
done

mkdir -p "$global_skills_destination" "$generated_root"
remove_stale_links "$global_skills_destination"
link_skills "$global_skills_source" "$global_skills_destination"

for repository in "$dev_root"/*; do
  [[ -d "$repository" ]] || continue
  remove_stale_links "$repository/.agents/skills"

  agents_file="$repository/AGENTS.md"
  if [[ -L "$agents_file" ]]; then
    agents_target=$(readlink "$agents_file")
    if [[ "$agents_target" == "$generated_root/"* && ! -e "$agents_target" ]]; then
      rm "$agents_file"
      printf 'Removed stale link %s\n' "$agents_file"
    fi
  fi
done

for project_source in "${project_sources[@]}"; do
  project_name=$(basename "$project_source")
  project_destination="$dev_root/$project_name"
  project_skills_source="$project_source/.agents/skills"
  project_skills_destination="$project_destination/.agents/skills"
  generated_directory="$generated_root/$project_name"
  generated_agents="$generated_directory/AGENTS.md"

  link_skills "$project_skills_source" "$project_skills_destination"
  update_git_excludes "$project_destination" "$project_skills_source"

  mkdir -p "$generated_directory"
  cp "$source_root/AGENTS.md" "$generated_agents"
  if [[ -f "$project_source/AGENTS.md" ]]; then
    printf '\n<!-- Project-specific instructions: %s -->\n\n' "$project_name" \
      >> "$generated_agents"
    cat "$project_source/AGENTS.md" >> "$generated_agents"
  fi

  replace_with_link "$generated_agents" "$project_destination/AGENTS.md"
done

echo 'Agent files installed successfully'