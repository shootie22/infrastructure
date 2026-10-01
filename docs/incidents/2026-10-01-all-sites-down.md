# 2026-10-01: All sites down for about an hour

Every public site returned Cloudflare's 523 (origin unreachable) from about 06:20 to 07:25 UTC. fuji and the cluster were fine the whole time. fuji had lost its LAN address, so the router's port forwards had nowhere to go.

## Timeline (UTC)

| Time | What happened |
|---|---|
| 2026-09-28 06:23 | fuji boots. The initrd gets an address by DHCP for remote disk unlock, with a 3-day lease. |
| 2026-10-01 ~06:23 | The lease runs out. Nothing had renewed it, so `192.168.100.136` disappears from eno1. |
| ~07:05 | Noticed while checking kronorite.com after its transfer: every site returns 523, and `hs.radunenu.com` doesn't answer at all. |
| ~07:10 | fuji is reachable over the tailnet (still working over IPv6). Traefik answers locally. eno1 has no IPv4 address. |
| ~07:20 | Gave NetworkManager a DHCP profile for eno1. The address comes back, and the sites with it. |
| ~07:25 | Joplin and picshare on thinkcentre recover too. thinkcentre reaches the cluster API through fuji's LAN address, so it had been cut off as well. |
| 07:15-07:31 | Permanent fix written and pushed to dotfiles, then applied with a rebuild. |

## Cause

fuji unlocks its disk over SSH at boot, so the initrd brings up eno1 and gets an address by DHCP. That address stays on the card after boot. NetworkManager saw an interface that already had an address, marked it "connected (externally)" and left it alone, which also means it never ran DHCP and never renewed the lease. After 3 days the kernel dropped the address.

It only showed up now because fuji had been up for exactly the length of one lease.

## Fix

- The rest of the initrd's IPv4 gets dropped before NetworkManager starts, so NetworkManager always manages eno1 itself ([616228c](https://github.com/shootie22/dotfiles/commit/616228c)).
- eno1's DHCP profile is declared in the config instead of being made up at runtime ([3f9d39d](https://github.com/shootie22/dotfiles/commit/3f9d39d)).

While checking the rebuild, a second, older problem turned up: fuji's config listed an encrypted swap partition that was never unlocked at boot. fuji has never had swap, and every boot and rebuild left systemd waiting for that device forever, which also held up the new network profile. The swap entry is gone ([57b7aa2](https://github.com/shootie22/dotfiles/commit/57b7aa2)).

## What made it worse

- Nothing alerted. I only found out by accident ([#48](https://github.com/shootie22/infrastructure/issues/48)).
- Everything public enters through one address at one site. One expired lease was enough to take it all down, which is what the edge and failover in [docs/ha](../ha/README.md) are for.
- My usual way into fuji is its LAN address, which was the thing that was gone. The tailnet still worked.

## Follow-ups

- [#81](https://github.com/shootie22/infrastructure/issues/81): the workstation and mixi unlock their disks the same way and probably have the same problem.
- [#48](https://github.com/shootie22/infrastructure/issues/48): send alerts somewhere. An external check on the public sites would have caught this within minutes.
