# Headlamp

Headlamp 0.45.0 is served at `https://hl.radunenu.com` via Traefik and
cert-manager. Ensure the DNS record for this hostname points at Traefik before
merging. The ApplicationSet will discover this directory automatically. The
Deployment is pinned to Fuji (`kubernetes.io/hostname: fuji`); it will stay
Pending rather than move to another node if Fuji is unavailable.

## Login and permissions

Headlamp requires a Kubernetes bearer token to log in. The server pod runs as
`headlamp-server`, which has no RoleBinding or ClusterRoleBinding. Never enable
`-unsafe-use-service-account-token`: it would make
every visitor use the pod's identity.

The separate `headlamp-viewer` account has the built-in cluster-wide `view`
role plus read-only access to nodes and namespaces. It cannot read Secrets or
write workloads. To get a short-lived login token, an administrator can run on
Fuji (do not paste the token into chat, logs or Git):

```sh
sudo kubectl -n headlamp create token headlamp-viewer --duration=1h
```

The browser's token login is the authorization boundary. Keycloak already
authenticates Grafana, but Headlamp OIDC would also require a Keycloak client,
callback URL, an encrypted client secret, and K3s API-server OIDC trust.
Those settings are not declared in this repository. Do not add OIDC to
Headlamp until the API-server configuration and per-user RBAC are verified.

## Rollout checks

Once DNS and Git changes are ready, check the `headlamp` Argo application is
Synced and Healthy. On Fuji, use `sudo kubectl` to check the Deployment and
pod, the Ingress, and the certificate in the `headlamp` namespace. Confirm an
anonymous browser gets the token login, then sign in with a short-lived viewer
token and inspect namespaces, nodes and workloads. Check the RBAC boundary
without printing any credentials:

```sh
sudo kubectl auth can-i list pods --all-namespaces --as=system:serviceaccount:headlamp:headlamp-viewer
sudo kubectl auth can-i list nodes --as=system:serviceaccount:headlamp:headlamp-viewer
sudo kubectl auth can-i get secrets --all-namespaces --as=system:serviceaccount:headlamp:headlamp-viewer
sudo kubectl auth can-i create deployments -n default --as=system:serviceaccount:headlamp:headlamp-viewer
sudo kubectl auth can-i create pods/exec -n default --as=system:serviceaccount:headlamp:headlamp-viewer
sudo kubectl auth can-i list pods --all-namespaces --as=system:serviceaccount:headlamp:headlamp-server
```

The first two should return `yes`, and the remaining checks should return `no`.
