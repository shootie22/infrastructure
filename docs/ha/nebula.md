# Nebula: the servers' own network

Decision: [decisions.md](decisions.md), 2026-10-05. Work: [#141](https://github.com/shootie22/infrastructure/issues/141).

fuji, the thinkcentre, the edge, mixi and minima talk to each other over Nebula, next to tailscale. Tailscale stays for devices, admin access and the private services. Nebula is for what the cluster itself needs at boot (etcd, the k3s API, flannel, from Phase 3 on), because it doesn't need a control server: each server has a certificate on disk and finds the others through two lighthouses, the edge and fuji.

Config: dotfiles `lib/nebula.nix` (hosts and addresses) and `modules/nixos/nebula-mesh.nix`. VM rehearsal: dotfiles `tests/nebula-backbone.nix`.

## How it's set up

- **Lighthouses and relays:** the edge, and fuji through a UDP port forwarded on the RO router. The others find each other through either one, and go through one when NAT blocks a direct path.
- **Ports:** 4242 on the lighthouses, 4241 everywhere else. Not 4242 on the others: another RO host on it would take RO's public 4242 when NATed, the port forwarded to fuji.
- **Never over the tailnet or the pod network:** hosts don't advertise those addresses, and nobody accepts them as a way to reach a peer. On RO and DK, the mesh's own packets to the LAN skip tailscale's routes (an `ip rule` for those two ports only).
- **Same LAN, direct:** the two DK hosts and the two RO hosts talk over their LAN, not through a relay.
- **Keys:** each server makes its own key pair on the first activation; only the public half gets signed. The CA key is kept privately, encrypted to the personal key, with the signing steps.
- **Monitoring:** Prometheus scrapes Nebula's metrics on each server over the mesh itself (job `nebula`). `NebulaHostUnreachable` fires when one can't be reached there for 10 minutes. The metrics only listen on the mesh address.

## What's been tested

In VMs (both sites behind NAT, like the real ones): full mesh, the edge down, fuji down, a cold start of everything. On the real servers: full mesh on all 20 paths, and the edge's Nebula stopped while another host restarted its own; everything still found everything through fuji.

Things the real test found that the VMs didn't: minima's packets to fuji went over the tailnet (tailscale routes fuji's LAN address for DK), and mixi could only resolve names through tailscale. Both fixed.

## Adding a server

1. An entry in `lib/nebula.nix` and `dotfiles.nebulaMesh.enable = true` in its config. After the deploy it has `/var/lib/nebula-mesh/host.pub`.
2. Sign that public key with the CA (steps next to the CA key), commit the certificate as `lib/nebula/<name>.crt`. On the next deploy Nebula starts.
3. Add it to the Prometheus job `nebula`.
