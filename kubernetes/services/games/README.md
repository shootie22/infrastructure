# Games (the new GameVault)

The server for the new GameVault (radu/gamevault on git.yeetus.net): a desktop app for Linux, Windows and
macOS that installs and launches games, syncs saves, and has the activity feed, screenshots and friends. Everything is
encrypted by the app before it gets here, so this server stores the games, saves, screenshots and records
without being able to read any of them. It replaces the old GameVault in [../gamevault](../gamevault/README.md)
once everyone has the app (radu/gamevault#26).

- `deployment.yaml`: the server, one copy, on whichever of the thinkcentre and fuji holds the
  `ha.radunenu.com/games` label (site-failover, as the old one). Its folder is `/home/main/storage/games` on
  the thinkcentre's 4 TB disk, mounted at `/srv/ha/games` and copied to fuji every 10 minutes. In it, `blobs/`
  (every game chunk, save version and screenshot, encrypted and padded), with `blobs/tmp/` for uploads in
  progress. It runs as 1000 with a read-only root.
- `database.yaml`: its Postgres (CloudNativePG, one instance in each site, the primary follows the server),
  and the hourly dump into fuji's Borg folder. The membership log and the records, all encrypted by the app
  except who wrote them and when.
- `ingress.yaml`: only `/v1` (the API and the websocket) and `/healthz` on games.yeetus.net; everything else
  still goes to the old GameVault until the cutover, so no new DNS name is needed. Hidden from the status
  page until then.
- `networkpolicy.yaml`: in only from Traefik, monitoring and the nodes; out to its Postgres and 443
  (Keycloak's keys).
- `updater.yaml`: the fast lane until the first release. The image is `git.radunenu.com/radu/gamevault-server:main`,
  which radu/gamevault's CI publishes after its tests and a smoke test pass; this restarts the server when
  it changes.
- Sign-in is the `games` client in `keycloak/realms.yaml` (network-yeetus): public, PKCE, the device code
  grant for the Steam Deck, and DPoP-bound tokens. People need the `games` client role `access`, which the
  `games` group gives.

Backups: the database hourly through fuji's Borg. The folder goes with the thinkcentre's Borg backup of
`/home/main`, all of it: saves and screenshots are blobs too, and they can't be told apart from the games
from here.

## First-time setup

1. radu/gamevault needs a `REGISTRY_TOKEN` Actions secret (a Gitea token with package write), so its CI
   publishes the image. Until then the image job skips itself and the pod can't pull.
2. On the thinkcentre, the folder on the 4 TB disk, owned by the server's user. Only by hand: while the disk
   isn't mounted the folder isn't there, so the pod stays Pending instead of starting on an empty library.

   ```sh
   sudo install -d -o 1000 -g 1000 -m 0750 /home/main/storage/games
   ```

3. dotfiles: `games` in `dotfiles.siteFailover.services` on the thinkcentre (initial) and fuji, then rebuild
   both. That makes `/srv/ha/games` and the label; until then the pod stays Pending.
4. The `games` Keycloak client (in the same pull request chain as this folder).
5. radu signs in with the app first and creates the group. The app shows the recovery key once; it goes
   in Vaultwarden. Everyone else signs in after that and radu lets each of them in from the app.
