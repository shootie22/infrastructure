# Cook

https://cook.yeetus.net is Mealie, the shared cookbook: recipes (imported from a link or typed in), with
categories and tags, meal plans and shopping lists. The sign-in is Keycloak's network-yeetus realm: anyone
in the `cook` group gets in and has an account made at their first sign-in; `cook-admin` makes a Mealie
admin. There are no passwords and no sign-up in Mealie itself.

- `deployment.yaml`: Mealie, one copy, on whichever of the thinkcentre and fuji holds the
  `ha.radunenu.com/mealie` label (site-failover, as Gitea). Recipe photos and Mealie's own backups are in
  `/srv/ha/mealie`, copied to the other site every 10 minutes. Its settings are in the `mealie-env`
  ConfigMap at the end.
- `database.yaml`: its Postgres (CloudNativePG, one instance in each site, the primary follows Mealie), and
  the hourly dump into fuji's Borg folder.
- `secret.sops.yaml`: the Keycloak client secret.
- `ingress.yaml`: all of it behind Mealie's sign-in, which goes straight to Keycloak.
- `networkpolicy.yaml`: out to its Postgres, to Ollama (11434) for the AI features, and to 80/443 for Keycloak and the recipe sites it
  imports from. It sends no mail.
- The client itself is in `keycloak/realms.yaml` (network-yeetus, gated by the `cook` group), with its
  secret in `keycloak/mealie-client.sops.yaml`. Home's tile is in `keycloak/home-catalog.yaml`.

## First-time setup

1. The secrets (done once, already in the repo):
   `nix shell nixpkgs#sops -c bash scripts/create-mealie-secret.sh`.
2. dotfiles: `mealie` in `dotfiles.siteFailover.services` on the thinkcentre (initial) and fuji, then
   rebuild both. That makes `/srv/ha/mealie` and the label; until then the pod stays Pending.
3. DNS: `yeetus.net/cook/CNAME` in `tofu/dns-records.tf`.
4. In Keycloak (network-yeetus), add people to `cook`, and yourself to `cook-admin` too.
5. Sign in at https://cook.yeetus.net. New accounts all go in the same group and household, so recipes and
   shopping lists are shared by all.
