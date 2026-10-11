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

## Who gets into which app

Keycloak lets anyone in the realm sign in to any client, and some apps create an account for whoever arrives. So every app in network-yippie gets a gate:

- a client role `access` on the app's client;
- a group per app (`audiobooks`, `notes`, `passwords`, `git`, `calendar`) that has that role, in `realms.yaml`;
- the client's browser flow overridden with a copy of Keycloak's browser flow plus a last step: if the user doesn't have the role, Deny access.

The gate also applies when someone is already signed in elsewhere (the cookie path), which a test on a Keycloak copy checked. A refused person gets the login theme's "Not yet" page with a ready mail asking for access (message key `yippieNoAccess`). Adding someone to an app is adding them to its group in the admin UI. Home uses the same groups.

The blocks for an app (here `audiobooks`, client `audiobookshelf`), in network-yippie's file:

```yaml
clients:
  - clientId: audiobookshelf
    name: Audiobooks
    # ... the app's own settings
    authenticationFlowBindingOverrides:
      browser: gate audiobookshelf
roles:
  client:
    audiobookshelf:
      - name: access
groups:
  - name: audiobooks
    clientRoles:
      audiobookshelf: [access]
authenticatorConfig:
  - alias: audiobookshelf no access
    config: {condUserRole: audiobookshelf.access, negate: "true"}
  - alias: audiobookshelf deny
    config: {denyErrorMessage: yippieNoAccess}
authenticationFlows:
  - alias: gate audiobookshelf
    providerId: basic-flow
    topLevel: true
    builtIn: false
    authenticationExecutions:
      - {flowAlias: gate audiobookshelf sign in, requirement: REQUIRED, priority: 10, autheticatorFlow: true}
      - {flowAlias: gate audiobookshelf check, requirement: CONDITIONAL, priority: 20, autheticatorFlow: true}
  - alias: gate audiobookshelf sign in
    providerId: basic-flow
    topLevel: false
    builtIn: false
    authenticationExecutions:
      - {authenticator: auth-cookie, requirement: ALTERNATIVE, priority: 10}
      - {flowAlias: gate audiobookshelf forms, requirement: ALTERNATIVE, priority: 20, autheticatorFlow: true}
  - alias: gate audiobookshelf forms
    providerId: basic-flow
    topLevel: false
    builtIn: false
    authenticationExecutions:
      - {authenticator: auth-username-password-form, requirement: REQUIRED, priority: 10}
      - {flowAlias: gate audiobookshelf 2fa, requirement: CONDITIONAL, priority: 20, autheticatorFlow: true}
  - alias: gate audiobookshelf 2fa
    providerId: basic-flow
    topLevel: false
    builtIn: false
    authenticationExecutions:
      - {authenticator: conditional-user-configured, requirement: REQUIRED, priority: 10}
      - {authenticator: auth-otp-form, requirement: ALTERNATIVE, priority: 20}
  - alias: gate audiobookshelf check
    providerId: basic-flow
    topLevel: false
    builtIn: false
    authenticationExecutions:
      - {authenticator: conditional-user-role, authenticatorConfig: audiobookshelf no access, requirement: REQUIRED, priority: 10}
      - {authenticator: deny-access-authenticator, authenticatorConfig: audiobookshelf deny, requirement: REQUIRED, priority: 20}
```

(`autheticatorFlow` is spelled that way in Keycloak's own format.) When passkeys get turned on, the 2fa flow gets the WebAuthn step too, like Keycloak's own browser flow.

## Services

| Service | Support | Plan |
|---|---|---|
| Grafana | OIDC | Done, network-admin |
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
