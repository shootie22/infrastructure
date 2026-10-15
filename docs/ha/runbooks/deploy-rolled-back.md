# A deploy was rolled back

Every host comin deploys runs a switch guard (dotfiles `modules/nixos/switch-guard.nix`), since the [2026-10-14 incident](../../incidents/2026-10-14-fuji-cut-off.md), where a deploy left fuji unable to reach anything until it was power-cycled.

## What it does

Every 30 seconds the host pings the other servers over Nebula. At least one has to answer.

- A system that has run healthy for 10 minutes becomes the **known-good** one (`/var/lib/switch-guard/good`, kept from garbage collection).
- If no server answers for **5 minutes** while the host runs anything else (a fresh deploy, or a boot into a new system), it switches back to the known-good system, the way comin deploys, and points comin's profile at it so the next boot uses it too.
- Then it **holds comin**: comin is stopped and won't start again, not even after a reboot, so it can't put the bad system straight back.
- Once the network works again it sends **"Deploy rolled back on <host>"** to the alert relays (emergency).
- On the known-good system it never does anything: an outage that isn't a deploy's doing is not its business.

Tested in dotfiles `tests/switch-guard.nix`, not yet for real.

## When the alert comes

1. Which deploy it was: `cat /var/lib/switch-guard/rolled-back-from` on the host, and `journalctl -u switch-guard -u switch-guard-rollback` for the timeline.
2. Fix `main` in dotfiles: revert the commit, or fix it. Don't let comin go before that, or it deploys the same thing again. The later hosts won't deploy it meanwhile: deploys go in stages (thinkcentre and mixi, then fuji and minima, then the edge; [decisions](../decisions.md)), and a host whose comin is held blocks the stages after it.
3. Let comin go again:

   ```sh
   sudo rm /var/lib/switch-guard/hold && sudo systemctl start comin
   ```

4. Watch it deploy: `journalctl -u comin -f`. The new system becomes known good after 10 healthy minutes (`journalctl -u switch-guard`).

## Checking on it

```sh
systemctl list-timers switch-guard.timer
journalctl -u switch-guard -n 20 --no-pager
cat /var/lib/switch-guard/good; readlink -f /run/current-system
ls /var/lib/switch-guard/hold 2>/dev/null && echo "comin is held"
```

## Deploys in stages

thinkcentre and mixi deploy a commit at once; fuji and minima after both have run it for 30 minutes; the edge after fuji. On a later host, `journalctl -u deploy-gate -n 5` says what it's waiting for, and `sudo comin confirmation accept` lets a commit through by hand (a fix that has to go out now). A commit that doesn't change the earlier hosts goes after 60 minutes, as long as they stayed healthy.

## Turning it off on one host

`dotfiles.switchGuard.enable = false;` in the host's configuration. Its timings are options too (`failAfter`, `acceptAfter`, `interval`).
