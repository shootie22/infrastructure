# infrastructure

```text
GitHub + SOPS  ──Argo CD──▶  [ server #1 | server #2 | server #3 | server #4 ]  ──Traefik──▶  services
                                      Kubernetes cluster
                                         2 countries

                               Prometheus · Grafana · Loki · Alloy¹
```

This repo is the source of truth for my self-hosted infrastructure.

The main environment is a multi-node Kubernetes cluster running K3s, spread across two countries. Argo CD reconciles the manifests in this repo, Traefik handles ingress, cert-manager manages certificates, and secrets committed to Git are encrypted with SOPS and age.

Monitoring also lives in the cluster, using Prometheus, Grafana, Loki and Alloy.¹

Matrix Synapse and LiveKit are kept on a separate VPS for now, outside of this setup.²

Host configuration lives separately in my [dotfiles repo](https://github.com/shootie22/dotfiles). All servers except server #4, a Mac mini M4, run NixOS and are configured declaratively there (my workstation and laptop run NixOS too because it's nice).

Some configuration and deployment work is done with the help of AI where it makes sense, because it speeds up some steps considerably.

## Repo layout

- `kubernetes/bootstrap/` — cluster bootstrap
- `kubernetes/argocd/` — Argo CD and shared cluster components
- `kubernetes/services/` — workloads managed by Kubernetes and Argo CD
- `services/production/` — remaining external or non-Kubernetes workloads
- `services/retired/` — old service definitions kept for reference
- `services/testing/` — temporary and experimental deployments
- `services/utils/` — shared configuration from older deployment setups
- `scripts/` — repository and secret-management helpers
- `docs/` — longer infrastructure notes

<details>
<summary><strong>History</strong></summary>

The infrastructure has been rebuilt quite a few times as both the hardware and the way I wanted to manage it changed.

I started by hosting Minecraft servers over [Hamachi](https://vpn.net/), then spent some time paying for managed Minecraft hosting. Soon enough I became progressively more interested in being able to mess around with more of the server and see what could be done, which eventually led to running my own server hardware, Linux, and port forwarding.

The first proper server was an HP MicroServer in 2013, followed by a larger HP server and later a period of running things on OVH VMs. In 2017 I moved back to hardware at home with a Raspberry Pi 3B+, later adding an old laptop as a storage server before consolidating onto a Dell tower in 2018.

That setup eventually evolved into Proxmox in 2024, then Git-managed Docker deployments with Komodo in 2025, and finally the current Kubernetes + Argo CD setup in 2026.

Most of those changes came from some combination of reducing cost and power use, trying different ways of managing servers, swapping Linux distributions to learn how they work, and generally experimenting with different setups. In 2025 I became increasingly curious about making the setup more reliable, declarative and reproducible, which naturally led me down the path of NixOS and Kubernetes.

*(all roads lead to Kubernetes)*

</details>

---

¹ Soon to be added: a standalone out-of-band monitoring node at one of the sites, running from its own UPS and separate mobile broadband connection. Its job will be to monitor the site and send alerts even when the site's normal power or internet connection is unavailable.

² Matrix Synapse and LiveKit will eventually be migrated from the VPS into a highly available setup spread across two servers in different physical locations.
