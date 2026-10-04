# Move the thinkcentre to NixOS

Phase 2 ([#18](https://github.com/shootie22/infrastructure/issues/18)). The thinkcentre is in DK and nobody can get to it for months, so no step may end in a machine that needs someone on site. NixOS gets installed next to Debian, booted once, run for three days with Debian as the way back, and only then does Debian go.

Untouched the whole time: `/home` (all service data) and the 4 TB disk. Debian's root volume stays until the last step, and gets archived into Borg before it's deleted.

The config is in dotfiles under `hosts/thinkcentre/` (`configuration.nix`, `boot-safety.nix`, `hardware-configuration.nix`), and `rehearsal/` is a VM of the whole thing. The inventory of the Debian install is kept privately.

## Why it can't get stuck

| Layer | Covers |
|---|---|
| Debian's GRUB starts NixOS once (`grub-reboot`). The firmware isn't involved: it keeps booting Debian's entry like it always has | a NixOS that doesn't work: the next reboot is Debian. Lenovo firmware is known to ignore or reorder boot entries, so the plan doesn't depend on it |
| NixOS reboots by itself if nobody unlocks it within 45 minutes, if it has no LAN or SSH 15 minutes after boot, on a kernel panic, or when the hardware watchdog fires | every way of being stuck becomes a reboot, and so Debian |
| Boot counting in systemd-boot, with Debian as the last entry | the firmware or GRUB doing something unexpected: three failed NixOS boots end in Debian anyway |
| Data disks can't stop the boot; k3s waits for them | a disk that doesn't open means stopped services, never an unreachable machine or data on the wrong disk |
| Two unlock paths: LAN through mixi (initrd SSH), and the edge tunnel once its keys exist | one path failing |

The rehearsal VM checks all of this before the real thing.

## 1. Before (no downtime)

- [x] 4 TB keyfile and k3s token in SOPS, all age keys and the keyfile in the password manager
- [x] Borg restore test ([#16](https://github.com/shootie22/infrastructure/issues/16))
- [x] Audit and inventory ([#15](https://github.com/shootie22/infrastructure/issues/15), kept privately)
- [x] Follow-up audit: GRUB supports one-time boots
- [x] Minecraft HC's world moved off Debian's root volume onto /home (4 Oct)
- [x] Rehearsal on the workstation: all 8 scenarios pass (4 Oct). It found two real bugs first: the initrd network handover could leave NixOS without IPv4, and the boot health check relied on pings alone

## 2. Prove Debian and GRUB (two reboots, ~10 minutes downtime each)

Debian's fallback role only counts once it's shown to come back from a reboot on its current kernel, so it gets proven first.

1. Take swap out of Debian, because its volume becomes the NixOS root: `swapoff`, comment the swap line in `/etc/fstab`, `RESUME=none` in `/etc/initramfs-tools/conf.d/resume`, `update-initramfs -u -k all`.
2. **Reboot 1, one-time boot:** `grub-reboot` an older installed kernel from the "Advanced options" menu, then reboot. Unlock through mixi as usual (dropbear, port 2222). It must come up on that kernel (`uname -r`).
3. **Reboot 2, back to default:** plain reboot. It must come up on the newest kernel. That proves the one-time boot reverts by itself, which is what the NixOS trial relies on.

If either fails: stop. Debian still works, so nothing is lost; the plan gets rethought.

## 3. Install next to Debian (Debian keeps running)

4. **Stop: confirmation needed.** Delete the swap volume and create `nixos` in its place: `lvremove thinkcentre-vg/swap_1`, `lvcreate -l 100%FREE -n nixos thinkcentre-vg`, `mkfs.ext4 -L nixos`.
5. Nix on Debian, temporarily, with `/nix` bind-mounted from a folder on `/home` so it doesn't fill Debian's root.
6. Mount `nixos` at `/mnt` and the ESP at `/mnt/boot`, and create `/home/rancher` and `/home/docker`. Then copy in:
   - `/etc/sops/age/keys.txt` → `/mnt/var/lib/sops-nix/key.txt`
   - `/etc/rancher/node/password`, so k3s rejoins as the same node with its labels
   - `/var/lib/tailscale/tailscaled.state`, for the same tailnet node and address
   - `/etc/ssh/ssh_host_*`, so every known_hosts entry stays valid
   - a new initrd host key in `/mnt/etc/secrets/initrd/`; note its fingerprint
7. Back up the ESP's fallback loader (`EFI/BOOT/BOOTX64.EFI`) next to it. NixOS's systemd-boot replaces it.
8. `nixos-install --flake github:shootie22/dotfiles#thinkcentre --no-root-passwd`, then set main's password with `nixos-enter`.
9. A GRUB entry for NixOS in `/etc/grub.d/40_custom`, chainloading `/EFI/systemd/systemd-bootx64.efi` from the ESP, with `--id nixos`. Then `update-grub`, and check it's there.

## 4. Trial boot (downtime starts here)

10. Stop k3s on Debian and copy `/var/lib/rancher/k3s` to `/home/rancher/k3s`, so the ~15 GB of images don't get downloaded again.
11. **Stop: confirmation needed.** `grub-reboot nixos`, reboot.
12. Unlock through mixi (initrd SSH on 2222, the new host key from step 6). Then check:
    - node Ready, Argo Synced/Healthy, Gitea shows its repositories (so the 4 TB disk is open), Vaultwarden, Joplin, Audiobookshelf, the game servers, the Gitea runner
    - `systemctl --failed` is empty, and `boot-health` passed
    - the edge reaches Traefik and the game ports
    - one Borg run by hand

    Anything wrong: `reboot`, and Debian comes back on its own.

## 5. Three days on NixOS

While NixOS runs, any reboot lands in Debian (that's the point). During these days:
- a scheduled Borg run
- a DHCP lease renewal (the 2026-10-01 incident was a lease running out after 3 days)
- normal use of the services and game servers

## 6. Make NixOS the default

13. GRUB's default becomes the NixOS entry, and the firmware gets a systemd-boot entry first in its order. Either path now ends in systemd-boot.
14. Reboot and unlock. This is the first boot where NixOS starts on its own.
15. Edge tunnel from the initrd: public keys into `lib/edge-tunnels.nix`, `dotfiles.edgeTunnel.initrd = true`, then test `unlock-via-edge thinkcentre` on the next reboot.

## 7. Retire Debian

16. Archive Debian's root volume into Borg (its own archive, kept).
17. **Stop: double confirmation needed.**
    - Delete Debian's EFI entry and files, plus GRUB.
    - `lvremove` Debian's root.
    - `lvextend -l +100%FREE` the `nixos` volume, then `resize2fs` (online).
    - Set `dotfiles.bootSafety.debianFallback = false`.
18. Journal entry, close #18.
