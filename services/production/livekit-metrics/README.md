# LiveKit Metrics

This stack exposes the LiveKit (Element Call SFU) Prometheus endpoint from the
Hetzner host back to the edge Prometheus instance through FRP.

LiveKit binds its metrics port to loopback only (`127.0.0.1:6789`), so it is not
reachable off-box. An `frpc` sidecar on the LiveKit host tunnels it to the edge
`frps`, which Prometheus reaches over `monitoring_net`.

## Expected LiveKit Host Configuration

LiveKit must have its Prometheus listener enabled on the local-only port:

```yaml
prometheus_port: 6789
```

The container already publishes this as `127.0.0.1:6789->6789/tcp`. Prometheus
scrapes the tunneled endpoint with `metrics_path: /metrics`.

## Deployment Split

- Deploy [frps/docker-compose.yml](/home/krator/GitRepos/infrastructure/services/production/livekit-metrics/frps/docker-compose.yml) on the edge host.
- Deploy [livekit-metrics/docker-compose.yml](/home/krator/GitRepos/infrastructure/services/production/livekit-metrics/livekit-metrics/docker-compose.yml) on the LiveKit (Hetzner) host.

The edge `frps` joins `monitoring_net` with alias `livekit-frps`; Prometheus
scrapes `livekit-frps:5997` (see `grafana/prometheus/targets/livekit.yml`).
