# Remote access

How I get into machines I'm not standing next to, mainly the ones in DK (mixi, the thinkcentre, the workstation, the router). If remote access to DK breaks, someone has to go there to fix it, so this page is about doing it in a way that can't lock me out.

## Rules

- **Admin devices only.** Servers trust exactly the admin devices in [lib/admin-ssh-keys.nix](https://github.com/shootie22/dotfiles/blob/main/lib/admin-ssh-keys.nix) (nixpad, the workstation, the phone). Servers never hold keys that open other servers. When one machine is only a stepping stone, SSH jumps through it (`ProxyJump`) with the admin device's own key.
- **New path first, old path last.** Before removing a way in (a key, a tunnel, an unlock route), the new one has to have worked for real, with the old one still there. Then remove the old one, then test again.
- **Two independent ways into every site.** If the only way into DK depends on one box, that box being down means a trip.
- **Management interfaces never on the internet.** No Winbox, SSH or web admin on public addresses. They're reachable over the tailnet, with ACLs that only let admin devices in.

## When the tailnet is down: through the edge

fuji and mixi each keep a reverse SSH tunnel open to the edge, so their SSH is reachable there on a loopback port. From an admin device, `via-edge mixi` or `via-edge fuji` jumps through the edge's public SSH (the edge is the one box whose SSH is on the internet, keys only) and logs in end to end with the device's own key. The host key is checked under the same name as on the tailnet, so a wrong machine at the end of a tunnel fails the check.

The tunnel keys live on fuji and mixi and can only open their own listening port on the edge, nothing else. The edge has no keys for the sites.

From there the rest of each site is one more jump: the thinkcentre and the workstation through mixi, minima through fuji.

**Unlocking after a reboot.** fuji and mixi have encrypted disks and wait in the initrd for the passphrase. That works from the LAN (`mixi-unlock` jumps through the thinkcentre), and through the edge with `unlock-via-edge mixi|fuji` once the initrd tunnels are on. Tracked in [#103](https://github.com/shootie22/infrastructure/issues/103).

Not covered yet: the thinkcentre gets its own tunnel when it moves to NixOS (Phase 2). Until then it's reachable through mixi.

## The workstation (DK)

Usually off. Woken from inside the DK LAN, then its disk is unlocked over SSH before it boots. The unlock goes through a jump host with an admin key, so no server holds a key for it ([#106](https://github.com/shootie22/infrastructure/issues/106)).

## The DK router (MikroTik)

Not reachable from outside today. Options, best first:

1. **Subnet route on the tailnet.** mixi and the thinkcentre both advertise a route to the router's LAN address (just that one address, a /32). Admin devices then reach the router as if they were in DK; one of the two Linux boxes forwards the traffic. Nothing new runs on the router. With two advertisers, Headscale fails over to the other when one is down. The ACL allows only admin devices to the router's management ports.
2. **MikroTik's Back To Home.** Built into RouterOS 7.12 and later (ARM, ARM64 and TILE CPUs): a WireGuard server on the router itself, reachable through MikroTik's relay when there's no public IP. End-to-end encrypted, and the relay can't read the traffic. It doesn't depend on mixi or the thinkcentre, which makes it a good second way in for when both are down, but it is a MikroTik cloud service.
3. **Tailscale in a RouterOS container.** Possible on RouterOS 7.6 and later with the container package, using community images (there's no official one) that support a Headscale login server. More moving parts on the one box that must never break, so only if the first two don't fit.

Plan: 1 as the everyday path, 2 as the independent fallback if the router supports it. Plus some router hardening while at it: unused services off (telnet, ftp, api, plain www), management only from the LAN, Winbox's MAC access off on the WAN side, a strong admin password. Tracked in [#107](https://github.com/shootie22/infrastructure/issues/107).

Caveat: the tailnet is coordinated by Headscale on fuji. While RO is down, existing tailnet connections keep working, but new ones may not come up until Headscale is back or runs in both sites (Phase 5). Back To Home doesn't have that problem.

## Sources

- [Headscale: routes and high availability](https://headscale.net/stable/ref/routes/)
- [MikroTik: Back To Home](https://help.mikrotik.com/docs/spaces/ROS/pages/197984280/Back+To+Home)
- [Tailscale in a MikroTik container (community)](https://github.com/Fluent-networks/tailscale-mikrotik)
