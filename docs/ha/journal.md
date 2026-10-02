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

## 2026-10-01: Everything down for a while

All sites were down for about an hour because fuji lost its LAN address. Full write-up in [docs/incidents](../incidents/2026-10-01-all-sites-down.md). Two lessons for this project: nothing alerted me, and with one site and one entry point, one expired DHCP lease was enough to take everything down. That's what the edge and failover are for.

## 2026-10-01: The edge exists

The OVH VPS is now the edge, running NixOS. Before wiping it I archived the whole disk to fuji, checked the archive against the live disk file by file, and waited for it to land in Borg. Two finds along the way: fuji's Borg job had never covered Keycloak's database or Baikal, and the VPS still had the old Komodo-era age key, which now lives in Bitwarden.

The install itself was one command from a clean checkout of dotfiles. It wiped the disk, installed, rebooted, and the box came back with the same SSH host key, so there was no host key warning, and it joined the tailnet by itself. That's the part that has to work again in February on the cheaper VPS.

## 2026-10-01: How fast is the edge?

Faster than I expected for a VPS. Over the tailnet it does about 760 Mbit/s with fuji (28 ms away) and 790 Mbit/s with the thinkcentre in DK (14 ms), both directions, both direct with no relay. So when RO is down and DK serves through the edge, it should hardly feel slower.

## 2026-10-01: The edge passes traffic through

HAProxy on the edge now passes 80 and 443 through to Traefik, fuji first and the thinkcentre as backup, and Traefik runs on both sites. Requests to the edge's public IP get the real sites with valid certificates. Nothing points at it yet; that's the failover checker's job.

The health check caught something before any real traffic did: on the tailnet, fuji's 443 goes to the private tools proxy, so the edge would have sent visitors there. Checking Traefik with a made-up hostname over TLS marked fuji down until the edge was exempted from that redirect.

Switching Traefik's service to node-local traffic recreated the port listeners, and the sites flickered for about 80 seconds. I expected nothing. Next time a change like that gets a heads-up.

## 2026-10-01: The failover checker exists, in dry run

The checker runs on the edge and only logs. It sees RO as healthy and waits for its partner on mixi. Before deploying it, I ran it on the laptop with RO's name pointed at a name that doesn't exist: three seconds of "RO is down", then exactly one line saying it would move ro to the edge. Nothing changed.

The edge also relays the game ports now, using the same port list as fuji, so a Minecraft client pointed at the edge already reaches the server in DK.

One surprise: comin hung on the edge when a new commit landed in the middle of a long build after the flake.lock update. It logged a store error and then did nothing for 20 minutes. Restarting it fixed it.

## 2026-10-02: Alerts reach the phone

Alerts now come from three independent places and reach the phone through Pushover, with email as the fallback. Each path was tested for real: stopping the relay made healthchecks.io send a Pushover emergency six minutes later, a monitor on a closed port made UptimeRobot alert through Pushover's email gateway and by email, and a relay test with Pushover broken on purpose fell through to the next channel.

ntfy was the original second channel, but its iOS app never showed a notification, which turned out to be a known, unfixed bug. Email replaced it. The relay delivers straight to Mailfence without a login; the edge's IP went into radunenu.com's SPF record instead of putting the main mail password on a public VPS. While at it, every domain got SPF and DMARC, and the three that never send mail now tell the world to reject anything claiming to come from them.
