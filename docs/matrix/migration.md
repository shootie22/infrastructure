# Moving nuke.zip, and its users to yeetus.net

## The constraint

A Matrix ID belongs to its server name for good. `@user:nuke.zip` can't become `@user:yeetus.net`: every event in every room is signed with nuke.zip's key, and no tool renames a server. So "moving users to yeetus.net" means new accounts on yeetus.net, and nuke.zip has to keep running somewhere for its history and media to stay readable.

## The order

1. **yeetus.net first, on its own.** Built, used by a couple of us, and through the failover drills (Phase 4). nuke.zip stays on the VPS, untouched, the whole time.
2. **Rehearse the nuke.zip move** on a copy: restore a dump and the media into a namespace with no ingress and all egress denied. That copy holds nuke.zip's real signing key, so it must never be reachable or reach out. Time it.
3. **Move nuke.zip into the cluster**, same server name, signing key, database and media, in a short window announced in advance:
   1. stop Synapse on hetzy
   2. last dump, last media rsync
   3. restore into `matrix-nuke` (its own CNPG database, its own media label, the shared LiveKit)
   4. point nuke.zip's DNS at the edge front door (nuke.zip goes into tofu and onto the deSEC standby first)
   5. check: log in, history, media, a call, the bots
4. **Keep hetzy stopped but intact** for 2-4 weeks as the way back, then cancel it. LiveKit, the metrics tunnels and matrix-webhook-bot move off it too.
5. **Federate nuke.zip and yeetus.net** with each other and nobody else. nuke.zip has federation off today ([audit](nuke-zip-audit.md)), so this turns it on with yeetus.net as the only allowed server. Users switch when they're ready.

nuke.zip keeps the login it has today (passwords), so nobody has to do anything for step 3: their apps reconnect, and that's all they see.

What moves, from the [audit](nuke-zip-audit.md):

- the database: Postgres 16, 1.8 GB, `C` collation. `pg_dump`/`pg_restore` into CNPG (Postgres 18) with the same collation. No SQLite port needed; the SQLite file `homeserver.yaml` names is an unused leftover.
- the media: 30 GB. Copied ahead of time while nuke.zip runs. The final rsync in the window only sends what changed.
- the signing key, and the lk-jwt-service appservice registration.
- the GIF bot and the free games bot, **with their E2EE stores and sessions**, so they don't come back as new unverified devices. They run in the cluster like steamhappy (file copy, site-failover).
- the sticker picker (`s.nuke.zip`, 749 MB of static files), as a static site with a copy per site.
- Synapse at the same version as on hetzy, or newer. Its schema only migrates forward.

Not moved: Element Web's old copy on hetzy (the cluster serves c.nuke.zip since #160), and the monitoring containers. The dead vhosts (`g.nuke.zip`, `j.nuke.zip`, `auth.radunenu.com`) also stay behind. coturn only moves if something still uses old-style calls.

nuke.zip uploads can be up to 5000 MB, so its names stay DNS-only to the edge, not through Cloudflare's proxy (100 MB cap).

Optional before the move: removing devices nobody has used in months. Messages queued for them (`device_inbox`) are 1.25 GB of the 1.8 GB database. It's a change on production, so only with an explicit go.

## What a user does to switch (guide to write)

1. Sign in to yeetus.net through Keycloak (Element Web at chat.yeetus.net, or Element X).
2. From the nuke.zip account, invite the new account to each room, and give it the same power level.
3. Export the E2E room keys from the nuke.zip account (Settings → Security) and import them into the new one, so old encrypted messages stay readable.
4. Start DMs again from the new account.
5. Keep the nuke.zip account signed in somewhere if you want, as the archive.

Rooms keep their full history on yeetus.net once it's joined, as long as nuke.zip is up to backfill. Media posted on nuke.zip stays on nuke.zip, which is why nuke.zip stays up as the archive instead of being turned off.

## Later

Once everyone has switched: no new rooms on nuke.zip, it only serves the archive. Turning it off for good would lose old media and history nobody has opened from yeetus.net, so that's a separate decision for much later.
