# Homepage

[Homepage](https://gethomepage.dev/) provides a small, curated launcher for the
self-hosted applications that are useful day to day. It is available only on
the tailnet at <https://hub.infra.radunenu.com>.

The catalogue and appearance live in `configmap.yaml`. To add, remove, or move
a card, edit `services.yaml` inside that ConfigMap and keep the list limited to
interactive applications. Prefer an internal Kubernetes Service URL for
`siteMonitor` while retaining the normal HTTPS URL as `href`. Do not add API
credentials solely for a dashboard widget.

Kubernetes discovery is deliberately disabled in `kubernetes.yaml`. The pod
has no service account token or RBAC and does not inspect Ingresses or cluster
objects; curation happens through Git. The compact Cluster card reads node,
aggregate CPU, and aggregate memory metrics from the existing in-cluster
Prometheus service without another collector or secret.

Private DNS maps the hub hostname to Fuji's `100.64.0.1` tailnet address. HTTPS
shares the existing host-network Caddy listener in the Headlamp application,
whose certificate covers both `hl.infra.radunenu.com` and
`hub.infra.radunenu.com`. Homepage has no public Ingress or public DNS record.
