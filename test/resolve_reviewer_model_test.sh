#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
resolver="$repo_root/.agents/skills/do-it/scripts/resolve-reviewer-model.sh"
sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/home"

# Usage: resolve <harness> [VAR=value...]; runs the resolver with a clean environment.
resolve() {
  local harness=$1
  shift
  env -i PATH="$PATH" HOME="$sandbox/home" "$@" "$resolver" ${harness:+"$harness"} \
    2> "$sandbox/stderr"
}

expect() {
  local expected=$1 actual=$2
  if [[ "$actual" != "$expected" ]]; then
    printf 'Expected: %q\nActual:   %q\n' "$expected" "$actual" >&2
    exit 1
  fi
}

tab=$'\t'

# Defaults per harness
expect "gpt-5.3-codex${tab}default" "$(resolve copilot)"
expect "opus${tab}default" "$(resolve claude)"
expect "pro${tab}default" "$(resolve antigravity)"

# Per-harness env wins over generic env
expect "sonnet${tab}env:DO_IT_REVIEWER_MODEL_CLAUDE" \
  "$(resolve claude DO_IT_REVIEWER_MODEL_CLAUDE=sonnet DO_IT_REVIEWER_MODEL=haiku)"

# Generic env is used when valid for the harness
expect "gpt-5.6-sol${tab}env:DO_IT_REVIEWER_MODEL" \
  "$(resolve copilot DO_IT_REVIEWER_MODEL=gpt-5.6-sol)"

# Generic env invalid for the harness falls through with a warning
expect "opus${tab}default" "$(resolve claude DO_IT_REVIEWER_MODEL=gpt-5.3-codex)"
grep -qF 'do-it: ignoring env:DO_IT_REVIEWER_MODEL' "$sandbox/stderr"

# Unsafe Copilot values are rejected
expect "gpt-5.3-codex${tab}default" "$(resolve copilot 'DO_IT_REVIEWER_MODEL_COPILOT=gpt; rm -rf /')"
grep -qF 'do-it: ignoring env:DO_IT_REVIEWER_MODEL_COPILOT' "$sandbox/stderr"

# Config file at the default XDG location: comments, spaces, quotes, last value wins
mkdir -p "$sandbox/home/.config/do-it"
cat > "$sandbox/home/.config/do-it/config" <<'EOF'
# reviewer settings
DO_IT_REVIEWER_MODEL_ANTIGRAVITY = flash
DO_IT_REVIEWER_MODEL_ANTIGRAVITY="inherit"
DO_IT_REVIEWER_MODEL=haiku
EOF
expect "inherit${tab}config:DO_IT_REVIEWER_MODEL_ANTIGRAVITY" "$(resolve antigravity)"
expect "haiku${tab}config:DO_IT_REVIEWER_MODEL" "$(resolve claude)"

# Env beats config
expect "sonnet${tab}env:DO_IT_REVIEWER_MODEL_CLAUDE" \
  "$(resolve claude DO_IT_REVIEWER_MODEL_CLAUDE=sonnet)"

# DO_IT_CONFIG overrides the config path
printf 'DO_IT_REVIEWER_MODEL_CLAUDE=fable\n' > "$sandbox/custom-config"
expect "fable${tab}config:DO_IT_REVIEWER_MODEL_CLAUDE" \
  "$(resolve claude DO_IT_CONFIG="$sandbox/custom-config")"

# Usage errors
for harness in unknown ''; do
  set +e
  resolve "$harness" > /dev/null
  status=$?
  set -e
  expect 2 "$status"
done

echo 'Resolver tests passed'
