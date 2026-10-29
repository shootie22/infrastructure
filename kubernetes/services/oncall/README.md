# On-call agent

Alertmanager sends every alert here. For each one, the agent reads what it takes to explain it and posts a
short report to `#oncall` on nuke.zip, one thread per incident. The first message is short enough for a
lock screen: what's wrong, the impact, the likely cause and how sure it is, and what to do. The evidence
is in the thread under it, each claim with the line it rests on.

It only reads. It can't change the cluster, the repos or Alertmanager. The alert relay (edge, mixi) still
delivers every alert as before; this only adds the explanation. How it works and what to do when it
misbehaves: [docs/ha/runbooks/oncall-agent.md](../../../docs/ha/runbooks/oncall-agent.md). The code is
`hub oncall`, in infra-hub `internal/oncall`.

- `deployment.yaml`: one pod on the thinkcentre, with two containers. `hub oncall` does the work.
  `matrix-webhook-bot` holds the Matrix login and encryption keys of `@oncall:nuke.zip`, and posts to the
  room what the agent hands it.
- `env.yaml`: its settings: the room, the models, the Claude budgets, Pushover on or off.
- `collectors-configmap.yaml`: what it reads for which alerts before any model sees them.
- `rbac.yaml`: Hub's read-only role (`hub-reader`), bound to its own account.
- `networkpolicy.yaml`: in, Alertmanager and Prometheus only. Out, DNS, the monitoring stack, minima's
  Ollama, the API server and HTTPS.
- `pvc.yaml`: the bot's encryption keys and the agent's state (open incidents, this month's spend).
- `secret.sops.yaml`: the tokens between Alertmanager, agent and bot, the bot's login, the Claude key, and
  Pushover's keys. `monitoring/alertmanager-oncall.sops.yaml` has the webhook token for Alertmanager.
- `../monitoring/alertmanager.yaml` sends it every alert (the `relay` receiver's third webhook).
  `../monitoring/prometheus-configmap.yaml` has `OncallAgentDown`, `OncallReportsFailing` and
  `OncallLocalModelFailing`. `../monitoring/loki-alloy-configmap.yaml` ships the hosts' kernel logs and
  system warnings (`{job="node-journal"}`), which the agent reads for host alerts.

## First-time setup

1. The bot's account and room on nuke.zip (hetzy's Synapse): register `@oncall:nuke.zip`, then log it in
   once for an access token (README of matrix-webhook-bot, "First-time setup for encrypted rooms"). Make an
   encrypted room `#oncall`, invite the bot, and turn its notifications on in Element. Put the room's ID in
   `env.yaml` (`ONCALL_MATRIX_ROOM`).
2. A Claude API key from its own workspace in the Console, with a monthly spend limit there too ($30
   matches `ONCALL_BUDGET_MONTH_USD`). Optional: without it, only the local model writes reports.
3. The secrets: `nix shell nixpkgs#sops -c bash scripts/create-oncall-secret.sh`. It asks for the bot's
   access token, the Claude key and Pushover's keys (the alert relay's), and makes the rest. CI's
   `hub render --check` fails until both secret files exist.
4. The local model, once, on minima: `kubectl -n ollama exec deploy/ollama -- ollama pull qwen3.5:9b`.
5. matrix-webhook-bot `v0.0.9` (the send API) built; pin it by digest in `deployment.yaml`.
6. Merge. Then verify the bot's device from Element (it retries its encryption setup every 5 minutes;
   until then it refuses to post into the encrypted room, and `OncallReportsFailing` fires), and
   test with a fake alert:
   `kubectl -n monitoring exec alertmanager-0 -- amtool alert add OncallTest severity=warning namespace=mealie --annotation=summary="test from the runbook" --alertmanager.url=http://localhost:9093`.
   A thread should appear in `#oncall` within about 3 minutes. The relay sends this one to the phone
   too.
