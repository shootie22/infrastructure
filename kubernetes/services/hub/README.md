# Hub

The home of the setup: the Overview, the map, incidents and the deploy tool. The code is in the private Gitea repo `radu/infra-hub`; the design is [docs/design.md](https://git.radunenu.com/radu/infra-hub/src/branch/main/docs/design.md) there.

On the tailnet only, at <https://hub.infra.radunenu.com> (hub-new.infra.radunenu.com still works too). Login through Keycloak's `infra` realm, client `hub`, client role `admin`.

## What's here

- `deployment.yaml`, `database.yaml`, `service.yaml`, `updater.yaml`, `networkpolicy.yaml`: come with the first image (infra-hub #28).
- `rbac.yaml`: read-only access to exactly the kinds Hub shows. No Secrets, ConfigMaps, logs or exec. It may only write its own lease.
- `oidc.sops.yaml`: the Keycloak client secret (`scripts/create-hub-oidc-secret.sh`).
- `public.yaml`, `public-db.sops.yaml`: hub-public, the incident API on the internet (infra-hub #40), with a database role that reads two views only. On the internet at https://status.radunenu.com/api/v1/incidents.
- `writer.yaml`: hub-writer, which opens the deploy tool's pull requests as the GitHub App (infra-hub #45). The App's id and key are in `writer-app.sops.yaml` (`scripts/create-hub-writer-app.sh <app id> <key.pem>`).

The tailnet entry is in `headlamp/tailnet-proxy-configmap.yaml` (the tools proxy on fuji and the thinkcentre) and `tailnet-dns`.
