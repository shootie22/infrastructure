#!/usr/bin/env bash
# Makes kubernetes/services/matrix/secrets.sops.yaml: every secret yeetus.net's
# Synapse and MAS need (#139, docs/matrix/), generated here and encrypted
# straight away, never printed or written to disk in plain text outside a
# private temporary folder that is removed at the end. Also adds the matching
# client secret (MATRIX_SECRET) to keycloak/config-cli.sops.yaml, which needs
# the personal age key to decrypt.
#
#   nix shell nixpkgs#sops nixpkgs#openssl nixpkgs#python3 nixpkgs#yq-go -c bash scripts/create-matrix-secrets.sh
#
# Refuses to run if the file exists: replacing Synapse's signing key changes
# the server's identity, and new database passwords don't reach a database
# that's already initialised. Rotating one secret is done by hand with
# `sops edit`.
#
# Prints the upstream provider's ID (a ULID, not secret): realms.yaml's
# redirect URI and mas.yaml use it.
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

for bin in sops openssl python3 yq; do
  command -v "$bin" >/dev/null || { printf '%s is required; see the header for the nix shell line\n' "$bin" >&2; exit 1; }
done

target=kubernetes/services/matrix/secrets.sops.yaml
keycloak=kubernetes/services/keycloak/config-cli.sops.yaml
provider_id=${MAS_PROVIDER_ID:?set MAS_PROVIDER_ID to the ULID already used in mas.yaml and realms.yaml}
if [[ -e "$target" ]]; then
  printf 'Refusing to overwrite %s\n' "$target" >&2
  exit 1
fi
if sops decrypt --extract '["spec"]["secretTemplates"][0]["stringData"]["MATRIX_SECRET"]' "$keycloak" >/dev/null 2>&1; then
  printf '%s already has MATRIX_SECRET; refusing to replace it\n' "$keycloak" >&2
  exit 1
fi

umask 077
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

rand() { openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c "$1"; }
db_password=$(rand 40)
macaroon=$(rand 64)
form_secret=$(rand 64)
mas_shared=$(rand 64)
client_secret=$(rand 48)
mas_encryption=$(openssl rand -hex 32)
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$work/rsa.pem" 2>/dev/null
openssl ecparam -name prime256v1 -genkey -noout -out "$work/ec.pem" 2>/dev/null
# Synapse's format: "ed25519 <key id> <unpadded base64 of the 32-byte seed>".
signing_key="ed25519 a_$(rand 4) $(openssl rand 32 | base64 | tr -d '=\n')"

indent() { sed 's/^/                  /' "$1"; }

cat > "$work/plain.yaml" <<YAML
apiVersion: isindir.github.com/v1alpha3
kind: SopsSecret
metadata:
  name: matrix
  namespace: matrix
spec:
  secretTemplates:
    # Synapse's database user, given to CNPG at bootstrap (database.yaml):
    # Synapse can't read a password from a file, so it's in its config too.
    - name: synapse-db-credentials
      type: kubernetes.io/basic-auth
      stringData:
        username: synapse
        password: "$db_password"
    # Loaded after synapse.yaml's homeserver.yaml; Synapse replaces whole
    # top-level keys, so each block here is complete.
    - name: synapse-secrets
      stringData:
        signing.key: "$signing_key"
        secrets.yaml: |
          database:
            name: psycopg2
            args:
              user: synapse
              password: "$db_password"
              dbname: synapse
              host: synapse-db-rw.matrix.svc.cluster.local
              port: 5432
              cp_min: 5
              cp_max: 10
              keepalives_idle: 10
              keepalives_interval: 10
              keepalives_count: 3
          macaroon_secret_key: "$macaroon"
          form_secret: "$form_secret"
          matrix_authentication_service:
            enabled: true
            endpoint: http://mas.matrix.svc.cluster.local:8080/
            secret: "$mas_shared"
    # Loaded after mas.yaml's config.yaml; these sections are only here.
    - name: mas-secrets
      stringData:
        secrets.yaml: |
          secrets:
            encryption: "$mas_encryption"
            keys:
              - kid: rsa-2026-10
                key: |
$(indent "$work/rsa.pem")
              - kid: ec-2026-10
                key: |
$(indent "$work/ec.pem")
          matrix:
            kind: synapse
            homeserver: yeetus.net
            endpoint: http://synapse.matrix.svc.cluster.local:8008
            secret: "$mas_shared"
          upstream_oauth2:
            providers:
              # Keycloak, realm network-yeetus, client "matrix" (realms.yaml).
              - id: "$provider_id"
                human_name: Yeetus Network
                issuer: https://auth.yeetus.net/realms/network-yeetus
                client_id: matrix
                client_secret: "$client_secret"
                token_endpoint_auth_method: client_secret_basic
                scope: openid profile email
                claims_imports:
                  # @<keycloak username>:yeetus.net, nothing to choose.
                  localpart:
                    action: require
                    template: "{{ user.preferred_username }}"
                  displayname:
                    action: force
                    template: "{{ user.name }}"
                  email:
                    action: force
                    template: "{{ user.email }}"
YAML

sops --encrypt --filename-override "$target" "$work/plain.yaml" > "$work/enc.yaml"
mv -- "$work/enc.yaml" "$target"

printf '%s' "\"$client_secret\"" | sops set --value-stdin "$keycloak" '["spec"]["secretTemplates"][0]["stringData"]["MATRIX_SECRET"]'

unset db_password macaroon form_secret mas_shared client_secret mas_encryption signing_key
printf 'Created %s and added MATRIX_SECRET to %s.\n' "$target" "$keycloak"
printf 'Keep a copy of Synapse'"'"'s signing key in Vaultwarden:\n'
printf '  sops decrypt --extract '"'"'["spec"]["secretTemplates"][1]["stringData"]["signing.key"]'"'"' %s\n' "$target"
