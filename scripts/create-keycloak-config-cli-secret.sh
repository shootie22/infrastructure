#!/usr/bin/env bash
# Makes kubernetes/services/keycloak/config-cli.sops.yaml with the secret of
# Keycloak's config-cli client (#56), lists it in the folder's hub.yaml and
# lets the CronJob run. Create the client first, see docs/ha/keycloak-sso.md.
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

for bin in sops yq; do
  if ! command -v "$bin" >/dev/null; then
    printf '%s is required; run with: nix shell nixpkgs#sops nixpkgs#yq-go -c bash %s\n' "$bin" "$0" >&2
    exit 1
  fi
done

dir=kubernetes/services/keycloak
target=$dir/config-cli.sops.yaml
if [[ -e "$target" ]]; then
  printf 'Refusing to overwrite %s\n' "$target" >&2
  exit 1
fi

umask 077
tmp=$(mktemp "${target}.XXXXXX")
trap 'rm -f "$tmp"' EXIT

read -r -s -p 'Client secret of the "config-cli" client in master (input hidden): ' client_secret
printf '\n' >&2
if [[ ! "$client_secret" =~ ^[A-Za-z0-9_-]+$ ]]; then
  printf 'Missing or unexpected client secret; no file was created.\n' >&2
  exit 1
fi

cat <<YAML | sops --encrypt --filename-override "$target" /dev/stdin > "$tmp"
apiVersion: isindir.github.com/v1alpha3
kind: SopsSecret
metadata:
  name: keycloak-config-cli
  namespace: keycloak
spec:
  secretTemplates:
    - name: keycloak-config-cli
      stringData:
        KEYCLOAK_CLIENTSECRET: "$client_secret"
YAML
unset client_secret

mv -- "$tmp" "$target"
trap - EXIT

yq -i '.keep += ["config-cli.sops.yaml"] | .keep |= (unique | sort)' "$dir/hub.yaml"
sed -i 's/^  - /- /' "$dir/hub.yaml"  # Hub writes the list unindented
sed -i 's/^  suspend: true$/  suspend: false/' "$dir/config-cli.yaml"
sed -i '/^  # Until config-cli.sops.yaml exists.$/d' "$dir/config-cli.yaml"

printf 'Created %s, listed it in hub.yaml and switched the CronJob on.\n' "$target"
printf 'Commit the three files; the first run follows within 10 minutes.\n'
