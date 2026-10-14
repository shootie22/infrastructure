# nuke.zip audit

What runs on hetzy, the Hetzner VPS with nuke.zip's Matrix, as found on 2026-10-14 by two read-only passes (nothing was changed on the host). It's what Phase 5 has to move. Host hardening is tracked separately.

## Summary

- **Synapse 1.161.0**, installed from packages.matrix.org's Debian repository into `/opt/venvs/matrix-synapse`, run by systemd. Not Docker.
- **Postgres 16** on the host, database `synapsedb`, **1.8 GB**, collation `C` (what Synapse wants, and what CNPG must use too). Schema version 94.
- **Media: 30 GB**, nearly all our own uploads (about 18,700 files). Other servers' media is only about 160 MB.
- **No federation.** `send_federation: false`, and the whitelist only names a host that doesn't exist. Every room was created on nuke.zip and every member is a nuke.zip user. nginx still serves `/.well-known/matrix/server` and listens on 8448, which do nothing.
- **27 accounts, all with passwords**, no SSO. 19 used it in the last 30 days, 15 in the last 7. 272 devices.
- **Clients:** in the last 30 days, 14 users on Element X, 14 in a browser or Element Desktop.
- **109 rooms**, 92 of them encrypted, none in the public directory. The biggest has 14 members. Room versions 9, 10 and 11.
- **27 active key backups** (server-side encrypted key backup, one or more per user who set it up). That helps the switch to yeetus.net: old encrypted messages can be read again after exporting keys.
- **Backups:** Hetzner's daily snapshots of the whole VPS. They're taken while Postgres is running, and nothing else backs up the database or media.

## Synapse configuration

`/etc/matrix-synapse/homeserver.yaml` plus `conf.d/*.yaml`. The files in `conf.d/` override `homeserver.yaml`: the database there is Postgres, while `homeserver.yaml` still names an old 2 MB SQLite file that isn't used.

| Setting | Value | Note for the move |
|---|---|---|
| server_name | nuke.zip | keeps it |
| listener | 127.0.0.1:8008, client + federation + metrics, `x_forwarded` | |
| signing key | `/etc/matrix-synapse/homeserver.signing.key`, ed25519, created 2025-04-29 | the identity: SopsSecret + Vaultwarden copy |
| federation | off (`send_federation: false`, whitelist without a real server) | Phase 6 turns it on for yeetus.net only |
| max_upload_size | 5000M (nginx `client_max_body_size` 5000M too) | the names can't go through Cloudflare's proxy (100 MB cap); DNS-only to the edge |
| rate limits | `spam.yaml` sets `rc_message` 100/s, burst 5000, and loads after the Element Call limits, so it wins | decide what we want |
| registration | not enabled; a shared secret is set (admin user creation) | |
| TURN | coturn on the host, `r.nuke.zip`, shared secret, guests allowed | only for old-style 1:1 calls; Element Call doesn't use it. Check whether anything still does |
| Element Call | `msc3266`, `msc4222`, `msc4140`, `msc4143`, `msc4354`, `msc4502`, `msc4512`; `max_event_delay_duration: 24h`; `matrix_rtc` transport pointing at `a.nuke.zip/livekit/{sfu,jwt}` | same in the cluster |
| appservice | lk-jwt-service is registered as an appservice (MSC4512 proxy) | its registration moves too |
| metrics | on | already scraped over the tailnet |

## Around Synapse

| What | How it runs | Data | Moves to |
|---|---|---|---|
| LiveKit (`livekit/livekit-server:latest`, v1.13.1) | Docker, host ports 7880-7882 | none | the cluster's LiveKit (fuji, edge standby) |
| lk-jwt-service 0.7.0 | Docker, port 8080 behind nginx at `a.nuke.zip/livekit/jwt` | appservice registration | cluster, one service for both servers |
| Element Call (custom image) | Docker, `ec.nuke.zip` | config only | already in the cluster at call.nuke.zip; ec.nuke.zip can redirect |
| GIF bot | systemd, Python venv in the main user's home | login session and E2EE store (sqlite), a Tenor API key | cluster, file copy like steamhappy, keeping its store so its device stays verified |
| Free games RSS bot | systemd, Python venv | session, E2EE store, `seen_entries.json` | same |
| Sticker picker | nginx static, `s.nuke.zip`, 749 MB | files | cluster, a static site with a copy per site |
| Element Web | nginx static, `c.nuke.zip` | none | already in the cluster (the edge); this copy is unused since #160 |
| coturn | systemd | none | see TURN above |
| Monitoring (node exporter, cadvisor, nginx exporter, promtail, frpc, livekit-quality) | Docker | none | gone with the VPS; the cluster scrapes its own |

Not running, leftovers: `g.nuke.zip` and `j.nuke.zip` proxy to ports nothing listens on. There are also an old `auth.radunenu.com` vhost, a matrix-dimension directory (integration manager), a link bot directory, and certificates for `d.nuke.zip` and `x.nuke.zip`. The purposes of these last ones are still to be confirmed.

## What this means for the plan

- **The move is small.** Dumping and restoring 1.8 GB takes minutes. The 30 GB of media can be copied ahead of time while nuke.zip runs, and the final rsync only sends what changed. A cutover window of 15-30 minutes is realistic.
- **Postgres 16 → CNPG's 18:** `pg_dump` / `pg_restore` across major versions is the normal way, and the target cluster gets `C` collation like the source.
- **The Synapse version in the cluster** must be the same as hetzy's at cutover, or newer. Synapse only migrates its schema forward.
- **`device_inbox` is 1.25 GB of the 1.8 GB.** These are messages queued for old devices that never pick them up (272 devices for 27 users). Removing devices nobody uses before the move would shrink the database a lot. Optional, and it's a change on production, so only with an explicit go.
- **Federation doesn't exist today,** so nothing breaks by keeping it closed. Phase 6 turns it on with yeetus.net as the only allowed server.
- **The two bots** carry E2EE state. Their stores and sessions have to move with them, or they come back as new, unverified devices.
- **Element X is used by half the users.** Fine on nuke.zip with passwords as today. yeetus.net uses MAS, which Element X supports natively.
