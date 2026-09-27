# Homepage

[Homepage](https://gethomepage.dev/) provides a small, curated launcher for the
self-hosted applications that are useful day to day. It is available only on
the tailnet at <https://hub.infra.radunenu.com>.

The catalogue and appearance live in `configmap.yaml`. To add, remove, or move
a card, edit `services.yaml` inside that ConfigMap. The catalogue is derived
from the active directories under `kubernetes/services/`; backend-only
workloads and duplicate host aliases remain intentionally hidden. Argo CD
deploys the updated ConfigMap after it is committed. Prefer an internal
Kubernetes Service URL for `siteMonitor` while retaining the normal HTTPS URL
as `href`. Do not add API credentials solely for a dashboard widget.

Header clocks and weather live in `widgets.yaml` inside the same ConfigMap.
They currently show Bucharest and Copenhagen using their local time zones and
Open-Meteo, which needs no API key.

Homepage renders some settings into static HTML at startup. When changing
`settings.yaml`, also change the `homepage.gethomepage.dev/config-revision`
pod-template annotation in `deployment.yaml` so Argo CD performs a rollout.

When changing deployed services, audit `kubernetes/services/` for interactive
HTTP applications. Public websites and legacy routes have their own groups;
protocol-only servers, databases, exporters, runners and other supporting
workloads remain intentionally excluded. This explicit audit keeps the hub
comprehensive without granting Homepage discovery credentials or turning it
into a workload inventory.

Kubernetes discovery is deliberately disabled in `kubernetes.yaml`. The pod
has no service account token or RBAC and does not inspect Ingresses or cluster
objects; curation happens through Git. The compact Cluster card reads node,
aggregate CPU, and aggregate memory metrics from the existing in-cluster
Prometheus service without another collector or secret.

The background image is the repository-owned
`assets/nordic-lake.webp`. Homepage loads it from the repository's raw GitHub
URL and applies its native blur, saturation, brightness and opacity filters.

Private DNS maps the hub hostname to Fuji's `100.64.0.1` tailnet address. HTTPS
shares the existing host-network Caddy listener in the Headlamp application,
whose certificate covers both `hl.infra.radunenu.com` and
`hub.infra.radunenu.com`. Homepage has no public Ingress or public DNS record.
