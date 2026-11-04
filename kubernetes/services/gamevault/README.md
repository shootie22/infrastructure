# Games

https://games.yeetus.net is [GameVault](https://gamevau.lt), our library of DRM-free games: download and
install them from the web UI or the desktop app, with playtime, progress and save files. The sign-in is
Keycloak's network-yeetus realm: anyone in the `games` group gets in and has an account made at their first
sign-in. There are no passwords, no sign-up and no API keys in GameVault itself. `radu` is the admin
(`SERVER_ADMIN_USERNAME`); everyone else is a user.

- `deployment.yaml`: GameVault, one copy, on whichever of the thinkcentre and fuji holds the
  `ha.radunenu.com/gamevault` label (site-failover, as Mealie). Its folder is
  `/home/main/storage/gamevault` on the thinkcentre's 4 TB disk, mounted at `/srv/ha/gamevault` and copied
  to fuji every 10 minutes (without `tmp/`). In it: `files/` the games, `media/` covers, `savefiles/`,
  `config/` (the downloaded web UI), and `tmp/`, where a game that isn't an archive is packed for
  download. Its settings are in the `gamevault-env` ConfigMap at the end. It runs as 1000 with a
  read-only root.
- `database.yaml`: its Postgres (CloudNativePG, one instance in each site, the primary follows GameVault),
  and the hourly dump into fuji's Borg folder.
- `secret.sops.yaml`: the Keycloak client secret and `AUTH_SEED` (every token and session secret comes
  from it), made with `scripts/create-gamevault-secret.sh`.
- `igdb.sops.yaml`, once there: the Twitch app GameVault fetches covers and descriptions with, made with
  `scripts/create-gamevault-igdb-secret.sh`. Optional; without it there's no metadata.
- `ingress.yaml`: all of it behind GameVault's sign-in. DNS only in Cloudflare, like Send: whole games
  through the proxy break its terms, and it cuts uploads at 100 MB.
- `networkpolicy.yaml`: in only from Traefik and monitoring; out to its Postgres and 443 (Keycloak, IGDB,
  Twitch, GitHub for the web UI).
- The client itself is in `keycloak/realms.yaml` (network-yeetus, gated by the `games` group; no PKCE,
  GameVault doesn't send one), with its secret in `keycloak/gamevault-client.sops.yaml`. Home's tile is in
  `keycloak/home-catalog.yaml`.

Backups: the database hourly through fuji's Borg. The folder goes with the thinkcentre's Borg backup of
`/home/main`, except `files/` and `tmp/`: games can be downloaded again, and they'd fill the repository.
Covers and save files are kept.

## First-time setup

1. The secrets (done once, already in the repo):
   `nix shell nixpkgs#sops -c bash scripts/create-gamevault-secret.sh`.
2. On the thinkcentre, the folder on the 4 TB disk, owned by GameVault's user. Only by hand: while the
   disk isn't mounted the folder isn't there, so the pod stays Pending instead of starting on an empty
   library.

   ```sh
   sudo install -d -o 1000 -g 1000 -m 0750 /home/main/storage/gamevault
   ```

3. dotfiles: `gamevault` in `dotfiles.siteFailover.services` on the thinkcentre (initial) and fuji, then
   rebuild both. That makes `/srv/ha/gamevault` and the label; until then the pod stays Pending.
4. DNS: `yeetus.net/games/CNAME` in `tofu/dns-records.tf`, DNS only.
5. In Keycloak (network-yeetus), add yourself and the others to `games`.
6. Sign in at https://games.yeetus.net as `radu` first, then the others.
7. IGDB, when wanted: `nix shell nixpkgs#sops -c bash scripts/create-gamevault-igdb-secret.sh`, and bump
   `config-revision` in `deployment.yaml` in the same change.

## Adding games

Through the games inbox (https://games-inbox.yeetus.net, [../games-inbox](../games-inbox/README.md)): anyone
in `games` uploads into their own inbox, and radu moves what's good into the library from there. Or put them
in `/home/main/storage/gamevault/files` on the thinkcentre directly, owned by 1000 (`rsync -avP --partial`
as `main` resumes too). Archives (`.zip`, `.7z`, ...) where possible; GameVault finds new files by itself. The file name says what it is, e.g.
`Celeste (2018).zip` (the naming rules: https://gamevau.lt/docs/server-docs/structure). A folder works too,
but every download of it is packed into `tmp/` first. Uploads from the web UI work up to Traefik's 30-minute
limit per request.

Someone who leaves `games` can't sign in again, but a session already open lasts until its refresh token
runs out (30 days): deactivate them in GameVault's admin page too.

## Space

fuji keeps its copy on its root disk (`/srv/standby/thinkcentre/gamevault`). With the library past about
150 GB that's too tight: give fuji a disk for `/srv/standby` first.
