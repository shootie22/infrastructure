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
