#!/usr/bin/env bash
# Puts the Keycloak client secret of Hub's client (realm infra, client hub)
# into kubernetes/services/hub/oidc.sops.yaml, encrypted. The secret is read
# without echoing and never written anywhere in plain text.
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

if ! command -v sops >/dev/null; then
  printf 'sops is required; run with: nix shell nixpkgs#sops -c bash %s\n' "$0" >&2
  exit 1
fi

target=kubernetes/services/hub/oidc.sops.yaml
if [[ -e "$target" ]]; then
  printf 'Refusing to overwrite %s\n' "$target" >&2
  exit 1
fi

umask 077
tmp=$(mktemp "${target}.XXXXXX")
trap 'rm -f "$tmp"' EXIT

read -r -s -p 'Client secret of the "hub" client in the infra realm (input hidden): ' client_secret
printf '\n' >&2
if [[ ! "$client_secret" =~ ^[A-Za-z0-9_-]+$ ]]; then
  printf 'Missing or unexpected client secret; no file was created.\n' >&2
  exit 1
fi

cat <<YAML | sops --encrypt --filename-override "$target" /dev/stdin > "$tmp"
apiVersion: isindir.github.com/v1alpha3
kind: SopsSecret
metadata:
  name: hub-oidc
  namespace: hub
spec:
  secretTemplates:
    - name: hub-oidc
      stringData:
        client-secret: "$client_secret"
YAML
unset client_secret

mv -- "$tmp" "$target"
trap - EXIT
printf 'Encrypted SopsSecret created: %s\n' "$target"
