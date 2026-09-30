# Plan

## Layout

Two sites and a cheap VPS. RO can port forward; DK can't.

| | RO | DK | Edge VPS |
|---|---|---|---|
| etcd member | fuji | thinkcentre | yes, etcd only |
| Workers | minima | mixi | none |
| Public traffic | normal path | never directly | only when RO is down |
| Postgres (CNPG) | one instance | one instance | none |

Three etcd members in three places means any one of them can go away and the other two still have a majority.

The edge runs no services. It has three jobs: the third etcd vote, a TCP pass-through into Traefik in RO and DK, and possibly a DERP relay. If it dies, nothing visible happens.

## Traffic

DNS normally points only at RO, so everyday traffic uses the gigabit line at home and never touches the edge. Health checkers on the edge and in DK watch RO. If RO stops answering, they switch the records to the edge, which forwards to DK over the tailnet. With a 60s TTL that takes about 1-3 minutes.

DNS is served by two providers (Cloudflare and one more), both fed from DNSControl in this repo, so a DNS provider outage doesn't take everything down either.

## Phases

Each phase is a milestone with one issue per step.

| Phase | What it gets us |
|---|---|
| [0. Declarative DNS](https://github.com/shootie22/infrastructure/milestone/1) | All zones in Git, served by two providers |
| [1. Edge VPS](https://github.com/shootie22/infrastructure/milestone/2) | NixOS edge that can be replaced in minutes |
| [2. Thinkcentre on NixOS](https://github.com/shootie22/infrastructure/milestone/3) | The last Debian node, and the DK control plane server |
| [3. HA control plane](https://github.com/shootie22/infrastructure/milestone/4) | etcd across fuji, thinkcentre and edge |
| [4. Replicated Postgres](https://github.com/shootie22/infrastructure/milestone/5) | CNPG template, one instance per site |
| [5. Keycloak HA](https://github.com/shootie22/infrastructure/milestone/6) | Keycloak and Headscale survive losing a site |
| [6. Failover path](https://github.com/shootie22/infrastructure/milestone/7) | Edge proxy and DNS failover |
| [7. Failure drills](https://github.com/shootie22/infrastructure/milestone/8) | Break things on purpose, time the recovery |

Running alongside: [Housekeeping](https://github.com/shootie22/infrastructure/milestone/9) (certs, alerts, keys) and the [Infra map](https://github.com/shootie22/infrastructure/milestone/10).

Rough estimate: 4-8 weeks of evenings and weekends. Phase 2 and Phase 3 are the risky ones.

## Cost

About 2-3 GB of extra RAM across the cluster and very little CPU: etcd on two nodes, a second Keycloak, a Postgres replica and the operators. The edge VPS is the only new monthly cost.

## Domains

See [dns-inventory.md](dns-inventory.md): registrars, expiry dates, every record, and what to keep or delete.
