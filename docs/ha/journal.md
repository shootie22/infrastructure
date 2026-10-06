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

## 2026-10-03: An old experiment had been changing Keycloak

While setting up Renovate I removed the SaveHub release workflow, a leftover from a project I'd tried to build with a much weaker LLM. Its manifests were never deployed, but the workflow ran every five minutes with push access to main, and on 1 October it had quietly swapped Keycloak's official image for its own themed build. Keycloak is back on the official 26.5.5 image now, and main on both repos only takes direct pushes from me; bots and keys can only open branches and pull requests.

## 2026-10-03: A way in that doesn't need the tailnet

fuji and mixi now keep a reverse SSH tunnel open to the edge, so I can get into either one through the edge's public SSH even if Headscale or the tailnet is broken. The tunnel keys can only listen on their own port on the edge and nothing else; I tried the restrictions on a throwaway sshd before turning it on. The same works from the initrd, for unlocking after a reboot.

mixi got the first real test. It rebooted onto the new kernel, the unlock tunnel showed up on the edge 70 seconds later, and the passphrase went in through it. Then the boot sat in emergency mode anyway: I was slower than 90 seconds, and that's how long systemd waits for the root volume before giving up. The disk was already open, so one `systemctl default` through the same tunnel finished the boot. mixi now waits as long as the unlock takes. Also found on the way: mixi's /boot was readable by every user, initrd keys included. Not anymore.

Element Call and yeetus.net were down for the six minutes, because their only copy runs on mixi. Good data for deciding which services get a second one.

## 2026-10-03: Disk latency for etcd

etcd wants fsync to finish in under about 10 ms at the 99th percentile. Same fio test on the three future members:

| Host | p50 | p99 |
|---|---|---|
| edge | 0.5 ms | 0.9 ms |
| thinkcentre | 0.7 ms | 1.5 ms |
| fuji | 4.3 ms | 9.5 to 14.5 ms |

fuji is borderline. Its NVMe is the same class as the thinkcentre's, so the difference is btrfs (plus whatever fuji is busy with). Turning off copy-on-write for the test folder made no clear difference. With members spread over three sites, the network round trip is bigger than that anyway and the etcd timeouts get raised for it (#25). If fuji's disk turns out to matter, etcd gets its own small ext4 volume there.

## 2026-10-03: The thinkcentre's NixOS config, and how to install it without going to DK

The config is written and builds, from an inventory of the Debian install. The original plan was a reinstall, which with nobody in DK means one bad boot and the box stays down until someone gets there. So NixOS goes next to Debian instead: on a new volume made from the 24 GB swap space, with `/home` and the 4 TB disk shared and untouched. The firmware keeps booting Debian. NixOS gets started once with `BootNext`, and reboots itself if nobody unlocks it within 30 minutes or it can't reach fuji 20 minutes after boot. A reboot lands back in Debian. Debian's root only gets deleted once NixOS has run for a while.

## 2026-10-04: Rehearsing the thinkcentre move in a VM

Before touching the real machine, the whole thing ran in a VM on the workstation: same disk layout scaled down, the same boot safety module, UEFI firmware, and a stand-in Debian that prints a marker when it boots. A script walked it through every way the switch could go wrong: nobody unlocking the disk, the firmware ignoring the boot order, no network, a kernel panic, a missing data disk, and a broken update after the switch. All eight end up somewhere reachable.

It took four runs, and the first ones were worth it. The network handover from the initrd only dropped IPv4, so with IPv6 still on the card NetworkManager decided someone else was in charge and never asked for an address. The VM came up without IPv4 at all, the health check noticed and rebooted it, exactly as designed. fuji would have hit the same thing on its next reboot, since RO's LAN has IPv6. The health check also leaned on pings alone; it now accepts an ARP reply too, and only reboots a generation that hasn't proven itself, so a router that drops pings can't cause a reboot loop.

## 2026-10-05: The thinkcentre runs NixOS (trial)

First two plain Debian reboots, to prove the parts NixOS would lean on: Debian's own remote unlock had never run for real, and GRUB's one-time boot had never been used. Both worked. The newest kernel came up once and the next reboot went back to the default by itself.

Then NixOS went onto the old swap volume, next to Debian. It was built on the workstation and copied over as a store archive, so Debian never needed Nix installed. Before the real boot I tested the one hop the rehearsal had skipped, Debian's GRUB handing over to systemd-boot, in a VM with Debian's actual shim and GRUB. That found a trap: if the handover fails, GRUB goes back to its menu with NixOS still picked and tries it forever. The entry now reboots instead, which lands in Debian.

The first real boot came up with everything running, but not cleanly:
- The initrd got a different LAN address than Debian does, and my port checks from mixi made OpenSSH stop answering mixi for a few minutes. So the unlock was locked out until that wore off. The initrd doesn't do that anymore.
- Debian keeps the hardware clock in local time and NixOS assumed UTC, so it booted two hours in the future until NTP corrected it. k3s restarted a few times and comin stopped fetching. NixOS uses local time too now, until Debian is gone.
- A CI job got cut off when k3s stopped the first time, because the jobs run in the host's Docker. The script waits for them now.

Three days on NixOS from here. Any reboot lands back in Debian.

## 2026-10-05: The servers got their own network

While planning etcd it turned out the cluster would need the tailnet to start, and the tailnet needs Headscale, which runs in the cluster. I tested it: a node that reboots while Headscale is down doesn't get back on the tailnet at all. So the servers now also have Nebula between them, with no control server: certificates on disk, the edge and fuji as lighthouses. Tailscale stays for my devices.

Rehearsed in VMs with both sites behind NAT first, then rolled out to all five servers. The VMs caught a port clash on the RO router. The real thing caught two more that the VMs couldn't: minima talked to fuji over the tailnet without anyone noticing (tailscale routes fuji's LAN address, and that route wins), and mixi could only resolve names through tailscale. Both fixed, and with the edge's Nebula switched off everything still found everything through fuji.

## 2026-10-05: The cluster isn't only on fuji anymore

Phase 3 done in one evening. fuji moved from SQLite to etcd and onto its Nebula address in one switch (the API was away for about 20 seconds), the thinkcentre joined as the second server, the edge as the third etcd member that only votes, and mixi and minima moved their pod network onto Nebula. Then the real test: k3s on fuji stopped for three minutes. The thinkcentre kept answering, nothing on the websites noticed, and fuji rejoined by itself.

The rehearsal paid for itself twice before the real thing even started, but the real cluster still had two surprises: the migration kept a never-expiring API endpoint for fuji's old LAN address, and fuji's backup job was still copying the SQLite file nobody writes to anymore. Both fixed.

## 2026-10-06: Postgres across both sites, rehearsed

Before putting any database on CNPG I ran it in VMs set up like the real cluster: etcd on fuji, the thinkcentre and the edge, everything over Nebula, both sites behind NAT. One Postgres instance per site. Times, from the moment the primary goes away until a write goes through again:
- primary's pod deleted: about 10 seconds
- primary's machine crashed: about 2 minutes (Kubernetes needs a while to decide a node is gone). It came back as a replica by itself.
- RO and DK cut off from each other: RO took writes after about 80 seconds, and the old primary in DK stopped taking writes at the same moment, so there were never two primaries. After the link came back both were in sync and no rows were missing.

The hourly dump from the replica also works. Took a few runs to get there: the operator's own manifest wants to pull its image every start, and the dump folder and test table had the wrong owners.
