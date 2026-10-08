#!/usr/bin/env bash
# A read-only GitHub token for Hub, so reading the infrastructure and
# dotfiles repos isn't held to GitHub's 60 anonymous API calls an hour.
# Make it at https://github.com/settings/personal-access-tokens/new:
# fine-grained, "Public repositories" (read-only), no permissions added.
# Written encrypted to kubernetes/services/hub/github.sops.yaml and listed in
# that folder's hub.yaml; never in plain text. Commit both files after.
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

if ! command -v sops >/dev/null; then
  printf 'sops is required; run with: nix shell nixpkgs#sops -c bash %s\n' "$0" >&2
  exit 1
fi

dir=kubernetes/services/hub
target=$dir/github.sops.yaml
if [[ -e "$target" ]]; then
  printf 'Refusing to overwrite %s\n' "$target" >&2
  exit 1
fi

umask 077
tmp=$(mktemp "${target}.XXXXXX")
trap 'rm -f "$tmp"' EXIT

read -r -s -p 'GitHub token (read-only, input hidden): ' tok
printf '\n' >&2
if [[ ! "$tok" =~ ^(github_pat_|ghp_)[A-Za-z0-9_]+$ ]]; then
  printf 'That does not look like a GitHub token; no file was created.\n' >&2
  exit 1
fi

cat <<YAML | sops --encrypt --filename-override "$target" /dev/stdin > "$tmp"
apiVersion: isindir.github.com/v1alpha3
kind: SopsSecret
metadata:
  name: hub-github
  namespace: hub
spec:
  secretTemplates:
    - name: hub-github
      stringData:
        token: "$tok"
YAML
unset tok

mv -- "$tmp" "$target"
trap - EXIT

# hub render --check wants every file of the folder listed in hub.yaml.
if ! grep -qx -- '- github.sops.yaml' "$dir/hub.yaml"; then
  {
    sed '/^keep:$/q' "$dir/hub.yaml"
    { grep '^- ' "$dir/hub.yaml"; echo '- github.sops.yaml'; } | LC_ALL=C sort -u
    sed -n '/^keep:$/,$p' "$dir/hub.yaml" | sed '1d' | grep -v '^- '
  } > "$dir/hub.yaml.new"
  mv -- "$dir/hub.yaml.new" "$dir/hub.yaml"
fi
printf 'Encrypted SopsSecret created: %s (and listed in %s/hub.yaml)\n' "$target" "$dir"
printf 'Commit both: git add %s %s/hub.yaml && git commit -m "hub: a read-only GitHub token"\n' "$target" "$dir"
