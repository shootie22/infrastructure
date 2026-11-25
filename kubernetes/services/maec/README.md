# maec: Mental Asylum Entertainment Center

Radu's friends' minigame hub (repo radu/maec, which has the architecture in
`docs/architecture.md`). One container runs the hub server, one server per
game, and Caddy serving maec.yeetus.net: the site, the browser build, the
game pack and the launchers. Everything is behind the yeetus sign-in
(Keycloak client `maec`, group `maec`).

| What | Where |
|---|---|
| Site, browser game, downloads | https://maec.yeetus.net, through oauth2-proxy |
| Native game servers | UDP 24600-24615 on the node (hostPort), `maec-udp.yeetus.net` via the edge relay |
| Browser game servers | WebSockets at `/ws/<port>`, proxied inside the pod |
| Who's playing | `/status` (the updater reads it in-cluster) |

- **Image**: `git.radunenu.com/maec/maec:dev`, private (organization
  `maec`), pulled with `maec-registry` (scripts/create-maec-registry-secret.sh).
- **Updates**: fast lane. Every merge to main in radu/maec publishes `:dev`;
  `updater.yaml` restarts onto it once nobody is playing, or after 30
  minutes. Clients update themselves when they reconnect.
- **Placement**: nothing on disk; it moves with site-failover
  (`ha.radunenu.com/maec`, dotfiles).
- **Secrets**: `secret.sops.yaml` (client and cookie secrets) and
  `../keycloak/maec-client.sops.yaml` hold the same client secret
  (scripts/create-maec-secrets.sh).
- **Giving a friend access**: add them to the `maec` group in Keycloak
  (realm network-yeetus).
