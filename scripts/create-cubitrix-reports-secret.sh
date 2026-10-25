#!/usr/bin/env bash
# Makes the two secrets for cubitrix-reports.yeetus.net (kubernetes/services/cubitrix-reports):
#   cubitrix-reports/secret.sops.yaml          GlitchTip's own: its Django key, the
#                                              Keycloak client secret, the admin password
#   keycloak/cubitrix-reports-client.sops.yaml the same client secret, for config-cli,
#                                              which sets it on the client in realms.yaml
# Everything is made here, so nothing has to be copied from Keycloak and no key
# is needed: sops only encrypts.
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

if ! command -v sops >/dev/null; then
  printf 'sops is required; run with: nix shell nixpkgs#sops -c bash %s\n' "$0" >&2
  exit 1
fi

app_target=kubernetes/services/cubitrix-reports/secret.sops.yaml
client_target=kubernetes/services/keycloak/cubitrix-reports-client.sops.yaml
for target in "$app_target" "$client_target"; do
  if [[ -e "$target" ]]; then
    printf 'Refusing to overwrite %s\n' "$target" >&2
    exit 1
  fi
done

umask 077
app_tmp=$(mktemp "${app_target}.XXXXXX")
client_tmp=$(mktemp "${client_target}.XXXXXX")
trap 'rm -f "$app_tmp" "$client_tmp"' EXIT

# 32 random bytes each, URL-safe base64.
random() { head -c 32 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=\n'; }
client_secret=$(random)
django_key=$(random)
admin_password=$(random)

cat <<YAML | sops --encrypt --filename-override "$app_target" /dev/stdin > "$app_tmp"
apiVersion: isindir.github.com/v1alpha3
kind: SopsSecret
metadata:
  name: glitchtip
  namespace: cubitrix-reports
spec:
  secretTemplates:
    - name: glitchtip
      stringData:
        SECRET_KEY: "$django_key"
        OIDC_CLIENT_SECRET: "$client_secret"
        ADMIN_PASSWORD: "$admin_password"
YAML

cat <<YAML | sops --encrypt --filename-override "$client_target" /dev/stdin > "$client_tmp"
apiVersion: isindir.github.com/v1alpha3
kind: SopsSecret
metadata:
  name: keycloak-config-cli-cubitrix-reports
  namespace: keycloak
spec:
  secretTemplates:
    - name: keycloak-config-cli-cubitrix-reports
      stringData:
        CUBITRIX_REPORTS_OIDC_SECRET: "$client_secret"
YAML
unset client_secret django_key admin_password

mv -- "$app_tmp" "$app_target"
mv -- "$client_tmp" "$client_target"
trap - EXIT
printf 'Encrypted SopsSecrets created:\n  %s\n  %s\n' "$app_target" "$client_target"
