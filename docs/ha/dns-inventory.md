# DNS inventory

Snapshot from 2026-09-30, pulled from the Cloudflare API. 7 zones, 103 records. Every hostname was probed over HTTPS and compared with the Ingresses in this repo.

## Domains

| Domain | Registrar | Expires | Records |
|---|---|---|---|
| radunenu.com | Porkbun | 2032-11-27 | 52 |
| yeetus.net | Porkbun | 2027-09-21 | 14 |
| nuke.zip | Porkbun | | 13 |
| byradu.com | Porkbun | 2027-03-17 | 10 |
| kronorite.com | Namecheap | **2026-12-15** | 10 |
| cubi.tube | Porkbun | **2026-12-29** | 2 |
| cubtube.lol | Porkbun | **2026-12-29** | 2 |

All zones are on Cloudflare's nameservers today. Porkbun and Namecheap both let you set custom nameservers, so adding Hetzner's is fine.

## What this means for the plan

- **Most web records are proxied (orange cloud).** That stays: Cloudflare in front of web traffic is fine. No tunnels, though. A nice extra for later: if the Cloudflare proxy is down but its API works, unproxy the records automatically.
- **Proxying makes failover easier.** Visitors only ever see Cloudflare's IPs, so changing the origin behind a proxied record takes effect in seconds, with no TTL to wait out. Only the DNS-only names (game servers, `hs`, `share`, Matrix) depend on TTL.
- **Everything hangs off `noc-studios.go.ro`**, the router's dynamic DNS name at Digi. It works, but it's another outside dependency. Our own updater writing the RO IP straight into Cloudflare would remove it, and the failover checker needs the same API access anyway.
- **A second DNS provider can't mirror proxied records.** Hetzner can only be a standby copy of the zone, not an active second nameserver.

## Keep

These are live, or mail and verification records:
- Everything that matches an Ingress in the repo (33 names), plus `beacon.radunenu.com` as the alias most names point at.
- Mail for radunenu.com and yeetus.net: Mailfence MX, SPF, DKIM. byradu.com keeps its Porkbun email forwarding (MX, SPF, autodiscover). Also `ownercheck.yeetus.net` and the two `google-site-verification` TXT records.
- **nuke.zip: all of it, untouched.** It belongs to the Matrix stack. DNSControl leaves this zone alone until the Matrix project.

## Delete (dead, no Ingress, origin doesn't answer)

- **radunenu.com:**
  - `chat`, `cloud`, `cubitube`, `dev`, `graphs`, `hl`, `komodo`, `lt`, `translate`, `monitor`, `panel`, `s`, `sb`, `sd`, `services`, `status`;
  - the `*-monitor` names: filestorage, gamesv, scratchpad, skynet, webservers;
  - `ocean` (old DigitalOcean IP);
  - `kanban` (the OVH VPS, which is empty);
  - the `*` wildcard (Porkbun parking page);
  - two stale `_acme-challenge` TXT records.
- **kronorite.com:** `status`.
- **yeetus.net:** `ass`, `tits`.

## Restore (should work, currently broken)

- `git.kronorite.com`: redirect to git.radunenu.com. Fixed in legacy-redirects.
- `www.radunenu.com`: redirect to the apex. Fixed in legacy-redirects.
- `cats.radunenu.com`: landing page for the cats archive.
- `aki.kronorite.com` and `kairi.kronorite.com`: redirect to `aki.radunenu.com` and `kairi.radunenu.com`, read-only galleries of a friend's cats. The radunenu.com names don't exist in DNS yet.
- `7zile7arte.byradu.com`: an archive site made for a friend. Its target, `archive.radunenu.com`, stays too.
- `analytics.byradu.com`: one of the old APIs.
- `discord.kronorite.com`: probably a redirect to a Discord invite.

The content for these isn't in this repo or in the OVH retirement archives on fuji.

## Game servers

One central name, DNS only (game traffic can't go through the proxy):
- `games.radunenu.com` CNAME `noc-studios.go.ro`
- `mc.radunenu.com`, `mc.kronorite.com`, `play.radunenu.com`, `play.yeetus.net` and `bopl.yeetus.net` CNAME `games.radunenu.com`, all DNS only

All of them resolve to the RO IP, and the port picks the game (Minecraft 25565 and 6767, MegaBopl3D 24545, Hytale 5520).

