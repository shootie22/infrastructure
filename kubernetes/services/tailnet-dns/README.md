# Private DNS for `*.infra.radunenu.com`

This Argo application serves the `infra.radunenu.com` zone on Fuji's Tailscale address,
`100.64.0.1`, over UDP and TCP 53. It listens only on that address and does
not forward other DNS queries. The pod has no Kubernetes API token.

Roll this out before configuring Headscale split DNS. First check that the pod
is healthy, that Fuji permits TCP/UDP 53 on `tailscale0`, and that a tailnet
client can run `dig @100.64.0.1 hub.infra.radunenu.com A` and receive
`100.64.0.1`. Only then add
`dns.nameservers.split.infra.radunenu.com: [100.64.0.1]` to Headscale's
config and check resolution from a tailnet client without specifying the DNS server.
The Headscale Deployment must restart after a ConfigMap change to load this
setting. Its pod-template `config-revision` annotation triggers that rollout.
Do not point clients at this resolver until these checks pass: failed DNS
would affect the entire `infra.radunenu.com` suffix.

These records name tailnet addresses only. Their private HTTPS routes go
through the tools proxy in `../headlamp` (the folder keeps Headlamp's name;
Headlamp itself is retired), and none of them is published through a public
Ingress. Browser-trusted certificates for these private routes
use DNS-01 validation and do not require public A or AAAA records.
