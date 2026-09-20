# Kubernetes monitoring

This directory is the declarative source of truth for the K3s observability
stack. Argo CD discovers it through the services `ApplicationSet`.

## Core dashboards

Grafana provisions the following drill-down path in the `Observability` folder:

1. **Platform Overview** — availability, workload health, capacity, active
   alerts, public probes, and recent warning Events.
2. **Nodes / Hosts** — Linux USE signals, filesystems, disks, network, and
   kubelet-reported PVC usage for Fuji, ThinkCentre, and mixi.
3. **Kubernetes Workloads** — replica health, pod stability, workload CPU and
   memory, requests, readiness, OOM terminations, and top consumers.
4. **Pod / Container Drilldown** — pod state, placement, restart history,
   container resources, Events, and correlated logs.
5. **Kubernetes Logs** — namespace → app → pod → container investigation,
   volume concentration, explicit error/warning token trends, raw logs, and
   Kubernetes Events.
6. **Edge / Traefik** — request rate, status classes, error ratios, latency,
   routers, service errors/latency, bytes, connections, and internal public
   probes. Traefik active-health-check state is omitted because the live routes
   do not emit `traefik_service_server_up`.
7. **Observability Stack** — Prometheus, Loki, Alloy, Grafana, exporters,
   scrape/rule health, ingestion, and log-forwarding failures.

The older Edge, Fleet Overview, Containers, Logs, Synapse, and LiveKit
dashboards remain mounted during the transition. Synapse and LiveKit are kept
as application deep dives until those metrics are connected to this Prometheus.

## Dashboard generation

`generate-dashboards.py` is the human-maintained source for the seven core
dashboard ConfigMaps. It uses only Python's standard library and emits one
ConfigMap per dashboard to avoid large client-side apply annotations.

```bash
nix-shell -p python3 --run \
  'python3 kubernetes/services/monitoring/generate-dashboards.py'
git diff --exit-code -- kubernetes/services/monitoring/grafana-dashboard-*-configmap.yaml
```

Grafana provisioning is read-only (`allowUiUpdates: false`); durable edits must
be made in the generator and reconciled through Git.

Static validation requires PyYAML:

```bash
nix-shell -p python3Packages.pyyaml --run \
  'python3 kubernetes/services/monitoring/validate-monitoring.py'
```

Prometheus configuration and both rule files must also be checked using the
`promtool` version shipped with Prometheus 3.9.1.

## Added telemetry

- Traefik's existing Prometheus endpoint is exposed through a dedicated,
  internal metrics Service by `kubernetes/argocd/traefik-config.yaml`. Router
  labels are enabled; no path, client IP, request ID, or header labels are
  added.
- Loki and all Alloy endpoints are scraped through annotated Services.
- A singleton Alloy Deployment collects Kubernetes Events into Loki with only
  the low-cardinality `job`, `namespace`, and collector `instance` stream
  labels. Event fields remain logfmt content and are parsed at query time.
- The Kubernetes API server `/metrics` endpoint is scraped with the Prometheus
  ServiceAccount token and the minimum non-resource RBAC permission.
- blackbox-exporter probes the public Grafana, Headscale, and Element Call
  endpoints from Fuji. This detects DNS/connect/TLS/HTTP failure from the
  cluster but is explicitly not outside-in monitoring.
- Prometheus uses the official Prometheus Operator config reloader sidecar and
  lifecycle endpoint so ConfigMap changes reload without a manual restart.

Node journals are not collected. Adding privileged host journal mounts solely
for broad system logs was not proportionate; focused k3s and kernel-error
collection can be reconsidered after retention and noise are measured.

## Secrets

Grafana requires the `grafana-auth` Secret created by the SOPS Secrets Operator.
Copy `grafana-secret.sops.yaml.example`, provide real values, encrypt the
`secretTemplates` field with the repository's Age recipient, and save it as
`grafana-secret.sops.yaml`. The example file is not applied by Argo.

The legacy OVH/FRP targets are documented in
`transitional-external-targets.md` and deliberately remain disabled. ThinkCentre
is already represented natively by K3s; Hetzner, Synapse, and LiveKit require a
new connectivity decision that does not depend on OVH.
