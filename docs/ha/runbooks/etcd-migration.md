# Move the cluster from SQLite to etcd

Phase 3 ([#20](https://github.com/shootie22/infrastructure/issues/20)-[#26](https://github.com/shootie22/infrastructure/issues/26)). Today fuji is the only k3s server and keeps the cluster in SQLite. Afterwards fuji, the thinkcentre and the edge each hold a copy in etcd, and any one of them can go away.

Rehearsed in VMs: dotfiles `tests/etcd-migration.nix` (`nix build .#checks.x86_64-linux.etcd-migration -L`), same k3s version as fuji, flannel over WireGuard, latency like the real tailnet. All steps pass (2026-10-04).

## What the rehearsal showed

- Switching fuji to etcd took about 20 seconds of API downtime. The ConfigMap and the running workload were untouched.
- A second server joined in under a minute and a half. The etcd-only member got its taint and no pods.
- With fuji crashed, the thinkcentre kept serving the API, including writes. The agent stayed Ready: k3s agents remember all servers, not just the one they joined through. fuji rejoined by itself and caught up on the write it had missed.
- Round trips between the three members are 13-55 ms. etcd's defaults (100 ms heartbeat, 1 s election timeout) are comfortably above that, so no tuning is needed for now ([#25](https://github.com/shootie22/infrastructure/issues/25)).

## Before

1. Phase 2 done: the thinkcentre runs NixOS.
2. The tailnet lets the three servers reach each other: etcd 2379-2380, the API 6443, the kubelet 10250, flannel's WireGuard 51820/udp. The Headscale ACL has to allow fuji, the thinkcentre and the edge to reach each other on these, and each host's firewall has to accept them on `tailscale0`. The VM test doesn't cover this part.
3. Backups: a Borg run on fuji, plus a copy of `/var/lib/rancher/k3s/server/db/state.db` taken while k3s is stopped.
4. A quiet hour. The API is down for a moment during step 5. Workloads keep running, but Argo and kubectl wait.

## Steps

5. **fuji to etcd:** `services.k3s.clusterInit = true` on fuji, deploy. Check: `/var/lib/rancher/k3s/server/db/etcd` exists, `kubectl get nodes` and every Argo app look like before.
6. **thinkcentre as the second server:** `role = "server"`, `serverAddr` pointing at fuji, the server token. Wait until it's Ready and `etcdctl member list` shows two started members.
7. **Straight on: the edge as the third member.** Two members are worse than one: losing either one loses the majority. So this window stays short. The edge gets `--disable-apiserver --disable-controller-manager --disable-scheduler` and the taint `node-role.kubernetes.io/etcd=true:NoExecute`. Wait for three started members.
8. Agents (mixi, minima) need nothing: they learn the new servers by themselves. A fixed registration address for joining while fuji is down is [#21](https://github.com/shootie22/infrastructure/issues/21).
9. **Snapshots:** k3s's scheduled etcd snapshots on, and their folder (`/var/lib/rancher/k3s/server/db/snapshots`) in Borg ([#26](https://github.com/shootie22/infrastructure/issues/26)).
10. **Test:** stop k3s on fuji for a few minutes. The API keeps answering from the thinkcentre, and the edge's HAProxy keeps sending web traffic to DK's Traefik. Then start it again.

## If it goes wrong

- Step 5 fails and k3s won't come up: turn `clusterInit` off again and restore `state.db` from the copy taken in step 3.
- A member that won't join: remove it with `etcdctl member remove`, wipe its `/var/lib/rancher/k3s/server/db`, and join it again. While only two members exist, don't take either one down.

## Restoring a snapshot

For when the cluster's data is lost or broken on every member. Rehearsed in the same VM test.

1. Stop k3s on all three servers.
2. On one of them (fuji in the rehearsal), run k3s once by hand with its usual flags plus `--cluster-reset --cluster-reset-restore-path=<snapshot>`. It restores and exits. Then start the service again. That server is now a one-member cluster with the snapshot's data. Everything written after the snapshot is gone.
3. On the other two, delete `/var/lib/rancher/k3s/server/db` and start k3s. They join the restored cluster from scratch.
4. Wait for three started members, then check Argo.
