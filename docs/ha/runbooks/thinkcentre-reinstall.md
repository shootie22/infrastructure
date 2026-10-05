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
- [x] Unlocking over SSH into the NixOS initrd, rehearsed (4 Oct)
- [x] `thinkcentre-unlock` (dotfiles, admin devices): finds the thinkcentre on the DK LAN by its MAC through mixi, whichever address the initrd got, and unlocks Debian or NixOS
- [x] Debian's real initrds booted in a VM on the workstation: network, dropbear with the real host key, admin key, unlock

## 2. Prove Debian and GRUB (two reboots, ~10 minutes downtime each)

Debian's remote unlock was set up after its last reboot, so it has never run for real, and the newest kernel has never booted. Both get proven before NixOS is involved.

1. `debian-prep.sh` (no reboot): takes swap out of Debian (`swapoff`, the fstab line, `RESUME=none`), rebuilds both initrds and checks inside each that dropbear, the admin keys, port 2222, DHCP on the LAN card, the NIC driver, the root disk and LVM are there, then sets GRUB: default the running kernel, one-time the newest.
2. The initrd VM test above passes for both kernels.
3. **Stop: confirmation needed. Reboot 1:** boots the never-booted kernel once. If it fails and reboots, the known-good one comes up. Unlock with `thinkcentre-unlock`; it must come up on the new kernel.
4. **Reboot 2:** plain reboot, back on the default kernel. That proves the one-time boot reverts by itself, which is what the NixOS trial relies on.

If either fails: stop. Debian still works, so nothing is lost; the plan gets rethought.

Done 5 Oct: reboot 1 came up on the new kernel after a remote unlock through mixi, reboot 2 went back to the default kernel by itself.

## 3. Install next to Debian (Debian keeps running)

Two scripts, run with sudo (kept on the thinkcentre, not in a repo).

4. **Stop: confirmation needed.** `nixos-volume.sh`: deletes the swap volume and creates `nixos` in its place (`lvremove thinkcentre-vg/swap_1`, `lvcreate -l 100%FREE -n nixos`, `mkfs.ext4 -L nixos`). It refuses if anything still uses or points at swap.
5. No Nix on Debian. The NixOS system is built on the workstation and copied over as an archive of its store (1.8 GB, 786 paths). The script unpacks it onto the `nixos` volume and bind-mounts it at `/nix` only while installing.
6. `nixos-install.sh` mounts `nixos` at `/target` and the ESP at `/target/boot`, and creates `/home/rancher` and `/home/docker`. Then it copies in:
   - `/etc/sops/age/keys.txt` → `/target/var/lib/sops-nix/key.txt`
   - `/etc/rancher/node/password`, so k3s rejoins as the same node with its labels
   - `/var/lib/tailscale/tailscaled.state`, for the same tailnet node and address
   - the ed25519 and RSA host keys from `/etc/ssh`, so every known_hosts entry stays valid
   - a new initrd host key in `/target/etc/secrets/initrd/`; note its fingerprint
7. It saves the firmware's boot entries, a tar of the whole ESP and the old `40_custom` to `/root`, and the ESP's fallback loader (`EFI/BOOT/BOOTX64.EFI`) next to itself. NixOS's systemd-boot replaces the fallback loader. The firmware boots `\EFI\debian\shimx64.efi`, so that doesn't change what starts.
8. `nixos-install --system <the built system> --no-root-passwd`, then main's password with `nixos-enter`. systemd-boot goes on with `--no-variables`; the script checks that the firmware's entries are the same afterwards.
9. A GRUB entry for NixOS in `/etc/grub.d/40_custom`, chainloading `/EFI/systemd/systemd-bootx64.efi` from the ESP, with `--id nixos`. If the chainload fails, it reboots: GRUB has already cleared the one-time entry by then, so that lands in Debian. Without the `reboot`, GRUB would go back to its menu with NixOS still the default and try it again forever. Tested in a VM with Debian's real shim and GRUB (dotfiles `hosts/thinkcentre/rehearsal/grub-chain-test.sh`). Then `update-grub` and `grub-script-check`.

Done 5 Oct. One snag: the installed generation's edge tunnel key step ran before the users existed and failed. It makes the key on the first real boot instead; fixed in dotfiles for next time.

## 4. Trial boot (downtime starts here)

10. Stop k3s on Debian and copy `/var/lib/rancher/k3s` to `/home/rancher/k3s`, so the ~15 GB of images don't get downloaded again. Copy `tailscaled.state` onto `nixos` again too, since Debian kept using it after step 6.
11. **Stop: confirmation needed.** `grub-reboot nixos`, reboot.
12. Unlock with `thinkcentre-unlock` (initrd SSH on 2222, the new host key from step 6). Then check:
    - node Ready, Argo Synced/Healthy, Gitea shows its repositories (so the 4 TB disk is open), Vaultwarden, Joplin, Audiobookshelf, the game servers, the Gitea runner
    - `systemctl --failed` is empty, and `boot-health` passed
    - the edge reaches Traefik and the game ports
    - one Borg run by hand

    Anything wrong: `reboot`, and Debian comes back on its own.

Done 5 Oct. All checks passed. What the first real boot turned up, all fixed since:
- The NixOS initrd got a different LAN address than Debian. `thinkcentre-unlock` finds it by MAC, so it only matters when typing the address by hand.
- Probing the initrd's SSH port from mixi without logging in made OpenSSH stop answering mixi for a while, which locked out the real unlock. The initrd's sshd no longer does that.
- Debian keeps the hardware clock in local time and NixOS read it as UTC, so it booted two hours ahead until NTP pulled it back. k3s restarted a few times over it and comin stopped fetching until restarted. NixOS now treats the clock as local time too, until Debian is gone.
- The initrd's unlock timer survived the switch to the real system and showed up failed there. It's stopped at the switch now.
- The edge tunnel failed until its key was registered on the edge; that part of step 15 is done.
- The trial script first stopped because CI jobs run in Debian's Docker. It now waits for running CI steps to finish before stopping k3s.

## 5. Three days on NixOS

While NixOS runs, any reboot lands in Debian (that's the point). During these days:
- a scheduled Borg run
- a DHCP lease renewal (the 2026-10-01 incident was a lease running out after 3 days)
- normal use of the services and game servers

## 6. Make NixOS the default

13. **Stop: confirmation needed.** `nixos-default.sh`: the firmware gets a new first boot entry for `\EFI\systemd\systemd-bootx64.efi` (`efibootmgr --create`, which puts it first). GRUB's default stays Debian on purpose: systemd-boot's Debian entry goes through GRUB, so a GRUB defaulting to NixOS would send three failed NixOS boots straight back into systemd-boot, forever. This way they end in Debian. If the firmware ignores the new order, Debian starts, which is still reachable.
14. Reboot and unlock. This is the first boot where NixOS starts on its own.
15. Edge tunnel from the initrd: `dotfiles.edgeTunnel.initrd = true` (both keys are already registered), then test `unlock-via-edge thinkcentre` on the next reboot.

## 7. Retire Debian

16. Archive Debian's root volume into Borg (its own archive, kept).
17. **Stop: double confirmation needed.**
    - Delete Debian's EFI entry and files, plus GRUB.
    - `lvremove` Debian's root.
    - `lvextend -l +100%FREE` the `nixos` volume, then `resize2fs` (online).
    - Set `dotfiles.bootSafety.debianFallback = false`.
18. Journal entry, close #18.
