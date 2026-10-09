#!/usr/bin/env bash
# Puts the GitHub App that hub-writer acts as (infra-hub #45) into
# kubernetes/services/hub/writer-app.sops.yaml, encrypted: its id and its
# private key. Usage: scripts/create-hub-writer-app.sh <app id> <key.pem>
# Delete the downloaded .pem afterwards; this file is the only copy needed.
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

if ! command -v sops >/dev/null; then
  printf 'sops is required; run with: nix shell nixpkgs#sops -c bash %s\n' "$0" >&2
  exit 1
fi
if [[ $# -ne 2 ]]; then
  printf 'usage: %s <app id> <private key .pem>\n' "$0" >&2
  exit 2
fi
app_id=$1
key_file=$2
if [[ ! "$app_id" =~ ^[0-9]+$ ]]; then
  printf 'The app id is a number (the App settings page shows it).\n' >&2
  exit 1
fi
if ! grep -q -- '-----BEGIN RSA PRIVATE KEY-----' "$key_file"; then
  printf '%s is not the private key GitHub gave for the App.\n' "$key_file" >&2
  exit 1
fi

target=kubernetes/services/hub/writer-app.sops.yaml
if [[ -e "$target" ]]; then
  printf 'Refusing to overwrite %s\n' "$target" >&2
  exit 1
fi

umask 077
tmp=$(mktemp "${target}.XXXXXX")
trap 'rm -f "$tmp"' EXIT

{
  cat <<YAML
apiVersion: isindir.github.com/v1alpha3
kind: SopsSecret
metadata:
  name: hub-writer-app
  namespace: hub
spec:
  secretTemplates:
    - name: hub-writer-app
      stringData:
        app-id: "$app_id"
        private-key.pem: |
YAML
  sed 's/^/          /' "$key_file"
} | sops --encrypt --filename-override "$target" /dev/stdin > "$tmp"

mv -- "$tmp" "$target"
trap - EXIT
printf 'Encrypted SopsSecret created: %s\n' "$target"
