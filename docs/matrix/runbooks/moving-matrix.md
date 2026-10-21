# Where Matrix runs, and moving it

yeetus.net's Synapse runs on whichever of fuji and the thinkcentre holds `ha.radunenu.com/matrix=active`, like the other services with files ([../../ha/runbooks/site-failover.md](../../ha/runbooks/site-failover.md)). Two things are different for Matrix:

- **The media copy runs every minute**, not every 10 (`standby-copy-matrix`). `MatrixMediaCopyStale` fires past 10 minutes.
- **The databases follow Synapse.** site-failover on the node running Synapse switches the CNPG primary of `synapse-db` and `mas-db` to the instance next to it, a minute after it finds it in the other site and only while CNPG is healthy (at most once per 10 minutes). It's a clean switchover (the replica catches up first), so it loses nothing. `PlacementDrift` fires if they're apart for 10 minutes anyway, and pages after an hour.

MAS, lk-jwt-service and the well-known run in both sites all the time; nothing to move.

## Where is it now?

```sh
kubectl get nodes -L ha.radunenu.com/matrix
kubectl -n matrix get pods -o wide
kubectl cnpg status synapse-db -n matrix | head -20
kubectl -n matrix get endpoints livekit     # which SFU takes calls
```

## Moving it on purpose

At a quiet moment, both nodes up (from site-failover.md, with `matrix` as the service):

0. A few hours before, tell people in Network Updates ([network-updates.md](network-updates.md)): about 30 s of "sending...", and calls may drop once.
1. On the active node: `systemctl start standby-copy-matrix` and check it succeeded.
2. Right after: `kubectl label node <active> ha.radunenu.com/matrix-` then `kubectl label node <other> ha.radunenu.com/matrix=active`. The old node fences Synapse within seconds.
3. `kubectl -n matrix delete pod -l app=synapse`; the new one starts on the other node (about 30 s of "sending...").
4. Within about two minutes the database primaries follow: `journalctl -u site-failover | grep switchover` on the new node.

Never put the label on both nodes: site-failover then refuses to move the databases (it logs "not only by this node"), and two Synapses could try to start.

## Calls

fuji's SFU takes calls; the edge's only while fuji's is unreachable or still has calls from then. Moving calls by hand isn't needed: stop fuji's (`kubectl -n matrix scale deploy livekit-ro --replicas 0`, Argo puts it back) and new calls go to the edge.
