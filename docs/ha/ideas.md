# Maybe later

Things that would make the setup better but aren't part of the plan. Nothing here has an issue or a phase, and the migration is done without them. If one of them turns out to be needed, it gets an issue and a decision then.

## Near-zero loss for the SQLite apps (Litestream + Garage)

Today the SQLite apps (Baikal, Headscale, Audiobookshelf's library) reach the other site with the 10-minute file copies ([decisions.md](decisions.md), 6 Oct). Litestream could stream every change instead, to S3 storage in the other site, so a failover loses about a second instead of up to 10 minutes.

- **What it takes:** a small S3 server in each site, and Litestream next to each SQLite app, writing to the other site's S3.
- **For the S3 server:** [Garage](https://garagehq.deuxfleurs.fr/), a small S3 server made for spreading over several sites on modest hardware. Not MinIO, which stopped publishing its community builds in 2025.
- **Gains:**
  - about a second of loss instead of up to 10 minutes
  - restoring to any point in time
  - an S3 endpoint in each site that other things could use too
- **Costs and risks:**
  - another stateful service per site, which needs its own backups, monitoring and upgrades
  - a second way of restoring next to the rsync copies, which is one more thing to get right in a bad moment
  - it only covers three apps, and they rarely write (calendar entries, tailnet nodes, listening progress)

Worth doing if one of those apps starts writing often enough that 10 minutes hurts, or if something else wants S3 anyway.
