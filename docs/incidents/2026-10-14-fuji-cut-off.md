# 2026-10-14: fuji cut off from the cluster, sites down behind RO

**Open.** Written while it's still going on, to be finished once fuji is back and the cause is known.

fuji dropped off Nebula and Tailscale at about 21:02 UTC while staying up: its Traefik kept answering on RO's public address. Every site that reaches the cluster through RO returned 504 (radunenu.com, yeetus.net, git, ...). DNS failover didn't move anything, because to the checkers RO looked healthy. Element Web (c.nuke.zip) kept working from the edge.

## Timeline (UTC)

| Time | What happened |
|---|---|
| ~20:55-21:00 | dotfiles PR #3 (Matrix phase 1: the `matrix` site-failover service, a CNPG primary that follows it, LiveKit firewall ports on fuji and the edge) and infrastructure #294 (the `matrix` namespace and its two empty CNPG clusters) are merged. |
| ~20:58 | The two Matrix CNPG clusters start; their primaries come up on fuji, the replicas begin joining from the thinkcentre. |
| 21:01:52 | fuji's last heartbeat to the cluster. |
| 21:02:26 | comin deploys PR #3 on the thinkcentre (site-failover restarts there). fuji got the same deploy at about the same time. |
| ~21:03 | fuji NotReady. Its pods are evicted after 30 s; those with a replica pinned per site (Keycloak, oauth2-proxy, blackbox, grafana-standby) can't go anywhere else in RO. |
| ~21:03 | site-failover on the thinkcentre takes over fuji's services with files (Headscale, Baikal, legacy-web, steamhappy), as designed. Matrix stays unclaimed, also as designed: no whole copy had reached the thinkcentre yet. |
| 21:04 | fuji is still reachable from the internet on 443 (Traefik's 404), RO's router answers ping. From the tailnet and over Nebula (from the thinkcentre), fuji doesn't answer at all. Sites through RO: 504 after 6 s; Keycloak, with a pod on fuji, still answers. |

## Cause

Not known yet; needs fuji's console or logs. What's established:

- fuji's kernel, its LAN and the port forward to its pods work (Traefik answers from the internet), but nothing addressed to fuji itself gets an answer: Nebula, Tailscale, ping. That looks like traffic **to** fuji (iptables INPUT) being dropped while traffic **through** it to pods (FORWARD, DNAT) still flows.
- It started within a minute of comin deploying PR #3, which also reloaded fuji's firewall (new ports: 50881/tcp and 50882/udp on `eno1`, 7880 and 6789/tcp on `cni0`). The firewall uses iptables, not nftables, and the change only added ports. The thinkcentre (no firewall change) and the edge (firewall change, global lists) are fine after the same deploy.
- Not resource pressure: fuji had 51% of its CPU and 16% of its memory requested, and the scheduler reported preemption as not helpful.

To check on fuji: `iptables -L INPUT -nv`, `iptables -L nixos-fw -nv`, `journalctl -u firewall -u comin -u nebula@mesh -u tailscaled -b`.

## The cases nothing covered

1. **A site that answers but can't reach the cluster.** The DNS failover checkers decide "RO is up" from Traefik's 404 on RO's public address. A Traefik on a node that's cut off from the cluster still answers it, so the checkers keep sending everyone to a Traefik that can only reach the pods on its own node. The edge's HAProxy already asks each node's site-failover status page whether it reaches the cluster (`cluster=ok`) before using it; the checkers don't. Result: a public outage while the thinkcentre could have served almost everything.
2. **No way to override the checkers.** Pointing `ro.radunenu.com` at the edge by hand doesn't stick: the checkers see RO "healthy" and fail back on their next round. Stopping them on both voters (the edge and mixi) is the only way, and nothing documents it.
3. **A deploy that cuts a node off can't be undone remotely.** comin pulls from GitHub, so a node without working networking never gets the revert. A NixOS switch that breaks networking has no automatic rollback, unlike deploy-rs's "magic rollback".
4. **Every host gets a change at once.** comin deploys a merge to all hosts within minutes. A firewall change went to fuji and the edge, the two entrances, together.
5. **No out-of-band access to fuji.** Its disk needs unlocking by hand after a reboot, and there's no remote console. minima and the Mac mini are on the same LAN (192.168.100.0/24), which may be the only remote way in.

## Ideas to discuss

Not decided; for working through together.

- **Checkers that test the cluster too**: count RO as up only if Traefik answers *and* fuji's site-failover status says `cluster=ok`, the same test HAProxy uses. Careful: the checkers then depend on Nebula, so a Nebula problem could cause a failover.
- **A manual hold**: a file or a DNS TXT record the checkers obey ("stay on the edge" / "stay on RO"), with an alert while it's set.
- **Staged deploys**: hosts follow different branches, or comin waits per host (thinkcentre first, fuji an hour later, the edge last), so a bad change only takes one entrance.
- **Rollback when a switch breaks the node**: after a switch, a timer checks the node still reaches the cluster (or Nebula peers); if not within a few minutes, it switches back to the previous generation. That's deploy-rs's idea, done locally.
- **Firewall changes on their own**: never bundled with features; one host at a time, watched.
- **Out-of-band access**: a jump path through minima or the Mac mini (SSH to fuji's LAN address), initrd SSH for unlocking the disk, a smart plug for a hard power cycle.

## Recovery

Two paths, both without touching fuji physically:

- **Get into fuji over its LAN**: from minima (or the Mac mini), `ssh fuji@192.168.100.136`. If that works: check the firewall (above), `systemctl restart firewall`, and if Nebula and Tailscale don't come back, `nixos-rebuild switch --rollback`. Then merge dotfiles `revert-matrix-phase1` so comin doesn't put the change back.
- **Send RO's traffic through the edge** while fuji stays broken: stop `failover-checker` on the edge and mixi, then point `ro.radunenu.com` at `edge.radunenu.com` in Cloudflare. HAProxy on the edge already treats fuji as down, so traffic goes to the thinkcentre. Undo both once fuji is back.
