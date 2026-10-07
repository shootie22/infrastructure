# Failover

How traffic moves to the edge when RO goes down, and back. [#41](https://github.com/shootie22/infrastructure/issues/41). Live since 2026-10-07, checkers in dotfiles `modules/nixos/failover-checker/`.

## What gets switched

One record: `ro.radunenu.com`. Today it's a DNS-only CNAME to `noc-studios.go.ro`, the router's dynamic DNS name. Everything public hangs off it:

- proxied names (radunenu.com, git, vw, ...) → `beacon` → `ro`. Cloudflare follows the chain to find the origin.
- DNS-only names (`hs`, `games` and the game names) → `ro` directly.

Failover points `ro` at a new DNS-only record, `edge.radunenu.com` (A, 141.95.67.178). Cloudflare then sends proxied traffic to the edge, HAProxy passes it to Traefik in DK (or on fuji over the tailnet, if fuji is alive and only RO's public path is broken). Failing back points `ro` at `noc-studios.go.ro` again.

The same change goes to deSEC, so the standby stays in step. On deSEC the zone apexes are A records with RO's address (no CNAME flattening there), so the checker rewrites those to the edge's address too.

`ro` gets a 60s TTL. OpenTofu ignores changes to its content, so a failover isn't reverted by the next `tofu apply`.

## Is RO down?

From outside RO, every 15 seconds: an HTTPS request to RO's public address (whatever `noc-studios.go.ro` resolves to) with SNI `edge-check.invalid`, expecting Traefik's 404. That covers the router, the port forward, fuji and Traefik in one go, which is exactly the path that broke on 2026-10-01.

A checker's answer only counts if its own network works: it must also reach Cloudflare's and deSEC's nameservers and the edge (or DK). Otherwise it abstains.

## Who decides

Checkers outside RO vote: the edge (Germany) and a machine in DK. A checker in RO can't tell "RO is down" from "my own uplink is down", so RO never votes to fail over, only to fail back.

There's no leader. Each checker serves its current view on the tailnet, reads the others', and when the votes say so, any of them makes the change. Setting a record to the value it already has is harmless, so two checkers acting at once is fine.

## Timing

- fail over after RO has failed for 3 minutes in a row, on every voting checker
- fail back after RO has been healthy for 10 minutes
- at most one failover per hour; anything faster means something is flapping and needs a human

Total outage before traffic moves: about 3 minutes of detection plus up to a minute for Cloudflare. DNS-only names (`hs`, games) can take another minute for resolvers that respect the 60s TTL.

## Rollout

1. dry run: checkers log what they would do, nothing changes. Ran from 2 Oct through the edge and thinkcentre drills; the votes went over Nebula fine.
2. a forced test (2026-10-07): RO's 443 blocked on both checkers' side only, RO itself stayed up. Both voted RO down at 11:01:36 and both switched `ro` and the deSEC records to the edge at 11:04:35, three minutes later as designed. The edge carried the traffic (to fuji over Nebula) and no site check failed. Unblocked at 11:07:15, back on RO at 11:17:16. "RO is down" reached the phone.
3. live since 2026-10-07.

After any switch the checkers won't fail over again for an hour.

## Not covered

- Game servers through the edge. Only 80 and 443 are passed through. Games in DK would need their ports on the edge too ([#96](https://github.com/shootie22/infrastructure/issues/96)).
- RO services. Whatever only runs in RO is down anyway ([service-ha.md](service-ha.md)).
