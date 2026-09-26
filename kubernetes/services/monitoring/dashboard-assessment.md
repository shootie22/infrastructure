# Active dashboard assessment

Work through dashboards individually; keep Archive unchanged. Changes are committed
per dashboard. Local validation does not establish that live metrics exist or that
Grafana rendered correctly. No deployment or push is implied by a local commit.

## Nodes / Hosts

- Keep the original panel positions; append historical container CPU/memory,
  CPU modes, fan RPM and temperature for spike investigation.
- Normalize external `host` labels to `node` in queries, including old samples,
  so filtering and legends work for both Kubernetes and Hetzner.
- Label kubelet PVC numbers as backing filesystem utilization. Shared local-path
  filesystems can report the same utilization for several claims. Requested sizes
  are not measured consumption or local-path quotas. Scope both panels to nodes.
- Select a host, then drag over a CPU spike: all time series use the dashboard
  range, including container attribution. Container CPU is in cores; host CPU is
  a fraction of total CPUs. CPU modes distinguish iowait and steal.
- Host processes outside containers are not attributed by current collection.
  Fan sensors depend on hardware/driver exposure; absent data is not zero RPM.
- Pending operator evidence: backing volumes, fan metrics, container label/data
  availability, and rendered dashboard verification after deployment.

## Remaining sweep

Edge / Traefik, Platform Overview, Kubernetes Workloads, Pod / Container
Drilldown, Kubernetes Logs, Observability Stack, Synapse, LiveKit / Element Call.
