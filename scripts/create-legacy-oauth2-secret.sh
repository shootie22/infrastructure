#!/usr/bin/env bash
# Makes the two secrets for legacy.yeetus.net's login (kubernetes/services/legacy):
#   legacy/secret.sops.yaml          client + cookie secret, for oauth2-proxy
#   keycloak/legacy-client.sops.yaml the same client secret, for config-cli,
#                                    which sets it on the client in realms.yaml
# The client secret is made here, so nothing has to be copied from Keycloak
# and no key is needed: sops only encrypts.
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

if ! command -v sops >/dev/null; then
  printf 'sops is required; run with: nix shell nixpkgs#sops -c bash %s\n' "$0" >&2
  exit 1
fi

proxy_target=kubernetes/services/legacy/secret.sops.yaml
client_target=kubernetes/services/keycloak/legacy-client.sops.yaml
for target in "$proxy_target" "$client_target"; do
  if [[ -e "$target" ]]; then
    printf 'Refusing to overwrite %s\n' "$target" >&2
    exit 1
  fi
done

umask 077
proxy_tmp=$(mktemp "${proxy_target}.XXXXXX")
client_tmp=$(mktemp "${client_target}.XXXXXX")
trap 'rm -f "$proxy_tmp" "$client_tmp"' EXIT

# 32 random bytes, URL-safe base64. The cookie secret is AES-256 for oauth2-proxy.
client_secret=$(head -c 32 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=\n')
cookie_secret=$(head -c 32 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=\n')

cat <<YAML | sops --encrypt --filename-override "$proxy_target" /dev/stdin > "$proxy_tmp"
apiVersion: isindir.github.com/v1alpha3
kind: SopsSecret
metadata:
  name: legacy-oauth2
  namespace: legacy
spec:
  secretTemplates:
    - name: legacy-oauth2
      stringData:
        OAUTH2_PROXY_CLIENT_SECRET: "$client_secret"
        OAUTH2_PROXY_COOKIE_SECRET: "$cookie_secret"
YAML

cat <<YAML | sops --encrypt --filename-override "$client_target" /dev/stdin > "$client_tmp"
apiVersion: isindir.github.com/v1alpha3
kind: SopsSecret
metadata:
  name: keycloak-config-cli-legacy
  namespace: keycloak
spec:
  secretTemplates:
    - name: keycloak-config-cli-legacy
      stringData:
        LEGACY_OAUTH2_SECRET: "$client_secret"
YAML
unset client_secret cookie_secret

mv -- "$proxy_tmp" "$proxy_target"
mv -- "$client_tmp" "$client_target"
trap - EXIT
printf 'Encrypted SopsSecrets created:\n  %s\n  %s\n' "$proxy_target" "$client_target"
