#!/usr/bin/env bash
# Makes the two secrets for games.yeetus.net (kubernetes/services/gamevault):
#   gamevault/secret.sops.yaml          GameVault's own: the Keycloak client
#                                       secret and AUTH_SEED, which every
#                                       token and session secret comes from
#   keycloak/gamevault-client.sops.yaml the same client secret, for
#                                       config-cli, which sets it on the
#                                       client in realms.yaml
# Everything is made here, so nothing has to be copied from Keycloak and no key
# is needed: sops only encrypts. The IGDB keys are separate
# (create-gamevault-igdb-secret.sh), since they come from a Twitch app.
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

if ! command -v sops >/dev/null; then
  printf 'sops is required; run with: nix shell nixpkgs#sops -c bash %s\n' "$0" >&2
  exit 1
fi

app_target=kubernetes/services/gamevault/secret.sops.yaml
client_target=kubernetes/services/keycloak/gamevault-client.sops.yaml
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

# 32 random bytes, URL-safe base64.
random() { head -c 32 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=\n'; }
client_secret=$(random)
auth_seed=$(random)

cat <<YAML | sops --encrypt --filename-override "$app_target" /dev/stdin > "$app_tmp"
apiVersion: isindir.github.com/v1alpha3
kind: SopsSecret
metadata:
  name: gamevault
  namespace: gamevault
spec:
  secretTemplates:
    - name: gamevault
      stringData:
        OIDC_CLIENT_SECRET: "$client_secret"
        AUTH_SEED: "$auth_seed"
YAML

cat <<YAML | sops --encrypt --filename-override "$client_target" /dev/stdin > "$client_tmp"
apiVersion: isindir.github.com/v1alpha3
kind: SopsSecret
metadata:
  name: keycloak-config-cli-gamevault
  namespace: keycloak
spec:
  secretTemplates:
    - name: keycloak-config-cli-gamevault
      stringData:
        GAMEVAULT_OIDC_SECRET: "$client_secret"
YAML
unset client_secret auth_seed

mv -- "$app_tmp" "$app_target"
mv -- "$client_tmp" "$client_target"
trap - EXIT
printf 'Encrypted SopsSecrets created:\n  %s\n  %s\n' "$app_target" "$client_target"
