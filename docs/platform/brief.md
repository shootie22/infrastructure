# Infra platform: brief

The starting point for designing the platform. Nothing gets built until the design is written down and agreed (milestone [Platform 0](https://github.com/shootie22/infrastructure/milestone/14), [#163](https://github.com/shootie22/infrastructure/issues/163)).

## What it is

One self-hosted web platform that becomes the home of the whole setup: a hub page, with modules behind it. It will be extended for years, so the core has to stay small and the modules have to plug in without touching it.

The modules known so far:

- **Hub.** The front page: what's healthy, what's broken, what changed lately, links into everything. [Homepage](../../kubernetes/services/homepage/) does part of this today and may be replaced or absorbed.
- **Infra map** ([#53](https://github.com/shootie22/infrastructure/issues/53), [#54](https://github.com/shootie22/infrastructure/issues/54), [#52](https://github.com/shootie22/infrastructure/issues/52)). What runs where and why: DNS to site to front door to Traefik to service to pod to node, plus etcd, Postgres, site-failover and the edge. A static layer generated from Git (this repo, dotfiles, OpenTofu), a live layer from read-only Prometheus queries, a short plain-language description per component. #52 adds service-to-service traffic from Alloy/Beyla.
- **Incidents** ([#157](https://github.com/shootie22/infrastructure/issues/157)). Every alert and resolve in one timeline, grouped into incidents, kept over time, so the owner doesn't dig through Pushover and email. Hand-written incident reports already live in [docs/incidents](../incidents/).
- **Deploy tool** ([#161](https://github.com/shootie22/infrastructure/issues/161), with the owner's notes in its comments). A new service from an image and a few answers, with its HA pattern chosen (suggested from what it keeps, home site selectable), written to Git as a pull request, deployed by Argo CD and comin. Detects ports, volumes, health checks and architectures from the image where that's reliable, asks otherwise. A web form and a CLI, same result.

## The environment

Read [docs/ha/](../ha/) first: [plan.md](../ha/plan.md), [decisions.md](../ha/decisions.md), [service-ha.md](../ha/service-ha.md), [failover.md](../ha/failover.md), [alerting.md](../ha/alerting.md), and the runbooks. In short:

- Two home sites (RO: fuji, minima; DK: thinkcentre, mixi) and the edge VPS. The servers talk over Nebula; the tailnet (Headscale) is for devices. DK takes no incoming connections.
- k3s with etcd on fuji, the thinkcentre and the edge. Everything in the cluster is in this repo and deployed by Argo CD. Host config is in the dotfiles repo (NixOS), deployed by comin. Secrets: SOPS.
- HA patterns in use: two replicas one per site (stateless), CNPG Postgres with an instance per site, site-failover with copies every 10 minutes (services with files), per-site copies (monitoring), the edge as a front door (Element Web).
- Monitoring: a Prometheus, Loki and Grafana per site, two clustered Alertmanagers, an alert relay on the edge with a standby on mixi (Pushover, then email). Checkers for RO failover, Element's front door and the nameservers, each with a status page.
- Login: Keycloak, two replicas. Realms: master for admins only, an infra realm for admin tools, a main realm for friends and user services.
- Code: GitHub (public) and Gitea (private, CI runners, container registry). Renovate keeps images up to date.
- Compute: plenty of RAM; CPU is the tighter resource (fuji and the thinkcentre have 4 cores each).
- [docs/infrastructure-topology.md](../infrastructure-topology.md) describes the old setup and is out of date.

## Requirements

- **HA like everything else:** runs in both sites, its own data replicated, survives losing either site with seconds of trouble at most.
- **Secure:** read-only by default, least privilege for each data source (no blanket Kubernetes or Secret access), changes only through pull requests, login through Keycloak, not public unless a part is meant to be.
- **Self-hosted FOSS only,** on the existing hardware. No paid services, no new VPS, no dependency on Cloudflare features.
- **Maintainable:** few dependencies, all of them maintained, updated by Renovate; a structure a future session can understand from the repo; tests for the parts that write to Git.
- **Deterministic:** the same input gives the same output. No guessing where the tool isn't sure; it asks.
- **Light:** CPU especially.
- **Public repo:** nothing sensitive in it. Sensitive notes go to the private sidecar repo, secrets to SOPS.

## How the design is made

1. Research, online and in both repos: existing FOSS for each module (to use, adapt or learn from, and why not), secure ways to read each data source, how the core and modules fit together, where the platform keeps its own data and how that's HA, the stack.
2. Questions to the owner as they come up: what the hub shows first, who gets access to what, what's public, how incidents are named, grouped and closed, what the deploy form asks, anything else that's a matter of taste or priority rather than fact.
3. A design document in `docs/platform/design.md`: architecture, modules, data, security, HA, the stack and why, what's left out.
4. The owner's OK.
5. Issues in the Platform 1-4 milestones, in build order.

## Questions to start from

- One app with modules, or a small set of services behind one hub?
- Which existing FOSS covers enough of a module to reuse it instead of building (an alert history store, a service catalogue, a map renderer)?
- Where does incident history live, and how long?
- How does the deploy tool get permission to open pull requests in both repos without holding broad tokens?
- How does the map stay correct without being edited by hand?
