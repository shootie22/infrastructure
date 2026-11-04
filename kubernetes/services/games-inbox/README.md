# Games inbox

https://games-inbox.yeetus.net is where games for [GameVault](../gamevault/README.md) are uploaded:
[copyparty](https://github.com/9001/copyparty), behind Keycloak. Anyone in the network-yeetus `games` group
can sign in (the same check as GameVault). Everyone can upload straight into `library`, which is GameVault's
`files/` (GameVault picks it up by itself), and has their own `inbox/<username>`, which only they and radu
can see. radu sees every inbox and moves what's good into the library. In the library nobody can delete,
rename or overwrite what's there: a second upload under a taken name is saved under a new name, and deleting
is GameVault's. Uploads go in resumable chunks: a big game survives a slow
line, a closed laptop or a restart, and continues where it stopped when the same file is dropped again.

- `deployment.yaml`: copyparty, one copy, on whichever node holds GameVault's `ha.radunenu.com/gamevault`
  label. It sees only `inbox/` and `files/` in GameVault's folder, and keeps its upload database in
  `.inbox-state/`. Runs as 1000 (GameVault's user) with a read-only root. Its settings are the
  `copyparty-config` ConfigMap at the end: who may see and do what, 200 GiB waiting per person, and no
  uploads once the 4 TB disk is down to 300 GiB free.
- `oauth2-proxy.yaml`: the login, two copies, one per site. Keycloak's gate on the `games-inbox` client
  (GameVault's) and `--allowed-role=gamevault:access` both keep out anyone not in `games`. A session is
  re-checked with Keycloak every hour and ends after 12.
- `ingress.yaml`: every request goes through oauth2-proxy (Traefik forwardAuth), which gives copyparty the
  username in `X-Auth-Request-Preferred-Username`; whatever the browser sent in that header is dropped
  first. DNS only, like games, and off the status page.
- `networkpolicy.yaml`: copyparty takes the username header from the pod network, so only Traefik (and the
  nodes, for probes) may reach it, and it can't reach anything. oauth2-proxy only reaches Keycloak.
- `secret.sops.yaml`: oauth2-proxy's client and cookie secrets, made with
  `scripts/create-games-inbox-secret.sh` along with `keycloak/games-inbox-client.sops.yaml`.
- The client is in `keycloak/realms.yaml` (network-yeetus, `games-inbox`).

The inbox isn't copied to fuji or backed up (dotfiles: GameVault's site-failover `exclude`, the
thinkcentre's Borg excludes): it's only a waiting room, and once a game is in the library it's copied like
the rest.

## Using it

- Upload: sign in, open `library` (or your folder under `inbox`, to leave it for radu to look at), drop files
  on the page. Archives (`.zip`, `.7z`) named `Title (Year).zip` work best in GameVault.
- radu: open `inbox/<someone>`, select the files, cut (`ctrl-x`), open `library`, paste (`ctrl-v`). It's a
  move on the same disk, so it's instant whatever the size. To turn something down, delete it from the
  inbox.
- Someone taken out of `games` can't sign in again, and an open session ends within the hour.

## First-time setup

1. The secrets (done once, already in the repo):
   `nix shell nixpkgs#sops -c bash scripts/create-games-inbox-secret.sh`.
2. dotfiles: the excludes for `inbox/` and `.inbox-state/` (both nodes), merged before this.
3. DNS: `yeetus.net/games-inbox/CNAME` in `tofu/dns-records.tf`, applied with `scripts/tofu`.
