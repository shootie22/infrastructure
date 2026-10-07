# Restore from Borg

For what HA doesn't cover: data that went bad and got copied to the other site with it (a wrong delete, a broken upgrade), or both copies gone. Every service runs in both sites now (service-ha.md), so this is about bringing back an older state, not about a site being down.

Not tested yet: the test plan at the end is [#92](https://github.com/shootie22/infrastructure/issues/92).

## What is where

| What | Backed up by | When | Kept |
|---|---|---|---|
| Postgres (Gitea, Vaultwarden, Keycloak, Joplin, Rybbit) | hourly `pg_dump -Fc` into `/var/lib/pg-dumps` on fuji, then fuji's Borg job (`fuji-k3s`) | dump hourly, Borg 03:30 daily | Borg: 7 daily, 4 weekly, 6 monthly |
| The cluster (etcd snapshots) | k3s every 12 hours into `server/db/snapshots`, then `fuji-k3s` | 03:30 daily | same |
| Volumes on fuji (Headscale, legacy-web, Prometheus and Loki on fuji) | `fuji-k3s`, through `backup-staging/storage` | daily | same |
| Services with files, wherever they are active | the thinkcentre's job (`server-backups`, all of `/home`): its own services in `/home/main/services`, fuji's in `/home/standby/fuji` | Tue, Thu, Sat, Sun 03:00 UTC | see its prune settings |
| Grafana's database | not backed up on purpose: nothing in it has to survive (decisions.md) | | |

Both repositories are on the Mac's 10 TB disk (`/Volumes/Expansion/borg_repos`), and from there in Backblaze, the only offsite copy (decisions.md, 2026-10-07). The passphrases are in the hosts' sops files; see [bootstrap.md](../../bootstrap.md) for the keys that live outside Git.

The services with files always have their live data on one node and a copy at most 10 minutes old on the other, and the thinkcentre's Borg job sees both: it backs up its own active folders and the copies it receives from fuji. So whichever node a service is on, its files reach Borg.

## Restore a database

From the newest good dump. The Borg archive name says the day; the dump inside it is the last hourly one before 03:30.

1. On fuji as root, extract the dump: `borg extract <repo>::<archive> var/lib/pg-dumps/<db>.dump` into a scratch folder.
2. Stop the app, so nothing writes meanwhile: `kubectl -n <ns> scale deploy/<app> --replicas=0` (Argo puts it back on its next sync, so pause auto-sync for that app first).
3. Restore into the primary: copy the dump into the primary's pod and run `pg_restore --clean --if-exists -d <db> <db>.dump` as the app's user. The replica follows by itself.
4. Start the app again and turn Argo's auto-sync back on.

## Restore a service's files

For the services on site-failover. The live folder is on whichever node holds `ha.radunenu.com/<svc>=active`.

1. Stop the service (scale to 0, Argo paused as above). The copy job doesn't send while it can't confirm it's active, but stopping the app is what matters.
2. On the active node as root, extract the folder from the right archive (thinkcentre's `server-backups`; fuji's own copies of DK's services are also in there under `home/standby/fuji`) into a scratch folder, then move it into place with the owner the app expects.
3. Start the service. The next copy, within 10 minutes, overwrites the other site's copy with the restored state.

## Restore the cluster

[bootstrap.md](../../bootstrap.md), "Everything lost".

## Test plan (#92)

Each test restores into a scratch place, never over live data, and notes the time it took.

1. **A database:** Gitea's dump from last night's `fuji-k3s` archive into a scratch CNPG cluster (one instance, a `restore-test` namespace); compare row counts of a few tables with the live one; delete the namespace.
2. **Files:** PrivateBin's folder from the thinkcentre's latest archive into `/tmp/restore-test` on the thinkcentre; `diff -r` against the live folder (only the last days' pastes should differ).
3. **A game world:** Minecraft Skyblock's world the same way, then start a throwaway server on it on the workstation to see it loads.
4. **The cluster:** an etcd snapshot restored in a VM on the workstation (`--cluster-reset-restore-path`), checking `kubectl get ns` lists everything.

Needs root on fuji and the thinkcentre for the Borg passphrases, so it's done together.
