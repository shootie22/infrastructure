# 2026-10-29: fuji's network card hung, sites down behind RO for about 4 minutes

**What went wrong:** fuji's onboard Intel network card (I219-LM, e1000e) stopped sending packets, a known fault of these chips, and the driver couldn't recover it, so fuji was cut off until it was power-cycled.

**Fix:** fuji and the thinkcentre turn off the card's segmentation offload and power saving at boot, which avoids the known triggers, and a watchdog resets the card by itself if it hangs anyway. Being done in dotfiles.

**Recovered.** Public services were down about 4 minutes, from the hang at 11:29:49 UTC until DNS failover sent traffic to the thinkcentre through the edge at about 11:34. fuji was power-cycled and its disk unlocked through the edge's early-boot tunnel, and traffic went back to RO at 12:00, after 10 healthy minutes as designed.

The card's transmit queue froze. The kernel logged "Detected Hardware Unit Hang" every 2 seconds (491 times) until the power cycle, the machine kept running at its usual 10-20 W, and it didn't answer anything on the network, not even ARP from the Mac mini next to it. RO's internet and router stayed up throughout.

## Timeline (UTC)

| Time | What happened |
|---|---|
| 11:13 | The last CI job of the morning finished (radunenu.com-minimal v0.1.48's image build). Nothing ran in CI after that. |
| 11:29:49 | fuji: `e1000e 0000:00:1f.6 eno1: Detected Hardware Unit Hang`. From here fuji sends nothing; the message repeats every 2 s. |
| ~11:31 | Every site that reaches the cluster through RO returns Cloudflare 523 (radunenu.com, yeetus.net, git, ...). RO's public address answers "No route to host": the router can't reach fuji to forward to it. |
| 11:33:31 | The checkers on the edge and in DK point `ro.radunenu.com` at the edge (about 3 minutes, as designed). |
| 11:34:02 | Checked from outside: the sites answer again, through the edge and the thinkcentre. Public outage over. |
| ~11:40 | Someone in RO confirms the internet is up. Over the tailnet the Mac mini answers, fuji doesn't. From the Mac mini on RO's LAN: fuji's ARP entry is incomplete, no ping, early-boot SSH (2222) closed. The Mac mini has been up 15 days, so no power cut. fuji's smart plug shows 10-20 W, its usual idle. |
| 11:46:09 | fuji's last hang message, just before the power cycle. |
| ~11:47 | fuji power-cycled with the smart plug. |
| ~11:50 | fuji's disk unlocked through the edge's early-boot tunnel (`unlock-via-edge fuji`, port 2212); it boots and is back on the tailnet and Nebula. |
| 12:00:13 | The checkers point `ro.radunenu.com` back at RO after 10 healthy minutes. |

## Cause

fuji's card is an Intel Ethernet Connection (7) I219-LM (`8086:15bb`, firmware 0.5-4) on kernel 6.18.54, with TSO and GSO on and EEE enabled but inactive on its link. It's a hardware fault of Intel's onboard network chips with the e1000e driver: under sending load the card's transmit queue can freeze, and the driver only logs it ("Detected Hardware Unit Hang") without getting the card working again. It's widely reported for the I217/I218/I219 family, and the triggers named most often are the card doing TCP segmentation itself (TSO/GSO) and its Energy Efficient Ethernet low-power transitions (EEE). Turning those off is the usual workaround.

What exactly set it off here isn't proven. No CI job was running (the last one ended 16 minutes before). fuji is always sending: standby copies to the thinkcentre every 10 minutes (Matrix media every minute) and every site's traffic through its Traefik.

Not related to the day's changes: dotfiles #25 only changes `home/nixa` (fuji uses `home/fuji`), #26 only adds a hosts entry on minima, cordoning minima only affects scheduling, and comin never reboots fuji by itself.

## What went well

- DNS failover moved traffic about 4 minutes after the hang and moved it back by itself.
- The edge's early-boot tunnel worked for unlocking fuji without the tailnet or anyone in RO.

## Follow-ups

In dotfiles [#27](https://github.com/shootie22/dotfiles/pull/27):


- **At boot on fuji and the thinkcentre (same driver):** turn off TSO and GSO, and turn off EEE, before the network comes up. Turning TSO/GSO off doesn't reset the link (checked in the driver's `e1000_set_features`, which only sets a flag for those); turning EEE off does (`e1000e_set_eee` reinitialises the card), so it only happens at boot. RX checksum and VLAN offloads stay on: changing them resets the link, and nothing ties them to this fault.
- **Watchdog:** if the kernel has logged a hardware unit hang in the last minute and the router doesn't answer, reset the port, then reload the driver if that doesn't help, at most 3 times an hour. It only acts when the host is already cut off. Tested with a dry run and a fake hang message before it's allowed to act.
- **minima** (separate): its VM had been off the tailnet for about 8 hours before this, while its kubelet still reported; it's cordoned and needs a restart and a look at why.

Sources: [Proxmox forum, e1000e hardware unit hang](https://forum.proxmox.com/threads/intel-nic-e1000e-hardware-unit-hang.106001/post-713319), [Arch forum](https://bbs.archlinux.org/viewtopic.php?id=280098), [an I219-LM write-up](https://gist.github.com/nfl0/189222c24b61c75f4aa23e67490ff54b), the e1000e driver source (`drivers/net/ethernet/intel/e1000e/netdev.c`, `ethtool.c`).
