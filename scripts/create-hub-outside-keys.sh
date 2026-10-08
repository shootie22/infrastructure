#!/usr/bin/env bash
# The read-only API keys Hub uses to read the outside checks' history for
# its incidents (infrastructure #178): healthchecks.io's read-only key and
# UptimeRobot's read-only key. Written encrypted to
# kubernetes/services/hub/outside.sops.yaml; never in plain text.
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

if ! command -v sops >/dev/null; then
  printf 'sops is required; run with: nix shell nixpkgs#sops -c bash %s\n' "$0" >&2
  exit 1
fi

target=kubernetes/services/hub/outside.sops.yaml
if [[ -e "$target" ]]; then
  printf 'Refusing to overwrite %s\n' "$target" >&2
  exit 1
fi

umask 077
tmp=$(mktemp "${target}.XXXXXX")
trap 'rm -f "$tmp"' EXIT

read -r -s -p 'healthchecks.io read-only API key (Project settings > API access, input hidden): ' hc
printf '\n' >&2
read -r -s -p 'UptimeRobot read-only API key (Integrations & API, input hidden): ' ur
printf '\n' >&2
for k in "$hc" "$ur"; do
  if [[ ! "$k" =~ ^[A-Za-z0-9_-]+$ ]]; then
    printf 'Missing or unexpected key; no file was created.\n' >&2
    exit 1
  fi
done

cat <<YAML | sops --encrypt --filename-override "$target" /dev/stdin > "$tmp"
apiVersion: isindir.github.com/v1alpha3
kind: SopsSecret
metadata:
  name: hub-outside
  namespace: hub
spec:
  secretTemplates:
    - name: hub-outside
      stringData:
        healthchecks: "$hc"
        uptimerobot: "$ur"
YAML
unset hc ur

mv -- "$tmp" "$target"
trap - EXIT
printf 'Encrypted SopsSecret created: %s\n' "$target"
