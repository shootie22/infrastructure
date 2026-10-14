# Restoring yeetus.net's Matrix

For losing both database instances, or rolling back a bad upgrade. A single lost instance or site needs none of this: CNPG and site-failover handle it ([moving-matrix.md](moving-matrix.md)).

What there is:

- **Databases**: hourly `pg_dump` into `/var/lib/pg-dumps/matrix-synapse.dump` and `matrix-mas.dump` on fuji, and Borg's nightly copies of that folder (Mac mini, then Backblaze). Restoring from these loses what was written since the dump.
- **Media**: `/home/fuji/services/matrix/media` on fuji, its copy on the thinkcentre (`/home/standby/fuji/matrix`), and Borg's nightly copies of fuji.
- **Secrets** (signing key, MAS keys, passwords): in Git (`secrets.sops.yaml`), the signing key also in Vaultwarden.

## Restore a database from a dump

1. Stop the writers: `kubectl -n matrix scale deploy synapse mas --replicas 0` (Argo CD scales them back on its next sync; pause auto-sync for the `matrix` app first).
2. Restore into the current primary (Synapse shown; MAS the same with `mas-db`, user and database `mas`):

   ```sh
   p=$(kubectl -n matrix get cluster synapse-db -o jsonpath='{.status.currentPrimary}')
   kubectl -n matrix exec -i $p -c postgres -- \
     pg_restore --clean --if-exists --no-owner --role=synapse -U postgres -d synapse < matrix-synapse.dump
   ```

3. Start them again (resume auto-sync). Synapse checks the schema at start.
4. Sign in, check recent history, the canary.

If the whole cluster is gone, the CNPG cluster can bootstrap from the dump instead (`bootstrap.initdb.import`), then the same steps.

Restoring from Borg: [../../ha/runbooks/restore.md](../../ha/runbooks/restore.md) for getting files back from the Mac mini or Backblaze.

## Rehearsal

Part of Phase 4: restore last night's dumps into a scratch namespace and boot a Synapse on them with federation and ingress off.
