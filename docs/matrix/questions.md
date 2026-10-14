# Questions from planning

Asked while planning on 2026-10-14, kept here so the answers don't get lost.

**Synapse or another homeserver?**
Synapse. It's the only one with replicated Postgres, MAS for Keycloak login and everything Element Call needs (delayed events, MSC4222). Dendrite is in maintenance mode. tuwunel and continuwuity are fast but keep their data in an embedded database that can't be replicated across sites. Details in [architecture.md](architecture.md#synapse).

**How fast can it switch when something goes down?**
Seconds for most things, 2-3 minutes if fuji or all of RO dies. Synapse's main process can only run once, so true active-active needs Element's paid Synapse Pro. Clients hold messages as "sending" meanwhile, so nothing is lost. Table in [architecture.md](architecture.md#how-long-a-switch-takes).

**How much work is open federation later?**
Possible and reversible. The cost depends on which rooms we join: big public rooms mean gigabytes of state and CPU spikes on fuji. It needs workers (and Redis), cleanup jobs, a moderation bot and a bigger database. [architecture.md](architecture.md#open-federation-if-we-ever-want-it)

**Do the Gitea runners slow it down?**
Enough CPU, and chat shouldn't lag: Matrix gets top priority and real CPU requests, and fuji's CI slot is down to 2 of 4 cores. Calls are where it could be felt, through RO's uplink (image pushes from fuji to Gitea in DK) rather than the CPU. Measured in Phase 4; if felt, CI bandwidth on fuji gets capped or the runner skips the Matrix node. [architecture.md](architecture.md#gitea-runners-on-the-same-nodes)

**Can nuke.zip users keep everything when they move to yeetus.net?**
Not in place: a Matrix ID belongs to its server name. nuke.zip moves into the cluster with the same identity (nothing lost, nothing for users to do), then users switch to yeetus.net accounts at their own pace while nuke.zip stays as the archive. [migration.md](migration.md)

**Build yeetus.net beside nuke.zip and test it before touching nuke.zip?**
Yes, that's the order: yeetus.net is built and drilled first, nuke.zip stays on the VPS until then, and its move is rehearsed on a sealed-off copy.

**Media: S3 or files?**
Files, with the site-failover copy running every minute for Matrix. In-cluster S3 (Garage) can't take writes with one of two sites down, and an outside S3 is a new dependency (the Backblaze plan is Personal Backup, not S3). [architecture.md](architecture.md#media)

**Where does LiveKit run, given the edge is small?**
fuji (UPS, port forwards) runs the SFU. The edge only gets a small, stateless standby SFU for when fuji's is down; no Synapse, database or media there. [architecture.md](architecture.md#calls)

**Non-standard ports to hide from scanners?**
Not for HTTPS: scanners cover every port, and many networks block anything but 443. LiveKit's media ports and a future federation port can be unusual for free. What actually hides the setup is a wildcard certificate (names stay out of Certificate Transparency logs) and SNI routing. [architecture.md](architecture.md#non-standard-ports)
