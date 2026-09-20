# External observability audit

Audit date: 2026-09-20. This is an inventory and migration plan, not authority
to change or restart the Matrix application stack.

## Hetzner findings

- `ec.nuke.zip` currently resolves directly to the Hetzner host
  (`195.201.129.220`). Hetzner is not a member of the current Headscale tailnet.
- The repository defines independent node-exporter (`:9100`), cAdvisor
  (`:9101`), nginx-exporter (`:9102`), Promtail (`:9080`), and FRP clients.
  These collectors are separate from the Matrix application lifecycle.
- Read-only probes from Fuji found all four exporter/collector HTTP ports
  reachable on the public address. They are plaintext and unauthenticated, so
  Fuji deliberately does not adopt them as permanent scrape targets.
- Synapse metrics are expected at the Hetzner loopback listener
  `127.0.0.1:8008/_synapse/metrics`; LiveKit at `127.0.0.1:6789/metrics`; and
  the optional quality exporter at `127.0.0.1:6790/metrics`. None is publicly
  reachable. Existing FRP clients forward them to OVH-local FRP servers.
- The Hetzner Promtail config targets
  `https://mon.radunenu.com/loki/api/v1/push` using credentials held only in
  the remote encrypted environment. The new Fuji Loki contains no `host=hetzner`
  or `job=livekit` streams, so remote log delivery is not currently reaching it.
- Key-based SSH from Fuji was not authorized. No remote configuration, process,
  container, firewall, or application was changed or restarted.

## Safe reconnection boundary

The preferred implementation is an independent, host-level secure path from
Hetzner to Fuji (Headscale/Tailscale if approved for that host, or a narrowly
scoped WireGuard/SSH tunnel). Exporter and application metric listeners should
remain loopback- or overlay-only. Fuji can then scrape them with static targets,
without making Matrix depend on Fuji.

For logs, deploy an independent Alloy/Promtail collector that reads only
Synapse errors/warnings, LiveKit application logs, and nginx logs needed for
availability investigations. Send over the secure path to Loki, with labels
limited to `host`, `app`/`service`, and optionally `environment`. Do not retain
the existing broad `auth.log` collection, and do not promote user IDs, client
IPs, request IDs, rooms, participants, paths, or message content to labels.

This work can be done by restarting only monitoring collectors/tunnels. If an
application metrics listener is not already enabled, leave that source blocked
rather than restarting Synapse or LiveKit.

## OVH dependency inventory

The legacy OVH monitoring deployment still defines Grafana, Prometheus, Loki,
Promtail, node-exporter, cAdvisor, Apache/mtail exporters, and FRP server
containers. The FRP servers are the current rendezvous for:

- Hetzner node-exporter, cAdvisor, and nginx-exporter;
- Synapse native metrics;
- LiveKit native metrics;
- LiveKit quality metrics;
- older ThinkCentre monitoring paths (obsolete because K3s now covers it).

The old Prometheus target files consume those OVH-local aliases. The old local
Promtail also feeds OVH host logs into the old Loki. Public Grafana DNS and
ingress have moved to Fuji, but that does not remove these internal consumers.

Therefore the OVH monitoring stack is **not safe to retire yet**. Keep its
configuration and historical data intact. After Hetzner metrics/logs are proven
healthy in Fuji, verify the old Prometheus has no remaining unique targets and
the old Loki has no active remote writers; then stop only the monitoring
containers while retaining data/configuration for rollback. Unrelated OVH
services are out of scope.
