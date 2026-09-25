# Private DNS for `*.infra.radunenu.com`

This Argo application serves the `infra.radunenu.com` zone on Fuji's Tailscale address,
`100.64.0.1`, over UDP and TCP 53. It listens only on that address and does
not forward other DNS queries. The pod has no Kubernetes API token.

Roll this out before configuring Headscale split DNS. First check that the pod
is healthy, that Fuji permits TCP/UDP 53 on `tailscale0`, and that a tailnet
client can run `dig @100.64.0.1 hl.infra.radunenu.com A` and receive
`100.64.0.1`. Only then add
`dns.nameservers.split.infra.radunenu.com: [100.64.0.1]` to Headscale's
config and check resolution from a tailnet client without specifying the DNS server.
Do not point clients at this resolver until these checks pass: failed DNS
would affect the entire `infra.radunenu.com` suffix.

The `hl.infra.radunenu.com` DNS record currently names Fuji only. Headlamp still requires
the SSH tunnel documented in `../headlamp/README.md`; a DNS record does not
publish its Kubernetes Service. Any future HTTP route must be restricted to
the tailnet and tested for actual client source IP preservation. Similarly,
add `mon.infra.radunenu.com` or `gp.infra.radunenu.com` only after their
private HTTP endpoints exist. A browser-trusted certificate for a private
HTTPS route requires DNS-01 validation; the existing issuer uses HTTP-01.
