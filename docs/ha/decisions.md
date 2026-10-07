# Decisions

Newest at the bottom. Each one says what, why, and what else was on the table.

## 2026-09-30: The edge VPS runs no services

It only holds the third etcd vote, passes TCP through to Traefik, and maybe runs DERP. Putting anything stateful there would turn a cheap throwaway box into a single point of failure.

## 2026-09-30: DNS failover instead of two A records

Two A records (RO and edge) would send about half of all traffic through the edge all the time, and I'd end up paying for a faster VPS. With failover, everyday traffic goes straight to RO and the edge only carries traffic during an outage. The cost is 1-3 minutes of downtime while DNS switches.

## 2026-09-30: No Cloudflare in the traffic path

If Cloudflare goes down I still want my services to work. Cloudflare Tunnel was the easy option (free, no port forwarding, handles failover), but it only does HTTP, Cloudflare decrypts the traffic, and it's another outside dependency. Cloudflare stays as one of two DNS providers, DNS only.

## 2026-09-30: DNS lives in Git before anything else

Failover and a second provider both need the records in one place that can push to both. DNSControl, with credentials in SOPS.

## 2026-09-30: Headscale stays in the cluster

Moving it to the edge would make the edge matter. Headscale can't run more than one copy, so it stays in the cluster with its data somewhere replicated, and restarts in the other site if its site dies. How exactly is [#37](https://github.com/shootie22/infrastructure/issues/37).

Replaced on 2026-10-05, see below.

## 2026-09-30: Tracking in GitHub, not a self-hosted tool

The plan involves taking the cluster down on purpose. Notes about how to bring it back can't live on the cluster. Tasks go in GitHub Issues and the board; knowledge goes in these Markdown files.

## 2026-09-30: Hetzner DNS as the second DNS provider

I already have a Hetzner account for the Matrix box. It's free, EU based, allows a 60s TTL (the minimum), and DNSControl supports it as `HETZNER_V2`. The old dns.hetzner.com API was shut down in May 2026, so this uses the new Hetzner Console API from the start. Bunny DNS was the runner-up. deSEC was out because of its 1 hour minimum TTL.

## 2026-09-30: Cloudflare proxy stays for web traffic

This replaces part of "No Cloudflare in the traffic path". Proxied web records are fine: if Cloudflare is down, most of the internet is too. What I don't want is being tied to it through Tunnels or anything else that only works on Cloudflare. Proxying also makes failover faster, since the origin behind a proxied record can be swapped in seconds. Maybe later: automatically unproxy records when the Cloudflare proxy is down but its API still works.

## 2026-09-30: Hetzner is a cold standby, not a second nameserver

Proxied records can't be copied to another provider, so Hetzner can't answer alongside Cloudflare. DNSControl keeps a DNS-only copy of every zone at Hetzner, but the registrars only list Cloudflare. If Cloudflare were down for a long time, I'd switch the nameservers at the registrar to Hetzner's. That takes a few hours to spread, and sites are then reached directly, without the proxy. It costs nothing to keep ready.

## 2026-09-30: One DNS name for all game servers

`games.radunenu.com` points at RO, DNS only, and every game hostname (`mc.*`, `play.*`, `bopl.yeetus.net`) CNAMEs to it. The port picks the game. When RO's address changes or failover kicks in, there's one record to change.

## 2026-09-30: nuke.zip stays out of this project

It's part of the Matrix stack. DNSControl doesn't manage it until the Matrix project does.

## 2026-09-30: OpenTofu instead of DNSControl

This replaces DNSControl in the entries above. DNSControl is cleaner if all you ever manage is DNS, but this won't stay DNS-only: Cloudflare settings, Hetzner and maybe the edge VPS can all go through the same tool later. OpenTofu is the open source fork of Terraform, which is what most teams use, so it's also the more useful thing to learn. The state is encrypted with OpenTofu's built-in state encryption and kept in the repo. One list of records feeds both Cloudflare and the Hetzner standby (the `hcloud` provider has DNS support since 1.54).

## 2026-09-30: deSEC replaces Hetzner as the standby, for DNSSEC

This replaces "Hetzner is a cold standby". radunenu.com, yeetus.net and cubtube.lol have DNSSEC on, and Hetzner can't sign zones, so switching to it would have meant removing DNSSEC first and waiting a day. deSEC signs everything and supports multi-signer DNSSEC (RFC 8901) together with Cloudflare: each provider signs with its own keys, publishes the other's, and both DS records sit at the registrar. The switch then keeps DNSSEC valid, and all six zones can have DNSSEC.

The catch is deSEC's 1 hour minimum TTL. That only matters for record changes made while running on the standby, which is fine for a fallback. Other options were thin: NS1 supports multi-signer but costs enterprise money, and self-hosting (Knot, PowerDNS) would mean running a live service on the infrastructure that might be down.

The deSEC provider (`Valodim/desec`) is a community one, and OpenTofu couldn't check its signature. The version and hashes are pinned in `.terraform.lock.hcl`.

## 2026-09-30: Nameserver failover is automatic, with strict detection

The whole point is not having to log in and fix things by hand. The risk of an automatic switch is a false positive: undoing a switch can take up to 48 hours to spread, and sites run without the proxy meanwhile. So checkers run in three places (RO, DK, edge) as NixOS services outside Kubernetes. A switch needs 2 of 3 to agree for 30-60 minutes, each one proves its own network works by also reaching deSEC, and there's a one-switch-per-day brake. There's no leader: setting the same nameservers twice is harmless, so any checker that sees the majority can act. Tracked in [#77](https://github.com/shootie22/infrastructure/issues/77). kronorite.com moves to Porkbun ([#76](https://github.com/shootie22/infrastructure/issues/76)) so one API covers every domain.

## 2026-09-30: DS records through the Porkbun API

Entering DS records by hand at Porkbun turned out to depend on the registry: .tube only accepted the public key (Key Data), .com only the DS values. Porkbun's API does it the same way every time, and the automatic nameserver failover needs it anyway ([#77](https://github.com/shootie22/infrastructure/issues/77)). The key is restricted to my domains and stored in SOPS next to the Cloudflare token, which can do just as much damage. `scripts/porkbun-ds-sync` compares the DS records OpenTofu expects with what the registry actually publishes, and adds what's missing.

## 2026-09-30: Keep Digi's dynamic DNS, and make `ro.radunenu.com` the switch

This replaces the plan for our own IP updater. The router updates `noc-studios.go.ro` the moment the RO address changes, which is faster than anything we'd poll. What was missing was one record we control: `ro.radunenu.com` (DNS only) points at Digi's name, `beacon` (proxied), `games` and `hs` point at `ro`, and every other proxied name points at `beacon`. DNS-only names can't point at `beacon`, because they'd resolve to Cloudflare's addresses. Failover ([#41](https://github.com/shootie22/infrastructure/issues/41)) only has to change `ro`.

## 2026-09-30: The OVH VPS is the edge until February

It's on contract until February 2027 anyway, so it becomes the edge now instead of paying for a second VPS. Everything on it gets backed up first ([#79](https://github.com/shootie22/infrastructure/issues/79)), then it's wiped and reinstalled with NixOS like the plan says. In February it's replaced by a cheaper one ([#80](https://github.com/shootie22/infrastructure/issues/80)), which doubles as the real test of the replacement runbook.

## 2026-10-01: Every machine follows Git, the way Argo does for the cluster

Servers deploy themselves from the dotfiles repo with [comin](https://github.com/nlewo/comin): it checks `main` every 60 seconds and switches to the new config, so a push is live within a minute. Polling everywhere instead of webhooks: only fuji and the edge could even receive a GitHub webhook (DK has no port forwarding, the desktops are behind NAT), and two mechanisms for the same job isn't worth saving a minute. A webhook can be added to fuji and the edge later if the minute ever matters.

Kernel updates need a reboot, which comin doesn't do. Each server reboots itself in a nightly window when the running kernel is older than the deployed one.

The desktops (nixpad, workstation) only keep their checkout in sync: fetch every minute, fast-forward only when there are no local changes or unpushed commits, otherwise just show that they're behind. They never rebuild on their own.

New package versions only arrive when `flake.lock` changes, so a weekly job on the Gitea runner updates it, checks that every host still builds, and commits. A broken update fails the build and never reaches `main`.

Rollout: the edge first, then the desktops' sync, then fuji, mixi and minima one at a time, thinkcentre once it runs NixOS.

## 2026-10-01: HA for a few services, tested restores for the rest

Replicating every service would cost enough RAM, disk and cross-site bandwidth to need more servers, and Gitea alone is hundreds of GB. So services get one of three tiers: survives, stateless copy, or restore. Only small, important ones survive losing their site; the rest are covered by Borg and a restore that has been tested. Replicated block storage for everything (Longhorn and similar) is out for now. Which service lands in which tier is still open in [#88](https://github.com/shootie22/infrastructure/issues/88), details in [service-ha.md](service-ha.md).

## 2026-10-01: Alerting with several detectors and one notification per event

Detection from inside (Alertmanager) and outside (healthchecks.io as a dead man's switch, UptimeRobot for the public sites, the failover checker on the edge, later the LTE laptop), so the infrastructure going down doesn't take its own alerting with it. Delivery through a relay on the edge that tries Pushover, then ntfy, then Matrix, and stops at the first that accepts, so one event is one notification. SMS from the laptop as the last resort. Pushover over ntfy as primary for its track record and priorities; it costs about 5 € once. ntfy stays as the independent second channel. Telegram is out, I don't use it. Details in [alerting.md](alerting.md).

## 2026-10-01: The LTE laptop is optional, not part of alerting

The external services (healthchecks.io, UptimeRobot) already cover "everything at home is down", which was the main reason for the laptop. It stays as an optional out-of-band access project: SMS, and a way into the LAN when the home internet is down. Details in [alerting.md](alerting.md#the-lte-laptop-is-optional).

## 2026-10-02: Email instead of ntfy as the second alert channel

ntfy's iOS app shows messages when opened but never notifies, with every setting right. That's a known, unfixed problem ([ntfy #1796](https://github.com/binwiederhier/ntfy/issues/1796), [#1844](https://github.com/binwiederhier/ntfy/issues/1844)), and a backup channel that fails silently is worse than none. Email replaces it. The relay delivers straight to Mailfence as alerts@radunenu.com with no login, because the Mailfence password is the main account's and must not sit on a public VPS. The edge's IP is in radunenu.com's SPF record instead, and DMARC was added in report-only mode.

## 2026-10-02: Mail protection on every domain

radunenu.com and yeetus.net send mail through Mailfence (yeetus.net is the throwaway address for sign-ups) and get SPF, DKIM and DMARC, with DMARC in report-only mode until the reports look clean ([#104](https://github.com/shootie22/infrastructure/issues/104)). byradu.com only receives through Porkbun's forwarding and gets report-only DMARC too. kronorite.com, cubi.tube and cubtube.lol never send mail, so they say so: `v=spf1 -all` and DMARC `p=reject`, strict from day one since there's nothing legitimate to break. Domains without such records are the easiest to spoof. All reports go to alerts@radunenu.com, which radunenu.com explicitly allows for the other domains.

## 2026-10-03: A second way into both sites, through the edge

The tailnet is the everyday way in, but it's one system, coordinated by Headscale on fuji. If it breaks, DK needs someone on site. So fuji and mixi each keep a reverse SSH tunnel open to the edge, and their sshd shows up there on a loopback port. Admin devices get in by jumping through the edge with their own keys, end to end; the edge holds no keys for the sites. The keys the tunnels use can only listen on their own port on the edge: no shell, no other ports, nothing reachable from outside the edge. Tested with a throwaway sshd before turning it on.

The same goes for the initrd, so a rebooted fuji or mixi can be unlocked without the tailnet. Those keys sit unencrypted on /boot, which is fine for what they can do (listen on one port). The connection is still checked end to end against the initrd's host key, so someone holding a stolen tunnel key can't pretend to be the machine.

Rejected: a VPN on the router (DK has no port forwarding, and the router stays as simple as possible) and Cloudflare Tunnel (no Cloudflare in the path, see the 2026-09-30 entry). mixi's old tunnels pointed at RO's public SSH port, which has been gone since the RO rework; they're replaced, not repaired. Tracked in [#103](https://github.com/shootie22/infrastructure/issues/103).

## 2026-10-05: The servers talk over Nebula, the tailnet is for devices

With etcd across the sites, the members can only reach each other over an overlay network. Tailscale needs Headscale to come up after a reboot (tested: a node that reboots while Headscale is down gets no tailnet address), and Headscale runs in the cluster. So a fuji reboot, or a power cut everywhere, could never finish on its own.

The servers (fuji, the thinkcentre, the edge, mixi, minima) get a second overlay just for themselves: Nebula. Each node has its own certificate on disk and finds the others through two lighthouses, the edge and fuji, so it comes up at boot without asking anyone. etcd, the k3s API and flannel run over it. Tailscale and Headscale stay for my devices, admin access and the private services, and Headscale becomes an ordinary HA service in the cluster (Phase 5).

Also on the table: Headscale outside the cluster on the edge or on fuji (removes the loop, but Headscale stays a single copy and the edge starts to matter), or Headscale in the cluster with a manual cold-start procedure (keeps the loop). Disk unlock after a reboot stays manual for now. Replaces "Headscale stays in the cluster" above.

## 2026-10-06: Nodes join the cluster through k3s-api

A new node, or one restarting with an outdated list of servers, needs an address that works when fuji is gone ([#21](https://github.com/shootie22/infrastructure/issues/21)). It's the name `k3s-api`, in every server's hosts file, pointing at the Nebula address of each server running the API (fuji and the thinkcentre), generated from dotfiles `lib/nebula.nix`. The API servers carry the name in their certificate. No DNS and no tailnet involved, so it works in the same situations the cluster itself does. Rehearsed (a node that had never been in the cluster joined with fuji crashed) and rolled out on 6 Oct.

Also on the table: a DNS name with both addresses (adds a dependency on DNS at join time), or a virtual IP (needs something to move it).

## 2026-10-06: Which services survive losing their site (#88)

Almost everything. Bandwidth and disk are there, and the point of all this is that a site going down doesn't take what I use with it.

- **Survives** (a standby in the other site takes over): Keycloak, Headscale, Vaultwarden, Baikal, Joplin, PrivateBin, Send (shared links keep working), Gitea (the hub for my projects), Audiobookshelf, legacy web, Rybbit, the Minecraft and Vintage Story servers, monitoring (a second Prometheus and Alertmanager in DK), and the admin tools (homepage, Headlamp, tailnet DNS, external-services: a second copy on the thinkcentre).
- **Stateless copy** (runs in both sites): radunenu.com, yeetus.net, the redirect domains, Element Web and Call, and the stateless game servers (Bopl 2D, Crosty, MegaBopl3D).
- **GPU services** (Ollama, SearXNG, steamhappy): the replica goes on mixi (M1, GPU available under Asahi), once tested there.
- **Retired:** Pinga (only radunenu.com's status page uses it; replaced by a status feed from Prometheus, which knows every service already), picshare.

Three building blocks cover it: replicated Postgres (CNPG, Phase 4), one file-copy mechanism over Nebula for everything with files (repos, worlds, audiobooks, uploads), and failover control that promotes the standby when a site is gone (Phase 6). Copies are asynchronous: a failover can miss the last minute or two of writes (a push, a few minutes of a game world). Synchronous replication over the WAN would slow every write; not worth it.

Standby copies in RO go on fuji's spare 1 TB SSD, not the Mac's external drive (a macOS USB disk that's also the Borg target).

## 2026-10-06: Postgres storage and backups (#30, #32)

Each CNPG instance keeps its data on its own node's disk, through k3s' local-path provisioner. CNPG does the replication, so the storage underneath doesn't need to. One instance on fuji, one on the thinkcentre, never both in the same site. They can only run on nodes labelled for databases, which keeps them off mixi, minima and the edge.

Backups go the same way as everything else: every hour a job dumps each database from the replica into a folder on fuji, and fuji's nightly Borg job picks it up, so it ends up on the Mac's 10 TB disk and from there in Backblaze. No WAL archive and no restore to a point in time. Losing both instances at once still leaves the last hourly dump on fuji; losing fuji's disk too falls back to the nightly copy. Fine for what runs here.

Also on the table: Longhorn or another replicated volume under CNPG (two layers doing the same job over the WAN), and CNPG's own backups to object storage (would mean B2 or MinIO just for this, next to a Borg setup that already works).

## 2026-10-06: Files reach the other site by rsync every 10 minutes (#142)

Everything with files (Gitea's repos, Audiobookshelf, PrivateBin, Send, Baikal, Headscale, the game worlds) gets copied to the other site by the hosts themselves: a NixOS module in dotfiles (`modules/nixos/standby-copy.nix`) runs rsync over SSH on the Nebula mesh every 10 minutes. DK's services land on fuji's standby SSD, RO's on the thinkcentre. SQLite files are copied from a `sqlite3 .backup` snapshot, never mid-write. The receiving side only lets the sender's key write into that sender's own folder, and refuses when the standby disk isn't mounted. A Prometheus alert fires when a copy is more than an hour old.

A failover can lose up to the last 10 minutes of files. Starting the standby when a site is gone is the failover controller's job (Phase 6), not this.

Also on the table: Syncthing (continuous, but two-way with conflict files, and live SQLite or git files can arrive half-written), Longhorn (every write waits on the other site over the internet, ruled out for Postgres already), and Litestream to S3 storage for the SQLite apps (about a second of loss instead of 10 minutes, but one more stateful service per site, and a second restore path, for three apps that rarely write). Litestream is written up in [ideas.md](ideas.md) in case it's ever needed.

## 2026-10-06: Services with files fail over by themselves, and stay where they land (Phase 6)

For the services tied to files on one node (Gitea, Audiobookshelf, PrivateBin, Send, Baikal, Headscale, legacy-web, and the game worlds once their copies exist), each one has a pair of nodes, one per site, and exactly one of them is active, marked by a label on the node. The Deployment only runs where the label is. Both nodes see the service's folder at the same path: the active one has the live data, the other the copy.

- **Failing over:** when the active node has stopped answering for about a minute, a small controller moves the label to the other node, and Kubernetes starts the service there on the copy. Changing the label goes through the cluster's API, so only the side that still has the cluster can do it.
- **Fencing:** a node that loses the cluster for about 20 seconds stops these services itself. A site that's only cut off, not dead, has shut its copy down before the other site starts one, so the two never run at once.
- **Copy direction:** the copies always go from the active node to the other one. A node that can't confirm with the API that it's active doesn't send, so a cut-off site can never overwrite newer data when it comes back.
- **No moving back:** the service stays where it landed, and the copy direction reverses with it. Nothing to run by hand afterwards, and no second outage to move it home.

A failover can lose up to the last copy interval of files (10 minutes, less for the small services if it turns out to matter). Game worlds get a save-and-pause before each copy, through the server console, so the copy is never caught mid-save.

Also on the table: failing over by hand with one command (safe, but someone has to be awake), and building the decision into the DNS failover checker's voting (duplicates what the cluster already decides). Moving services back home automatically was dropped: it adds a second outage and a second copy to get right, for nothing.

## 2026-10-07: Traefik holds 80 and 443 itself on each node (#158)

k3s puts a port listener (svclb) in front of Traefik. It's a pod, and kube-proxy spreads traffic coming from pods over every Traefik, whatever the Service's traffic policy says. So half of RO's visitors were served by DK's Traefik, and stalled for about 70 seconds when DK went away. Traefik now takes 80 and 443 on its own node (hostPort), and its Service is internal only. A site's traffic stays on that site's Traefik, and Traefik sees the visitor's real address. The Ingresses carry ro.radunenu.com as their address, which Argo CD needs to call them healthy.

Also on the table: `internalTrafficPolicy: Local` on the Service (tried; kube-proxy's rule for pod traffic ignores it), and Traefik on the host network (would also work, but the pods then see every host port and interface).

## 2026-10-07: A short connect timeout and a retry in front of every service (#160)

Traefik gives up connecting to a pod after 2 seconds and retries on another replica, up to three times, for every request on both entry points. Before, a request that went to a pod on a node that had just died waited until Kubernetes noticed the node was gone, 40 seconds or more. Only failed connections are retried, so nothing that reached a pod is sent twice.

## 2026-10-07: Element Web's front door is the edge, with RO as the fallback (#160)

Element Web has to keep working, with at most a few seconds of trouble, whatever goes down. DNS can't switch that fast, so the address the browser has must stay up: the edge. c.nuke.zip and call.nuke.zip are CNAMEs to element.radunenu.com, which normally points at the edge. The edge runs its own copies of Element Web and Element Call (k3s pods, same image and config as in the sites) and serves them itself, with the certificates cert-manager renews in the cluster. If its copy fails, HAProxy uses the home sites' Traefiks within a second or two. So losing RO, DK or both doesn't touch Element Web.

If the edge itself goes down, front checkers on mixi and fuji point element.radunenu.com at RO's front door after a minute, and back once the edge has been healthy for 10 minutes. That one case costs a minute or two.

Also on the table: Cloudflare's static hosting or its load balancer (fast, but Element Web would then depend on Cloudflare), and a floating IP between two VPSes at one provider (5-15 s even when the edge dies, but a second VPS and a provider API in the path). The edge with DNS as the fallback was chosen, a minute being fine for the rare case.

## 2026-10-07: A second alert relay on mixi (#156)

With the edge down, Prometheus's alerts had nowhere to go. mixi runs the same relay as a standby: Alertmanager and the checkers send to both, and the standby only passes an alert on while the edge's relay doesn't answer its health check. No double alerts, and no gap.

## 2026-10-07: The nameservers switch to deSEC by themselves (#77)

The edge, mixi and fuji each ask Cloudflare's nameservers for every zone (not nuke.zip, which belongs to the Matrix stack). When two of them agree a zone has been unanswered for 45 minutes, while deSEC answers fine, they switch that zone's nameservers at Porkbun to deSEC. Back after 6 hours of Cloudflare answering everyone, at most once a day per zone. It runs as a dry run first, reporting what it would do.
