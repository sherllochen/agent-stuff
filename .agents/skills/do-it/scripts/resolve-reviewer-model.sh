#!/usr/bin/env bash
# Resolve the do-it reviewer model for a harness.
# Usage: resolve-reviewer-model.sh <copilot|claude|antigravity>
# Prints "<model>\t<source>" on stdout; warnings go to stderr.

set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <copilot|claude|antigravity>" >&2
  exit 2
}

[[ $# -eq 1 ]] || usage
harness=$1

case "$harness" in
  copilot) suffix=COPILOT; default_model=gpt-5.3-codex ;;
  claude) suffix=CLAUDE; default_model=opus ;;
  antigravity) suffix=ANTIGRAVITY; default_model=pro ;;
  *) usage ;;
esac

specific_key="DO_IT_REVIEWER_MODEL_${suffix}"
generic_key='DO_IT_REVIEWER_MODEL'
config_file=${DO_IT_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/do-it/config}

is_valid() {
  local value=$1
  case "$harness" in
    copilot) [[ "$value" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]] ;;
    claude) [[ "$value" =~ ^(opus|sonnet|haiku|fable)$ ]] ;;
    antigravity) [[ "$value" =~ ^(inherit|flash|pro)$ ]] ;;
  esac
}

# Prints the last value assigned to KEY in the config file, without sourcing it.
config_value() {
  local key=$1 line value=''
  [[ -f "$config_file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line=${line%$'\r'}
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    if [[ "$line" =~ ^[[:space:]]*([A-Z_]+)[[:space:]]*=[[:space:]]*(.*)$ ]] \
      && [[ "${BASH_REMATCH[1]}" == "$key" ]]; then
      value=${BASH_REMATCH[2]}
    fi
  done < "$config_file"
  value=${value%"${value##*[![:space:]]}"}
  if [[ "$value" =~ ^\"(.*)\"$ || "$value" =~ ^\'(.*)\'$ ]]; then
    value=${BASH_REMATCH[1]}
  fi
  printf '%s' "$value"
}

try_candidate() {
  local value=$1 source=$2
  [[ -n "$value" ]] || return 0
  if is_valid "$value"; then
    printf '%s\t%s\n' "$value" "$source"
    exit 0
  fi
  printf 'do-it: ignoring %s="%s": not a valid %s reviewer model\n' \
    "$source" "$value" "$harness" >&2
}

try_candidate "$(printenv "$specific_key" || true)" "env:$specific_key"
try_candidate "$(printenv "$generic_key" || true)" "env:$generic_key"
try_candidate "$(config_value "$specific_key")" "config:$specific_key"
try_candidate "$(config_value "$generic_key")" "config:$generic_key"
printf '%s\t%s\n' "$default_model" 'default'
