# Tailnet tools proxy

This folder used to be Headlamp. Headlamp is retired now that Hub shows the
cluster, but the proxy that grew up next to it stays here, under the old
names: the folder, the `headlamp` namespace, the `headlamp-tailnet-proxy`
DaemonSet and the `headlamp-infra` certificate. Renaming them would mean a new
namespace, a new certificate and a short gap for every name below, so it
waits until there's a reason to touch it.

## What it serves

A Caddy on fuji and one on the thinkcentre (#149), each on its own node's
tailnet address, with HTTPS for:

- `hub.infra.radunenu.com` (and `hub-new`, its old name): Hub, straight to
  its pods with a sticky cookie
- `ollama.infra.radunenu.com`
- `sxng.infra.radunenu.com`

The names resolve to the tailnet addresses through `tailnet-dns` and Headscale
split DNS. Nothing here has a public Ingress or public A records. The host
forwards tailnet TCP 443 to Caddy's 8443 (dotfiles
`modules/nixos/tailnet-https.nix`). Caddy notices a changed Caddyfile or
certificate within 15 seconds and reloads itself.

## Certificate

The `headlamp-dns01` Issuer gets a browser-trusted certificate for all of the
names above with a DNS-01 challenge, so no public records are needed.
cert-manager uses a Cloudflare API token scoped to the `radunenu.com` zone
(`Zone DNS Edit` and `Zone Zone Read`), kept in an encrypted SopsSecret based
on `cloudflare-secret.sops.yaml.example`. To replace the token, run from the
repository root:

```sh
nix shell nixpkgs#sops -c bash scripts/create-headlamp-cloudflare-secret.sh
```

It asks for the token without echoing it and never writes it to disk in
plain text.

## Adding a name

Add a site block to `tailnet-proxy-configmap.yaml`, the name to
`certificate.yaml`, and the name to the `hosts` line in
`../tailnet-dns/configmap.yaml` (and bump `config-revision` in
`../tailnet-dns/deployment.yaml`, since that Corefile is only read at start).
Hub's deploy tool makes these edits itself for services it deploys.
