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
global_skills_source="$source_root/.agents/skills"

installer_script="$source_root/install-custom-skills.sh"
if [[ ! -f "$installer_script" ]]; then
  installer_script="$source_root/install.sh"
fi

global_skill_destinations=(
  "$HOME/.agents/skills"
  "$HOME/.claude/skills"
  "$HOME/.cursor/skills"
  "$HOME/.copilot/skills"
  "$HOME/.gemini/config/skills"
)

usage() {
  cat <<'EOF'
Usage: global-sync.sh [OPTIONS] [SKILL_NAME...]
       agent-stuff global-sync [OPTIONS] [SKILL_NAME...]

Scan harness skill directories for unmanaged global skills and adopt them
into this repository as the single source of truth (.agents/skills/).
Once adopted, install-custom-skills runs automatically to symlink them to all harnesses.

Options:
  -l, --list      List all discovered skills across harnesses and their status
  -a, --all, -y   Adopt all unmanaged skills without interactive confirmation
  -d, --dry-run   Show what would be adopted without modifying anything
      --delete    Delete specified SKILL_NAME(s) from all harness folders
      --no-sync   Do not run installer after adopting/deleting skills
  -h, --help      Show this help message

Interactive Prompt Actions:
  [y]  Adopt into repo (.agents/skills/) and sync across all harnesses
  [n]  Skip this skill (leave it as-is)
  [d]  Delete this skill from ALL harness folders
  [a]  Adopt all remaining unmanaged skills
  [q]  Quit without adopting remaining skills

Arguments:
  SKILL_NAME...   Optional list of specific skill names to adopt or delete.
                  If omitted, all unmanaged skills are reviewed.
EOF
}

mode="interactive"
run_sync=true
target_skills=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -l|--list)
      mode="list"
      shift
      ;;
    -a|--all|-y|--yes)
      mode="all"
      shift
      ;;
    -d|--dry-run)
      mode="dry-run"
      shift
      ;;
    --delete)
      mode="delete"
      shift
      ;;
    --no-sync)
      run_sync=false
      shift
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      target_skills+=("$1")
      shift
      ;;
  esac
done

delete_skill_from_all_folders() {
  local skill_name=$1
  local dest removed_any=false

  # Check repo global skills
  if [[ -e "$global_skills_source/$skill_name" || -L "$global_skills_source/$skill_name" ]]; then
    rm -rf "$global_skills_source/$skill_name"
    printf '  Removed %s\n' "$global_skills_source/$skill_name"
    removed_any=true
  fi

  # Check all harness destinations
  for dest in "${global_skill_destinations[@]}"; do
    if [[ -e "$dest/$skill_name" || -L "$dest/$skill_name" ]]; then
      rm -rf "$dest/$skill_name"
      printf '  Removed %s\n' "$dest/$skill_name"
      removed_any=true
    fi
  done

  if [[ "$removed_any" == true ]]; then
    printf 'Deleted skill "%s" from all folders.\n' "$skill_name"
  else
    printf 'Skill "%s" was not found in any folder.\n' "$skill_name"
  fi
}

if [[ "$mode" == "delete" ]]; then
  if [[ ${#target_skills[@]} -eq 0 ]]; then
    echo "Error: Specify one or more skill names to delete when using --delete." >&2
    exit 1
  fi

  for skill_name in "${target_skills[@]}"; do
    echo "Deleting $skill_name..."
    delete_skill_from_all_folders "$skill_name"
  done

  if [[ "$run_sync" == true && -f "$installer_script" ]]; then
    "$installer_script" > /dev/null
  fi
  exit 0
fi

is_managed() {
  local path=$1
  if [[ -L "$path" ]]; then
    local target
    target=$(readlink "$path" || true)
    if [[ "$target" == "$source_root"* ]]; then
      return 0
    fi
  fi
  return 1
}

extract_description() {
  local skill_dir=$1
  local skill_md="$skill_dir/SKILL.md"
  if [[ -f "$skill_md" ]]; then
    local desc
    desc=$(awk '
      BEGIN { in_desc = 0; desc = ""; }
      /^description:[[:space:]]*[>|]/ { in_desc = 1; next; }
      /^description:[[:space:]]*/ {
        sub(/^description:[[:space:]]*/, "");
        gsub(/^["'\''"]+|["'\''"]+$/, "");
        print;
        exit;
      }
      in_desc {
        if (/^[[:space:]]+/) {
          sub(/^[[:space:]]+/, "");
          desc = (desc == "" ? $0 : desc " " $0);
        } else {
          print desc;
          exit;
        }
      }
      END { if (in_desc && desc != "") print desc; }
    ' "$skill_md" 2>/dev/null || true)
    if [[ -n "$desc" ]]; then
      printf '%s' "$desc"
      return 0
    fi
  fi
  printf 'No description available'
}

ensure_valid_skill_md() {
  local skill_dir=$1
  local skill_name=$2
  local skill_md="$skill_dir/SKILL.md"

  [[ -d "$skill_dir" ]] || {
    echo "Warning: Destination $skill_dir is not a valid directory; skipping frontmatter check." >&2
    return 0
  }

  if [[ ! -f "$skill_md" ]]; then
    cat > "$skill_md" <<EOF
---
name: $skill_name
description: $skill_name skill
---

# $skill_name
EOF
    printf '  Created missing SKILL.md with frontmatter for %s\n' "$skill_name"
    return 0
  fi

  # Check if file has frontmatter (starts with ---)
  local first_line
  first_line=$(head -n 1 "$skill_md" || true)
  if [[ "$first_line" != "---" ]]; then
    local temp_file
    temp_file=$(mktemp)
    {
      cat <<EOF
---
name: $skill_name
description: $skill_name skill
---

EOF
      cat "$skill_md"
    } > "$temp_file"
    mv "$temp_file" "$skill_md"
    printf '  Added YAML frontmatter to %s/SKILL.md\n' "$skill_name"
  fi
}

# Scan all harness destinations
discovered_skills=()
discovered_sources=()
discovered_is_managed=()
broken_links=()

for harness_dir in "${global_skill_destinations[@]}"; do
  [[ -d "$harness_dir" ]] || continue

  for skill_path in "$harness_dir"/*; do
    [[ -d "$skill_path" || -L "$skill_path" ]] || continue
    skill_name=$(basename "$skill_path")

    # If it's a symlink
    if [[ -L "$skill_path" ]]; then
      # Check if broken symlink
      if [[ ! -e "$skill_path" ]]; then
        broken_links+=("$skill_name ($skill_path)")
        continue
      fi

      # Check if already managed
      if is_managed "$skill_path"; then
        discovered_skills+=("$skill_name")
        discovered_sources+=("$skill_path")
        discovered_is_managed+=("true")
        continue
      fi
    fi

    # If user passed specific skill filter, skip non-matching
    if [[ ${#target_skills[@]} -gt 0 ]]; then
      match=false
      for target in "${target_skills[@]}"; do
        if [[ "$target" == "$skill_name" ]]; then
          match=true
          break
        fi
      done
      [[ "$match" == true ]] || continue
    fi

    # It's an unmanaged real directory (or valid external symlink)
    discovered_skills+=("$skill_name")
    discovered_sources+=("$skill_path")
    discovered_is_managed+=("false")
  done
done

# Clean up any broken symlinks found
if [[ ${#broken_links[@]} -gt 0 ]]; then
  echo "Notice: Detected ${#broken_links[@]} dangling / broken symlink(s):"
  for item in "${broken_links[@]}"; do
    path="${item##* (}"
    path="${path%)}"
    if [[ -L "$path" && ! -e "$path" ]]; then
      rm -f "$path"
      printf '  Cleaned up stale link: %s\n' "$path"
    fi
  done
  echo ""
fi

# Deduplicate unmanaged skills by name
unmanaged_names=()
unmanaged_paths=()
managed_names=()

find_in_unmanaged() {
  local query=$1
  local i
  for i in "${!unmanaged_names[@]}"; do
    if [[ "${unmanaged_names[$i]}" == "$query" ]]; then
      printf '%s\n' "$i"
      return 0
    fi
  done
  return 1
}

for i in "${!discovered_skills[@]}"; do
  name="${discovered_skills[$i]}"
  path="${discovered_sources[$i]}"
  status="${discovered_is_managed[$i]}"

  if [[ "$status" == "true" ]]; then
    managed_names+=("$name ($path)")
  else
    if existing_idx=$(find_in_unmanaged "$name"); then
      printf 'Notice: Duplicate unmanaged skill "%s" found in %s (already found in %s)\n' \
        "$name" "$path" "${unmanaged_paths[$existing_idx]}" >&2
    else
      unmanaged_names+=("$name")
      unmanaged_paths+=("$path")
    fi
  fi
done

if [[ "$mode" == "list" ]]; then
  echo "=== Global Skills Status ==="
  echo ""
  echo "Managed skills (already synced from repo):"
  if [[ ${#managed_names[@]} -eq 0 ]]; then
    echo "  (none)"
  else
    for item in "${managed_names[@]}"; do
      echo "  • $item"
    done
  fi
  echo ""
  echo "Unmanaged skills (available to adopt):"
  if [[ ${#unmanaged_names[@]} -eq 0 ]]; then
    echo "  (none)"
  else
    for i in "${!unmanaged_names[@]}"; do
      name="${unmanaged_names[$i]}"
      path="${unmanaged_paths[$i]}"
      desc=$(extract_description "$path")
      echo "  • $name"
      echo "    Source:      $path"
      echo "    Description: $desc"
    done
  fi
  exit 0
fi

if [[ ${#unmanaged_names[@]} -eq 0 ]]; then
  echo "No unmanaged skills found to adopt."
  if [[ "$run_sync" == true && -f "$installer_script" ]]; then
    echo "Running $(basename "$installer_script") to ensure all harnesses are up to date..."
    "$installer_script"
  fi
  exit 0
fi

skills_to_adopt=()
deleted_count=0

if [[ "$mode" == "all" || "$mode" == "dry-run" ]]; then
  skills_to_adopt=("${unmanaged_names[@]}")
elif [[ "$mode" == "interactive" ]]; then
  echo "Found ${#unmanaged_names[@]} unmanaged skill(s):"
  echo ""

  for i in "${!unmanaged_names[@]}"; do
    name="${unmanaged_names[$i]}"
    path="${unmanaged_paths[$i]}"
    desc=$(extract_description "$path")

    echo "--------------------------------------------------"
    echo "[$((i + 1))/${#unmanaged_names[@]}] Skill: $name"
    echo "Source:      $path"
    echo "Description: $desc"
    echo ""
    while true; do
      printf 'Action: [y] adopt, [n] skip, [d] delete from all folders, [a] all, [q] quit: '
      if ! read -r answer; then
        echo ""
        echo "Aborting."
        exit 0
      fi
      case "$answer" in
        [Yy]*)
          skills_to_adopt+=("$name")
          break
          ;;
        [Nn]*)
          break
          ;;
        [Dd]*)
          printf 'Are you sure you want to delete "%s" from ALL folders? [y/N]: ' "$name"
          if ! read -r confirm; then
            echo "Cancelled."
            break
          fi
          case "$confirm" in
            [Yy]*)
              delete_skill_from_all_folders "$name"
              deleted_count=$((deleted_count + 1))
              break
              ;;
            *)
              echo "Deletion cancelled."
              ;;
          esac
          ;;
        [Aa]*)
          for ((j=i; j<${#unmanaged_names[@]}; j++)); do
            skills_to_adopt+=("${unmanaged_names[$j]}")
          done
          break 2
          ;;
        [Qq]*)
          echo "Aborting."
          exit 0
          ;;
        *)
          echo "Please enter y, n, d, a, or q."
          ;;
      esac
    done
  done
fi

if [[ ${#skills_to_adopt[@]} -eq 0 ]]; then
  if [[ $deleted_count -gt 0 ]]; then
    printf '\nFinished: deleted %d skill(s) from all folders.\n' "$deleted_count"
    if [[ "$run_sync" == true && -f "$installer_script" ]]; then
      "$installer_script" > /dev/null
    fi
  else
    echo "No skills selected for adoption."
  fi
  exit 0
fi

if [[ "$mode" == "dry-run" ]]; then
  echo "Dry run: would adopt ${#skills_to_adopt[@]} skill(s):"
  for name in "${skills_to_adopt[@]}"; do
    idx=$(find_in_unmanaged "$name")
    echo "  • $name from ${unmanaged_paths[$idx]} -> $global_skills_source/$name"
  done
  exit 0
fi

mkdir -p "$global_skills_source"

adopted_count=0
for name in "${skills_to_adopt[@]}"; do
  idx=$(find_in_unmanaged "$name")
  src="${unmanaged_paths[$idx]}"
  dest="$global_skills_source/$name"

  echo "Adopting $name..."
  if [[ -e "$dest" || -L "$dest" ]]; then
    printf '  Destination %s already exists; replacing with source from %s\n' "$dest" "$src"
    rm -rf "$dest"
  fi

  # Copy source to repository (dereference if source is a symlink)
  if [[ -L "$src" ]]; then
    cp -RL "$src" "$dest"
  else
    cp -R "$src" "$dest"
  fi
  ensure_valid_skill_md "$dest" "$name"
  printf '  Adopted into %s\n' "$dest"
  adopted_count=$((adopted_count + 1))
done

echo ""
printf 'Successfully adopted %d skill(s) into %s\n' "$adopted_count" "$global_skills_source"
if [[ $deleted_count -gt 0 ]]; then
  printf 'Successfully deleted %d skill(s) from all folders\n' "$deleted_count"
fi

if [[ "$run_sync" == true && -f "$installer_script" ]]; then
  echo ""
  echo "Syncing skills across all harnesses..."
  "$installer_script"
fi

echo "Done!"
