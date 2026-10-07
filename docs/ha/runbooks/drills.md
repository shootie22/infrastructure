# Failure drills (Phase 7)

Breaking things on purpose, to see the HA work for real and time it. One drill at a time, at a quiet moment, with me at the machines (a stopped fuji or thinkcentre needs its disk unlocked by hand to come back). Least risky first.

The times below are what the VM rehearsals measured (dotfiles `tests/cnpg-across-sites.nix`, `tests/site-failover.nix`); the drills say whether the real thing matches.

## Before every drill

- Nothing red in Grafana or Alertmanager, all nodes Ready.
- The standby copies are fresh: no `StandbyCopyStale` alert.
- From outside, a loop that checks the public sites every few seconds and logs the time of every failure (a laptop on mobile data for the RO drills).
- Note the start time; every drill is timed from the moment the machine goes away.

## 1. Shut down the edge (#45)

**What goes:** the edge VPS (`systemctl poweroff` on it; started again from the provider's console).

**What should happen:** nothing a visitor notices. etcd keeps 2 of 3 members (fuji, the thinkcentre) and RO keeps serving as usual: the edge is only in the path during a DNS failover. Alerts for the edge being down, and the DNS failover checker on the edge stops voting (mixi's alone can't fail over).

**Watch:** the sites from outside; `kubectl get nodes` (edge NotReady, nothing else changes); etcd member list.

**Back:** start it; it rejoins etcd by itself.

**Result (2026-10-07):** off for 12 minutes, 09:53:30 to 10:05:45. Passed.
- The sites never failed a single check (one every 8-10 s).
- etcd: fuji and the thinkcentre kept the thinkcentre as leader the whole time, no election.
- After 2 minutes on the console it was Ready again and back in etcd, with nothing to do by hand.
- What reached me while it was off: healthchecks.io ("relay down", through Pushover directly) and UptimeRobot (email). Prometheus's own alerts (EtcdMemberDown, the node down) had nowhere to go, because Alertmanager only sends to the relay on the edge. They came all at once when the edge was back. A second way out for Alertmanager is in #156.

## 2. Stop the thinkcentre (#46)

**What goes:** the thinkcentre (power off). DK keeps mixi.

**What should happen:**
- etcd keeps quorum with fuji and the edge.
- Postgres: every database whose primary was on the thinkcentre (CNPG) promotes its replica on fuji. Rehearsed: about 2 minutes.
- Services with files (Gitea, Audiobookshelf, PrivateBin, Send, the game worlds, Rybbit's ClickHouse) and the stateless games: fuji takes their labels about a minute after the thinkcentre is marked not ready and starts them on its copies. Rehearsed: running again after about 85 s. Up to 10 minutes of their files can be lost (the last copy).
- Vaultwarden, Keycloak, Joplin: rescheduled 30 s after the node is marked not ready.
- Visitors come in through RO as usual, so nothing changes about routing.
- The game relay points at fuji within about 10 s of the label moving.

**Watch:** the sites from outside; `kubectl get nodes -L` with the `ha.radunenu.com/*` labels; `kubectl get cluster -A` (CNPG primaries); a game client (Minecraft, Bopl).

**Back:** power on, unlock the disk through the edge. The thinkcentre comes back as the standby: the services stay on fuji (nothing moves back by itself), and the copies now go fuji → thinkcentre. Check `StandbyCopyStale` clears.

**Result (2026-10-07):** a reboot instead of a poweroff (nobody at DK could switch it back on if Wake-on-LAN failed; it sat at the unlock prompt, which is the same to the cluster). Gone at 10:21:25, unlocked at 10:34. Passed, with one service down.
- etcd: fuji took over as leader.
- Postgres: all five primaries were on fuji within 1.5 minutes.
- The file services were labelled to fuji at 10:22:59 (1.5 minutes). Back for visitors: Vaultwarden under 1 minute, Gitea and PrivateBin 2.3, Audiobookshelf 2.6, Keycloak 2.8, Send and Joplin 4.
- radunenu.com and yeetus.net were up except for about 70 s right after the thinkcentre went (10:21:38 to 10:22:49), when nothing got through to fuji from outside, not even the failover checkers going straight to RO's address. Not fuji's CPU. Open in #158.
- Rybbit's dashboard stayed down: its backend and client images only existed on the thinkcentre (`imagePullPolicy: Never`), so fuji couldn't start them. ClickHouse and Postgres moved fine. The images are in Gitea's registry now.
- The unlock looked dead: `thinkcentre-unlock` reported nothing on port 2222. OpenSSH 10.5 waits for the client to speak first, and the script's check waited for the server. A real `unlock-via-edge` worked. The check is fixed.
- After the unlock: all Postgres replicas back on the thinkcentre within 6 minutes, and fuji's copies of every moved service there within 5 minutes. Everything stays on fuji.

## 3. Unplug fuji (#43)

**Needs first:** the DNS failover checkers live (they run as a dry run today). RO's public traffic comes in only through fuji, so with fuji gone, visitors reach DK only after DNS moves to the edge.

**What goes:** fuji (power off).

**What should happen:**
- etcd keeps quorum with the thinkcentre and the edge.
- Postgres primaries on fuji move to the thinkcentre (about 2 minutes).
- Baikal, Headscale, legacy-web, steamhappy: the thinkcentre takes their labels and starts them on its copies (about 85 s).
- The DNS failover checkers (edge, mixi) agree RO is gone after 3 minutes and point `ro` at the edge; the edge sends traffic to the thinkcentre's Traefik. Total for visitors: about 3 minutes plus DNS caching.
- Ollama on minima keeps serving: minima is still up, and steamhappy reaches it over the cluster network.

**Watch:** the sites from outside (on mobile data); the checkers' votes (their status pages on the tailnet); the labels and CNPG primaries.

**Back:** power fuji on, unlock it. DNS fails back after RO has been healthy for 10 minutes. The moved services stay on the thinkcentre.

**Result:**

## 4. Cut RO's internet (#44)

**Needs first:** the DNS failover checkers live.

**What goes:** RO's uplink (unplug the router's WAN). fuji and minima stay up but can't be reached, and can't reach the rest.

**What should happen:**
- fuji loses etcd's majority (the thinkcentre and the edge keep it). Its services with files fence themselves within about 45 s (killed, folders removed) and the thinkcentre takes them over (about 100 s). Never both at once: rehearsed.
- Postgres: primaries in RO stop taking writes, DK promotes (rehearsed: about 80 s).
- DNS moves to the edge after 3 minutes, the edge serves from DK.
- minima's Ollama is unreachable: steamhappy (now in DK) uses mixi's copy.

**Watch:** from a phone on mobile data; the checkers; labels and primaries from the DK side.

**Back:** plug the uplink back in. fuji rejoins as the standby for what moved; DNS fails back after 10 healthy minutes.

**Result:**
