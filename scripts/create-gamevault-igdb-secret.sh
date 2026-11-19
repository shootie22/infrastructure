#!/usr/bin/env bash
# Makes gamevault/igdb.sops.yaml: the Client ID and Client Secret of a Twitch
# developer app, which GameVault uses to fetch covers and descriptions from
# IGDB. Free: a Twitch account with two-factor on, then at
# https://dev.twitch.tv/console/apps "Register Your Application" (OAuth
# Redirect URL http://localhost, category Application Integration, client
# type Confidential), "Manage", "New Secret".
#
# The Deployment reads it as optional, so GameVault runs without it. After
# writing it, run scripts/check-config-hash --fix in the same change, so GameVault
# restarts with it (it's read only at start).
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

if ! command -v sops >/dev/null; then
  printf 'sops is required; run with: nix shell nixpkgs#sops -c bash %s\n' "$0" >&2
  exit 1
fi

target=kubernetes/services/gamevault/igdb.sops.yaml
hub=kubernetes/services/gamevault/hub.yaml
if [[ -e "$target" ]]; then
  printf 'Refusing to overwrite %s\n' "$target" >&2
  exit 1
fi

read -r -p 'Twitch app Client ID: ' client_id
read -r -s -p 'Twitch app Client Secret (input hidden): ' client_secret
printf '\n'
if [[ -z "$client_id" || -z "$client_secret" ]]; then
  printf 'Both are needed\n' >&2
  exit 1
fi

umask 077
tmp=$(mktemp "${target}.XXXXXX")
trap 'rm -f "$tmp"' EXIT

cat <<YAML | sops --encrypt --filename-override "$target" /dev/stdin > "$tmp"
apiVersion: isindir.github.com/v1alpha3
kind: SopsSecret
metadata:
  name: gamevault-igdb
  namespace: gamevault
spec:
  secretTemplates:
    - name: gamevault-igdb
      stringData:
        CLIENT_ID: "$client_id"
        CLIENT_SECRET: "$client_secret"
YAML
unset client_id client_secret

mv -- "$tmp" "$target"
trap - EXIT

# hub render --check fails on files hub.yaml doesn't list.
if ! grep -qx -- '- igdb.sops.yaml' "$hub"; then
  sed -i 's/^- ingress.yaml$/- igdb.sops.yaml\n- ingress.yaml/' "$hub"
fi
printf 'Encrypted SopsSecret created: %s (and listed in %s)\n' "$target" "$hub"
