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

Decided 6 Oct ([#88](https://github.com/shootie22/infrastructure/issues/88), [decisions.md](decisions.md)). Since Phase 3 the cluster itself survives losing a site; this is about the services on it.

### Services

| Service | Runs on | Data | Tier | How |
|---|---|---|---|---|
| Keycloak | fuji | Postgres + files, a few MB | Survives | Postgres replica (Phase 4/5) |
| Headscale | fuji | SQLite | Survives | moves to Postgres, replica |
| Vaultwarden | thinkcentre | SQLite + attachments, ~7 MB | Survives | moves to Postgres, attachments copied |
| Baikal | fuji | files, <1 MB | Survives | file copy |
| Joplin | thinkcentre | Postgres | Survives | Postgres replica |
| PrivateBin | thinkcentre | small files | Survives | file copy |
| Send | thinkcentre | uploads on the 4 TB disk, ~100 MB | Survives | file copy, so shared links keep working |
| Gitea | thinkcentre | Postgres + 61 GB of repos | Survives | Postgres replica, repos/LFS/packages copied every few minutes |
| Audiobookshelf | thinkcentre | 14 GB library, 34 MB database | Survives | file copy |
| Legacy web (old API, Kronorite) | fuji, minima | 2 GB of files | Survives | file copy |
| Rybbit | thinkcentre | Postgres + ClickHouse | Survives | Postgres replica; ClickHouse to work out |
| Minecraft HC, Skyblock, Vintage Story | thinkcentre | worlds, up to 96 GB | Survives | world copied after a save, every few minutes |
| Bopl 2D, Crosty, MegaBopl3D | thinkcentre | none | Stateless copy | can run in either site |
| radunenu.com, yeetus.net, redirect domains | fuji, minima, mixi | none | Stateless copy | a replica per site |
| Element Web, Element Call | minima, mixi | none | Stateless copy | a replica per site |
| homepage, Headlamp, tailnet DNS, external-services | fuji, on its tailnet address | none | Survives | a second copy on the thinkcentre's address, DNS lists both |
| Monitoring (Prometheus, Grafana, Loki, Alertmanager) | fuji | metrics and logs | Survives | a second Prometheus and Alertmanager in DK, scraping the same targets |
| Ollama, SearXNG, steamhappy | minima (Mac M4 VM) | models, caches | Survives if mixi's GPU works | replica on mixi (M1, Asahi GPU), to test |
| Gitea runners | thinkcentre, mixi | caches | already one per site | |
| github-commit-sync | mixi | none | Stateless copy | |
| Pinga | thinkcentre | 2.3 GB | Retire | radunenu.com's status page reads from Prometheus instead |
| picshare | thinkcentre | small | Retired 6 Oct | Manifests removed; data left in /home/main/services/picshare and in Borg |

### Building blocks

1. **Replicated Postgres** (CNPG, Phase 4): one primary, a replica in the other site.
2. **File copy over Nebula**: one mechanism for every service with files, a copy every few minutes into the other site (in RO on fuji's spare 1 TB SSD). For game worlds and Git, in an order that keeps the copy consistent (save first; objects before refs).
3. **Failover control** (Phase 6): decides a site is gone and promotes the standby: Postgres replica to primary, the app started on the copy, traffic sent there.

Copies are asynchronous, so a failover can miss the last minute or two of writes.

### Platform

| Piece | Runs on | Today |
|---|---|---|
| etcd, the API | fuji, thinkcentre, the edge (etcd only) | survives losing any one (Phase 3) |
| Traefik | fuji and thinkcentre, one per site | both sites already; which one gets the traffic is the failover path (Phase 6) |
| Argo CD | fuji (not pinned) | its state is in etcd; moves by itself |
| cert-manager, the SOPS operator | minima (not pinned) | same |
