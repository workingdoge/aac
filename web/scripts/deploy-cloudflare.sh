#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'deploy-cloudflare: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: bash scripts/deploy-cloudflare.sh [--dry-run|--execute] [--skip-build]

Builds and deploys the canonical AAC Astro site in web/ to Cloudflare using
web/wrangler.toml. Credentials are not copied into this repo; by default the
script reads the existing Fish AAC lane SOPS file:

  $HOME/irai/fish/sites/aac/secrets/cloudflare-production.yaml

Environment overrides:
  AAC_FISH_SITE_ROOT           Fish AAC site root.
  AAC_CLOUDFLARE_SOPS_FILE     SOPS YAML with cloudflare_api_token.
  SOPS_AGE_KEY_FILE            Age key file for SOPS decryption.
  WRANGLER_BIN                 Optional wrangler executable.
EOF
}

mode="dry-run"
run_build=1

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      mode="dry-run"
      ;;
    --execute)
      mode="execute"
      ;;
    --skip-build)
      run_build=0
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
  shift
done

command -v bun >/dev/null 2>&1 || fail "bun is not available on PATH"

if [ "$run_build" -eq 1 ]; then
  bun run build
fi

run_wrangler() {
  if [ -n "${WRANGLER_BIN:-}" ]; then
    "$WRANGLER_BIN" "$@"
  else
    bun x wrangler@4.90.0 "$@"
  fi
}

if [ "$mode" = "dry-run" ]; then
  run_wrangler deploy --dry-run
  exit 0
fi

fish_site="${AAC_FISH_SITE_ROOT:-$HOME/irai/fish/sites/aac}"
sops_file="${AAC_CLOUDFLARE_SOPS_FILE:-$fish_site/secrets/cloudflare-production.yaml}"
age_key_file="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

[ -r "$sops_file" ] || fail "SOPS file is not readable: $sops_file"
[ -r "$age_key_file" ] || fail "SOPS age key file is not readable: $age_key_file"
command -v sops >/dev/null 2>&1 || fail "sops is not available on PATH"
command -v yq >/dev/null 2>&1 || fail "yq is not available on PATH"

cloudflare_token="$(
  SOPS_AGE_KEY_FILE="$age_key_file" sops --decrypt "$sops_file" \
    | yq -r '.cloudflare_api_token // ""' - \
    | tr -d '\r\n'
)"
[ -n "$cloudflare_token" ] || fail "SOPS file did not contain cloudflare_api_token"

trap 'unset CLOUDFLARE_API_TOKEN cloudflare_token' EXIT
export CLOUDFLARE_API_TOKEN="$cloudflare_token"
run_wrangler deploy
