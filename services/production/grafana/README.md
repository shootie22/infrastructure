# Grafana Monitoring Rollout

This stack now assumes centralized Prometheus scraping with per-host exporters exposed back to the Grafana host over loopback-bound FRP ports.

## Local Grafana Host

- `node-exporter` exposes host metrics to Prometheus on the internal Docker network.
- `cadvisor` exposes Docker/container metrics on `cadvisor:9101`.
- `apache-exporter` scrapes the local Apache `mod_status` endpoint from `http://host.docker.internal/server-status?auto`.
- `apache-ingress-exporter` tails `/var/log/apache2/ingress-metrics.log` and exposes per-vhost request, byte, and latency metrics from Apache access logs.
- `loki` stores centralized logs locally on the edge host.
- `promtail` on the edge host ships Apache and auth logs into Loki.
- Install [apache/server-status.conf](/home/krator/GitRepos/infrastructure/services/production/grafana/apache/server-status.conf) on the Grafana/edge host and reload Apache before enabling the exporter.
- Add the proxy rules from [apache/loki-proxy-snippet.conf](/home/krator/GitRepos/infrastructure/services/production/grafana/apache/loki-proxy-snippet.conf) to the real `mon.radunenu.com` Apache vhost before the catch-all `/` proxy so remote promtail agents can push to `https://mon.radunenu.com/loki/api/v1/push`.
- The remote promtail agents expect `LOKI_PUSH_USERNAME` and `LOKI_PUSH_PASSWORD` in their stack env.

## Remote Linux Hosts

- `thinkcentre-health-status` is upgraded into a real Linux monitoring bundle:
  - `127.0.0.1:5994` on the edge host maps to the ThinkCentre node exporter.
  - `127.0.0.1:5995` on the edge host maps to the ThinkCentre cAdvisor exporter.
  - local `promtail` ships `/var/log/auth.log` directly to central Loki over HTTPS.
- `hetzner-monitoring` provides the same host metrics plus a remote Nginx exporter:
  - `127.0.0.1:5991` node exporter
  - `127.0.0.1:5992` cAdvisor
  - `127.0.0.1:5993` Nginx exporter
  - local `promtail` ships `/var/log/auth.log` and Nginx logs directly to central Loki over HTTPS.
- `hetzner-synapse-metrics` provides a dedicated FRP path for the native Synapse metrics endpoint:
  - `synapse-frps:5996` from Prometheus on `monitoring_net`
  - local Synapse metrics endpoint expected on the Hetzner host at `127.0.0.1:8008/_synapse/metrics`
- Loki log shipping does not use FRP here; promtail pushes outbound directly to the edge Apache proxy.

## Grafana Assets

- Prometheus target inventories live under `prometheus/targets/`.
- Prometheus recording rules live under `prometheus/rules/`.
- Loki and promtail configs for the edge host live next to the Grafana stack root.
- The starter dashboard JSON is stored under `grafana/dashboards/`.
- Grafana dashboard provisioning is enabled through `grafana/provisioning/dashboards/default.yml`.
