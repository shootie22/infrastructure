# Observability design notes

## Operational model

Each core dashboard has one question and follows overview → workload/node → pod
and logs drill-down. Availability and user-impact symptoms are placed before
resource utilization. Red is reserved for unavailable state, failed probes,
firing alerts, or critically low capacity; ordinary CPU and memory variation is
shown without incident thresholds.

The dashboards use the repository's real scrape model:

- `node` from node discovery for node-exporter, kubelet, and cAdvisor;
- `namespace`, `pod`, and `container` from kube-state-metrics/cAdvisor;
- a small `namespace_workload_pod:kube_pod_owner:relabel` recording rule for
  Kubernetes workload ownership;
- Loki's indexed `namespace`, `app`, `pod`, `container`, `job`, and `instance`
  labels only;
- `kubernetes_service` for discovered scrape targets, avoiding collisions with
  exporters such as Traefik that already expose a meaningful `service` label.

No synthetic `host` label or Prometheus Operator `cluster`/`metrics_path`
assumption is introduced.

## Upstream engineering references

- [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus) and
  [kube-prometheus-stack dashboards](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack/templates/grafana): adopted the
  cluster → namespace/workload → pod hierarchy, separate usage/request/limit
  context, and focused node/resource dashboards. Queries were rewritten for
  this repository's jobs and labels rather than importing generated dashboards.
- [kubernetes-mixin](https://github.com/kubernetes-monitoring/kubernetes-mixin):
  adapted its pod-owner semantic record and workload aggregation pattern, and
  its symptom-oriented availability/restart/unschedulable rules. Only the
  abstractions reused by this small cluster were retained.
- [Grafana Kubernetes Monitoring](https://grafana.com/docs/grafana-cloud/observe-and-act/monitor-infrastructure/kubernetes-monitoring/): adopted the stability,
  infrastructure, and availability triage flow; metrics-to-logs context; and a
  singleton collector for Kubernetes Events. Cloud-only components and broad
  telemetry collection were not imported.
- [Prometheus instrumentation](https://prometheus.io/docs/practices/instrumentation/),
  [recording rules](https://prometheus.io/docs/practices/rules/), and
  [alerting](https://prometheus.io/docs/practices/alerting/): used RED for HTTP
  traffic, USE for nodes, `level:metric:operations` recording names, aggregated
  numerators/denominators, low-cardinality labels, sustained `for` durations,
  and a small symptom/action-oriented alert set.
- [Grafana dashboard best practices](https://grafana.com/docs/grafana/latest/visualizations/dashboards/build-dashboards/best-practices/) and
  [dashboard links](https://grafana.com/docs/grafana/latest/visualizations/dashboards/build-dashboards/manage-dashboard-links/): adopted question-oriented
  dashboards, top-to-bottom information hierarchy, consistent variables,
  24-column layout, and preserved time/variable context during drill-down.
- [Loki meta-monitoring](https://grafana.com/docs/loki/latest/operations/meta-monitoring/)
  and the [Loki mixin](https://github.com/grafana/loki/tree/main/production/loki-mixin):
  selected practical single-binary ingestion/rejection/request signals and
  Alloy send/retry/drop metrics instead of importing distributed-mode panels.
- [Traefik metrics](https://doc.traefik.io/traefik/observe/metrics/) and its
  [HTTP metric catalog](https://doc.traefik.io/traefik/v3.0/observability/metrics/overview/):
  used official entrypoint/router/service counters and histograms, enabled
  bounded router labels, and avoided per-path/client/header cardinality.
- [blackbox-exporter](https://github.com/prometheus/blackbox_exporter): adopted
  the multi-target exporter pattern for DNS/connect/TLS/HTTP reachability.

## Deliberate omissions

- No new Synapse or LiveKit overview is provisioned until live application
  metrics reach this Prometheus; the detailed legacy dashboards remain.
- Scheduler and controller-manager metrics are not forced open on K3s. The API
  server is scraped through its authenticated Kubernetes Service; the embedded
  control-plane components remain a documented gap.
- No etcd telemetry is configured because this cluster uses SQLite.
- No notification system is introduced. Prometheus alert rules populate
  `ALERTS` and establish semantics, but Alertmanager/contact-point delivery is a
  separate operator decision.
- No broad host journal or authentication-log ingestion is enabled.
- CPU throttling panels are omitted for now: the kubelet exposes the cAdvisor
  CFS metric names, but the live cluster has no current non-infrastructure
  container series for them. Shipping those panels would create permanent
  `No data` rather than an actionable signal.
- Traefik active backend-health panels are omitted because the live endpoint
  does not emit `traefik_service_server_up` without configured active health
  checks. Service 5xx symptoms and service p95 latency are used instead.
