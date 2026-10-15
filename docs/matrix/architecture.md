# Matrix architecture

The design for yeetus.net's homeserver, and later nuke.zip's. Planned 2026-10-14, nothing built yet. The decisions behind it are in [decisions.md](../ha/decisions.md) under 2026-10-14.

## What runs where

| Piece | Runs on | Data | How it survives |
|---|---|---|---|
| Synapse | fuji (home), thinkcentre (standby) | Postgres, media on `/srv/ha/matrix` | one process; site-failover moves it with its media (label `ha.radunenu.com/matrix`) |
| Synapse's Postgres (`synapse-db`) | fuji and the thinkcentre | 2 instances | CNPG, asynchronous like the other databases; the primary follows Synapse |
| MAS (login) | fuji and the thinkcentre | its own Postgres (`mas-db`, same as Synapse's) | two replicas, nothing on disk |
| lk-jwt-service | two replicas, one per site | none | either answers |
| LiveKit SFU | fuji (active), the edge (standby) | none | signalling fails over to the edge's SFU; calls reconnect |
| Element Web, Element Call | the edge and both sites | none | as today (#160): `chat.yeetus.net` and `call.yeetus.net` next to the nuke.zip names |
| Keycloak | as today | | a `matrix` client in `network-yeetus`, behind a gate |

Nothing else from Matrix goes on the edge: it's a small VPS for the front door and the votes. The LiveKit standby is stateless and small (about 100 MB idle), and only carries calls while fuji's SFU is down.

Why fuji is home: it has the UPS, RO's port forwards, and the edge's HAProxy tries it first. The thinkcentre should get a UPS too.

## Names

| Name | What |
|---|---|
| `yeetus.net` | the server name. `/.well-known/matrix/client` comes from the existing yeetus.net site. `/.well-known/matrix/server` only once we federate with nuke.zip |
| `matrix.yeetus.net` | Synapse's client API |
| `account.yeetus.net` | MAS |
| `chat.yeetus.net` | Element Web, the same deployment as c.nuke.zip with a `config.chat.yeetus.net.json` |
| `call.yeetus.net` | Element Call |
| `rtc.yeetus.net` | lk-jwt-service |
| `sfu.yeetus.net` | LiveKit signalling |

They're DNS-only (not through Cloudflare's proxy, which caps uploads at 100 MB; nuke.zip allows 5000 MB today). They all go through the edge's HAProxy, like Element Web: passed through to fuji's Traefik, the thinkcentre's when fuji's doesn't answer (about 2 seconds). If the edge itself dies, the front checker moves the names to RO's front door after a minute. That's much faster than the 3-minute `ro` DNS failover the other services use.

## Synapse

- **Synapse**, not Dendrite (maintenance mode) or tuwunel/continuwuity (an embedded database that can't be replicated across sites, less mature). It's the only one with Postgres, MAS and everything Element Call needs.
- **One process, no workers.** Ten users don't need them, and workers bring Redis and more things that can break. Revisit only for open federation.
- **Never two at once.** A Deployment with one replica and `Recreate`. Synapse's main process can't run twice; there's no leader election.
- **Next to its database.** Synapse makes many queries one after another, so 13-55 ms across the WAN on each would make every request slow. When site-failover moves the `matrix` label, it also switches the CNPG primary to that node. That is a planned switchover: CNPG stops the old primary cleanly and the replica catches up before taking over, so it takes seconds and loses nothing. `MatrixDbElsewhere` fires if they end up in different sites anyway. Gitea has the same latent problem and can reuse this.
- **Priority.** A `matrix-critical` PriorityClass and real CPU and memory requests, so a build on the same node gets the smaller share.

What isn't possible: Synapse running in both sites at once. Its main process is a singleton, and HA Synapse only exists in Element's paid Synapse Pro. So a site failure costs a couple of minutes, not zero.

## Media

On the node's disk at `/srv/ha/matrix`, copied to the other site like the other services with files, but **every minute** instead of every 10 (`copyEvery = "minutely"` in dotfiles). Uploaded media never changes once written, so the copies are cheap. Only our own uploads and thumbnails are copied; other servers' media and URL previews are caches and can be fetched again.

Messages are in Postgres, so they're never part of this. An abrupt site failure can lose at most the last minute or so of uploads. A message referring to such a file stays, the file shows as missing. `MatrixMediaCopyStale` fires if the copy falls more than 10 minutes behind.

Also looked at: Garage (our own S3) refuses writes with one of two sites down unless the edge holds a third copy; an outside S3 adds a dependency and a bill (the Backblaze plan I have is Personal Backup, not S3).

## Login

MAS (matrix-authentication-service) does the login for Synapse, using Synapse's native MAS support, which Element X needs. Its only provider is Keycloak (`network-yeetus`). No local passwords, no registration, no guests.

- The Matrix name comes from Keycloak: localpart `{{ user.preferred_username }}`, required (no username, no account), so everyone is `@<keycloak username>:yeetus.net` with nothing to choose. Name and email are copied from Keycloak at every sign-in.
- Users can't change their Keycloak username (admins can). MAS links accounts by Keycloak's `sub`, so even an admin rename keeps the old Matrix ID.
- Access through the usual gate: a `matrix` client with an `access` role, granted by the Keycloak group `chat`. Someone outside it gets the "no access" page.
- Leaving: remove from the group, then end their sessions in MAS ([runbooks/offboarding.md](runbooks/offboarding.md)).

## Calls

Element Call needs LiveKit (the media server, SFU) and lk-jwt-service (hands out call tokens to Matrix users). All in `kubernetes/services/matrix/livekit.yaml`.

- **Two separate SFUs**: `livekit-ro` on fuji (the one in use: UPS, RO's port forwards) and `livekit-edge` on the edge (the standby), both on the host network with the same keys.
- **Media ports 50881/tcp and 50882/udp**, deliberately not LiveKit's defaults. RO's router forwards them to fuji; the edge opens them itself. Signalling (7880) and metrics (6789) are host ports reachable only over Nebula and from pods on the node.
- **Which SFU takes calls**: `wss://sfu.yeetus.net` goes through Traefik to one Service with both SFUs in it, and a small sidecar next to each decides whether its SFU counts as ready:
  - fuji's takes new calls, unless calls are still running on the edge's;
  - the edge's takes them only while fuji's can't be reached, or while it still has calls of its own.

  So calls move to the edge within seconds when fuji's SFU dies, and come back only once the edge is idle. A call is never split across the two. If the SFU under a running call dies, the call drops and reconnects on the other. Tested against LiveKit and with faked room counts; to be drilled for real in Phase 4.
- **RO's address is dynamic.** LiveKit looks it up once at start, so a CronJob checks `noc-studios.go.ro` every 2 minutes and restarts fuji's SFU when it changes. The first run only records it.
- **lk-jwt-service**, two replicas, plain token mode (stateless; the newer appservice mode keeps state in memory or Redis). Only our own server may start calls (`LIVEKIT_FULL_ACCESS_HOMESERVERS=yeetus.net`, later nuke.zip too); one LiveKit serves both servers.
- **How clients find it**: `org.matrix.msc4143.rtc_foci` in the well-known and `matrix_rtc` in Synapse, both pointing at `https://rtc.yeetus.net`. Element Web loads Element Call from `call.yeetus.net`; Element X has it built in.
- Synapse: `msc4143`, `msc4222`, `msc4354` (sticky events), delayed events (`max_event_delay_duration: 24h`), the rate limits Element Call asks for.
- Alerts: `MatrixCallsDown` (neither SFU up, pages), `MatrixCallsOnStandby` (fuji's down for 10 minutes).
- Later: TURN over TLS on 443, for networks that only allow 443.

## How long a switch takes

Estimates until the drills measure them (Phase 4, with a canary bot that sends a message every minute).

| What breaks | Effect |
|---|---|
| Synapse crashes | 20-30 s, restarts in place |
| A MAS, JWT or Element pod, or its node | nothing, the other replica answers |
| RO's internet | about 2 s, the edge sends traffic to the thinkcentre |
| The edge | about a minute, the front checker moves the names to RO |
| fuji, or all of RO | 2-3 min: the cluster marks fuji not ready, site-failover moves the label, Synapse starts on the thinkcentre with the database promoted there |
| Planned maintenance | about 30 s, moved on purpose at a quiet time |

During any of these, clients keep messages as "sending" and send them once the server is back. Calls drop and reconnect. Losing the thinkcentre while Matrix runs on fuji costs nothing at all.

## Data safety

- **Postgres asynchronous**, like the other databases. Synchronous was tried and dropped: when the replica's machine crashed in the VM rehearsal, writes hung for about 216 s until CNPG noticed ([decisions](../ha/decisions.md)). Losing the standby's site now changes nothing; losing the primary's site abruptly can lose the last moment of writes (milliseconds of lag on a quiet chat; `PostgresReplicationLag` fires if it grows). Moving Matrix on purpose loses nothing (a clean switchover).
- Hourly `pg_dump` and nightly Borg, as for every database.
- The signing keys are in SopsSecrets, **and a copy is in Vaultwarden**. Losing a server's signing key means losing its identity.
- Upgrades: a dump first. Synapse's schema migrations can't be rolled back.
- Synapse's database needs `C` collation (`localeCollate`/`localeCType` in CNPG's `initdb`).

## Security

- **No federation**: `/_matrix/federation` and `/_matrix/key` aren't routed at all, and `federation_domain_whitelist` is empty. With nuke.zip later: each lists only the other.
- Login only through MAS and Keycloak, behind the gate. Keycloak's brute-force detection, MFA optional.
- `/_synapse/admin` and MAS's admin aren't routed publicly, only over the tailnet.
- Profiles only visible to people sharing a room. Rooms encrypted by default. URL previews off, or with private ranges denied.
- NetworkPolicies: Synapse only talks to its database, MAS and DNS.
- All secrets in SopsSecrets.

### Non-standard ports?

Looked at hiding things on unusual ports. Not for the HTTPS names: scanners (Shodan, Censys, masscan) go through all 65,535 ports anyway, and plenty of networks (hotels, schools, workplaces, some mobile carriers) block anything that isn't 443. For something that must always work, that's the wrong trade. Cloudflare's proxy only passes a few HTTPS ports too.

Where it's free, though:

- LiveKit's media ports can be any numbers, so they won't be the defaults (7881/7882).
- Federation, if we ever turn it on, can use any port; `/.well-known/matrix/server` says where.
- TURN stays on 443 on purpose: getting through networks that only allow 443 is its whole job.

What actually hides things:

- **A wildcard certificate** (`*.yeetus.net`, DNS-01 like Headlamp's issuer), *not done yet*. Every certificate is published in Certificate Transparency logs, and scanners try new names within minutes. Phase 2 uses ordinary per-name certificates (HTTP-01, the existing issuer) because DNS-01 needs a Cloudflare token scoped to `yeetus.net`. Little is lost meanwhile: `matrix`, `account` and `rtc` are public in the well-known anyway; only `sfu` would stay hidden.
- SNI routing: asking the address without the right name gets Traefik's 404, as today.
- Admin paths not routed at all, rate limits in Synapse and MAS, updates through Renovate.

`yeetus.net/.well-known/matrix/client` names the Matrix hosts publicly. Clients need it to find the server, so that one stays.

## Gitea runners on the same nodes

The verdict: **there's enough CPU, chat shouldn't lag, and calls are where it could be felt**, through RO's uplink rather than the CPU. To be confirmed by measuring (Phase 4).

What Matrix needs is small. On hetzy today, everything (Synapse, Postgres, LiveKit, coturn, two bots, monitoring) runs on 4 vCPUs with a load around 0.07, and Synapse uses 1.4 GB. In the cluster, fuji carries Synapse (one thread, about 1.5 GB), the Postgres primaries (about 1 GB), MAS and the LiveKit SFU (a few hundred MB, and an SFU only forwards packets). After Phase 5, nuke.zip's Synapse and database come on top: roughly 4-6 GB in all on fuji, and a replica's worth on the thinkcentre.

What a CI job can take on fuji: 2 of its 4 cores and 8 GiB (`ci-runner` `slots`, down from 3 cores), inside a Kata VM, with no limit on disk or network.

| What a build competes for | Effect on Matrix | What's done |
|---|---|---|
| CPU | Synapse slower to answer if it waits for a core | `matrix-critical` priority; real CPU requests (Synapse, Postgres) against the job's 250m, so under contention Matrix gets the much bigger share. With the job capped at 2 cores, 2 stay for everything else. Not expected to be felt |
| Memory | none while fuji has room for both | needs fuji's RAM to confirm (the job may use 8 GiB) |
| Disk | Postgres commits wait behind a build's writes: tens of ms at worst | not noticeable in chat; measure. If it is: the job's disk image onto fuji's other SSD |
| RO's uplink | **calls on fuji's SFU get choppy** while a job pushes an image (Gitea is in DK, so a push from fuji crosses RO's uplink) or pulls a big one | measure during a call; if felt, cap CI pods' bandwidth on fuji, or let the runner skip the node holding the `matrix` label |

The measurement: the heaviest build on fuji during a group call, watching Synapse's response times, Postgres commit times and the livekit-quality probe.

## Open federation, if we ever want it

Possible on this hardware, with care, and reversible (the whitelist can be narrowed again). What it costs depends on **which rooms we join**, not on how many users we have: a big public room (Matrix HQ and the like) means gigabytes of room state, CPU spikes on fuji's i3 and a database that grows fast. It would need:

- the federation routes and `/.well-known/matrix/server`
- probably federation sender and reader workers, which bring Redis back
- `synapse-compress-state` and a job that purges other servers' media
- a moderation bot with ban lists (Draupnir), against invite spam
- a bigger database volume
