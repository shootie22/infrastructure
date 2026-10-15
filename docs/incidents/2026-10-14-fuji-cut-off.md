# 2026-10-14: fuji cut off from the cluster, sites down behind RO

**Open.** Public services are back since about 21:30 UTC, through the edge and the thinkcentre. fuji is still cut off, powered and idle, until it's power-cycled on 15 Oct; the cause gets confirmed from its logs then.

fuji dropped off Nebula and Tailscale at about 21:02 UTC while staying up: its Traefik kept answering on RO's public address. Every site that reaches the cluster through RO returned 504 (radunenu.com, yeetus.net, git, ...) for about 28 minutes. DNS failover didn't move anything, because to the checkers RO looked healthy. Element Web (c.nuke.zip) kept working from the edge throughout.

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
| ~21:20 | From the Mac mini on RO's LAN: fuji drops ping and SSH (22) on its LAN address too, while 443 (Traefik's hostPort, forwarded to its pod) is open. So it's fuji's INPUT side refusing everything, not Nebula or Tailscale themselves. No remote shell is possible. |
| ~21:25 | dotfiles PR #4 (the revert of PR #3) merged. thinkcentre and the edge go back to the old config; fuji can't fetch it. |
| ~21:25 | RO router (reached through the Mac mini): 80/443 forwards to fuji turned off. |
| ~21:29 | The checkers on the edge and mixi see RO down and point `ro.radunenu.com` at the edge (about 3 minutes, as designed). The edge's HAProxy already treated fuji as down, so traffic goes to the thinkcentre. |
| 21:31 | Checked from outside: radunenu.com, yeetus.net, git, Vaultwarden, Keycloak, Element and Headscale all answer in 0.1-0.2 s. Public outage over, about 28 minutes after it began. |
| 21:33 | fuji's smart plug shows 10-12 W (the Mac mini's: about 3 W): idle, not stuck in anything heavy. Decision: leave fuji as it is overnight, power-cycle it on 15 Oct. |
| 15 Oct 07:08 | fuji power-cycled, its disk unlocked over early-boot SSH from the Mac mini. comin stopped straight away so the revert wouldn't be applied unwatched. |
| 07:12 | fuji fine on the very generation that broke it (PR #3, `flggsdn…`): Nebula, Tailscale and every route up, thinkcentre reachable over Nebula. |
| 07:19 | Controlled test: a timer armed to save the rules and restart the firewall after 4 minutes, then comin started. It switched fuji to the revert (back to `gw34k…`), reloading the firewall again. fuji stayed reachable over Tailscale and its LAN the whole time (checked every 15 s for 5 minutes); the timer's firewall restart changed nothing either. |

## Cause

Still not proven. The logs from the broken boot (fuji's local time, UTC+3) show, in one minute:

| fuji time | UTC | What |
|---|---|---|
| 00:00:18 | 21:00:18 | `comin-unstick` restarts comin |
| 00:01:14-00:01:46 | 21:01:14-46 | comin fetches the dotfiles repo, **1.34 GiB** at about 45 MiB/s (a full re-fetch) |
| 00:01:28-00:02:12 | 21:01:28-22:12 | the new Matrix databases' init pods run on fuji |
| 00:01:52 | 21:01:52 | the last node status the cluster got from fuji |
| 00:02:30-00:02:35 | 21:02:30-35 | comin switches to PR #3: stops site-failover, **reloads the firewall**, starts site-failover, the `matrix` copy timer and a mount; NetworkManager's dispatcher runs. Reported successful. |
| until the power cycle | | incoming dropped, outgoing to Nebula and pod addresses fails with `network is unreachable`, DNS fails |

What the test on 15 Oct settled: the generation itself is fine (fuji booted on it and worked), and reloading the firewall on a quiet fuji, in both directions, breaks nothing. What remains:

- **A race**: the firewall reload rewriting NixOS's chains while k3s (kube-proxy, kube-router) and Tailscale were rewriting theirs, with new pods and Services appearing on fuji in the same seconds. Fits "outgoing refused too", but nothing shows it directly; the broken rules were gone with the reboot.
- **The 1.34 GiB fetch** saturating fuji's link right before: explains etcd and the heartbeat going quiet for a moment, not 10 hours of broken routes.

Either way the trigger was a live switch on a busy node, and nothing could undo it remotely.

What was established on the night:

- fuji's kernel, its LAN and the port forward to its pods work (Traefik answers from the internet and from the LAN), but nothing addressed to fuji itself gets an answer, not even on its own LAN: ping, SSH, Nebula, Tailscale. Traffic **to** fuji (iptables INPUT) is dropped while traffic **through** it to pods (FORWARD, DNAT) still flows. Confirmed from the Mac mini on the same LAN.
- It started within a minute of comin deploying PR #3, which also reloaded fuji's firewall (new ports: 50881/tcp and 50882/udp on `eno1`, 7880 and 6789/tcp on `cni0`). The firewall uses iptables, not nftables, and the change only added ports. The thinkcentre (no firewall change) and the edge (firewall change, global lists) are fine after the same deploy.
- Not resource pressure: fuji had 51% of its CPU and 16% of its memory requested, and the scheduler reported preemption as not helpful. Not stuck either: 10-12 W at the plug is idle for it.
- Not a site-wide problem: RO's router, its connection and the Mac mini next to fuji were fine throughout.

To check on fuji: `iptables -L INPUT -nv`, `iptables -L nixos-fw -nv`, `journalctl -u firewall -u comin -u nebula@mesh -u tailscaled -b`.

## The cases nothing covered

1. **A site that answers but can't reach the cluster.** The DNS failover checkers decide "RO is up" from Traefik's 404 on RO's public address. A Traefik on a node that's cut off from the cluster still answers it, so the checkers keep sending everyone to a Traefik that can only reach the pods on its own node. The edge's HAProxy already asks each node's site-failover status page whether it reaches the cluster (`cluster=ok`) before using it; the checkers don't. Result: a public outage while the thinkcentre could have served almost everything.
2. **No way to override the checkers.** Pointing `ro.radunenu.com` at the edge by hand doesn't stick: the checkers see RO "healthy" and fail back on their next round. Stopping them on both voters (the edge and mixi) is the only way, and nothing documents it.
3. **A deploy that cuts a node off can't be undone remotely.** comin pulls from GitHub, so a node without working networking never gets the revert. A NixOS switch that breaks networking has no automatic rollback, unlike deploy-rs's "magic rollback".
4. **Every host gets a change at once.** comin deploys a merge to all hosts within minutes. A firewall change went to fuji and the edge, the two entrances, together.
5. **No out-of-band access to fuji.** No remote console and no remote power. The Mac mini (tailnet `macminim4`, user `radu`) is on fuji's LAN and reaches the router's admin page and fuji's early-boot SSH; the minima VM (tailnet `minima`) refused the admin key for `radu`, also to look into. With fuji's INPUT shut, nothing gets a shell.

6. **The dotfiles repo is about 1.3 GiB**, and comin re-fetches all of it whenever it re-clones, on every host. Half a minute of a saturated link on fuji right before it fell over.

## Ideas to discuss

Not decided; for working through together.

- **Checkers that test the cluster too**: count RO as up only if Traefik answers *and* fuji's site-failover status says `cluster=ok`, the same test HAProxy uses. Careful: the checkers then depend on Nebula, so a Nebula problem could cause a failover.
- **A manual hold**: a file or a DNS TXT record the checkers obey ("stay on the edge" / "stay on RO"), with an alert while it's set.
- **Staged deploys**: hosts follow different branches, or comin waits per host (thinkcentre first, fuji an hour later, the edge last), so a bad change only takes one entrance.
- **Rollback when a switch breaks the node**: after a switch, a timer checks the node still reaches the cluster (or Nebula peers); if not within a few minutes, it switches back to the previous generation. That's deploy-rs's idea, done locally.
- **Firewall changes on their own**: never bundled with features; one host at a time, watched.
- **A smaller dotfiles repo**: find what makes it 1.3 GiB and move it out (history included), so a re-fetch is cheap.
- **Out-of-band access**: a jump path through minima or the Mac mini (SSH to fuji's LAN address), initrd SSH for unlocking the disk, a smart plug for a hard power cycle.

## Overnight (14-15 Oct)

fuji stays powered and cut off; its own fence has stopped its services, and nothing public depends on it. What that means until it's back:

| | Effect | Covered by |
|---|---|---|
| etcd | 2 of 3 members (thinkcentre, edge) | still has quorum; losing either one too stops the Kubernetes API (running pods and DNS failover keep working). The thinkcentre has no UPS. |
| Postgres | every primary in DK | the hourly `pg_dump` jobs are pinned to fuji, so no new dump files; the data is safe on the instances in DK |
| Services with files | Headscale, Baikal, legacy-web, steamhappy on the thinkcentre | no standby copy until fuji is back; `StandbyCopyStale` alerts expected |
| Monitoring | fuji's Prometheus (15 days) unreachable | Prometheus in DK (3 days) and both Alertmanagers keep alerting; the profile-status card goes stale after about 3 hours |
| Public services | none run only on fuji | everything through the edge to the thinkcentre |
| Matrix (new) | its two databases are empty, unused, primaries on fuji | nothing to do |

## Bringing fuji back (15 Oct)

1. Power-cycle fuji with its smart plug (the 10-12 W one; the plugs sit between the UPS and the machines, so cutting the plug really cuts power). Whether it turns on by itself when power returns depends on its BIOS ("restore on AC power loss"), unknown; if it doesn't, it needs its power button.
2. Unlock its disk over early-boot SSH through the Mac mini (asks for the passphrase):

   ```sh
   ssh -J radu@macminim4 -p 2222 root@192.168.100.136
   ```

3. Before changing anything, collect the logs from the broken boot:

   ```sh
   ssh -J radu@macminim4 fuji@192.168.100.136 \
     'sudo journalctl -b -1 -u firewall -u comin -u nebula@mesh -u tailscaled --no-pager | tail -150'
   ```

4. comin then applies PR #4 (the revert) within about a minute, which reloads fuji's firewall again. If fuji drops off again right after, the reload is confirmed as the cause; one more power cycle fixes it, since fuji then boots straight into the reverted config.
5. Once fuji is Ready (`kubectl get nodes`) and Nebula works (`ping 10.99.0.2` from the thinkcentre): turn the router's 80/443 forwards back on. DNS fails back by itself after 10 healthy minutes. The moved services stay on the thinkcentre; copies go to fuji again.

## Recovery

Two paths, both without touching fuji physically:

- **Get into fuji over its LAN**: not possible, fuji refuses SSH on its LAN too (tried from the Mac mini). It takes a power cycle; its disk can then be unlocked over early-boot SSH from the Mac mini. If a shell ever works: check the firewall (above), `systemctl restart firewall`, and if Nebula and Tailscale don't come back, `nixos-rebuild switch --rollback`. Hold dotfiles `revert-matrix-phase1` until fuji's logs are read: a revert is itself another firewall reload on fuji, the prime suspect.
- **Used: take fuji off RO's port forwards.** The router's admin page (192.168.100.1) is reachable through the Mac mini (`ssh -L 8081:192.168.100.1:80 radu@macminim4`). Without the 80/443 forwards the checkers see RO down and fail over to the edge by themselves, and fail back once the forwards return.
- **Send RO's traffic through the edge** while fuji stays broken: stop `failover-checker` on the edge and mixi, then point `ro.radunenu.com` at `edge.radunenu.com` in Cloudflare. HAProxy on the edge already treats fuji as down, so traffic goes to the thinkcentre. Undo both once fuji is back.
