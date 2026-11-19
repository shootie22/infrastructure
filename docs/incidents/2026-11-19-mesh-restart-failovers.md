# 2026-11-19: a deploy took the thinkcentre off the mesh, eight databases failed over, Matrix stopped sending

**What went wrong:** The nixpkgs update (dotfiles #68) changed Nebula. A NixOS switch stops a changed service at its start and starts it at its end, and k3s, which restarts in between, waits up to 2 minutes for the mesh address and then fails without it. So the thinkcentre was off the mesh for 2.5 minutes. fuji's site-failover took over 15 services, and CloudNativePG, with no failover delay, promoted the replicas of eight databases. Synapse's database was one of them, and Synapse then failed every message send until it was restarted. The same Synapse failure had already lasted five days the week before, after a planned move switched its database while the replica was behind.

**Fix:** Nebula restarts in place on a deploy (dotfiles #69, live: on the next deploy each host was off the mesh for about a second); a primary is only replaced after 5 minutes without answering (`failoverDelay: 300` on every Cluster). Next: site-failover only switches over to a replica that's streaming and caught up; Synapse restarts after its database changes primary; the canary logs the actual error and restarts Synapse if sending keeps failing.

**Resolved.** Today: the 15 services ran in RO from 16:36 until their next quiet-hours move home; yeetus.net couldn't send messages from 16:38 to 16:45 UTC. 13-18 Nov: yeetus.net couldn't send messages from 13 Nov 01:14 to 18 Nov 08:50 UTC. yeetus.net is the test homeserver (nuke.zip, on hetzy, wasn't affected); its writes in the seconds before each promotion are most likely gone.

## Timeline (UTC)

| Time | What happened |
|---|---|
| 13 Nov 01:14:50 | Quiet-hours move of Matrix home to fuji. synapse-db's primary on the thinkcentre logs "terminating walsender process due to replication timeout": its replica is no longer receiving WAL. |
| 13 Nov 01:15:10 | The old primary shuts down for the switchover; the replica logs "Refusing to restore future timeline history file". |
| 13 Nov 01:14 - 18 Nov 08:50 | Every message send answers 500: `psycopg2.errors.ForeignKeyViolation: insert or update on table "event_forward_extremities" violates foreign key constraint "event_forward_extremities_event_id"`. MatrixCanaryFailing fires the whole time (10 minutes of green on 16 Nov). |
| 18 Nov 08:50 | Synapse restarts (during that day's k3s restart trouble); the next send succeeds. |
| 19 Nov 16:34:55 | #68 reaches the thinkcentre. comin: "stopping the following units: nebula@mesh.service". |
| 16:34:58 | The switch restarts k3s and tailscaled. k3s waits for the mesh address (`k3s-wait-addresses`), etcd on the thinkcentre has no leader, kubelet can't find node IP 10.99.0.3. |
| 16:36:35 | The CNPG operator: "Current primary isn't healthy, initiating a failover", for gamevault, mealie, games, rybbit and, in the next three minutes, gitea, hub, synapse-db and glitchtip. |
| 16:36:42 | fuji's site-failover takes over 15 services from the thinkcentre. |
| 16:37:32 | The switch finally starts Nebula; k3s had already failed ("unable to find interface nebula.mesh"). |
| 16:38:50 | First failed send on yeetus.net, same ForeignKeyViolation. |
| 16:45:13 | Synapse restarted by hand; sends succeed again. |
| 17:28 | #69 deployed: Nebula restarted in place on the thinkcentre, mixi and dell within a second each; nothing moved. |

## Causes

- **Nebula stopped for the whole switch.** NixOS's default for a changed service is stop first, start last. For the network k3s runs on, that turned a restart of a few seconds into 2.5 minutes without the mesh.
- **No failover delay.** CNPG promoted replicas within about 100 s of losing the primaries. The replicas are asynchronous, so a promotion can drop the last writes; for a short network outage that's a bad trade.
- **A planned switchover to a replica that was behind** (13 Nov). site-failover checks that the cluster is healthy and the replica ready, not that it's caught up.
- **Synapse doesn't survive its database losing writes.** It keeps what it wrote in memory, and new events then reference events the database no longer has. Only a restart clears that.
- **Nobody acted on five days of MatrixCanaryFailing.** The canary only logged "send-and-read-back failed", without the status or error.

## Follow-ups

- dotfiles #69: Nebula restarts in place on a deploy. Merged and live.
- `failoverDelay: 300` on every CloudNativePG Cluster (this change), and in Hub's database template.
- site-failover: a planned switchover waits until the target replica is streaming with no lag.
- Synapse (and MAS) restart after their database changes primary.
- The canary logs the HTTP status and error, and restarts Synapse after repeated server errors (at most once an hour).
