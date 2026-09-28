# Cluster bootstrap and recovery

What is not reconciled by Argo CD, and the order to bring the cluster back
from nothing. Host configuration lives in the
[dotfiles repo](https://github.com/shootie22/dotfiles).

## Keys that exist only outside Git

Keep all of these in the password manager; each one is needed before any
backup or secret can be read.

| What | Where it lives | Needed for |
|---|---|---|
| Fuji age key (`age1qwuleu9k…`) | Fuji `/var/lib/sops-nix/key.txt` | Fuji's host secrets **and** every `*.sops.yaml` in this repo (the cluster's `sops-age-key-file` secret holds the same key) |
| Fuji Borg passphrase | `secrets/fuji.yaml` in dotfiles (encrypted to the key above) | restoring `fuji-k3s` backups |
| Minima VM Borg passphrase | Mac `~/.config/borg/minima-vm.passphrase` | restoring `minima-vm` backups |
| Per-host age keys (mixi, thinkcentre, minima) | each host's `/var/lib/sops-nix/key.txt` | that host's secrets |

The Fuji age key's only other copy is inside Fuji's own Borg backups, which
need a passphrase encrypted to that key: without a copy outside Fuji, losing
Fuji's disk loses every secret.

## Order

Headscale runs in this cluster and the remote workers join over the tailnet,
so Fuji comes up alone first, on its LAN address.

1. **Fuji**: install NixOS from `hosts/fuji`, put the age key at
   `/var/lib/sops-nix/key.txt`, then
   `sudo nixos-rebuild switch --flake ~/git/dotfiles#fuji`.
   This starts the K3s server (API advertised on `192.168.100.136`) and
   Tailscale (DNS independent of the tailnet).
2. **Restore state before any workload runs** (keeps Headscale's identity,
   every PersistentVolume and the cluster database): with k3s stopped, extract
   the latest `fuji-k3s` archive from the Mac
   (`/Volumes/Expansion/borg_repos/fuji-k3s`) into
   `/var/lib/rancher/k3s/storage` and `/var/lib/rancher/k3s/server/db/state.db`.
   With the database restored, steps 3 and 4 are already done.
3. **Argo CD** (v3.5.2):
   ```sh
   kubectl create namespace argocd
   kubectl apply -n argocd --server-side \
     -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.2/manifests/install.yaml
   ```
4. **SOPS key for the operator**:
   ```sh
   kubectl create namespace sops
   kubectl -n sops create secret generic sops-age-key-file \
     --from-file=key=/var/lib/sops-nix/key.txt
   ```
5. **Hand over to Git**: `kubectl apply -f kubernetes/bootstrap/root.yaml`.
   Argo CD then installs everything under `kubernetes/argocd` and
   `kubernetes/services`, including Headscale, Traefik's config and the tailnet
   ACL policy.
6. **Tailnet route** for remote workers to reach the API's LAN address (not
   needed if the Headscale database was restored):
   ```sh
   kubectl -n headscale exec deploy/headscale -- \
     headscale nodes approve-routes -i <fuji node id> -r 192.168.100.136/32
   ```
7. **Workers**: mixi and Minima from their NixOS configs, thinkcentre from
   `hosts/thinkcentre/README.md` (dotfiles). Each joins
   `https://100.64.0.1:6443` over the tailnet.

## Checks

```sh
kubectl get nodes                         # 4 Ready
kubectl get applications -n argocd        # all Synced/Healthy
curl -s -o /dev/null -w '%{http_code}\n' https://hs.radunenu.com   # 200
```
