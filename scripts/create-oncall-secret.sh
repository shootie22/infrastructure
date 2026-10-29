#!/usr/bin/env bash
# Makes the two secrets for the on-call agent (kubernetes/services/oncall):
#   oncall/secret.sops.yaml                  the agent's and its Matrix bot's
#   monitoring/alertmanager-oncall.sops.yaml the same webhook token, for
#                                            Alertmanager to send alerts with
# The tokens between the three (Alertmanager, agent, bot) and the bot's
# encryption pickle key are made here. Asked for, never echoed:
#   - the bot's Matrix access token (a fresh login of @oncall:nuke.zip,
#     docs/ha/runbooks/oncall-agent.md), required
#   - a Claude API key, from a workspace with a monthly spend limit; empty
#     means no escalation, only the local model's reports
#   - Pushover's app token and user key (the alert relay's will do); empty
#     means no pings
# No key is needed: sops only encrypts.
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

if ! command -v sops >/dev/null; then
  printf 'sops is required; run with: nix shell nixpkgs#sops -c bash %s\n' "$0" >&2
  exit 1
fi

app_target=kubernetes/services/oncall/secret.sops.yaml
am_target=kubernetes/services/monitoring/alertmanager-oncall.sops.yaml
for target in "$app_target" "$am_target"; do
  if [[ -e "$target" ]]; then
    printf 'Refusing to overwrite %s\n' "$target" >&2
    exit 1
  fi
done

ask() {
  local prompt=$1 value
  read -rsp "$prompt: " value </dev/tty
  printf '\n' >&2
  printf '%s' "$value"
}
matrix_token=$(ask "Matrix access token of @oncall:nuke.zip")
if [[ -z "$matrix_token" ]]; then
  printf 'The Matrix access token is required.\n' >&2
  exit 1
fi
anthropic_key=$(ask "Claude API key (empty: no escalation)")
pushover_token=$(ask "Pushover app token (empty: no pings)")
pushover_user=""
if [[ -n "$pushover_token" ]]; then
  pushover_user=$(ask "Pushover user key")
fi

umask 077
app_tmp=$(mktemp "${app_target}.XXXXXX")
am_tmp=$(mktemp "${am_target}.XXXXXX")
trap 'rm -f "$app_tmp" "$am_tmp"' EXIT

# 32 random bytes, URL-safe base64.
random() { head -c 32 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=\n'; }
webhook_token=$(random)

# Optional keys are left out rather than empty: the agent treats a missing
# file as not set.
optional() {
  if [[ -n "$2" ]]; then
    printf '        %s: "%s"\n' "$1" "$2"
  fi
}

{
  cat <<YAML
apiVersion: isindir.github.com/v1alpha3
kind: SopsSecret
metadata:
  name: oncall
  namespace: oncall
spec:
  secretTemplates:
    - name: oncall
      stringData:
        webhook-token: "$webhook_token"
        bot-token: "$(random)"
        matrix-pickle-key: "$(random)"
        matrix-access-token: "$matrix_token"
YAML
  optional anthropic-api-key "$anthropic_key"
  optional pushover-token "$pushover_token"
  optional pushover-user "$pushover_user"
} | sops --encrypt --filename-override "$app_target" /dev/stdin > "$app_tmp"

cat <<YAML | sops --encrypt --filename-override "$am_target" /dev/stdin > "$am_tmp"
apiVersion: isindir.github.com/v1alpha3
kind: SopsSecret
metadata:
  name: alertmanager-oncall
  namespace: monitoring
spec:
  secretTemplates:
    - name: alertmanager-oncall
      stringData:
        token: "$webhook_token"
YAML
unset webhook_token matrix_token anthropic_key pushover_token pushover_user

mv -- "$app_tmp" "$app_target"
mv -- "$am_tmp" "$am_target"
trap - EXIT
printf 'Encrypted SopsSecrets created:\n  %s\n  %s\n' "$app_target" "$am_target"
