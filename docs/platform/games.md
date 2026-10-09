# Hub: games

Agreed on 2026-10-09 ([#193](https://github.com/shootie22/infrastructure/issues/193)). Builds on the deploy tool from [design.md](design.md). The work is in the [Platform 5: Games](https://github.com/shootie22/infrastructure/milestone/19) milestone.

I run a few Minecraft servers and want to stop setting them up by hand. Hub gets a Games section: deploy a server (vanilla, modded, a pack from Modrinth, CurseForge or FTB, or my own image), then run it from a panel with a console, files, players and settings. Like everything else here, anything that changes how a server is set up goes through a pull request.

## Decided with me

| Topic | Decision |
|---|---|
| Start and stop | `running: true/false` in the server's hub.yaml. Hub opens the PR and auto-merges it once the checks pass. Checks take 20-45 s and Argo syncs on GitHub's webhook, so it lands in about a minute. Restart is instant: `stop` over RCON and Kubernetes starts it again. |
| Files | A file manager in Hub, working straight on the server's disk: browse, edit, upload, download. Worlds and plugin configs are data, not config, so no PRs there. Every change goes in Hub's audit log. The server.properties keys Git manages show as read-only. |
| Sources | Modrinth, CurseForge, FTB, and plugins from SpigotMC. Mods and plugins go into a cart and the whole cart is one PR. |
| The servers I have | minecraft-hc and minecraft-skyblock get the panel first and nothing else changes. Moving them to the standard image comes later, one at a time, after a world backup. |

## What I looked at

Pterodactyl and Pelican (console, files, start-up variables per server type, SFTP), Crafty Controller and MCSManager (installing packs, scheduled tasks), and the Modrinth app for searching and picking versions. They all run their own daemon with access to the Docker socket, plus users, subusers and sometimes billing. I don't need any of that: Kubernetes already runs the containers and only I log in.

## A server is a hub.yaml

A game server is `kind: game` with a `minecraft` block:

```yaml
minecraft:
  type: paper            # vanilla, paper, purpur, fabric, forge, neoforge, modrinth, curseforge, ftb, image
  version: "1.21.4"      # a real version, never "latest"
  build: "232"           # Paper or Purpur build, Fabric loader, Forge version
  pack: {source: modrinth, id: "...", version: "..."}
  content:               # mods and plugins
    - {source: modrinth, id: "...", version: "..."}
    - {source: spigot, id: 1234, version: 5678}
  memory: 4G
  properties: {motd: "...", difficulty: hard, max-players: 20}
  whitelist: [...]
  ops: [...]
  running: true
  eula: true
```

Hub turns that into a Deployment on `itzg/minecraft-server`, the image most people use for this. It's pinned to a digest and Renovate bumps it by PR, with the Java tag picked from the Minecraft version by a fixed table. Each field becomes one of the image's variables. The image writes the properties I set into server.properties on every start and leaves the rest alone, so Git owns exactly what the form shows.

`type: image` is for my own containers: image, ports and variables, like the generic game kind already does.

The rest comes the same way as for the servers I wrote by hand:

- the site-failover Deployment on a home node, the world in `/srv/ha/<name>`, copied to the other site every 10 minutes
- the site-failover entries in dotfiles, with the hook that saves over RCON before each copy
- a random RCON password, encrypted with SOPS
- a port from the Minecraft range (the lowest free one, unless I pick one), added to the game relay, so players use `games.radunenu.com:<port>`

Every version is pinned when Hub makes the plan, not when the server starts: game version, build, pack, every mod and plugin. The same hub.yaml always gives the same server. Downloads end up in the world folder, so a failover starts from the copy and doesn't need the internet.

## Easy and advanced

The deploy form gets an easy mode for every kind of service, games included. Easy asks the minimum (for a game: type, version or pack, name) and fills in the rest. Advanced shows every field, already filled with what easy would pick.

Whatever Hub picks is written into hub.yaml as a plain value, and the plan says why: "memory 3 GiB: Paper's default", "home node thinkcentre: most free memory, and fuji has room for it after a failover". If a default changes later, existing servers don't. Before any PR, Hub checks that the server fits on its home node and on the standby node.

## Packs, mods and plugins

Hub searches Modrinth, CurseForge, FTB, and SpigotMC (through Spiget). A modpack sets `type` and `pack`. Mods and plugins go into a cart that only offers what fits the server: Fabric mods for a Fabric server, plugins for Paper, Spigot or Purpur. Checking out the cart opens one PR.

CurseForge needs an API key. I make it, it's stored with SOPS, and Hub uses it to search while servers use it to download. SpigotMC only lets free plugins hosted on SpigotMC itself be downloaded by a script. Premium and externally hosted ones show up as "download it yourself and upload it in Files".

## The panel

Every server gets a small game agent: `hub game-agent`, a new mode of the same image, running as its own Deployment on the same node with the world folder mounted. It keeps running while the server is stopped, so Files still works then.

- **Console**: the server's log, live from Loki. What I type goes over RCON and the answer shows inline.
- **Status**: who's online, the version, TPS where the server reports it, CPU and memory from Prometheus.
- **Files**: list, read, edit in Hub's editor, upload, download (folders as zip), delete. Everything stays inside the world folder, symlinks and `..` included (Go's `os.Root`).
- **Restart**: `save-all`, then `stop`.

Hub's new Games page lists the servers (status, players, port, version). Each one has tabs: Overview, Console, Files, Content (the cart), Players, Settings. Whitelist and ops are changed by PR. Kicks and bans go through the console.

## Keeping it safe

- The agent has no Kubernetes access. It knows its own server's RCON password and nothing else.
- It only acts on requests that carry my Keycloak token with Hub's admin role, and checks that token itself, the same way hub-writer does. Only Hub's pods can reach it. The server's RCON port only takes connections from its agent and from the site-failover copies.
- Hub stays read-only towards Kubernetes and never sees an RCON password.
- Every console command, file change and restart is in the audit log, with who and when.
- Mods, plugins and packs only come from their platforms, at pinned versions. Modrinth files come with hashes that the image checks.
- Anything that changes how a server is set up is a PR. Only the console, files and restarts act directly, and those are logged.
