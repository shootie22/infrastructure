# Runbooks

Step by step procedures. Each one says whether it has been run for real yet.

- [drills.md](drills.md): the failure drills (#43-#46, #160): what goes down, what should happen and how fast, how to get back. All run for real on 2026-10-07, results included.
- [site-failover.md](site-failover.md): where the services with files run, what happens when a site goes, and moving one on purpose. Proven in the drills.
- [restore.md](restore.md): bringing back older data from Borg, for what HA can't undo. Test plan in [#92](https://github.com/shootie22/infrastructure/issues/92), not run yet.
- [replace-edge.md](replace-edge.md): moving the edge to a new VPS. Run up to step 6 for the first install; the full swap is planned for February 2027.
- [dns-switch-to-standby.md](dns-switch-to-standby.md): switching nameservers to the deSEC standby by hand. #77 does it automatically (dry run for now). Not tested for real, since that means actually switching.
- [thinkcentre-reinstall.md](thinkcentre-reinstall.md): the thinkcentre's move to NixOS. Done 5 Oct.
- [etcd-migration.md](etcd-migration.md): fuji from SQLite to etcd. Done 5 Oct.
