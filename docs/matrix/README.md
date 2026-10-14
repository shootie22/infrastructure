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
- runbooks: written as each procedure gets tested

## Status

Planned on 2026-10-14. Nothing is built yet.

| Phase | What | Status |
|---|---|---|
| 0 | Audit hetzy, read-only: Synapse version, database, media size, auth, federation, bots | done 14 Oct |
| 1 | Platform: Matrix's Postgres (synchronous), the `matrix` site-failover label, near-continuous media copy, the edge front door | |
| 2 | yeetus.net: Synapse, MAS, the Keycloak client, Element Web config, monitoring, a canary bot | |
| 3 | Calls: LiveKit on fuji with a standby on the edge, the JWT service, Element Call | |
| 4 | Drills. yeetus.net counts as production only after these pass | |
| 5 | nuke.zip moves into the cluster, same name and keys, rehearsed first | |
| 6 | nuke.zip and yeetus.net federate, users switch at their own pace | |
