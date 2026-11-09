# infrastructure

```text
                                    RO                 DK            DE
GitHub + SOPS  ──Argo CD──▶  [ fuji · minima | thinkcentre · mixi | edge ]  ──Traefik──▶  services
                                       Kubernetes cluster (K3s)

                          Prometheus · Alertmanager · Grafana · Loki · Alloy
```

This repo is the source of truth for my self-hosted infrastructure.

The main environment is a K3s cluster of five nodes spread across three countries: two sites, in Romania and Denmark, plus a small edge VPS in Germany. Argo CD reconciles the manifests in this repo, Traefik handles ingress, cert-manager manages certificates, CloudNativePG runs Postgres with one instance per site, and secrets committed to Git are encrypted with SOPS and age.

Monitoring also lives in the cluster, using Prometheus, Alertmanager, Grafana, Loki and Alloy. The public status page at [radunenu.com/status](https://radunenu.com/status/) is built from the same probes.

Matrix is partway through moving into the cluster: yeetus.net already runs here, while nuke.zip's Synapse and LiveKit are still on a separate VPS until they move over.¹

Host configuration lives separately in my [dotfiles repo](https://github.com/shootie22/dotfiles). Every node runs NixOS and is configured declaratively there. minima is a Mac mini M4, so its node is a NixOS VM on top of macOS (my workstation and laptop run NixOS too because it's nice).

Some configuration and deployment work is done with the help of AI where it makes sense, because it speeds up some steps considerably, like drafting the issues and docs for the [HA project](docs/ha/README.md).

## Nodes

| Node | Site | Role |
|---|---|---|
| fuji | RO | control plane (etcd), databases |
| minima | RO | worker, a NixOS VM on a Mac mini M4 |
| thinkcentre | DK | control plane (etcd), databases |
| mixi | DK | worker, a Mac mini M1 running NixOS on Asahi |
| edge | DE | the third etcd member, the way in when RO is down, the tailnet's DERP relay, the alert relay |

A new node is joining the cluster soon, a nice little Dell PowerEdge server.

Both home sites run the same services where it's worth it, so losing one of them, or the edge, shouldn't take anything down. That's the [HA project](docs/ha/README.md), which is still being worked through phase by phase.

## Repo layout

- `kubernetes/bootstrap/` - cluster bootstrap
- `kubernetes/argocd/` - Argo CD and shared cluster components (cert-manager, CloudNativePG, Traefik config, sops-secrets-operator, the outage page)
- `kubernetes/services/` - one folder per service, each one an Argo CD app, described by its `hub.yaml`
- `tofu/` - DNS for every zone (Cloudflare, with deSEC as a standby), plus the external health checks
- `services/production/` - remaining external or non-Kubernetes workloads, mostly what's left on the Matrix VPS
- `services/retired/` - old service definitions kept for reference
- `services/testing/` - temporary and experimental deployments
- `services/utils/` - shared configuration from older deployment setups
- `scripts/` - repository checks and secret-management helpers
- `docs/` - longer infrastructure notes: [HA](docs/ha/README.md), [Matrix](docs/matrix/README.md), [updates](docs/updates.md), [incidents](docs/incidents/), [remote access](docs/remote-access.md)

## Making changes

Everything goes through a pull request. CI checks the manifests with kubeconform, runs the monitoring config through promtool, renders every service from its `hub.yaml` and compares the result, validates the tofu files, and checks things that have broken before (pods carrying the hash of the config they read, how many workloads a change restarts, where each database lives). Once it's merged, Argo CD rolls it out.

Image versions are pinned by tag and digest. Renovate opens pull requests for new versions every night and merges the safe ones by itself, and a daily Trivy scan files an issue for fixable CVEs. Game servers in active development and Element Web follow their newest build instead. The details are in [docs/updates.md](docs/updates.md).

## Monitoring & alerting

Alerts go out through a relay on the edge that tries Pushover, then email, then Matrix, and stops at the first that works. healthchecks.io and UptimeRobot watch from outside, so the cluster going down doesn't take its own alerting with it. Canary jobs push to Gitea every 10 minutes and run a CI job every 15, to catch the kind of problem where every component looks up but nothing actually works.

## Backup & disaster recovery

fuji, the thinkcentre and the minima VM are backed up with Borg to an external drive on minima (the Mac mini M4) on a regular schedule. That drive is then backed up off-site to Backblaze. TODO(radu): mixi and the edge, are they backed up, or is there nothing on them worth keeping?

This provides a local copy for normal restores and an off-site copy for recovery if the backup host or site itself is lost.

On top of that, the databases already on CloudNativePG have an instance in each site, so they survive losing one site without a restore.

<details>
<summary><strong>History</strong></summary>

The infrastructure has been rebuilt quite a few times as both the hardware and the way I wanted to manage it changed.

I started hosting Minecraft servers over [Hamachi](https://vpn.net/), and then moved onto managed hosting for a while... but soon enough I became progressively more interested in being able to mess around with more of the server and see what could be done, which eventually led me to running my own server hardware and setups.

My first proper server was an HP MicroServer in 2013, followed by a larger HP server and later a period of running things on OVH VMs. In 2017 I moved back to hardware at home with a Raspberry Pi 3B+, later adding an old laptop as a storage server before consolidating onto a Dell tower in 2018.

That eventually evolved into a Proxmox setup in 2024, in an attempt to "clean things up". The setup was good, but also very power hungry and it felt a little unstable. After about a year, I took that server apart and moved to a distributed setup using mini PCs (for low power consumption), with Komodo handling deployments across them. At the same time I moved most of the setup towards GitOps.

That setup worked too, but it started to feel a little slow and I didn't really like the deployment process. I had also been burning to play with Kubernetes and NixOS, so moving to the current Kubernetes + Argo CD setup felt like the natural next step.

*(all roads lead to Kubernetes)*

</details>

---

¹ The plan is in [docs/matrix/](docs/matrix/README.md): nuke.zip moves into the cluster under the same name and keys, then the two servers federate and people switch at their own pace.
