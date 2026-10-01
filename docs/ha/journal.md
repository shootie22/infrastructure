# Journal

Short dated notes: what happened, what broke, what I learned. Newest at the bottom.

## 2026-09-30: Planning

Started out wanting everything behind Keycloak, and quickly found that Keycloak running on one node on fuji would just become the thing that takes everything down. And it's not only Keycloak: fuji is the only control plane node, the cluster database is a single SQLite file on it, and Headscale runs there too.

So the SSO project waits, and HA comes first. The main thing I learned is that two sites aren't enough for automatic failover. Neither side can tell whether the other one is down or just unreachable. A cheap VPS in a third location fixes that by being the tiebreaker.

Also found that the Keycloak cert is a static one in SOPS rather than managed by cert-manager, and that alert rules exist but nothing actually sends them anywhere. Both are on the board now.

## 2026-09-30: DNS inventory

Pulled every record from Cloudflare: 7 zones, 103 records, and 37 of them point at nothing. Most are left over from the Komodo and Proxmox days.

The bigger surprise: nearly every web record is proxied through Cloudflare, so Cloudflare was already in the traffic path, which I'd forgotten about. The apexes are CNAMEs that only work because of Cloudflare's flattening, and everything ends at the router's dynamic DNS name. So Phase 0 grows a bit: proxy off, and our own dynamic IP updater before Hetzner can join. Details in [dns-inventory.md](dns-inventory.md).

## 2026-09-30: DNS is code now

All DNS except nuke.zip is in OpenTofu (`tofu/`). The import went through with zero changes, which was a nice check that the config matches Cloudflare exactly. Then the cleanup: 29 dead records gone, and the game hostnames all point at one name, `games.radunenu.com`. The only gotcha was Cloudflare refusing a CNAME next to an A record with the same name, so the old A records had to go in a separate apply first.

## 2026-09-30: First multi-signer DNSSEC zone

cubi.tube is now signed by both Cloudflare and deSEC, with both DS records at the registry, and validates on Google, Cloudflare and Quad9. Two things tripped me up. Cloudflare only shows its zone-signing key once multi-signer is on, so the key exchange takes two rounds. And Porkbun's DS form failed with a registry error ("2004 parameter value range error"); entering the public key under Key Data worked, and the registry works out the DS itself. Before touching the registrar I tested everything with `delv`, using both keys as trust anchors, which made the Porkbun step a lot less scary.

## 2026-09-30: DNSSEC everywhere (almost)

All five Porkbun domains now run multi-signer DNSSEC. byradu.com was the second one done by hand, and the `.com` registry turned out to want the exact opposite of `.tube`: DS values, not the public key. That was enough to switch to Porkbun's API, and after that each zone took minutes. For the three zones that already had DNSSEC, I checked Cloudflare's key and the DS at the registry before and after turning on multi-signer. Nothing changed, and they validated the whole time. Mail records validate too. kronorite.com is the only one left, waiting for its move to Porkbun.

## 2026-10-01: Everything down for a while, and why

Every site returned Cloudflare's 523. fuji was up and Traefik answered fine locally, but fuji had no LAN address anymore. The initrd that lets me unlock the disk over SSH gets an address by DHCP, and that address stayed on the card after boot. NetworkManager saw it, decided the card was configured by someone else, and never renewed the lease. Three days later the lease ran out and the address was gone, and with it every port forward. The tailnet kept working over IPv6, which is how I could get in and give NetworkManager a proper DHCP profile. The permanent fix drops the initrd's address before NetworkManager starts.

Two lessons for this project: nothing alerted me, and with one site and one entry point, one expired DHCP lease was enough to take everything down. That's what the edge and failover are for.
