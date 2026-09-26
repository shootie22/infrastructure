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

## Edge / Traefik

- Preserve existing panel positions. Break out 4xx and 5xx by route, backend and
  exact status, with error counts over the selected interval and request evidence.
- Add filtered JSON access logging through chart `additionalArguments`: all
  errors or requests taking at least 1 second; headers are dropped. Alloy already
  collects Traefik stdout. This requires a Traefik rollout and has no backfill.
- Request evidence can narrow host, path, router, service, entrypoint and status.
  All retains unmatched-route errors. Expand a line to compare downstream and
  origin status and duration. Router/service metrics lack entrypoint labels, so
  their filter boundaries are explicitly described.
- Error-ratio zero fallback now depends on existing traffic series. Scrape health
  is shown independently. Access logging is filtered, not a full request ledger.
- Validated with Prometheus 3.9.1, Loki 2.9.8, synthetic unmatched 404 and backend
  502 log fixtures, and Helm rendering against upstream chart 40.1.0 (operator
  reports K3s chart 40.1.4+up40.1.0). Live rendering awaits deployment.

## Platform Overview

- Fix host legends using the same historical normalization as Nodes / Hosts.
- Add target availability history, named node pressure conditions, workload CPU,
  unavailable replicas, container waiting reasons, and probe status codes.
- Keep existing panel coordinates; selected-range restart counts replace fixed
  one-hour counts. Give alert value columns a meaningful name and retain identity.
- The overview distinguishes Kubernetes workload CPU from external host CPU;
  external Docker attribution remains on Nodes / Hosts.

## Remaining sweep

Kubernetes Logs, Observability Stack, Synapse,
LiveKit / Element Call.

## Kubernetes Workloads

- Add historical per-container CPU, throttling, waiting reasons, owner-scoped
  pod events and logs. The evidence pod selector expands All to the owner's pod
  names rather than matching every pod in a namespace.
- Rank workload CPU/memory by peak in the selected range; restart counts also
  use the selected range. These retain evidence a current-only ranking missed.
- Explicitly label namespace-wide replica health: it must include workloads
  with no pods, which cannot be discovered through a pod-owner join.
- Give table values readable names. Workload aggregate resource panels remain
  aggregates; Evidence pod narrows the pod status and investigation panels.

## Pod / Container Drilldown

- Preserve pod identity in CPU/memory series when several pods have containers
  with the same name; previously those containers were merged.
- Make workload selection optional and expand All pods to the selected owners.
  Incoming pod links no longer inherit a fixed Prometheus workload.
- Add throttled-period ratio, waiting/last-termination history and working set
  relative to positive memory limits, beside the existing logs/events evidence.
- Merge waiting/termination table frames with meaningful value column names.
  Last termination is explicitly a retained state, not a fresh event count.
