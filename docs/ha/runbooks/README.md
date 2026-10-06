# Runbooks

Step by step procedures. Each one says whether it has been run for real yet.

Written:
- [replace-edge.md](replace-edge.md): moving the edge to a new VPS. Run up to step 6 for the first install; the full swap is planned for February 2027.
- [dns-switch-to-standby.md](dns-switch-to-standby.md): switching nameservers to the deSEC standby ([#6](https://github.com/shootie22/infrastructure/issues/6)). Not tested for real, since that means actually switching.

- [site-failover.md](site-failover.md): where the services with files run, what happens when a site goes, and moving one on purpose. Rehearsed in VMs; no real failover yet.

Planned:
- `etcd-migration.md`: switching fuji from SQLite to etcd ([#20](https://github.com/shootie22/infrastructure/issues/20))
