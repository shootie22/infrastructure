# Keycloak SSO

Putting services behind Keycloak at `auth.radunenu.com`. This waits for Keycloak HA (Phase 5), since otherwise one pod on fuji would decide whether I can log in to anything.

Tasks are in the [Keycloak SSO milestone](https://github.com/shootie22/infrastructure/milestone/11).

## Realms

Three of them, and every service goes in one of the two below master. The rule: if anyone besides me will ever use it, it goes in network-yippie.

| Realm | Login page says | Who logs in | What's in it | Access by |
|---|---|---|---|---|
| `master` | Keycloak Admin | me, only to manage Keycloak | the admin account, `config-cli` | nothing else, ever |
| `network-admin` | Network Admin | me | admin tools: Grafana, Hub | a role per app (`grafana-admin`) |
| `network-yippie` | Yippie Network | friends, family, my everyday account | services other people use: Send | a group per app (`share-uploaders`) |

master is Keycloak's own realm and can't be renamed or deleted. It's the key to everything else, so no app ever logs in through it. network-admin and network-yippie were called `infra` and `main` until 11 Oct.

A service's login URL is `https://auth.radunenu.com/realms/<realm>`. It goes in the Deployment as a plain value, not in the secret, so the realm a service uses is visible in Git.

## How services connect

- Native OIDC when the app supports it. Real users inside the app, and mobile and desktop clients keep working.
- oauth2-proxy with a Traefik ForwardAuth middleware for apps with no login of their own. Browser only, so it breaks API and sync clients.
- Every app keeps a local admin login as a fallback.
- Client secrets go in a `*.sops.yaml` next to the service, the login URL in the Deployment. Grafana (`kubernetes/services/monitoring/workloads.yaml`) is set up this way.

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
| Grafana | OIDC | Done, network-admin |
| Argo CD | none | No UI exposed, only the webhook; Hub shows its state |
| Audiobookshelf | OIDC | Link existing users by email, then password login off |
| Send | none | oauth2-proxy on uploads only |
| Gitea | OIDC | Existing accounts get linked, not recreated; last to move |
| Rybbit | unclear | OIDC if the version supports it, else forward-auth on the dashboard |
| Homepage, picshare, pinga admin | none | Shared oauth2-proxy |
| Headscale | OIDC | Careful: existing users and nodes have to move |
| Headlamp | none | Retired: Hub shows the cluster |
| Vaultwarden | SSO | Link by email; the master password stays and still unlocks the vault |
| Joplin | SAML | Matched by email, so emails get locked in Keycloak first |
| Baïkal | none | Stays on its own passwords: CalDAV clients only do username and password |
| Matrix | via MAS | Separate project |

Public sites, SearXNG, Ollama, bots, runners and game servers don't need it.

How each one moves without anyone losing data: [sso-migration.md](sso-migration.md).
