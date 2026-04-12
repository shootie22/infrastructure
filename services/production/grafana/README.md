# Grafana Monitoring Rollout

This stack now assumes centralized Prometheus scraping with per-host exporters exposed back to the Grafana host over loopback-bound FRP ports.

## Local Grafana Host

- `node-exporter` exposes host metrics to Prometheus on the internal Docker network.
- `cadvisor` exposes Docker/container metrics on `cadvisor:9101`.
- `apache-exporter` scrapes the local Apache `mod_status` endpoint from `http://host.docker.internal/server-status?auto`.
- `apache-ingress-exporter` tails `/var/log/apache2/ingress-metrics.log` and exposes per-vhost request, byte, and latency metrics from Apache access logs.
- Install [apache/server-status.conf](/home/krator/GitRepos/infrastructure/services/production/grafana/apache/server-status.conf) on the Grafana/edge host and reload Apache before enabling the exporter.

## Remote Linux Hosts

- `thinkcentre-health-status` is upgraded into a real Linux monitoring bundle:
  - `127.0.0.1:5994` on the edge host maps to the ThinkCentre node exporter.
  - `127.0.0.1:5995` on the edge host maps to the ThinkCentre cAdvisor exporter.
- `hetzner-monitoring` provides the same host metrics plus a remote Nginx exporter:
  - `127.0.0.1:5991` node exporter
  - `127.0.0.1:5992` cAdvisor
  - `127.0.0.1:5993` Nginx exporter
- `hetzner-synapse-metrics` provides a dedicated FRP path for the native Synapse metrics endpoint:
  - `synapse-frps:5996` from Prometheus on `monitoring_net`
  - local Synapse metrics endpoint expected on the Hetzner host at `127.0.0.1:8008/_synapse/metrics`

## Grafana Assets

- Prometheus target inventories live under `prometheus/targets/`.
- Prometheus recording rules live under `prometheus/rules/`.
- The starter dashboard JSON is stored under `grafana/dashboards/`.
- Grafana dashboard provisioning is enabled through `grafana/provisioning/dashboards/default.yml`.
