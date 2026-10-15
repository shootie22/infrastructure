# First deploy of yeetus.net's Matrix

What it takes to go from the merged branches to a working yeetus.net, in order. Phases 1-3 of [../README.md](../README.md). Nothing here touches nuke.zip or hetzy.

## Before merging

1. **RO router: two port forwards to fuji** for LiveKit's media: `50881/tcp` and `50882/udp`. Without them calls fail: fuji's SFU counts as ready (its readiness only checks that it runs), but nobody can reach its media. The edge opens its own ports through dotfiles.
2. **Keycloak usernames**: everyone who should get Matrix needs a Keycloak username that is a valid Matrix localpart (lowercase `a-z 0-9 . _ = - /`). MAS refuses a sign-in otherwise. Check in the admin console, realm `network-yeetus`.
3. **The signing key into Vaultwarden** (the server's identity; losing it means losing yeetus.net's Matrix identity):

   ```sh
   sops decrypt kubernetes/services/matrix/secrets.sops.yaml \
     | yq '.spec.secretTemplates[] | select(.name == "synapse-secrets") | .stringData["signing.key"]'
   ```

## Merging, in this order

1. **dotfiles `matrix-phase1`** (comin deploys it to fuji, the thinkcentre and the edge): the `matrix` site-failover service with its every-minute media copy and the database follow, and the firewall ports. On fuji, site-failover makes `/home/fuji/services/matrix` and puts the label `ha.radunenu.com/matrix=active` on fuji. Check:

   ```sh
   kubectl get nodes -L ha.radunenu.com/matrix      # fuji: active
   ls -ld /srv/ha/matrix                           # on fuji
   ```

2. **infrastructure `matrix-phase1`, then `matrix-phase2`, then `matrix-phase3`** (or all at once: each builds on the previous). Argo CD creates the namespace, the databases, Synapse, MAS, LiveKit and the routes. The Keycloak client appears within 10 minutes (config-cli's schedule).
3. **`tofu apply`** for the DNS records (matrix, account, chat, call, rtc, sfu) and the UptimeRobot monitors.

## Checks

```sh
kubectl -n matrix get pods -o wide                 # all Running; synapse on fuji, mas and lk-jwt-service one per site
kubectl -n matrix get cluster                      # synapse-db and mas-db: 2 ready instances
kubectl -n matrix get certificate                  # matrix: Ready (HTTP-01 needs the DNS records first)
curl -s https://yeetus.net/.well-known/matrix/client
curl -s https://matrix.yeetus.net/_matrix/client/versions | head -c 200
curl -s -o /dev/null -w '%{http_code}\n' https://matrix.yeetus.net/_synapse/admin/v1/server_version   # 404: not routed
curl -s -o /dev/null -w '%{http_code}\n' https://matrix.yeetus.net/_matrix/federation/v1/version      # 404: not routed
kubectl -n matrix get endpoints livekit            # exactly one address: fuji's (10.99.0.2)
```

Then, as a person:

1. Add yourself to the Keycloak group **`chat`**.
2. Open https://chat.yeetus.net, sign in: Keycloak's page, then back as `@<username>:yeetus.net`.
3. Element X: sign in with `yeetus.net` as the server.
4. Someone **not** in `chat` gets Keycloak's "no access" page.
5. A call between two people, one on mobile data.
6. Set up [the canary](canary.md).

Only after [the drills](../README.md) (Phase 4) does yeetus.net count as production.
