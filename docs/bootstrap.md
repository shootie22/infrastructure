# Cluster bootstrap and recovery

What isn't reconciled by Argo CD, and how to bring the cluster back, from one lost server up to nothing at all. Host configuration lives in the [dotfiles repo](https://github.com/shootie22/dotfiles).

Since 5 Oct 2026 the cluster's state is in etcd on three servers (fuji, the thinkcentre and the edge), and the servers talk over Nebula, not the tailnet ([decisions](ha/decisions.md), [Nebula](ha/nebula.md), [etcd runbook](ha/runbooks/etcd-migration.md)). Nothing here needs the tailnet or Headscale to be up: Headscale runs in the cluster and comes back with it.

## Keys that exist only outside Git

Keep all of these in the password manager. Each one is needed before some backup or secret can be read.

| What | Where it lives | Needed for |
|---|---|---|
| Personal age key (`age1a4pm…`) | admin devices, `~/.config/sops/age/keys.txt` | signing Nebula certificates (the CA key is encrypted to it, in the private sidecar repo); editing the thinkcentre's and the edge's secrets |
| Fuji age key (`age1qwuleu9k…`) | fuji `/var/lib/sops-nix/key.txt` | fuji's host secrets **and** every `*.sops.yaml` in this repo (the cluster's `sops-age-key-file` secret holds the same key) |
| Fuji Borg passphrase | `secrets/fuji.yaml` in dotfiles (encrypted to the key above) | restoring `fuji-k3s` backups, which hold the etcd snapshots |
| k3s server token | `secrets/fuji.yaml`, `secrets/thinkcentre-k3s.yaml`, `secrets/edge.yaml` in dotfiles | a server joining, and restoring an etcd snapshot (k3s encrypts part of the snapshot with it) |
| Minima VM Borg passphrase | Mac `~/.config/borg/minima-vm.passphrase` | restoring `minima-vm` backups |
| Per-host age keys (mixi, thinkcentre, minima; the edge uses its SSH host key) | each host's `/var/lib/sops-nix/key.txt` | that host's secrets |

The fuji age key's only other copy is inside fuji's own Borg backups, which need a passphrase encrypted to that key: without a copy outside fuji, losing fuji's disk loses every secret.

## One server lost

The common case, and the one the setup is built for: the other two etcd members keep the cluster running, so nothing has to be restored.

1. Reinstall the host from its NixOS config (the thinkcentre: `docs/ha/runbooks/thinkcentre-reinstall.md`; the edge: `docs/ha/runbooks/replace-edge.md`), with its age key in place.
2. **Nebula:** the fresh install makes a new key pair. Sign the new `/var/lib/nebula-mesh/host.pub` with the CA (steps next to the CA key in the private repo) and commit it as `lib/nebula/<host>.crt`. Nebula starts on the next deploy.
3. **etcd:** remove the old member from a surviving server (`etcdctl member remove <id>`), make sure the reinstalled host has no `/var/lib/rancher/k3s/server/db`, and start k3s. It joins as a new member.
4. Check: three started members, all on Nebula addresses, and `etcdctl get /registry/masterleases/ --prefix --keys-only` lists only live servers.

An agent (mixi, minima) only needs steps 1 and 2; it rejoins by itself.

## Everything lost

Order: Nebula first (it needs nothing), then one server restored from an etcd snapshot, then the other two join it, then the agents.

1. **fuji:** install NixOS from `hosts/fuji`, put the age key at `/var/lib/sops-nix/key.txt`, then `sudo nixos-rebuild switch --flake ~/git/dotfiles#fuji`. Sign its new Nebula key (above) and rebuild once more so Nebula starts. k3s starts as a fresh, empty one-member cluster.
2. **Restore before any workload runs**, from the latest `fuji-k3s` archive on the Mac (`/Volumes/Expansion/borg_repos/fuji-k3s`):
   - stop k3s;
   - extract the volumes into `/var/lib/rancher/k3s/storage` and the etcd snapshots into `/var/lib/rancher/k3s/server/db/snapshots`;
   - run k3s once by hand with its usual flags plus `--cluster-reset --cluster-reset-restore-path=<newest snapshot>`. It restores and exits; start the service again.

   With the snapshot restored, Argo CD, the SOPS key and every app are back as they were; skip to step 5.
3. **Only if there is no snapshot**, a fresh cluster: Argo CD (v3.5.2):
   ```sh
   kubectl create namespace argocd
   kubectl apply -n argocd --server-side \
     -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.2/manifests/install.yaml
   ```
   SOPS key for the operator:
   ```sh
   kubectl create namespace sops
   kubectl -n sops create secret generic sops-age-key-file \
     --from-file=key=/var/lib/sops-nix/key.txt
   ```
   Hand over to Git: `kubectl apply -f kubernetes/bootstrap/root.yaml`. Argo CD then installs everything under `kubernetes/argocd` and `kubernetes/services`, Headscale included.
4. **The thinkcentre and the edge:** install, sign their Nebula keys, deploy. With no `/var/lib/rancher/k3s/server/db` they join the restored cluster as new members.
5. **Agents:** mixi and minima from their NixOS configs, Nebula keys signed. They join through `k3s-api` (every API server, from the hosts file), so this works with either API server up.
6. **The tailnet** comes back with Headscale, once the cluster runs it again.

## Checks

```sh
kubectl get nodes -o wide                 # 5 Ready, every node on its Nebula address
kubectl get applications -n argocd        # all Synced/Healthy
etcdctl member list                       # 3 started, peer URLs on Nebula
curl -s -o /dev/null -w '%{http_code}\n' https://hs.radunenu.com   # 200
```

`etcdctl` with k3s's certificates, as root on a server:

```sh
d=/var/lib/rancher/k3s/server/tls/etcd
etcdctl --endpoints https://127.0.0.1:2379 --cacert $d/server-ca.crt --cert $d/client.crt --key $d/client.key member list
```
