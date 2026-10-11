# Keycloak SSO

Putting services behind Keycloak at `auth.radunenu.com`. This waits for Keycloak HA (Phase 5), since otherwise one pod on fuji would decide whether I can log in to anything.

Tasks are in the [Keycloak SSO milestone](https://github.com/shootie22/infrastructure/milestone/11).

## How services connect

- Native OIDC when the app supports it. Real users inside the app, and mobile and desktop clients keep working.
- oauth2-proxy with a Traefik ForwardAuth middleware for apps with no login of their own. Browser only, so it breaks API and sync clients.
- Every app keeps a local admin login as a fallback.
- Client secrets go in a `*.sops.yaml` next to the service. Grafana (`kubernetes/services/monitoring/workloads.yaml`) is already set up this way.

## Realms from Git

Clients, groups and roles are written in [`keycloak/realms.yaml`](../../kubernetes/services/keycloak/realms.yaml), and [keycloak-config-cli](https://github.com/adorsys/keycloak-config-cli) applies them every 10 minutes ([`config-cli.yaml`](../../kubernetes/services/keycloak/config-cli.yaml), #56). Only what's in the file is touched, and nothing is ever deleted: by default it deletes groups and clients it didn't make, which a test with a copy of the realms caught. So taking something out is a commit plus a click in the admin UI.

A client's secret is written as `$(env:NAME)` in the file, with `NAME` added to `keycloak/config-cli.sops.yaml` (`sops edit`).

Setting it up once, in the admin UI, realm `master`:
1. Clients, Create client: ID `config-cli`, Client authentication on, Service account roles on, Standard flow and Direct access grants off.
2. The client's Service account roles tab: Assign role, filter by realm roles, `admin`.
3. Copy the secret from the Credentials tab, then on nixpad: `nix shell nixpkgs#sops nixpkgs#yq-go -c scripts/create-keycloak-config-cli-secret.sh` and commit what it changed.

## Services

| Service | Support | Plan |
|---|---|---|
| Grafana | OIDC | Already done, move to the new realm |
| Argo CD | none | No UI exposed, only the webhook; Hub shows its state |
| Audiobookshelf | OIDC | Do it, set up in the web UI |
| Send | none | oauth2-proxy on uploads only |
| Gitea | OIDC | Do it, existing accounts get linked, not recreated |
| Rybbit | unclear | OIDC if the version supports it, else forward-auth on the dashboard |
| Homepage, picshare, pinga admin | none | Shared oauth2-proxy |
| Headscale | OIDC | Careful: existing users and nodes have to move |
| Headlamp | none | Retired: Hub shows the cluster |
| Vaultwarden | SSO | Optional, the master password still does the real work |
| Joplin, Baikal | none | Stay on local logins. Forward-auth would break sync |
| Matrix | via MAS | Separate project |

Public sites, SearXNG, Ollama, bots, runners and game servers don't need it.
