# Legacy

https://legacy.yeetus.net, one page about the old pages and APIs that came
back from the backups (#73): what each API returns, who used it, and what
the restored pages are. Only for me: it's behind the network-admin login.

The things it describes run elsewhere, in `legacy-web` and
`legacy-redirects`. This is just the page.

- `site.yaml`: the page (`index.html`) and Caddy's config. Fonts are inlined,
  so the page loads nothing from other hosts (the CSP in the Caddyfile
  enforces that).
- `deployment.yaml`: Caddy, one copy per site.
- `oauth2-proxy.yaml`, `ingress.yaml`: the login, one copy per site. Realm
  `network-admin`, client `legacy` (in `keycloak/realms.yaml`), client role
  `access`.

## Changing the page

Edit `index.html` in `site.yaml`, then bump `config-revision` in
`deployment.yaml` so the pods restart and read it. The sample responses are
real ones, cut down; the footer says when they were taken.

## First-time setup

1. `bash scripts/create-legacy-oauth2-secret.sh` (needs `sops`, no key)
   made `secret.sops.yaml` here and `keycloak/legacy-client.sops.yaml`
   with the same client secret. config-cli puts it on the client.
2. In Keycloak, realm network-admin: Users → my user → Role mapping →
   Assign role → filter by clients → `legacy` `access`. The user needs a
   verified email, or oauth2-proxy refuses the login.
3. DNS: `yeetus.net/legacy/CNAME` in `tofu/dns-records.tf`.
