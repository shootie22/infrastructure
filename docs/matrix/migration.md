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
5. **Federate nuke.zip and yeetus.net** with each other and nobody else. Users switch when they're ready.

nuke.zip keeps the login it has today, so nobody has to do anything for step 3: their apps reconnect, and that's all they see. If nuke.zip is SQLite rather than Postgres, step 3 includes `synapse_port_db` (Phase 0 finds out).

## What a user does to switch (guide to write)

1. Sign in to yeetus.net through Keycloak (Element Web at chat.yeetus.net, or Element X).
2. From the nuke.zip account, invite the new account to each room, and give it the same power level.
3. Export the E2E room keys from the nuke.zip account (Settings → Security) and import them into the new one, so old encrypted messages stay readable.
4. Start DMs again from the new account.
5. Keep the nuke.zip account signed in somewhere if you want, as the archive.

Rooms keep their full history on yeetus.net once it's joined, as long as nuke.zip is up to backfill. Media posted on nuke.zip stays on nuke.zip, which is why nuke.zip stays up as the archive instead of being turned off.

## Later

Once everyone has switched: no new rooms on nuke.zip, it only serves the archive. Turning it off for good would lose old media and history nobody has opened from yeetus.net, so that's a separate decision for much later.
