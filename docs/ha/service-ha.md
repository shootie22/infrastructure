# Service HA

Which services keep running when the site they live on goes down, and how. Not every service gets this. A second copy of everything would cost RAM, disk and cross-site bandwidth until it meant buying more servers, and some data is simply too big to replicate (Gitea is hundreds of GB).

The platform under it: etcd across both sites and the edge (Phase 3, done 5 Oct), replicated Postgres (Phase 4), Keycloak and Headscale in both sites (Phase 5), the failover path (Phase 6). This page is about the services on top.

## Tiers

| Tier | Meaning | Cost |
|---|---|---|
| Survives | Keeps working, or comes back within minutes, when its site is down | a second copy of the data, sometimes of the app |
| Stateless copy | Runs in both sites, nothing to replicate | a few tens of MB of RAM |
| Restore | Down until its site is back, or restored from Borg on the other side by hand | nothing extra, a tested restore |

## How, per kind of service

- **No data** (static sites, Element Web): a second replica pinned to the other site.
- **Postgres**: the database moves to CNPG with a replica in the other site (Phase 4). The app itself runs in both sites, or starts in the other one when the first is gone.
- **Small files or SQLite** (Vaultwarden, Baikal): active-passive. The app runs in one site, the data is copied to the other one continuously or every few minutes, and failover starts the app there. Candidates: Litestream for SQLite, a CNPG database where the app supports Postgres, or a small replicated volume.
- **Large files** (Gitea repos, game worlds, Audiobookshelf): Borg every night, and a written, tested restore. No live replication.

Replicated block storage for everything (Longhorn and similar) was ruled out for now: agents on every node and synchronous writes over a 13-55 ms WAN, for data that mostly doesn't need it.

## Status

Updated 5 Oct, after Phase 3. To be decided in [#88](https://github.com/shootie22/infrastructure/issues/88).

Since Phase 3 the cluster itself survives losing a site. What that doesn't cover is the services: most are pinned to one node and keep their data on its disk, so they stop with it. A service with no data and no pinning already moves by itself: Kubernetes restarts it on another node about five minutes after its node is gone. That's marked as "moves by itself" below.

### Services

| Service | Runs on | Data | Proposed tier |
|---|---|---|---|
| Keycloak | fuji | Postgres + files, a few MB | Survives (Phase 5) |
| Headscale | fuji | SQLite | Survives (Phase 5). Since 5 Oct the cluster doesn't need it, so it's an ordinary HA service now |
| Vaultwarden | thinkcentre | SQLite + attachments, ~7 MB | Survives |
| Baikal | fuji | files, <1 MB | Survives |
| radunenu.com, yeetus.net, redirect domains | fuji, minima, mixi | none | Stateless copy |
| Element Web, Element Call | minima, mixi | none | Stateless copy |
| PrivateBin | thinkcentre | small files | Stateless copy or Survives |
| Joplin | thinkcentre | Postgres | to decide |
| Pinga | thinkcentre | files, 2.3 GB | to decide |
| Legacy web (old API, Kronorite) | fuji, minima | 2 GB of files | to decide |
| Gitea | thinkcentre | Postgres + 61 GB of repos | Restore |
| Gitea runners | thinkcentre, mixi | caches | Restore (one per site already) |
| Game servers (Minecraft ×2, crosty, megabopl3d, Hytale) | thinkcentre | worlds, up to ~8 GB each | Restore |
| Ollama, SearXNG, steamhappy | minima | models, caches | Restore (needs the Mac's GPU) |
| Audiobookshelf | thinkcentre | 14 GB | Restore |
| picshare, Send, Rybbit | thinkcentre | small to 100 MB | Restore |
| homepage, Headlamp | fuji (pinned) | none | Restore, or unpinned to move by itself |
| github-commit-sync | mixi | none | Restore |

### Platform

| Piece | Runs on | Today |
|---|---|---|
| etcd, the API | fuji, thinkcentre, the edge (etcd only) | survives losing any one (Phase 3) |
| Traefik | fuji and thinkcentre, one per site | both sites already; which one gets the traffic is the failover path (Phase 6) |
| Argo CD | fuji (not pinned) | its state is in etcd; moves by itself |
| cert-manager, the SOPS operator | minima (not pinned) | same |
| tailnet DNS, external-services | fuji (pinned) | no data; unpinning or a second copy is cheap |
| Monitoring (Prometheus, Grafana, Loki, Alertmanager) | fuji | Restore. While fuji is down, the edge's alert relay and the healthchecks.io dead-man switch still notice |
