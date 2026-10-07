# Hub: design

Agreed on 2026-10-07 ([#163](https://github.com/shootie22/infrastructure/issues/163)). The starting point was [brief.md](brief.md). The build is split into the Platform 1-4 milestones, one issue per step.

Hub lives at `hub.infra.radunenu.com`, on the tailnet only. Its home page is the Overview. It took over from Homepage on 8 Oct.

## Decided with me

| Topic | Decision |
|---|---|
| Access | Only me, through Keycloak's `infra` realm, one role |
| Public | Nothing of the app itself. A read-only incident API with a token, and a public status page later. Public means: INC number, title, affected public services, start and end, status, and the state changes with their times. Never alert names, hosts, addresses or notes. |
| Look | "Calm console". Dark and light, both designed properly. Local time, UTC on hover. Every page works on the phone. |
| Overview | Health verdict and open problems first, then four sections: traffic and front doors, cluster and nodes, data and copies, services and alerting |
| Incidents | Grouped by time and site or service. Closed by themselves when the sources say everything works again. Auto title I can rename, notes, an `INC-0042` id to refer to from issues. healthchecks.io and UptimeRobot included. The two existing write-ups become INC-0001 and INC-0002. |
| Map | eBPF flows on every node. A one-line description per service, kept next to it in Git. Replay of the past built in from the start. |
| Deploy tool | New services, updates, removal, and every existing service adopted. I merge (or tick auto-merge per deploy). Secrets typed in the form and encrypted before they're committed. New DNS records applied by themselves after the merge. |
| Code | Private repo on Gitea, public image in Gitea's registry. Hub updates itself through the fast lane ([updates.md](../updates.md)). |

## What I looked at first

| Part | Looked at | Outcome |
|---|---|---|
| Overview | Homepage, Glance, Homarr, Backstage | Hub reads the same `gethomepage.dev/*` annotations Homepage does, so no manifest changes. Backstage needs a catalogue file per component, written by hand, which is exactly what I don't want. |
| Map | Headlamp's map view, Coroot, Kiali, Hubble UI, Grafana's node graph | Coroot comes closest (eBPF service map, Apache-2.0). It runs its own agent and ClickHouse on every node, knows nothing about sites, front doors, failover labels or copies, and SSO is in the paid edition. Headlamp's map only follows owner references. Kiali and Hubble need Istio or Cilium. |
| Incidents | Alerta, Keep, Grafana OnCall, Dispatch, incident.io, Statuspage, OpenStatus, Gatus, Uptime Kuma | OnCall's open source version was archived in March 2026, Dispatch in 2025. Keep was bought by Elastic and is built around AI features. Alerta lists alerts but doesn't really do incidents. None of them knows what the relay did with an alert, so none can tell me whether it reached the phone. The look follows incident.io and Statuspage: a status pill, a colour per state, a timeline of updates, affected services, uptime bars. |
| Deploy | Backstage templates, Kubero, Coolify, Dokploy, Kargo, bjw-s app-template | Kubero and Coolify deploy straight to the cluster, around Git. Backstage opens pull requests from a form, but brings all of Backstage. Kargo moves releases between stages; there's one stage here. Taken from them: commit the final YAML, not just the inputs (Akuity's "rendered manifests"), and a form that changes with the template. |

## How it's put together

One Go codebase and one image (`git.radunenu.com/radu/infra-hub`), run as three Deployments that can do different things:

| Deployment | Does | Can access | Copies |
|---|---|---|---|
| `hub` | the web app, the API, discovery, snapshots, incidents, following deploys | Kubernetes read-only, its database, its Keycloak client | 2, one per site |
| `hub-writer` | writes and opens pull requests, encrypts secrets | the GitHub App key, the age public key. No Kubernetes access at all. | 2, one per site |
| `hub-public` | the public incident API, later the status page | read access to the public views in the database, nothing else | 2, one per site |

The core is small: login, sessions, config, the clients for each data source, the snapshot store, live updates to the browser, and the look. Everything else is a module: `overview`, `map`, `incidents`, `deploy`. A module is a Go package that registers its routes, background jobs, Overview tiles, map parts and database migrations, plus a folder of pages in the frontend. Adding one means adding a line to the module list, nothing in the core (the same idea as Caddy's modules).

```
infra-hub/
  cmd/hub/            one binary: serve, writer, public, and the deploy CLI
  internal/core/      login, config, database, live updates, modules, audit log
  internal/sources/   Kubernetes, Prometheus, Alertmanager, Loki, relays, checkers, DNS, Git, outside services
  internal/snapshot/  the live structure, hashed and chained
  internal/modules/   overview, map, incidents, deploy
  internal/render/    the deploy templates and their tests
  api/openapi.yaml    the API, which both the Go and the TypeScript types are generated from
  web/                the SvelteKit app, built and embedded in the binary
```

## Where the data comes from

Hub finds out what exists from the systems themselves. Nothing gets typed into it or kept up to date by hand.

| Source | How | Access |
|---|---|---|
| Kubernetes | watches, no polling: nodes, pods, workloads, Services, Ingresses, volumes, Events, CNPG clusters, Argo applications, certificates, Traefik routes | read-only role listing exactly those. No Secrets, ConfigMaps, pod logs or exec. Leases in its own namespace for picking a leader. |
| Prometheus, both sites | its own site's first, the other one if it doesn't answer (like status-api). The targets API gives each source's real scrape interval and last scrape. | only queries written into the code, never free-form ones |
| Alertmanager | active alerts, silences, config | read-only endpoints |
| Loki, both sites | log queries and live tail | logs come from Loki, so Hub needs no log permission in Kubernetes |
| Alert relays | new: each relay writes every alert it gets, and what it did with it (sent through Pushover, fell back to email, dropped as a duplicate, over the hourly cap, held back as the standby), to a journal on disk. Hub reads the journal from both relays and drops the doubles. | the relays send exactly as before. If Hub is down, it catches up from the journal later. |
| Checkers, site-failover | their existing status pages over Nebula | already read-only |
| DNS | asks Cloudflare's and deSEC's nameservers directly where each hostname points right now | nothing needed |
| Hosts | new: a dotfiles module writes each host's facts (site, mesh address, which checkers, relays and failover services it runs) from its own NixOS config as metrics, through node-exporter. Generated from the config, so it can't go out of date. | nothing new |
| Git | the commit Argo synced for each app, the commit comin deployed on each host, commit details from GitHub | read-only |
| healthchecks.io, UptimeRobot | their APIs, every minute | read-only keys |
| Pod to pod traffic | OpenTelemetry's eBPF instrumentation (OBI, which used to be Beyla) through Alloy on every node, into Prometheus ([#52](https://github.com/shootie22/infrastructure/issues/52)) | Alloy already runs on every node |

Rules for showing it:

- Every number knows where it came from: the source, the query, when it was measured and how often it updates. Hovering shows all of that.
- A value older than twice its update interval shows as stale, with the reason ("Prometheus in RO isn't answering, using DK").
- Unknown is grey and says it's unknown. It's never shown as healthy.
- A link with no rate data is dashed: connected, rate unknown.

Prometheus only gets asked about what someone is looking at, plus what the Overview and incidents need. Queries run at the source's own scrape interval and line up on its steps, so every open tab shares one result. The browser gets its updates over one server-sent events stream.

### Snapshots

Git has what should be running. A lot of what actually happens never goes through Git: which node holds a failover label, which Postgres instance is the primary, where `ro` points, which node a pod landed on, which image digest runs, restarts. So Hub keeps its own record of the live structure.

When the structure changes, Hub writes it down as a snapshot: the whole structure in a fixed form, its hash, the hash of the snapshot before it, the time, and the commits that were live (Argo's and comin's). If nothing changed, nothing is written. It works like Git commits, but for what really ran. The map at any moment in the past is the snapshot from then plus Prometheus's numbers from then.

Snapshots are kept for 15 days, as long as Prometheus keeps its data. When an incident closes, everything from its time window is copied into the incident and kept for good: the snapshots, the traffic numbers, the alerts and the important log lines. So INC-0042 can be replayed years later. The snapshots live in Postgres rather than in a Git repo: same model, but it can be searched and it's HA like everything else.

## Overview

At the top, one line: all healthy, or how many problems, with the open incidents and anything degraded right under it. Then four sections of tiles with live numbers and small graphs:

- **Traffic and front doors:** requests, errors, slow requests, which front door is in use, where `ro` points, what the checkers say
- **Cluster and nodes:** etcd's leader and members, nodes per site, CPU, memory and disk, Argo's sync state, comin's deploys
- **Data and copies:** Postgres primaries and replication lag, every standby copy with its real age and interval, failover labels, the last database dumps
- **Services and alerting:** every service with its status and link (what Homepage does today), the relays, and what changed lately in Git, Argo and the cluster

The tile order is in Hub's config, in Git, so a new tile (like a live picture of the sites) can be tried without touching the rest.

## Map

Five levels, zoomed into in place. Each has its own URL, so links and the back button work.

1. **World:** the internet, Cloudflare, the DNS providers, RO, DK and the edge. Public traffic, Nebula, etcd, copies and alerts between them.
2. **Site:** its nodes, the router, Traefik.
3. **Node:** its pods grouped by service, the host's own services (Nebula, comin, checkers, relay, site-failover), resources.
4. **Service:** its pods in both sites, its hostnames and where they point, middlewares, its database, its copies, its HA pattern, Argo's state, its description.
5. **Pod:** containers, restarts, Events, resources, and the live log with filters.

Following a path: pick a hostname or a service and its whole route lights up, hop by hop (DNS, Cloudflare, `ro`, the router, fuji's Traefik, the Service, the pod, the Postgres primary), with the live numbers of each hop. From there it's one step sideways to the replica in the other site, to the database, or to where the copies go. A time slider turns any view into a replay.

What moves on the map, and what it means:

- the number of dots on a link is the measured rate (on a log scale; the legend says how many requests one dot is)
- the direction of the dots is the real direction of the traffic
- the share of red dots is the share of errors
- periodic jobs (copies, scrapes, comin's checks, the checkers' probes) pulse at the moments they actually ran, with the measured interval next to them
- latency and replication lag are shown as numbers and as a gap on the link. How fast the dots move doesn't mean anything, and the legend says so.

With reduced motion turned on in the system, the dots stop and the numbers stay.

Descriptions come from an annotation next to each service (`hub.radunenu.com/description`), falling back to the description in the image's labels. A service without one shows that it has none.

## Incidents

Alerts come from both relays' journals, healthchecks.io and UptimeRobot, so the list matches what reached my phone.

- **Grouping:** a new alert joins an open incident if it fires within 10 minutes of that incident's last alert and shares a site or a service with it. Otherwise it starts a new one. The same alerts always give the same incidents, and each alert says why it joined.
- **States:** ongoing, recovering (some alerts resolved), resolved, closed. An incident closes 15 minutes after the last of its alerts resolved with nothing new. Resolved is checked against the live state of each source (Alertmanager's active alerts, the outside services' current status), so one lost "resolved" message can't leave an incident open forever. It can be reopened.
- **Severity:** alerts labelled `page="true"` make an incident critical.
- **Delivery:** every alert shows whether it reached the phone, and how.
- **By hand:** rename, notes, merge, split, move an alert, link the write-up in [docs/incidents](../incidents/), and post an update that also shows publicly.
- **The incident page:** timeline, affected services, alerts, delivery, and a link that opens the map at that time.
- **API:** `/api/v1/incidents`, described in OpenAPI, on the tailnet and inside the cluster. The public part goes through `hub-public` and needs a token: a Keycloak client per consumer, with the role `incidents:read`. There's an Atom feed too.

## Deploy tool

The usual GitOps way: what I asked for and the final manifests are both in Git, Argo and comin apply them, nothing is applied by hand.

1. The web form or the CLI starts with what kind of service it is (web app, API, static site, game server, bot) and only asks what fits that kind. A game server gets no login question; it gets asked for its ports and which site its players are close to.
2. The image is read without downloading its layers: which architectures it has against the nodes, exposed ports, volumes, health check, user, labels. Anything unclear is asked, never guessed.
3. The HA pattern is suggested from what the service keeps, as in [service-ha.md](../ha/service-ha.md): nothing means two copies, one per site. A Postgres database means a CNPG instance per site and the hourly dumps. Files mean site-failover with a home node and copies every 10 minutes. The home site can be changed.
4. The output is generated the same way every time, from templates with tests for every pattern: the service's folder in `kubernetes/services/` with a short `hub.yaml` (my answers) and the plain manifests, written the same way as the hand-written ones. Plus the dotfiles entries for services with files, the DNS record in `tofu/`, and secrets as `*.sops.yaml`. Hub only has the public key, so it can encrypt secrets but never read them. Passwords that only need to be random are generated.
5. The pull requests come from a GitHub App installed on these two repos only, with access to contents and pull requests, using tokens that expire after an hour. The rulesets on `main` already require a pull request from everyone except me, so the App can't push to `main`. The dotfiles PR merges first, then the infrastructure one.
6. Every PR is checked on GitHub Actions: the manifests against the Kubernetes schemas, promtool, `validate-monitoring.py`, `hub render --check` (the manifests still match `hub.yaml`) and, on dotfiles, an evaluation of every host. Hub shows the plan, the diff and the checks. I merge, or tick auto-merge for that deploy.
7. Then it follows the rollout until the service is healthy: comin deployed the dotfiles commit on the hosts; the DNS record is applied; Argo synced the merge commit; the pods are ready in the right sites; the probe passes; the name answers at both DNS providers. If something fails, it shows where it stopped and offers a revert PR. Going back is always a revert, never a kubectl command.
8. Updates and removal work the same way. Removing a service keeps its data. Deleting the data is a separate step that has to be confirmed.
9. Every existing service gets adopted: an importer reads its folder into a `hub.yaml`, and the adoption PR has to generate the same files (or show the differences for me to accept). Anything the templates can't express yet is kept as-is inside `hub.yaml`, so every service can be adopted without changing what runs. Hub points out any file in a service folder it didn't generate, and anything Argo reports as out of sync.

New DNS records get applied by a small service on fuji, set up in dotfiles like comin. It watches `main`, and when `tofu/` changes it runs a plan. It applies only if the plan contains exactly what the merged change asked for; anything else stops it and sends an alert. Then it commits the state back with a deploy key that's allowed past the ruleset. fuji can already decrypt the DNS tokens. The Gitea runners can't hold them: they run every repo's CI with the host's Docker socket, so any job could read them.

## Security

- Login through Keycloak's `infra` realm, the usual code flow with PKCE, role `hub:admin`. Sessions are stored server side; cookies are HttpOnly, Secure and SameSite, and every change needs a CSRF token. The CLI logs in with the device flow (a code to confirm in the browser).
- Read-only everywhere. The only way Hub changes anything is a pull request. No restart or scale buttons.
- `hub-writer` takes requests only from `hub`'s pods, and only with my login token, which it checks itself. Every change is logged: who, what, which PR.
- `hub-public` can read the public views and nothing else.
- No scripts from other sites; fonts and icons are served by Hub itself.
- Network policies let each Deployment reach only what it uses. Only the writer can reach GitHub.
- This repo is public, so docs and code describe things in general terms. Anything sensitive goes in the private repo.

## HA

- `hub` runs one copy per site and both serve. Background work (reading the journals, snapshots, grouping incidents, following deploys) runs on one copy at a time, chosen with a Kubernetes lease. The other one takes over within about 15 seconds. All of it can safely run twice, and it keeps its place in the database.
- The database is CNPG with an instance per site and the hourly dump to fuji, picked up by Borg, the same as the other services. While CNPG switches primaries (about a minute and a half) the live views keep working, because they don't use the database. Incident ingest waits and then catches up from the relay journals, so nothing is lost.
- Each copy uses its own site's Prometheus and Loki, and the other site's when they don't answer.
- On the tailnet, the tools proxy on fuji and the thinkcentre serve it as they do now. One change: the tailnet DNS answers with both addresses, so a browser can switch to the other one in seconds instead of waiting for a cached answer to expire.
- New builds come through the fast lane. CI runs the tests and a smoke test before publishing, and a rolling update stops at a copy that doesn't get ready. Traefik keeps a browser on one copy, and the page reloads by itself when the server's build changes, so two builds can't mix (INC-0002).
- Alerts never depend on Hub. The relays deliver on their own.

## Look

"Calm console": a dark slate background, thin lines, one cyan accent, monospaced numbers, Inter and JetBrains Mono served by Hub. Colours for status only: red for broken, amber for degraded, green for healthy, grey for unknown. Dark and light come from the same colour tokens and both get tested. Things only move when the data does. On a phone, the map becomes a list you tap through with the same five levels, and the graph itself can be pinch-zoomed.

## The stack

| Part | Choice | Instead of | Why |
|---|---|---|---|
| Backend | Go, standard library HTTP server | Python, Node, Rust | One small binary, low CPU and memory. The Kubernetes, Prometheus, OIDC, GitHub and registry libraries are first-party or the standard ones. |
| Database | Postgres on CNPG; pgx, sqlc, goose | an ORM | The HA pattern that's already here. Queries are checked at build time; migrations are in the binary. |
| Login | go-oidc, x/oauth2 | oauth2-proxy in front | Needs roles in the app, the device flow for the CLI and tokens for the API |
| API | OpenAPI, Go types from oapi-codegen, TypeScript types from openapi-typescript | writing the types twice | One description for the web app, the CLI and anyone else reading it |
| Live updates | server-sent events | WebSockets | Only goes one way anyway, reconnects by itself, plain HTTP through Traefik |
| Frontend | Svelte 5 and SvelteKit, built to static files | React, Solid, Vue | Small bundles, updates only what changed (which matters with numbers changing every few seconds), animations built in. Svelte Flow is made by the same people as React Flow. React Flow is the more mature one, but React redraws more for live data. Solid has no version of it. |
| Map | Svelte Flow, ELK.js for the layout (in a Web Worker), one canvas for the moving dots | Cytoscape.js, Sigma.js, PixiJS, G6 | The map is small (around 300 things) but needs readable cards, nested groups and pan and zoom, which Svelte Flow has. ELK always lays out the same structure the same way. The dots go on a canvas because animated SVG lines are where Svelte Flow gets slow. Sigma and Pixi only pull ahead at thousands of nodes. |
| Charts | uPlot (about 50 KB, no dependencies), small SVG pieces | ECharts, Chart.js | Live charts for a fraction of the CPU: in uPlot's published comparison, 10% against 40-70% |
| UI parts | Bits UI (accessible, unstyled), Lucide icons, plain CSS | Tailwind, component libraries | Few dependencies, and the look stays ours |
| Reading images | go-containerregistry | pulling the image | Gets the config and architectures without the layers |
| Build | Gitea Actions on the thinkcentre (amd64) and mixi (arm64), one multi-arch tag, like steamhappy | | The runners and registry I already have. Renovate on Gitea keeps Hub's own dependencies current. |

Limits to check at every milestone: `hub` under 50m CPU and 150 MiB of memory when idle; the Overview under 2% of one laptop core, the map with moving flows under 10%.

## Left out

- Changing the cluster in any way other than a pull request. Hub never gets write access to Kubernetes.
- Storing metrics or logs. Prometheus and Loki do that.
- Sending notifications or on-call schedules. The relays send.
- More users and roles. One role for now; adding more later is small.
- Cloudflare's analytics. It would need another token. Maybe later.
- Matrix and nuke.zip, which come after this.

## Build order

The issues are in the milestones, in this order.

- **[Platform 1: Core](https://github.com/shootie22/infrastructure/milestone/15):** the repo and CI, login and the app shell, the data sources, host facts, snapshots, running it in the cluster, the Overview (and Homepage's retirement). #164-#170.
- **[Platform 2: Infra map](https://github.com/shootie22/infrastructure/milestone/16):** eBPF flows, the list of every real link and its metrics, a renderer test against the CPU limits, the five levels and following paths, live logs, replay, descriptions. #52, #171-#176.
- **[Platform 3: Incidents](https://github.com/shootie22/infrastructure/milestone/17):** the relay journals, ingest, grouping and closing, the incident pages, the API and `hub-public`, later the public status page. #177-#182.
- **[Platform 4: Deploy tool](https://github.com/shootie22/infrastructure/milestone/18):** templates, reading images, PR checks and rulesets, the GitHub App and the writer, form and CLI, following deploys, the DNS applier on fuji, updates and removal, adopting every existing service. #183-#191.
