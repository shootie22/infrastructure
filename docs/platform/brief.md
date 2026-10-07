# Infra platform: brief

The starting point for designing the platform. Nothing gets built until the design is written down and agreed (milestone [Platform 0](https://github.com/shootie22/infrastructure/milestone/14), [#163](https://github.com/shootie22/infrastructure/issues/163)).

## What it is

One self-hosted web platform that becomes the home of the whole setup: a hub page, with modules behind it. It will be extended for years, so the core has to stay small and the modules have to plug in without touching it.

The move from Komodo to Kubernetes and HA added layers the owner can't fully picture yet: sites, front doors, Traefik, Services, pods, replicas, failover, copies. The platform is how the owner understands and trusts the setup, from the top-level overview down to one pod's log output.

## What matters most

- **Automatic, and the source of truth.** It discovers what exists and what's happening from the live systems themselves. Nothing gets added or maintained by hand. If it shows something, it's real and current; if it doesn't know, it says so. The owner has to be able to trust it.
- **Real data, real timing.** Every graphic, animation and flow shows real data points: real request rates, directions, latencies, update intervals, replication lag, copy times. Animation is there to show direction, timing and rates as they are, never decoration. Where real data isn't available, it doesn't pretend.
- **Zoom from the top to the bottom.** From the one-page overview into a site, a node, a service, a pod, down to that pod's log lines, and back out. Follow a path: where a request enters, which front door, which Traefik, which pod, which database; where data goes (copies, replication, backups, alerts). Move in, out and sideways.
- **Looks good and stays fast.** Modern, techy, a little futuristic without overdoing it. Graphs, live visuals and animations that render smoothly and don't eat CPU on the server or the browser.
- **Established tools, not reinvented ones.** UI framework, charts, graph and flow rendering, animation: well-known, maintained libraries, picked after comparing them.

The modules known so far:

- **Hub.** A one-page overview of the setup's vitals (the name is open: platform, cluster, infra): what's healthy, what's broken, what changed lately, key stats and live graphics, split into categories, and the way into every module. [Homepage](../../kubernetes/services/homepage/) does part of this today and may be replaced or absorbed.
- **Infra map** ([#53](https://github.com/shootie22/infrastructure/issues/53), [#54](https://github.com/shootie22/infrastructure/issues/54), [#52](https://github.com/shootie22/infrastructure/issues/52)). What runs where and why: DNS to site to front door to Traefik to service to pod to node, plus etcd, Postgres, site-failover and the edge. A static layer generated from Git (this repo, dotfiles, OpenTofu), a live layer from read-only Prometheus queries, a short plain-language description per component. #52 adds service-to-service traffic from Alloy/Beyla.
- **Incidents** ([#157](https://github.com/shootie22/infrastructure/issues/157)). Every alert that reaches the owner's phone, from the same sources (Alertmanager, the checkers, the scripts that send through the relay), so the two never disagree. Alerts are grouped into incidents with a timeline, kept for later reference, and readable through an API for other places to show. Should look and work like the established incident and status tools. Hand-written incident reports already live in [docs/incidents](../incidents/).
- **Deploy tool** ([#161](https://github.com/shootie22/infrastructure/issues/161), with the owner's notes in its comments). The main way to deploy services from now on, so it follows established practice and has to be resilient and trustworthy. A new service from an image and a few answers, with its HA pattern chosen (suggested from what it keeps, home site selectable), written to Git as a pull request, deployed by Argo CD and comin, followed until it's healthy. Detects ports, volumes, health checks and architectures from the image where that's reliable, asks otherwise. A web form and a CLI, same result.

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

## How it's built and shipped

- The code lives on Gitea (push-to-create is on), its CI runners build it, and the image goes to Gitea's container registry, like the other in-house services.
- It's deployed through this repo and Argo CD like everything else, with its HA pattern.

## How the design is made

1. Research, online and in both repos: existing FOSS for each module (to use, adapt or learn from, and why not), secure ways to read each data source, how the core and modules fit together, where the platform keeps its own data and how that's HA, the stack.
2. Questions to the owner as they come up, whenever something is a matter of taste or priority rather than fact: what the hub shows first and what it's called, the look, who gets access to what, what's public, how incidents are named, grouped and closed, what the deploy form asks.
3. A design document in `docs/platform/design.md`: architecture, modules, data, security, HA, the stack and why, what's left out.
4. The owner's OK.
5. Issues in the Platform 1-4 milestones, in build order.

## Questions to start from

- One app with modules, or a small set of services behind one hub?
- Which existing FOSS covers enough of a module to reuse it instead of building (an alert history store, a service catalogue, a map renderer)?
- Where does incident history live, and how long?
- How does the deploy tool get permission to open pull requests in both repos without holding broad tokens?
- How does the map stay correct without being edited by hand?
