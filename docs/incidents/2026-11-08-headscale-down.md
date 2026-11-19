# 2026-11-08: Headscale down twice, then its database broken

**What went wrong:** A change that restarted about 30 workloads at once made fuji's API server too slow to answer for longer than site-failover allows, so it fenced Headscale and moved it to the thinkcentre, where every CPU was already requested and Headscale, at the same priority as everything else, couldn't start. On the way back to fuji it came up on a database snapshot sitting next to an old WAL file, and the database broke; the broken file then went to the other site with the next copy.

**Fix:** standby-copy removes the standby's old WAL files before a snapshot lands and never copies a database that fails its integrity check (dotfiles #52); core services get a priority class that lets them push out game servers and CI (#451); next, site-failover tells a slow API from a lost one, and changes that restart many workloads roll out in steps.

**Resolved.** The tailnet's control plane was down 10:45-11:03 and 11:17-11:48 UTC. Connections that existed kept working; nothing could join, and devices couldn't change where they connect from (the workstation lost its path to fuji until the end). Nothing was lost: the database was rebuilt from its rows with both users, all 10 nodes and the pre-auth keys.

## Timeline (UTC)

| Time | What happened |
|---|---|
| 10:43 | #453 merged and synced: every workload with a hand-bumped `config-revision` gets a computed `config-hash`, so about 30 restart at once (Synapse, MAS, LiveKit, Grafana, Alloy, Alertmanager, Headscale and others), with their image pulls. |
| 10:43-10:45 | etcd on fuji logs "apply request took too long" (100-400 ms) and the API server answers with handler timeouts. |
| 10:45:03 | site-failover on fuji can't reach the cluster for more than `apiGrace` (45 s): it fences Headscale and kills its container. |
| 10:45:41 | The thinkcentre takes Headscale over. Its pod stays Pending: "Insufficient cpu", 3.97 of 4 CPUs requested (Synapse had moved there too), "No preemption victims found", since every pod has the same priority. fuji won't take it back during the 30-minute hold-down. |
| 11:01 | `bopl2d` (0.1 CPU requested, about 0.01 used) scaled to 0 by hand. |
| 11:03 | Headscale runs on the thinkcentre. |
| 11:10:58 | The thinkcentre sends its usual copy of Headscale's folder to fuji: a `sqlite3 .backup` snapshot. |
| 11:15 | #454 (an ACL rule) restarts Headscale. Argo had scaled `bopl2d` back up meanwhile and it took the freed CPU, so the new pod is Pending on the thinkcentre again. |
| 11:17:45 | fuji takes Headscale over (stuck Pending on the thinkcentre for 126 s) and opens its own folder: the 11:10 snapshot next to the WAL left when the container was killed at 10:45. Headscale exits on start: "database disk image is malformed". |
| 11:20, 11:30 | fuji's copies send the broken database to the thinkcentre, over the good one. |
| ~11:39 | Headscale crash-looping on fuji: site-failover moves the label to the thinkcentre again, where the copy is now broken too and there's still no CPU. |
| 11:34 | Copies of Headscale stopped on both sites. The broken database checked: broken in both places and also, with a smaller defect in the same table, in the 03:00 Borg backup. |
| 11:44 | Database rebuilt on fuji from its rows (`sqlite3 .recover` into a new file): integrity ok, users `home` and `ci`, 10 nodes, 6 pre-auth keys. The workstation couldn't reach fuji over the tailnet, so through the thinkcentre and the Nebula mesh. |
| 11:47 | Label moved back to fuji by hand (removed from the thinkcentre first). |
| 11:48 | Headscale healthy on fuji; tailnet back. 11:51: copy to the thinkcentre run by hand, so its standby is the good database. |

## Causes

- **The burst of restarts.** Restarting about 30 workloads in one sync put enough load on fuji's control plane that API calls failed for over 45 s. site-failover treats that the same as being cut off.
- **No room on the failover node, no priorities.** Headscale needs 0.05 CPU. The thinkcentre had 0.03 free and nothing could be preempted, because nothing had a priority class.
- **The copy kept the standby's old WAL.** standby-copy excludes `db.sqlite-wal`, `-shm` and `-journal` from its rsync, so the snapshot isn't mixed with live files, but excluding them also kept rsync's `--delete` from removing the standby's own. A fence kills the service mid-write and leaves a WAL; the next snapshot landed next to it, and SQLite replayed the old WAL onto the new database.
- **Not proven:** where the smaller defect already in the 03:00 backup came from. The same WAL mixing after an earlier failover would explain it.

## Follow-ups

- dotfiles #52: standby-copy deletes the standby's `-wal`/`-shm`/`-journal` before a snapshot lands and refuses to send a database that fails `PRAGMA integrity_check`. Merged.
- #451: priority classes; Headscale, tailnet-dns, Gitea and the Postgres clusters can preempt game servers and CI on either site.
- site-failover: a slow API isn't a lost cluster. To decide: what it should count as "lost" (connection refused or no route vs. slow answers), and whether `apiGrace` and the other side's takeover delay go up together.
- Restarts in steps: a change to many pod templates at once (like #453) rolls out in batches, so it can't overload the control plane.
