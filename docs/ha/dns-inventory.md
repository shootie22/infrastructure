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

## What changes the plan

- **Most web records are proxied (orange cloud).** Cloudflare is in the traffic path today. A second DNS provider can't mirror proxied records, so every record has to become DNS only (grey cloud) before Hetzner joins. Origin certs are already valid (Cloudflare's strict mode checks them), so browsers won't notice. What goes away is Cloudflare hiding the home IP, and its caching and DDoS protection.
- **The apex records are CNAMEs.** For example `radunenu.com → beacon.radunenu.com → noc-studios.go.ro`. This only works because of Cloudflare's CNAME flattening. On Hetzner, an apex needs an A record, and the RO IP changes, so something has to keep those A records up to date on both providers.
- **Everything hangs off `noc-studios.go.ro`.** That's the router's dynamic DNS name at Digi, which makes it another outside dependency. Better: our own updater writes the RO IP to one record (e.g. `ro.radunenu.com`) on both providers, and the apexes get A records from the same updater. It's the same job the failover checker does later, so it can be one small service.

## Keep

These are live, or mail and verification records:
- Everything that matches an Ingress in the repo (33 names), plus `beacon.radunenu.com` as the alias most names point at.
- Mail for radunenu.com and yeetus.net: Mailfence MX, SPF, DKIM. Also `ownercheck.yeetus.net` and the two `google-site-verification` TXT records.
- The Matrix VPS records in nuke.zip: `nuke.zip`, `a`, `d`, `ec`, `g`, `r`, `s`, `x` and the `_matrix._tcp` SRV records. Some don't answer on HTTPS, which is expected for non-web services.

## Delete (dead, no Ingress, origin doesn't answer)

- **radunenu.com:**
  - `archive`, `cats`, `chat`, `cloud`, `cubitube`, `dev`, `graphs`, `hl`, `komodo`, `lt`, `translate`, `monitor`, `panel`, `s`, `sb`, `sd`, `services`, `status`;
  - the `*-monitor` names: filestorage, gamesv, scratchpad, skynet, webservers;
  - `ocean` (old DigitalOcean IP);
  - `kanban` (the OVH VPS, which is empty);
  - the `*` wildcard (Porkbun parking page);
  - two stale `_acme-challenge` TXT records.
- **kronorite.com:** `aki`, `discord`, `git`, `kairi`, `status`, `mc`.
- **byradu.com:** `7zile7arte`, `analytics`.
- **nuke.zip:** `j` (the OVH VPS).

## Needs an answer

- `www.radunenu.com` returns an error (526). The apex works, but no Ingress has `www`. Add it, or redirect it.
- **Game hostnames point at the empty OVH VPS:**
  - `mc.radunenu.com` and `bopl.yeetus.net` point at it directly;
  - `play.yeetus.net`, `ass.yeetus.net` and `tits.yeetus.net` CNAME to `mc.radunenu.com`;
  - `play.radunenu.com` points at the Matrix VPS.

  The game servers now go through fuji's raw edge, so these are probably broken. What do players actually connect to?
- **byradu.com mail:** Porkbun email forwarding (MX, SPF, autodiscover). Still used?
