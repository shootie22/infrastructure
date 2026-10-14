# Upgrading Synapse, MAS, LiveKit

Renovate opens the PRs (images are pinned by digest). Matrix is the one service where an upgrade can't be rolled back by reverting: Synapse and MAS migrate their database schema forward when they start.

## Synapse or MAS

1. Read the release notes from the current version up to the new one (github.com/element-hq/synapse/releases, .../matrix-authentication-service/releases): removed options, required changes, long migrations.
2. A fresh dump just before (the hourly one may be 59 minutes old):

   ```sh
   kubectl -n matrix create job --from=cronjob/synapse-db-dump synapse-db-dump-pre-upgrade
   kubectl -n matrix create job --from=cronjob/mas-db-dump mas-db-dump-pre-upgrade
   # on fuji: ls -l /var/lib/pg-dumps/matrix-*.dump
   ```

3. Merge at a quiet time. Synapse restarts (Recreate: about 30 s of "sending..."), its startup probe allows 15 minutes for migrations. MAS rolls one replica at a time.
4. Check: `kubectl -n matrix logs deploy/synapse | grep -i -E 'error|migrat'`, the canary stays green, sign in once.

If it goes wrong: going back means restoring the dump into the database ([restore.md](restore.md)) and reverting the image, losing whatever was sent since the dump.

Later, with nuke.zip in the cluster: upgrade yeetus.net first, nuke.zip a few days after.

## LiveKit, lk-jwt-service, Element Call

No database. Merge, then a test call. fuji's SFU restarting drops calls running on it; they reconnect.
