#!/usr/bin/env bash
# The canaries' Gitea token (kubernetes/services/canary). Before running:
#   1. create the private repository radu/canary on git.radunenu.com (empty)
#   2. create a token for it: Settings -> Applications, scope
#      "repository: read and write" (it pushes and reads the Actions runs)
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

if ! command -v sops >/dev/null; then
  printf 'sops is required; run with: nix shell nixpkgs#sops -c bash %s\n' "$0" >&2
  exit 1
fi

target=kubernetes/services/canary/secret.sops.yaml
if [[ -e "$target" ]]; then
  printf 'Refusing to overwrite %s\n' "$target" >&2
  exit 1
fi

umask 077
tmp=$(mktemp "${target}.XXXXXX")
trap 'rm -f "$tmp"' EXIT

read -r -s -p 'Gitea token for radu/canary (input hidden): ' token
printf '\n' >&2
if [[ ! "$token" =~ ^[A-Za-z0-9_-]{20,}$ ]]; then
  printf 'Missing or unexpected token; no file was created.\n' >&2
  exit 1
fi
if ! curl -fsS -m 20 -o /dev/null -H "Authorization: token $token" https://git.radunenu.com/api/v1/repos/radu/canary; then
  printf 'The token cannot see radu/canary; no file was created.\n' >&2
  exit 1
fi

cat <<YAML | sops --encrypt --filename-override "$target" /dev/stdin > "$tmp"
apiVersion: isindir.github.com/v1alpha3
kind: SopsSecret
metadata:
  name: canary-gitea
  namespace: canary
spec:
  secretTemplates:
    - name: canary-gitea
      stringData:
        token: "$token"
YAML
unset token

mv -- "$tmp" "$target"
trap - EXIT
# Hub checks that the folder holds exactly what hub.yaml keeps.
sed -i 's/^- namespace.yaml$/- namespace.yaml\n- secret.sops.yaml/' kubernetes/services/canary/hub.yaml
printf 'Encrypted SopsSecret created: %s (and listed in hub.yaml)\n' "$target"
