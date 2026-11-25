# How yeetus.net's Matrix can fail

Every way we know of that Matrix on yeetus.net can stop working, what notices it and what repairs it. Written on 2026-11-25 after Synapse was down for 12 hours ([incident](../incidents/2026-11-25-synapse-sequences-after-switchover.md)), from the code on main, Prometheus (15 days kept), Loki (2 weeks) and the alert relay's journal (since 26 Oct). "Not proven" means read from the code or config but never seen happen.

Each gap has a status: **fixed** (with the change), **open** (to do), **decided** (Radu chose to leave it) or **accepted** (small enough to leave).

## Outages in the 30 days before

| Start (UTC) | Length | Cause | How it ended |
|---|---|---|---|
| 13 Nov 01:14 | 5 d 7 h 36 min | fuji's primary killed by the isolation check, then a switchover to a replica that wasn't streaming lost writes; Synapse answered 500 to every send | Synapse happened to restart on 18 Nov |
| 19 Nov 16:38 | 7 min | a deploy took the thinkcentre off the mesh; failover lost writes, same 500s | restarted by hand |
| 24 Nov 01:59 | 4 min | Synapse's sequence check after the primary moved | primary moved back |
| 24 Nov 02:32 | 74 min | same | primary moved back at 03:46 |
| 25 Nov 01:04 | 12 h 15 min | same | sequences fixed by hand at 13:17 |

Plus about weekly blips of 15 s to 2 min on the front door (below), too short to page.

Detection worked every time: MatrixCanaryFailing or MatrixSynapseDown paged within minutes. The long ones are long because nothing repaired them and the pages went quiet (Paging, below).

## Databases (synapse-db, mas-db)

| How it fails | Notices | Repairs | Status |
|---|---|---|---|
| **The isolation check kills a healthy primary.** A k3s restart on either server cuts the primary on fuji off from the API and the replica for a minute or two; with the default `livenessProbeTimeout` of 30 s the probe kills it, and 5 minutes later CNPG fails over to the other site even though the primary came back. Seen: synapse-db-1 on 13, 16, 19, 24 Nov and twice on 25 Nov; mas-db-1 on 19 and twice on 24 Nov. It started every incident above. | PostgresPrimarySwitched, after the fact | kubelet restarts Postgres, site-failover moves the primary back and restarts Synapse/MAS | **fixed** for Matrix: `livenessProbeTimeout: 240` (database.yaml). **open** for the other 11 clusters and Hub's template |
| A failover (not a planned switchover) promotes a replica that wasn't streaming and loses writes (19 Nov). site-failover's streaming check (dotfiles #70) only covers its own switchovers. | MatrixCanaryFailing | restart-on-switch, and the sequences init container | accepted: the isolation fix removes the usual trigger |
| Synapse's sequences end up behind its stream positions after the primary moves over and back | MatrixSynapseDown | the sequences init container before every start; CI checks its list against each Synapse version | **fixed** (#507) |
| fuji lost as a whole: the label moves in about 60 s but the database only promotes after 300 s, so at least 6 minutes down plus the last moment of writes. architecture.md says 2-3 minutes. Never drilled. | MatrixSynapseDown, SiteFailoverMoved | automatic | **open**: time it in the Phase 4 drill, fix the docs |
| Partition between fuji and the thinkcentre only: the operator may promote in DK while Synapse stays on fuji and can't reach it, for as long as the partition lasts. Not proven. | PlacementDrift, MatrixSynapseDown | none until it heals | **open**: drill it |
| First Postgres minor or CNPG operator upgrade restarts every instance (and Synapse through restart-on-switch); a major upgrade needs pg_upgrade. Never done since Matrix went live, no runbook. | | by hand | **open**: runbook, first one done as a drill |
| CNPG operator down or wedged: no failover; it isn't scraped. | only pods not ready | by hand | **open**: scrape it, alert on reconcile errors |
| Disk full on a database node | NodeFilesystemCriticallyLow (pages) | | accepted |
| Replica falls far behind: slots are kept, WAL grows 15-80 MB a day | PostgresReplicationLag | CNPG | accepted |

## Backups and media

| How it fails | Notices | Repairs | Status |
|---|---|---|---|
| Borg stops making archives: `borg_last_archive_timestamp_seconds` is exported but nothing alerts on it | nothing | | **open**: alert after 30 hours |
| The hourly dump is one file, overwritten every hour, so the dump taken before an upgrade is gone at the next :23 | | | **open**: keep 24 hourly dumps |
| Dumps only run on fuji and only fuji's Borg has them, so nothing is backed up while fuji is down | | | **open** |
| A Matrix restore has never been rehearsed and has no measured time (restore.md) | | | **open**: rehearse, write down the time |
| After an abrupt fuji loss, the last minute of uploaded media is only on fuji, and the first copy back from the thinkcentre runs `rsync --delete` and removes it. Not proven. | nothing | | **open**: move deleted files aside instead |

## Synapse, MAS, calls

| How it fails | Notices | Repairs | Status |
|---|---|---|---|
| Synapse won't start (bad release, config, migration, database state) | MatrixSynapseDown, MatrixCanaryFailing | nothing automatic: the canary only restarts Synapse after HTTP 500, a start failure is 503 | needs a person; see Paging |
| Synapse runs but every write fails, `/health` still OK | MatrixCanaryFailing | the canary restarts it after 10 failed sends (never needed since it was added) | covered |
| Renovate merged new Synapse and MAS releases by itself at 00:30 UTC, with no dump and nobody watching | | | **open**: decided 2026-11-25, Renovate opens a pull request that is merged by hand |
| MAS crash-loops for a few minutes after each database switch, both replicas on the same database | MatrixLoginDown | kubelet, restart-on-switch | accepted |
| The canary stops reporting (pod restarted or moved): the page resolves although nothing is fixed (16 Nov) | MatrixCanaryNotReporting, a warning after 30 min | | decided: no paging changes |
| Calls: media path or lk-jwt-service down. No calls in 15 days; the standby SFU has never been ready; failover not drilled | SFU scrapes only | | **open**, low while calls are unused |

## Front door (DNS, edge, Traefik)

| How it fails | Notices | Repairs | Status |
|---|---|---|---|
| **One site's hiccup takes both sites off the edge.** The edge checks each node through `traefik-ready.invalid/ping`, but that Service picks every Traefik pod in both sites, so when the thinkcentre's Traefik goes away half of fuji's checks fail too and the edge marks both down. Seen 16, 18 (twice), 19, 24 (twice) Nov, 15 s to 2 min each. | nothing, too short | Kubernetes drops the endpoint | **open**: each Traefik answers its own check |
| The front checker only checks the edge's own Element page, so it never moves element.radunenu.com when the edge stops passing traffic home; no runbook for moving it by hand | MatrixCanaryFailing, UptimeRobot | nothing | **open**: also check `matrix.yeetus.net/_matrix/client/versions`; runbook |
| The edge's fallback to the home sites for Element Web and Call never works: those four server lines lack `send-proxy-v2`, which the front doors require | nothing (EdgeBackendDown only watches traefik-https) | the front checker moves DNS after 60 s | **open** |
| chat.yeetus.net (Element Web in the cluster) isn't checked by anything: the Element check, UptimeRobot and blackbox all load c.nuke.zip | nothing | the nightly updater | **open** |
| The front checker's DNS switch fails (expired token) and only logs it | nothing until it's needed | | **open**: notify, and verify tokens hourly |
| The edge's logs aren't in Loki | | | **open** |
| yeetus.net/.well-known goes through Cloudflare and RO, not the edge (architecture.md says otherwise); 3-4 minutes if RO's line drops | UptimeRobot | ro failover | accepted; docs fixed later |
| Certificates: one certificate for five names, renewed by HTTP-01 around 14 Dec | CertificateNotReady, CertificateExpiringSoon | cert-manager | covered |
| Edge VPS down | UptimeRobot, HACheckerDown | front checker moves DNS in about a minute | covered |

## Paging

| How it fails | Status |
|---|---|
| A page repeats on Pushover for an hour (silent at night), sends one email at 15 minutes, then nothing until Alertmanager repeats it 12 hours later. This turned 25 Nov into 12 hours and 13-18 Nov into 5 days. | decided 2026-11-25: no changes |
| 84 of 154 pages in 30 days were PlacementDriftLong ("everything still works"), mostly at night | decided: no changes |
| The relay gives up when Pushover or the mail server says slow down (6 pages lost in 30 days), and drops a page that fires again within 10 minutes of resolving | **open**: retry with backoff, one send at a time, clear the duplicate key on resolve |
| Monitoring down at the same time as Matrix | covered: two Prometheuses and Alertmanagers, Watchdog to healthchecks.io, UptimeRobot, relay standby on mixi |
| Pages delivered over Matrix | not a risk: the relay uses Pushover and email, the on-call agent posts to nuke.zip |
