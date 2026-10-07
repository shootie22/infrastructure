# Replace the edge VPS

For moving the edge to a different VPS. The first real run is planned for February 2027, when the OVH contract ends and a cheaper VPS takes over ([#80](https://github.com/shootie22/infrastructure/issues/80)). The same steps installed the edge on the OVH VPS on 2026-10-01, so everything up to step 6 has been run once.

The edge has no data, so this is a reinstall, not a migration. Its identity (the SSH host key) comes from `secrets/edge-bootstrap.yaml` in dotfiles, and the whole config is `hosts/edge`.

What it runs since 7 Oct 2026, all of which comes back by itself from the config and the cluster:
- an etcd member (the third vote), Nebula lighthouse and relay
- HAProxy: the way in for failover, and Element Web/Call's front door, served from its own copies (k3s pods) with certificates copied from the cluster every 15 minutes
- the main alert relay (mixi's is the standby), the RO failover checker, the nameserver checker
- the tailnet's relay (derper, derp.radunenu.com)

## Before buying

- Criteria: about 5 €/month, 2 decent cores, 2-4 GB RAM (2 GB is the floor with everything above), an SSD (etcd waits on its disk), gigabit port, public IPv4, generous traffic, Germany or Austria.
- Buy one with a trial or refund period, because of step 7.
- Note the disk device. Most providers use `/dev/sda` or `/dev/vda`. If it isn't `/dev/sda`, change it in `hosts/edge/configuration.nix` before installing.

## Steps

1. **Pre-auth key.** On fuji (`--user` takes the numeric ID from `headscale users list`, not the name):
   ```sh
   sudo kubectl -n headscale exec deploy/headscale -- headscale users list
   sudo kubectl -n headscale exec deploy/headscale -- headscale preauthkeys create --user 1 --expiration 24h
   ```
2. **Store it** in dotfiles, without it ending up in the shell history or on screen:
   ```sh
   read -rs K && nix shell nixpkgs#sops -c sops set secrets/edge.yaml '["tailscale_authkey"]' "\"$K\""
   ```
   Commit and push.
3. **Install from a clean checkout,** so the VPS gets exactly what's committed and not a local `flake.lock`:
   ```sh
   git worktree add --detach /tmp/edge-install HEAD && cd /tmp/edge-install
   hosts/edge/install <user>@<new ip>
   ```
   The user needs root or passwordless sudo. Add `-i <ssh key>` if the right key isn't the default one. The script asks for the address again before it wipes anything.
4. **Fix `known_hosts`** on the admin devices: remove the provider's old key for the new IP, then add the edge's key:
   ```sh
   ssh-keygen -R <new ip>
   echo "<new ip> $(cut -d' ' -f1,2 hosts/edge/ssh_host_ed25519_key.pub)" >> ~/.ssh/known_hosts
   ```
   `ssh edge@<new ip>` must then work with no host key warning. If it warns, the identity didn't carry over.
5. **Check the box.** `systemctl is-system-running` should say `running`, `systemctl --failed` should be empty, and `tailscale ip` gives the new tailnet address.
   comin takes over from here: `sudo comin status` should show the latest commit on `main`. From now on, changes to the edge are just commits.
6. **Tailnet.** Remove the old edge in Headscale (`headscale nodes list`, then `headscale nodes delete -i <id>`). If the new edge got a different tailnet address, update `edge` and `edge6` in the ACL ([headscale configmap](../../../kubernetes/services/headscale/configmap.yaml)) and bump `config-revision` in the deployment.
7. **Throughput,** while the VPS can still be refunded. Same test as [#10](https://github.com/shootie22/infrastructure/issues/10): a temporary ACL rule for port 5201, a runtime firewall rule and `iperf3 -s` on the edge, then `iperf3 -c <edge tailnet ip>` from fuji and thinkcentre, both directions. The OVH VPS did 700-800 Mbit/s each way. A cheap 2-core box may do less; anything above a few hundred Mbit/s is fine for failover.
8. **Point things at the new IP.** Once the edge has jobs, these need the new address too:
   - `edge.radunenu.com` in OpenTofu (`tofu/dns-records.tf`), and the `edge_ip` the failover checker writes to deSEC (dotfiles, `modules/nixos/failover-checker`)
   - radunenu.com's SPF record, which allows the edge to send alert emails
   - `edgeAddress` in dotfiles `modules/nixos/edge-tunnel.nix`: the initrd tunnels connect by address (no DNS that early). fuji and mixi pick it up on their next rebuild, but their initrd only on the next boot, so check `unlock-via-edge` before relying on it
   - Nebula: the edge's `reach` address in dotfiles `lib/nebula.nix` (every host finds the mesh through it), and the new host key signed into `lib/nebula/edge.crt` ([bootstrap.md](../../bootstrap.md), "One server lost")
   - etcd: remove the old edge member first, then let the new one join empty (bootstrap.md, "One server lost", step 3). Never both at once: two of three must stay up meanwhile.
   - `edge_ip` for the front checker (dotfiles `modules/nixos/failover-checker`, frontSettings)
   - the relay's `ipv4` in Headscale's `derp.yaml` ([configmap](../../../kubernetes/services/headscale/configmap.yaml)), and `config-revision`
   - the scrape targets for the edge in `prometheus-configmap.yaml` (its tailnet address, if that changed)
9. **Cancel the old VPS** only after the new one has run for a day.
10. **Journal entry,** with how long it took.
