#!/usr/bin/env bash
# Makes the pull secret for the private maec image (organization mentalasylum on
# Gitea): kubernetes/services/maec/registry-secret.sops.yaml, a
# kubernetes.io/dockerconfigjson secret "maec-registry" used by the
# Deployment and the updater. Asks for a Gitea token with read:package only
# (Settings > Applications on git.yeetus.net), made by the user named below.
# Run with: nix shell nixpkgs#sops -c bash scripts/create-maec-registry-secret.sh
set -euo pipefail
repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"
command -v sops >/dev/null || { echo 'sops is required: nix shell nixpkgs#sops -c bash' "$0" >&2; exit 1; }
target=kubernetes/services/maec/registry-secret.sops.yaml
[[ -e "$target" ]] && { echo "Refusing to overwrite $target" >&2; exit 1; }

read -r -p 'Gitea user that owns the token [radu]: ' user
user=${user:-radu}
read -r -s -p 'Token with read:package (input hidden): ' token
printf '\n' >&2
[[ "$token" =~ ^[A-Za-z0-9_-]+$ ]] || { echo 'Missing or unexpected token; nothing written.' >&2; exit 1; }

umask 077
auth=$(printf '%s:%s' "$user" "$token" | base64 -w0)
# Both names of the one Gitea: the nodes pull through git.radunenu.com (pinned
# to the mesh), people know it as git.yeetus.net.
config=$(printf '{"auths":{"git.radunenu.com":{"auth":"%s"},"git.yeetus.net":{"auth":"%s"}}}' "$auth" "$auth")
cat <<YAML | sops --encrypt --filename-override "$target" /dev/stdin > "$target"
apiVersion: isindir.github.com/v1alpha3
kind: SopsSecret
metadata:
  name: maec-registry
  namespace: maec
spec:
  secretTemplates:
    - name: maec-registry
      type: kubernetes.io/dockerconfigjson
      stringData:
        .dockerconfigjson: '$config'
YAML
unset token auth config
# List it in hub.yaml (every file in the folder must be).
hub=kubernetes/services/maec/hub.yaml
grep -q "^- registry-secret.sops.yaml$" "$hub" || sed -i "s/^- secret.sops.yaml$/- registry-secret.sops.yaml\n- secret.sops.yaml/" "$hub"
echo "Encrypted: $target (and listed in $hub)"
