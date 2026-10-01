# Service HA

Which services keep running when the site they live on goes down, and how. Not every service gets this. A second copy of everything would cost RAM, disk and cross-site bandwidth until it meant buying more servers, and some data is simply too big to replicate (Gitea is hundreds of GB).

The platform under it is already planned: etcd across both sites and the edge (Phase 3), replicated Postgres (Phase 4), Keycloak and Headscale in both sites (Phase 5), the failover path (Phase 6). This page is about the services on top.

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

Replicated block storage for everything (Longhorn and similar) was ruled out for now: agents on every node and synchronous writes over a 14-28 ms WAN, for data that mostly doesn't need it.

## Status

Proposed tiers, to be decided in [#88](https://github.com/shootie22/infrastructure/issues/88):

| Service | Site | Proposed tier | Data |
|---|---|---|---|
| Keycloak | RO | Survives | Postgres (Phase 5) |
| Headscale | RO | Survives | SQLite (Phase 5, [#37](https://github.com/shootie22/infrastructure/issues/37)) |
| Vaultwarden | DK | Survives | SQLite + attachments |
| Baikal | RO | Survives | SQLite / files |
| radunenu.com, yeetus.net, redirect domains | RO, DK | Stateless copy | none |
| Element Web, Element Call | RO | Stateless copy | none |
| PrivateBin | DK | Stateless copy or Survives | small files |
| Joplin | DK | to decide | Postgres |
| Pinga | DK | to decide | files |
| Legacy web (old API, Kronorite) | RO | to decide | 2 GB of files |
| Gitea | DK | Restore | Postgres + hundreds of GB of repos |
| Game servers | DK | Restore | worlds |
| Ollama, SearXNG, steamhappy | RO (minima) | Restore | needs the Mac's GPU |
| Audiobookshelf, picshare, Send, Rybbit | DK | Restore | large or unimportant |
| Monitoring | RO | Restore | metrics and logs |
