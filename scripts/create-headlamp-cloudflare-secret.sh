#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

if ! command -v sops >/dev/null; then
  printf 'sops is required; run with: nix shell nixpkgs#sops -c bash %s\n' "$0" >&2
  exit 1
fi

target=kubernetes/services/headlamp/cloudflare-secret.sops.yaml
if [[ -e "$target" ]]; then
  printf 'Refusing to overwrite %s\n' "$target" >&2
  exit 1
fi

umask 077
tmp=$(mktemp "${target}.XXXXXX")
trap 'rm -f "$tmp"' EXIT

read -r -s -p 'Cloudflare API token (input hidden): ' token
printf '\n' >&2
if [[ -z "$token" ]]; then
  printf 'No token supplied.\n' >&2
  exit 1
fi
if [[ ! "$token" =~ ^[A-Za-z0-9_-]+$ ]]; then
  printf 'Unexpected token characters; no file was created.\n' >&2
  exit 1
fi

cat <<YAML | sops --encrypt --filename-override "$target" /dev/stdin > "$tmp"
apiVersion: isindir.github.com/v1alpha3
kind: SopsSecret
metadata:
  name: headlamp-cloudflare-api-token
  namespace: headlamp
spec:
  secretTemplates:
    - name: headlamp-cloudflare-api-token
      stringData:
        api-token: "$token"
YAML
unset token

mv -- "$tmp" "$target"
trap - EXIT
printf 'Encrypted SopsSecret created: %s\n' "$target"
