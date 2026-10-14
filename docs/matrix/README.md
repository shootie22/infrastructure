# Matrix

Matrix is the service with the most users (about 10 a day) and the one that matters most: it's how we talk. Today it's nuke.zip's Synapse and LiveKit on one Hetzner VPS (`hetzy`), outside the cluster, with no failover and a price I want to stop paying. This project moves Matrix into the cluster, highly available like the rest ([#139](https://github.com/shootie22/infrastructure/issues/139)).

## The goal

- A new homeserver for **yeetus.net**: users are `@user:yeetus.net`, login only through Keycloak, no federation with anyone (later only with nuke.zip).
- The full Element Call stack (LiveKit and its JWT service), just as available.
- It keeps working when a node, a site or the edge goes down, with the shortest switch we can get.
- Later, nuke.zip moves off the VPS **with nothing lost**, and its users move to yeetus.net accounts when they're ready.

## Where things are

- [architecture.md](architecture.md): the design, what runs where, how it fails over, and why
- [migration.md](migration.md): how nuke.zip moves in and how its users switch
- [questions.md](questions.md): the questions asked while planning, with the answers
- [../ha/decisions.md](../ha/decisions.md): the decisions, dated 2026-10-14
- [nuke-zip-audit.md](nuke-zip-audit.md): what's actually on hetzy
- `drills.md`: failover drills with the measured downtime (Phase 4)
- runbooks:
  - [first-deploy.md](runbooks/first-deploy.md): from merged branches to a working yeetus.net, and the steps only a human can do
  - [moving-matrix.md](runbooks/moving-matrix.md): where Matrix runs, moving it on purpose, how the databases follow
  - [upgrades.md](runbooks/upgrades.md): Synapse and MAS migrate their schema forward, so a dump first
  - [restore.md](runbooks/restore.md): databases from the dumps, media from the copies and Borg
  - [offboarding.md](runbooks/offboarding.md): someone leaves
  - [canary.md](runbooks/canary.md): the canary's account, room and token

## Status

Planned on 2026-10-14. Phases 1-3 are written (branches `matrix-phase1` to `matrix-phase3`, and dotfiles `matrix-phase1`) but not deployed yet; [runbooks/first-deploy.md](runbooks/first-deploy.md) is the way in.

| Phase | What | Status |
|---|---|---|
| 0 | Audit hetzy, read-only: Synapse version, database, media size, auth, federation, bots | done 14 Oct |
| 1 | Platform: Matrix's Postgres (one instance per site), the `matrix` site-failover label, media copied every minute, the database primary following Synapse, fuji's CI slot down to 2 CPUs | in review |
| 2 | yeetus.net: Synapse, MAS, the Keycloak client, Element Web config, monitoring, a canary bot | built, in review (canary bot to do) |
| 3 | Calls: LiveKit on fuji with a standby on the edge, the JWT service, Element Call | built, in review; needs RO port forwards |
| 4 | Drills. yeetus.net counts as production only after these pass | |
| 5 | nuke.zip moves into the cluster, same name and keys, rehearsed first | |
| 6 | nuke.zip and yeetus.net federate, users switch at their own pace | |
