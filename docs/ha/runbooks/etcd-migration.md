# Move the cluster from SQLite to etcd

Phase 3 ([#20](https://github.com/shootie22/infrastructure/issues/20)-[#26](https://github.com/shootie22/infrastructure/issues/26)). Today fuji is the only k3s server and keeps the cluster in SQLite. Afterwards fuji, the thinkcentre and the edge each hold a copy in etcd, and any one of them can go away.

The servers talk over Nebula ([nebula.md](../nebula.md)), not the tailnet. The tailnet needs Headscale to come back after a reboot, and Headscale runs in the cluster; Nebula needs nothing from the cluster ([#37](https://github.com/shootie22/infrastructure/issues/37), decision 2026-10-05).

Rehearsed in VMs: dotfiles `tests/etcd-over-nebula.nix`, with RO and DK behind NAT, Nebula like the real one, and a tailnet that gets switched off. The older `tests/etcd-migration.nix` covers snapshot restore.

## What the rehearsal showed

- fuji moves to etcd and onto its Nebula address in one switch. The data stays, pods keep running and reach each other.
- The thinkcentre goes from agent to server in place, the edge joins as the etcd-only third member, and every etcd member is on a Nebula address.
- With the tailnet switched off: the API, writes and the pod network keep working.
- fuji crashes and comes back with no tailnet: it rejoins etcd and is Ready about 25 seconds after booting. This is the case that couldn't work over the tailnet.
- A cold start of everything with no tailnet comes back on its own.
- flannel's WireGuard runs inside Nebula. With `--flannel-iface nebula.mesh` it sizes its packets to fit; the rehearsal pings with big packets at every step to prove it.
- After a node reboots, its flannel WireGuard key is new (k3s keeps it in /run). The other nodes pick it up by themselves.

## Before

1. Nebula on all servers, both lighthouses tested ([#141](https://github.com/shootie22/infrastructure/issues/141)). Done 5 Oct.
2. k3s waits for the node's Nebula address before it starts, like it waits for the tailnet today (dotfiles `modules/nixos/k3s-tailnet-guard.nix`), so a reboot doesn't start k3s on an address that isn't there yet.
3. Backups: a Borg run on fuji, plus a copy of `/var/lib/rancher/k3s/server/db/state.db` taken while k3s is stopped.
4. A quiet hour. The API is down for a moment during step 5. Workloads keep running, but Argo and kubectl wait.

Nothing to open in the Headscale ACL or the host firewalls: Nebula's interface is trusted on the servers, and only our certificates get onto it.

## Steps

5. **fuji, in one switch:** `services.k3s.clusterInit = true`, and its node address, external address and advertised API address all its Nebula address, plus `--flannel-iface nebula.mesh` instead of `--flannel-external-ip`. Check: `/var/lib/rancher/k3s/server/db/etcd` exists, `kubectl get nodes -o wide` shows fuji on its Nebula address, every Argo app looks like before.
6. **thinkcentre as the second server:** `role = "server"`, `serverAddr` fuji's Nebula address, the same flags on its own Nebula address, the server token. Wait until it's Ready and `etcdctl member list` shows two started members.
7. **Straight on: the edge as the third member.** Two members are worse than one: losing either one loses the majority. So this window stays short. The edge gets its Nebula flags, `--disable-apiserver --disable-controller-manager --disable-scheduler` and the taint `node-role.kubernetes.io/etcd=true:NoExecute`. Wait for three started members, all with peer URLs on Nebula addresses.
8. **Agents, one at a time** (mixi, minima): `serverAddr` fuji's Nebula address, node and external address their Nebula address, `--flannel-iface nebula.mesh`. After each: the node is Ready on its new address, and its pods reach pods on another node. A fixed registration address for joining while fuji is down is [#21](https://github.com/shootie22/infrastructure/issues/21).
9. **Snapshots:** k3s's scheduled etcd snapshots on, and their folder (`/var/lib/rancher/k3s/server/db/snapshots`) in Borg ([#26](https://github.com/shootie22/infrastructure/issues/26)).
10. **Test:** stop k3s on fuji for a few minutes. The API keeps answering from the thinkcentre, and the edge's HAProxy keeps sending web traffic to DK's Traefik. Then start it again.
11. **Later, once all of this is settled:** fuji's tailnet route for its LAN address (used today so DK reaches the API) isn't needed anymore. The API is on Nebula.

## Done 5 Oct

All steps in about an hour, no outage beyond the API pausing for ~20 seconds at fuji's switch. Three things the real cluster had that the first rehearsal didn't:

- The agents' node addresses were LAN or public IPv6, not the tailnet. Dropping `--flannel-external-ip` at fuji's switch would have sent flannel to addresses the other site can't reach. The servers keep it (it now points at their Nebula addresses), and the rehearsal starts from the real setup.
- The migration from SQLite copied the API's lease for fuji's old LAN address without its expiry, so the `kubernetes` service kept that address as an endpoint forever (only reachable from DK over the tailnet). Deleted by hand from etcd: `etcdctl del /registry/masterleases/<old address>`. After any migration, check `etcdctl get /registry/masterleases/ --prefix --keys-only` only lists live servers.
- fuji's Borg job backed up a copy of the SQLite file, which stopped changing. It backs up the etcd snapshots now.

Test afterwards: k3s on fuji stopped for 3 minutes. The thinkcentre kept serving the API, the cluster state kept updating, all sites answered, and fuji rejoined by itself.

## If it goes wrong

- Step 5 fails and k3s won't come up: back to the previous flags, `clusterInit` off, and restore `state.db` from the copy taken in step 3.
- A member that won't join: remove it with `etcdctl member remove`, wipe its `/var/lib/rancher/k3s/server/db`, and join it again. While only two members exist, don't take either one down.
- An agent that doesn't come back after step 8: its previous flags and `serverAddr` still work while fuji is up, and it rejoins as before.

## Restoring a snapshot

For when the cluster's data is lost or broken on every member. Rehearsed in `tests/etcd-migration.nix`.

1. Stop k3s on all three servers.
2. On one of them (fuji in the rehearsal), run k3s once by hand with its usual flags plus `--cluster-reset --cluster-reset-restore-path=<snapshot>`. It restores and exits. Then start the service again. That server is now a one-member cluster with the snapshot's data. Everything written after the snapshot is gone.
3. On the other two, delete `/var/lib/rancher/k3s/server/db` and start k3s. They join the restored cluster from scratch.
4. Wait for three started members, then check Argo.
