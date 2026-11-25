#!/usr/bin/env bash
# Makes the secrets for maec.yeetus.net (kubernetes/services/maec): a new
# random secret for the Keycloak client "maec", in both places that need it,
# and oauth2-proxy's cookie secret:
#   kubernetes/services/maec/secret.sops.yaml       maec-secrets (oauth2-proxy, game servers)
#   kubernetes/services/keycloak/maec-client.sops.yaml   MAEC_OAUTH2_SECRET for config-cli
# Refuses to overwrite either. Run with: nix shell nixpkgs#sops -c bash scripts/create-maec-secrets.sh
set -euo pipefail
repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"
command -v sops >/dev/null || { echo 'sops is required: nix shell nixpkgs#sops -c bash' "$0" >&2; exit 1; }

app=kubernetes/services/maec/secret.sops.yaml
kc=kubernetes/services/keycloak/maec-client.sops.yaml
for f in "$app" "$kc"; do
  [[ -e "$f" ]] && { echo "Refusing to overwrite $f" >&2; exit 1; }
done

umask 077
client_secret=$(head -c 32 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=\n')
# 32 random bytes, URL-safe base64, as oauth2-proxy expects for AES-256.
cookie_secret=$(head -c 32 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=\n')

cat <<YAML | sops --encrypt --filename-override "$app" /dev/stdin > "$app"
apiVersion: isindir.github.com/v1alpha3
kind: SopsSecret
metadata:
  name: maec-secrets
  namespace: maec
spec:
  secretTemplates:
    - name: maec-secrets
      stringData:
        OAUTH2_PROXY_CLIENT_SECRET: "$client_secret"
        OAUTH2_PROXY_COOKIE_SECRET: "$cookie_secret"
YAML

cat <<YAML | sops --encrypt --filename-override "$kc" /dev/stdin > "$kc"
apiVersion: isindir.github.com/v1alpha3
kind: SopsSecret
metadata:
  name: keycloak-config-cli-maec
  namespace: keycloak
spec:
  secretTemplates:
    - name: keycloak-config-cli-maec
      stringData:
        MAEC_OAUTH2_SECRET: "$client_secret"
YAML
unset client_secret cookie_secret
echo "Encrypted: $app, $kc"
