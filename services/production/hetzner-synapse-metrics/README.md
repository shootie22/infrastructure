# Hetzner Synapse Metrics

This stack exposes the native Synapse metrics listener from the Hetzner host back to the edge Prometheus instance through FRP.

## Expected Synapse Host Configuration

Configure Synapse on the Hetzner host with metrics enabled on its existing local-only listener:

```yaml
enable_metrics: true

listeners:
  - port: 8008
    tls: false
    type: http
    x_forwarded: true
    bind_addresses:
      - '::1'
      - '127.0.0.1'
    resources:
      - names: [client, federation, metrics]
```

Prometheus scrapes the tunneled endpoint with `metrics_path: /_synapse/metrics`.

## Deployment Split

- Deploy [frps/docker-compose.yml](/home/krator/GitRepos/infrastructure/services/production/hetzner-synapse-metrics/frps/docker-compose.yml) on the edge host.
- Deploy [hetzner-synapse-metrics/docker-compose.yml](/home/krator/GitRepos/infrastructure/services/production/hetzner-synapse-metrics/hetzner-synapse-metrics/docker-compose.yml) on the Hetzner host.
