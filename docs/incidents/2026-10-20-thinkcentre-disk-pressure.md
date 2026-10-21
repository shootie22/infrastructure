# 2026-10-20: thinkcentre's disk full, its services down, nothing moved

**Recovered.** Down about an hour: from 20:35 UTC kubelet on the thinkcentre evicted nearly every pod there and turned new ones away: Gitea, Headscale, Baikal, PrivateBin, Send, Audiobookshelf, legacy-web, steamhappy, the game servers, Rybbit's ClickHouse, hub-test, CI, and the DK replicas of Keycloak, Joplin and SearXNG. The node stayed Ready the whole time, so site-failover moved nothing, although fuji had a fresh copy of every service. DiskPressure cleared at 21:32 once 96 GiB were freed, and the services came back on the thinkcentre by themselves.

## Timeline (UTC)

| Time | What happened |
|---|---|
| days before | The thinkcentre's `/home` (413 GiB, also `/var/lib/rancher`: containerd's layers and the local-path volumes) has 48-51 GiB free, about 11%. No alert: the disk alerts only watch `/` and `/boot`. |
| from 13:00 | Every CI job pod on the thinkcentre takes 12-23 GiB of `/home` while it runs and gives it back when it's deleted (free space and `ci-thinkcentre`'s lifetimes match one for one). Gitea's packages grow by about 5 GB over the day. |
| 19:00 | 25 GiB free. Kubelet's image garbage collection is over its 85% mark and finds nothing to delete. |
| 20:35 | `/home` under 5% free with a CI job running: DiskPressure. Kubelet evicts CI first (priority -100), which frees about 30 GiB, then keeps going: k3s sets the minimum reclaim to 10% of the disk (41 GiB), so it evicts Baikal, Keycloak, Gitea, Joplin, SearXNG, legacy-web and on, node-exporter and Alloy included. |
| 20:35-20:38 | The evicted pods come back Pending: the node is tainted `disk-pressure:NoSchedule` and their `ha.radunenu.com/<service>` label keeps them on it. `hs.radunenu.com` stops answering. |
| 20:38 | `SiteFailoverServiceNotRunning` fires for all 17 services, but only because the thinkcentre's node-exporter was gone with its metrics; to site-failover every service was still "active" on the thinkcentre. |
| 20:52 | 59 GiB free (14.3%), short of the 15% kubelet wants before it lets go. The only pod left to evict is Traefik, which it may not evict. DiskPressure stays on for good. |
| 21:00-21:25 | Investigation. The copies (the first suspicion) were fine all along: every job in both directions finished within its 10 minutes. The retired Vintage Story world (96 GiB, untouched since Oct 2025) is copied to the 4 TB disk and checked with `diff`. |
| ~21:28 | The world is removed from `/home`: 151 GiB free. |
| 21:32 | DiskPressure clears. Pods are scheduled on the thinkcentre again; Git and Headscale answer within a few minutes. |
| 21:35-21:55 | The DaemonSets' evicted pods are replaced (with the controller's backoff, up to 15 minutes for headlamp's tailnet proxy). The DK Postgres replicas catch up by 21:42, except Vaultwarden's, which stays in recovery: its base backup had been cut off, so it has to be cloned again. |

## Why nothing moved

1. **site-failover only took over from a node that wasn't Ready.** A node under disk pressure is Ready: it answers, it heartbeats, it just won't run anything. Every service sat on the thinkcentre's label with its pods Pending, and fuji, with a whole copy of each, did nothing.
2. **k3s's minimum reclaim is 10% of the disk.** Evicting CI alone would have been enough. Kubelet evicted almost everything and then stayed in DiskPressure with nothing left to evict, an outage that couldn't end by itself.
3. **CI shared the disk with everything else, with nothing checking for room.** One job's 23 GiB on a disk that was 11% free.
4. **`/home` wasn't watched.** `NodeFilesystemFillingUp` and the critical one only looked at `/` and `/boot`. The thinkcentre's `/home` was under 20% free for days.
5. **The monitoring on the node was evicted with the rest.** node-exporter and Alloy were ordinary pods, so the thinkcentre's disk went unmeasured exactly when it mattered, and the one alert that fired fired for the wrong reason.

## What changed

- **site-failover takes over from a node that's up but can't run the service** (dotfiles): when a workload of the service has had no pod running and one stuck Pending on the holder for 2 minutes (unschedulable there, or never getting its containers started: 10 minutes more for that, it may be pulling an image). Not for an image that can't be pulled or a pod that crashes once started, since the other node wouldn't do better. At most once every 30 minutes per service, and never onto a node under pressure itself. Rehearsed in the VM test with a real full disk.
- **A node running a service refuses copies of it** (dotfiles): the old holder may still be up now, and its copy would land in the new holder's live folder. The receiving side refuses copies of a service that runs there, and the node taking over stops any copy already under way.
- **Kubelet reclaims 2 GiB, not 10% of the disk** (dotfiles `k3s-eviction.nix`, every node): the biggest user goes, the rest stays.
- **CI waits for room** (`ci-runner` dispatcher): a job pod starts on a node only if the disk holding its container layers keeps 10% free plus 35 GiB.
- **Alerts**: `KubernetesNodeUnderPressure` (paging) for Disk/Memory/PID pressure; `NodeFilesystemCriticallyLow` (under 10%, paging) and `NodeFilesystemFillingUp` (under 20%) now cover `/home` (and `/srv/standby` for the warning).
- **node-exporter and Alloy are `system-node-critical`**: kubelet neither evicts them nor turns them away under pressure.

## Follow-ups

- Vaultwarden's DK replica (`vaultwarden-db-1`) cloned again: `kubectl cnpg destroy vaultwarden-db 1` (the primary on fuji is fine).
- Vintage Story into its own Borg archive, outside the prune prefix, then off the 4 TB disk too.

- Gitea's packages are 83 GiB on the thinkcentre's `/home`: a cleanup rule for old container image versions.
- `/home/main/services/gitea-act-runner-thinkcentre` (12 GiB, root's, from before the CI runner moved into the cluster) looks unused.
- Where a CI job's 23 GiB actually go on `/home` (the job's Docker disk is an emptyDir on `/`): look at a running job.
- containerd's layers on their own logical volume, so the services' data and CI can't starve each other.
- `site_failover_active` says a node *may* run a service, not that it does. An alert on the service's pods running would have said what was down, not only that metrics were missing.
