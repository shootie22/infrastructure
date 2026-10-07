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

## 2026-10-06: Vaultwarden on Postgres

Phase 4 went live. Every node has a site label now (k3s restarted one server at a time, nobody noticed), the CNPG operator runs once in each site, and Vaultwarden's database has one instance on the thinkcentre and one on fuji.

The labels went on after the operator had already started, so both of its pods landed on minima. The one-per-site rule only counts when a pod gets scheduled. Rolled them again and they spread out. Upgrades now replace one pod at a time, since a surge pod would have nowhere to go.

Moving the data was a dry run into a scratch database first, then the real thing in one commit: the old pod stops, Vaultwarden makes its own tables in Postgres, pgloader copies the rows. About 45 seconds without Vaultwarden. Same row counts as in SQLite, no errors, and the apps synced as if nothing happened. The SQLite file stays where it was in case I need to go back.

Vaultwarden itself still only runs on the thinkcentre, because of the key it signs logins with. That's next.

Later the same day: the signing key went into a SOPS secret and Vaultwarden lost its pin to the thinkcentre. It came back up on mixi about 10 seconds later, and the phone synced without asking me to log in again, so the key carried over. Attachments and file Sends are off, since those would live on one node's disk. Files go through Send anyway.

## 2026-10-06: The other databases

Keycloak, Joplin, Rybbit and Gitea moved to CNPG the same afternoon, one after another. CNPG can import straight from a running Postgres, so no pgloader this time, and Gitea went from Postgres 14 to 18 on the way. Each one was down for somewhere between 20 seconds and a minute and a half. Keycloak and Joplin had nothing else on disk, so they can now run on fuji or the thinkcentre and move by themselves 30 seconds after their node stops answering.

Gitea's repos and Rybbit's ClickHouse still only live on the thinkcentre. The old Postgres containers stay a few days in case something turns up.

While at it: signups were open on both Vaultwarden and Rybbit. Closed.

## 2026-10-06: Copies to the other site

The file side of #142. A small NixOS module pushes folders to the other site every 10 minutes with rsync over Nebula. The VM test found three things before it went live: nixpkgs keeps rrsync in its own package, SQLite needs a busy timeout or the snapshot fails while the app writes, and a test of mine was checking the wrong thing. The real hosts found one more: rrsync lets only one copy into a folder at a time, so the second and third job from the thinkcentre bounced. Fixed and covered by the test now.

PrivateBin, Send's uploads and Audiobookshelf go to fuji's standby SSD, Baikal to the thinkcentre. Gitea's 105 GB comes next.

## 2026-10-06: Services with files move by themselves

Phase 6 for the services tied to folders. Each one runs on whichever of fuji and the thinkcentre holds its label, and a small daemon on both moves the label when the node holding it is gone, but only to a node a whole copy has reached. A node that loses the cluster kills the service's container and removes its folder after 45 seconds, so a site that's only cut off stops before the other one starts.

The VM rehearsal earned its keep again. A crash moved the counter to fuji in about 85 seconds, carrying on from the copy, and a cut-off fuji stopped at about 50 seconds while the thinkcentre took over at about 100. On the way it showed:
- Python's ismount doesn't see a bind mount on the same filesystem, so the daemon stacked binds until the kernel refused.
- A server cut off from etcd's majority keeps restarting k3s, and containerd goes with it. The first fence asked containerd to stop the container, which only worked when it happened to be up. Now it kills the container's process directly, found through the runtime's files.
- Crashing a VM a few minutes after k3s unpacked its images leaves containerd broken. A real server unpacked them long ago, so the test syncs the disks first.

Then live, one at a time: PrivateBin, Send, Audiobookshelf and Baikal, each down for 10 to 40 seconds while it switched to its new path. One more snag from the copies: a first Gitea copy held up a config switch for hours, because the switch wanted to restart it. Copy jobs aren't restarted by switches anymore.

Later that evening, the rest of the services with files: Gitea (its SSH turned out never to have worked from outside, so it's off now instead of tying Gitea to one node), and the game worlds. The Minecraft servers get RCON switched on at every start from a secret, and every copy goes "save-off, save-all, copy, save-on", so a copy is never caught halfway through writing the world. The game relay now asks the failover daemons which node has each game and points there, over Nebula. The edge reaches Traefik over Nebula too now, the admin tools have a second copy on the thinkcentre, and picshare and the Vintage Story server are retired.

One self-inflicted outage: Rybbit's analytics was down for 11 minutes because I let its Caddy run on either node without checking how traffic reached it. It was a hostPort on the thinkcentre's tailnet address, with a relay pointing there. Now the relay goes through Caddy's Service. Lesson: before unpinning anything, look for hostPorts and hardcoded addresses pointing at it.

Late that night, the GPU services. Ollama runs on mixi's M1 GPU too: Fedora's Mesa has Asahi's Vulkan driver, so the same image I built for minima worked first try, at about 54 tokens a second on a small model. mixi only has 8 GB, so it keeps a 1.5B version of steamhappy's model under the same name, and a small nginx in front sends everything to minima until minima's copy is gone. steamhappy itself had only ever been built for arm64; it builds for both now and lives on fuji with the other services with files. Getting there took two fixes in CI: Traefik cut image uploads off after 60 seconds once they went over Nebula, and `docker manifest` can't combine images that are already manifest lists, so it's buildx's imagetools now.

## 2026-10-07: Breaking things on purpose

Drill day. Every failure the HA work is meant to survive, done for real, with a log running from outside. Details per drill in [runbooks/drills.md](runbooks/drills.md).

The edge went off first. Nobody would have noticed: the sites never failed a check and etcd kept the same leader. It did show that Prometheus's alerts had only one way out, the relay on the edge, so with the edge off they went nowhere. mixi runs a standby relay now that only speaks up when the edge's doesn't answer.

The thinkcentre was next, rebooted rather than switched off: if Wake-on-LAN failed, nobody in DK could press the button. Postgres and the services with files were on fuji within a minute and a half, every site back within four. Rybbit wasn't, because its images had only ever existed on the thinkcentre. The unlock looked dead afterwards too, but only to my script: OpenSSH 10.5 waits for the client to say hello first, and the script waited for the server.

DNS failover went live after a forced test, both checkers blocked from seeing RO while RO itself stayed up. DNS moved to the edge 3 minutes later and came back 10 minutes after the block was gone, without a single failed check.

Then RO lost its internet: the cable from the switch to the router, so fuji and minima were cut off from everything but each other. fuji fenced its services after 50 seconds and DK had everything 1.5 minutes in. Coming back was the interesting part. Nebula found fuji by `ro.radunenu.com`, which the failover had just pointed at the edge. So the thinkcentre couldn't reach fuji, fuji's Traefik came and went, the checkers saw RO flapping and never moved DNS back. A loop only a person could break. Nebula uses the router's own name now. The fence also turned out to miss containers that mount a folder inside the service's (Audiobookshelf, Baikal), and Send and Keycloak each wasted minutes crashing on startup while their dependencies moved. All fixed.

The one that took digging: when the thinkcentre went away, RO's sites stalled for about 70 seconds. RO shouldn't care about DK at all. The cause was k3s' port listener in front of Traefik. It's a pod, and kube-proxy spreads traffic from pods over every Traefik, whatever the traffic policy says. So half of RO's visitors had been going through DK all along, and hung when DK went. Sending 40 marked requests through the router showed a 20/20 split. Traefik now holds 80 and 443 on its own node, and the same 40 requests all land on fuji.

Also found on the way: the steamhappy images I'd built for both architectures came from the wrong branch, without anything since rc1. The bot had been restarting every 6 minutes since. Fixed in rc6.
