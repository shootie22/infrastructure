# Move the thinkcentre to NixOS

Phase 2 ([#18](https://github.com/shootie22/infrastructure/issues/18)). The thinkcentre is in DK and nobody is there, so nothing here may need someone on site. That's why NixOS doesn't replace Debian in one go: it's installed next to it, booted once, and Debian stays the default until NixOS has run for a while.

What stays untouched the whole time: `/home` (all service data), the 4 TB disk, and Debian's root volume until the very last step.

The config is in dotfiles, `hosts/thinkcentre/`. The inventory it's based on is in [#15](https://github.com/shootie22/infrastructure/issues/15).

## How the trial boot protects us

- The firmware keeps booting Debian by default. NixOS is started with a one-time `BootNext`, so any reboot after that lands in Debian again.
- In NixOS's initrd, a timer reboots after 30 minutes if nobody has unlocked the disk.
- After boot, a check reboots 20 minutes in if fuji isn't reachable over the tailnet.
- The hardware watchdog reboots if the kernel or systemd hangs.

The worst case is a reboot into Debian, then unlocking it the usual way.

## Before the window (no downtime)

1. **Fresh Borg backup and a test restore** ([#16](https://github.com/shootie22/infrastructure/issues/16)).
2. **Secrets into `secrets/thinkcentre.yaml`.** Only the thinkcentre's own age key can edit that file, so this is done on the thinkcentre with sudo:
   - `k3s_agent_token`: the `K3S_TOKEN` from `/etc/systemd/system/k3s-agent.service.env`
   - `tc_storage_key`: the 4 TB disk's keyfile, `/root/tc-storage4tb.key`. Check `sudo file` on it first. If it's binary, it goes into its own SOPS file in binary format instead, and the config changes to match.
   - test that the stored key opens the disk: decrypt it to a file in `/run`, then `cryptsetup open --test-passphrase --key-file <file> /dev/sdb`, then delete the file
   - turn `sops.validateSopsFiles` back on in the config
3. **The 4 TB keyfile also goes into the password manager.** Without it, that disk only comes back from Borg.
4. **Carry-over files** into a root-only folder on `/home` (it survives everything):
   - `/etc/sops/age/keys.txt`: the age key the secrets are encrypted to
   - `/etc/rancher/node/password`: so k3s rejoins as the same node, with its labels
   - `/var/lib/tailscale/tailscaled.state`: same tailnet identity and address
5. **Move Minecraft HC's data** from `/opt/docker-data/` (Debian's root) to `/home/main/services/`, and change the hostPath in `kubernetes/services/minecraft-hc/` in the same go. That's a short restart of that server.
6. **The boot-only guard for the DHCP handover** (#81) is merged. Without it, NixOS's first live switch could drop the LAN address.

## The window (about an hour, Debian keeps running until the reboot)

7. **Make room for NixOS.** Swap off, delete the swap volume, create `nixos` in its place, `mkfs.ext4` it. Take swap out of Debian's fstab and set `RESUME=none` for its initramfs, then `update-initramfs -u`, or Debian's next boot waits for a swap device that's gone.
   **Stop: confirmation needed.** This is the first step that deletes something (only swap).
8. **Nix on Debian, temporarily.** Bind-mount a folder on `/home` to `/nix` first, since Debian's root only has ~10 GB free. Then the official installer.
9. **Install.**
   - Mount the `nixos` volume at `/mnt`, bind the ESP (`/boot/efi`) to `/mnt/boot`, and create `/home/rancher`. The bind mount for k3s needs that folder at boot.
   - Copy in the carry-over files: the age key to `/mnt/var/lib/sops-nix/key.txt`, plus the node password and Tailscale state.
   - Generate the initrd host key into `/mnt/etc/secrets/initrd/`.
   - Run `nixos-install --flake github:shootie22/dotfiles#thinkcentre --no-root-passwd`, then set main's password with `nixos-enter`.
10. **Boot entry.** Create it with `efibootmgr -c` for `\EFI\systemd\systemd-bootx64.efi`, then put Debian back first in `BootOrder`, because `-c` puts the new entry first. Then `efibootmgr -n <nixos>`. Check the output: Debian first in the order, NixOS only as `BootNext`.
    **Stop: confirmation needed** before the reboot.
11. **Trial boot.** Reboot. Unlock from the LAN through mixi (initrd SSH on 2222, host key alias `thinkcentre-initrd`; it's a new key, so compare the fingerprint printed during step 9). Then check:
    - the node is Ready and Argo apps are Synced/Healthy
    - Gitea (repos visible, so the 4 TB disk is open), Vaultwarden, Joplin, Audiobookshelf, the game servers
    - Borg: run the job once by hand
    - the edge reaches Traefik and the game ports

    If anything is off, `reboot`: Debian comes back.

## After a day or two on NixOS

12. Make NixOS the default (`efibootmgr -o`), then remove the trial-fallback units from the config.
13. Edge tunnel from the initrd: copy the two public keys from `/etc/ssh/edge-tunnel/` into `lib/edge-tunnels.nix`, then turn on `dotfiles.edgeTunnel.initrd`. Test `unlock-via-edge thinkcentre` on the next reboot.
14. Move the DK failover vote from mixi to the thinkcentre, if wanted.

## Retire Debian

15. **Stop: double confirmation needed.** Delete Debian's root volume, grow `nixos` into the space (`lvextend` and `resize2fs`, both online), delete Debian's EFI entry and the old `/boot` partition.
16. Decide about the unused 120 GB SSD (sda).
17. Journal entry, close #18.
