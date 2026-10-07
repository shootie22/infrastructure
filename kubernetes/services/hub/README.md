# Hub

The home of the setup: the Overview, the map, incidents and the deploy tool. The code is in the private Gitea repo `radu/infra-hub`; the design is [docs/platform/design.md](../../../docs/platform/design.md).

On the tailnet only, at <https://hub.infra.radunenu.com> (hub-new.infra.radunenu.com still works too). Login through Keycloak's `infra` realm, client `hub`, client role `admin`.

## What's here

- `deployment.yaml`, `database.yaml`, `service.yaml`, `updater.yaml`, `networkpolicy.yaml`: come with the first image (#169).
- `rbac.yaml`: read-only access to exactly the kinds Hub shows. No Secrets, ConfigMaps, logs or exec. It may only write its own lease.
- `oidc.sops.yaml`: the Keycloak client secret (`scripts/create-hub-oidc-secret.sh`).

The tailnet entry is in `headlamp/tailnet-proxy-configmap.yaml` (the tools proxy on fuji and the thinkcentre) and `tailnet-dns`.
