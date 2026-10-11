#!/usr/bin/env bash
# Puts the GitHub App that publishes the profile's infrastructure card
# (kubernetes/services/profile-status) into
# kubernetes/services/profile-status/github-app.sops.yaml, encrypted: its id,
# its installation's id and its private key, and lists that file in the
# service's hub.yaml.
# Usage: scripts/create-profile-status-app.sh <app id> <installation id> <key.pem>
# Delete the downloaded .pem afterwards; this file is the only copy needed.
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

if ! command -v sops >/dev/null; then
  printf 'sops is required; run with: nix shell nixpkgs#sops -c bash %s\n' "$0" >&2
  exit 1
fi
if [[ $# -ne 3 ]]; then
  printf 'usage: %s <app id> <installation id> <private key .pem>\n' "$0" >&2
  exit 2
fi
app_id=$1
installation_id=$2
key_file=$3
if [[ ! "$app_id" =~ ^[0-9]+$ ]]; then
  printf 'The app id is a number (the App settings page shows it).\n' >&2
  exit 1
fi
if [[ ! "$installation_id" =~ ^[0-9]+$ ]]; then
  printf 'The installation id is a number (the end of the installation settings URL).\n' >&2
  exit 1
fi
if ! grep -q -- '-----BEGIN RSA PRIVATE KEY-----' "$key_file"; then
  printf '%s is not the private key GitHub gave for the App.\n' "$key_file" >&2
  exit 1
fi

dir=kubernetes/services/profile-status
if [[ ! -d "$dir" ]]; then
  printf 'No %s here: run this from the infrastructure repo, on the branch that adds profile-status.\n' "$dir" >&2
  exit 1
fi
target=$dir/github-app.sops.yaml
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
  name: profile-status-github-app
  namespace: profile-status
spec:
  secretTemplates:
    - name: profile-status-github-app
      stringData:
        app-id: "$app_id"
        installation-id: "$installation_id"
        private-key.pem: |
YAML
  sed 's/^/          /' "$key_file"
} | sops --encrypt --filename-override "$target" /dev/stdin > "$tmp"

mv -- "$tmp" "$target"
trap - EXIT

if ! grep -qx -- '- github-app.sops.yaml' "$dir/hub.yaml"; then
  sed -i 's/^- github-app.sops.yaml.example$/- github-app.sops.yaml\n&/' "$dir/hub.yaml"
fi
printf 'Encrypted SopsSecret created: %s\n' "$target"
