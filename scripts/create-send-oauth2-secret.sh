#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

if ! command -v sops >/dev/null; then
  printf 'sops is required; run with: nix shell nixpkgs#sops -c bash %s\n' "$0" >&2
  exit 1
fi

target=kubernetes/services/send/secret.sops.yaml
if [[ -e "$target" ]]; then
  printf 'Refusing to overwrite %s\n' "$target" >&2
  exit 1
fi

umask 077
tmp=$(mktemp "${target}.XXXXXX")
trap 'rm -f "$tmp"' EXIT

read -r -p 'Keycloak realm (as in https://auth.radunenu.com/realms/<realm>): ' realm
if [[ ! "$realm" =~ ^[A-Za-z0-9_-]+$ ]]; then
  printf 'Unexpected realm name; no file was created.\n' >&2
  exit 1
fi

read -r -s -p 'Client secret of the "share" client (input hidden): ' client_secret
printf '\n' >&2
if [[ ! "$client_secret" =~ ^[A-Za-z0-9_-]+$ ]]; then
  printf 'Missing or unexpected client secret; no file was created.\n' >&2
  exit 1
fi

# 32 random bytes, URL-safe base64, as oauth2-proxy expects for AES-256.
cookie_secret=$(head -c 32 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=\n')

cat <<YAML | sops --encrypt --filename-override "$target" /dev/stdin > "$tmp"
apiVersion: isindir.github.com/v1alpha3
kind: SopsSecret
metadata:
  name: send-oauth2
  namespace: send
spec:
  secretTemplates:
    - name: send-oauth2
      stringData:
        OAUTH2_PROXY_OIDC_ISSUER_URL: "https://auth.radunenu.com/realms/$realm"
        OAUTH2_PROXY_CLIENT_SECRET: "$client_secret"
        OAUTH2_PROXY_COOKIE_SECRET: "$cookie_secret"
YAML
unset client_secret cookie_secret

mv -- "$tmp" "$target"
trap - EXIT
printf 'Encrypted SopsSecret created: %s\n' "$target"
