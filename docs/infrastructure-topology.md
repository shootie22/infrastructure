# Infrastructure Topology

This document explains the mental model behind the repository so future changes can be made without reverse-engineering deployment patterns from individual compose files.

## Overview

This environment uses a centralized edge model:

- One edge host acts as the public entrypoint.
- Multiple remote hosts run services privately.
- Remote hosts connect back to the edge host using FRP or rathole patterns.
- Public traffic is served through the edge host, which currently uses Apache as the main reverse proxy layer.

This means service exposure is generally inward-to-edge, not direct-from-host-to-internet.

## Host Roles

Known host categories in the current environment include:

- Edge host:
  - central ingress
  - centralized Grafana and Prometheus
  - edge-side `frps` listeners
  - reverse proxy responsibilities
- Linux remote hosts:
  - application workloads
  - host exporters and service exporters
  - remote-side `frpc` connectors back to edge
- Mac hosts:
  - present in the environment
  - not interchangeable with Linux hosts for host-metrics exporters

Known examples at the time of writing:

- `thinkcentre`: Linux remote host
- `hetzner`: Linux remote host
- Mac minis: present but not part of the current Linux monitoring baseline

## Service Exposure Pattern

The common pattern is:

1. A service or exporter runs on a remote host.
2. An `frpc` instance on that remote host connects to the edge host.
3. A matching `frps` listener on the edge host exposes the remote endpoint to the edge environment.
4. Edge-side reverse proxying or centralized scraping reaches that exposed endpoint.

Practical implications:

- `frps` stacks belong on the edge host.
- `frpc` stacks belong on the remote host.
- Edge-side port allocations are part of the architecture and should be treated as shared infrastructure state.

## Monitoring Topology

Monitoring is centralized:

- Grafana and Prometheus run on the edge host in `services/production/grafana`.
- Linux hosts use:
  - `node-exporter` for host metrics
  - `cadvisor` for container metrics
- HTTP services can use server-specific exporters such as:
  - Apache exporter
  - Nginx Prometheus exporter

Current baseline:

- Edge host:
  - local `node-exporter`
  - local `cadvisor`
  - local Apache exporter
- ThinkCentre:
  - `node-exporter`
  - `cadvisor`
  - FRP back to edge
- Hetzner:
  - `node-exporter`
  - `cadvisor`
  - Nginx exporter
  - FRP back to edge

Monitoring communication details:

- Prometheus target inventories are maintained centrally under `services/production/grafana/prometheus/targets/`.
- Grafana dashboards are provisioned from disk under `services/production/grafana/grafana/dashboards/`.
- Shared cross-project Docker networking for monitoring uses `monitoring_net`.

## Docker And Non-Docker Workloads

Not all workloads are equal from a monitoring perspective:

- Docker workloads are visible through `cadvisor`.
- Host metrics come from `node-exporter`.
- Host-managed or `systemd` services are not automatically visible through `cadvisor`.

This matters for services such as:

- host-managed Nginx
- `systemd` bots
- any other service not running in Docker

Those services need either:

- service-specific exporters
- process/systemd-oriented monitoring
- or blackbox/HTTP health checks

## Secrets And Deployment Model

Secrets are typically handled like this:

- encrypted `.env` is the tracked source of truth
- `age.pub` identifies the recipient used for that stack
- local plaintext `runtime.env` is generated for deployment and is gitignored

Important rule:

- Do not treat local `runtime.env` changes as durable repository changes.
- If a new stack or new env variable matters for future deployments, ensure the tracked encrypted `.env` flow is updated where applicable.

## Port And Naming Guidance

When adding new remote monitoring or tunnelled services:

- choose non-conflicting edge ports
- verify existing FRP allocations before choosing new ones
- keep host labels and scrape target labels consistent
- prefer descriptive Docker network names such as `monitoring_net`

When multiple compose projects must communicate by Docker DNS:

- use a shared external Docker network
- avoid relying on host loopback from inside containers
- recreate containers if aliases or shared-network attachments change and DNS looks stale

## Recommended Workflow For Future Monitoring Changes

For new monitoring additions:

1. Decide whether the target is host-level, container-level, or service-level.
2. Determine which host owns the workload.
3. If the workload is remote, add or reuse the edge-side `frps` and remote-side `frpc` path.
4. Add centralized Prometheus scrape targets under `services/production/grafana/prometheus/targets/`.
5. Add or update Grafana dashboards under `services/production/grafana/grafana/dashboards/`.
6. Validate from three layers:
   - local exporter endpoint on the remote host
   - edge-side FRP-exposed endpoint
   - Prometheus target health and dashboard behavior

## Things To Verify Explicitly

- A service name in the repo does not automatically reveal which physical host runs it.
- A host with existing health checks is not necessarily fully monitored.
- Linux exporter patterns do not automatically apply to Mac hosts.
- `up` in Prometheus does not always mean every expected metric series is present; check sample freshness and specific series when dashboards look odd.
