# Homepage

[Homepage](https://gethomepage.dev/) provides a small, curated launcher for the
self-hosted applications that are useful day to day. It is available only on
the tailnet at <https://hub.infra.radunenu.com>.

HTTP discovery is opt-in, not fully automatic: a new application appears only
after its Kubernetes Ingress has these annotations:

```yaml
gethomepage.dev/enabled: "true"
gethomepage.dev/external: "true"
```

`external: "true"` prevents Homepage from looking up Pods, keeping its access
limited to reading Ingresses. Add the optional group, name, icon, description,
weight, and internal `siteMonitor` annotations to produce a polished card.
Removing the Ingress removes the discovered card.

`services.yaml` in `configmap.yaml` contains only entries that cannot be
discovered from an Ingress, including the cluster summary, private Headlamp
route, legacy multi-host routes, and protocol-only game servers. Do not add API
credentials solely for a dashboard widget.

Header clocks and weather live in `widgets.yaml` inside the same ConfigMap.
They currently show Bucharest and Copenhagen using their local time zones and
Open-Meteo, which needs no API key.

Homepage renders some settings into static HTML at startup. When changing
`settings.yaml`, also change the `homepage.gethomepage.dev/config-revision`
pod-template annotation in `deployment.yaml` so Argo CD performs a rollout.

Discovery uses a dedicated service account with an explicitly projected,
hour-long rotating token. Its ClusterRole permits only `get` and `list` on
Ingresses. It cannot read Secrets, ConfigMaps, Services, Pods, Nodes, logs, or
metrics and cannot modify any Kubernetes object. Traefik CRD and Gateway API
discovery are disabled.

Backend-only workloads, duplicate host aliases, runners, databases, and
supporting components stay hidden because discovery is opt-in. The cluster and
node cards read aggregate and per-node health from the existing in-cluster
Prometheus service without additional Kubernetes permissions, collectors, or
secrets.

The background image is the repository-owned
`assets/nordic-lake.webp`. Homepage loads it from the repository's raw GitHub
URL and applies its native blur, saturation, brightness and opacity filters.

Private DNS maps the hub hostname to Fuji's `100.64.0.1` tailnet address. HTTPS
shares the existing host-network Caddy listener in the Headlamp application,
whose certificate covers both `hl.infra.radunenu.com` and
`hub.infra.radunenu.com`. Homepage has no public Ingress or public DNS record.
