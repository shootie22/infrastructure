# Cubitrix reports

https://cubitrix-reports.yeetus.net is GlitchTip, a Sentry-compatible server, holding Cubitrix's crash
reports (cubitrix#312 on git.yeetus.net). The app posts a report when it crashes or freezes, if its user
said yes. Native crashes come as minidumps. Reports are deleted after 30 days. Only I can read them: the
sign-in is Keycloak's network-admin realm, and posting a report doesn't let anyone read one.

- `deployment.yaml`: GlitchTip 6, web and worker in one process (`run-all-in-one.sh`), one copy. The
  worker's periodic jobs (deleting what's past 30 days) must run once. Its queue and cache are in
  Postgres, so there's no Valkey. Its settings are in the `glitchtip-env` ConfigMap at the end.
- `setup.yaml`: run by the init container at every start, after the migrations. It does what would
  otherwise be clicked in GlitchTip's admin:
  - the Keycloak sign-in (client `cubitrix-reports`, PKCE);
  - an admin account, so nobody can sign up with a password;
  - Cubitrix's project, with the key the app is built with (`CUBITRIX_DSN_KEY`);
  - whoever has signed in with Keycloak made an owner.
- `database.yaml`: its Postgres (CloudNativePG, one instance in each site, primary in RO), and the
  hourly dump into fuji's Borg folder.
- `secret.sops.yaml`: GlitchTip's Django key, the Keycloak client secret and the admin password.
- `ingress.yaml`: all public. The apps post to `/api/<project>/envelope/` and `/api/<project>/minidump/`
  with the project's key, and everything else asks for a sign-in.
- `networkpolicy.yaml`: out to its Postgres and to Keycloak (443) only. It sends no mail.
- The client itself is in `keycloak/realms.yaml` (network-admin), with its secret in
  `keycloak/cubitrix-reports-client.sops.yaml`.

The app's DSN is `https://<CUBITRIX_DSN_KEY>@cubitrix-reports.yeetus.net/1`. The key isn't a secret: it's
in every copy of Cubitrix, and it only lets reports be posted.

## First-time setup

1. The secrets (done once, already in the repo):
   `nix shell nixpkgs#sops -c bash scripts/create-cubitrix-reports-secret.sh`.
2. DNS: `yeetus.net/cubitrix-reports/CNAME` in `tofu/dns-records.tf`.
3. Sign in at https://cubitrix-reports.yeetus.net with Keycloak. That makes the account, but not yet an
   owner. Then `kubectl -n cubitrix-reports rollout restart deploy/glitchtip`: at its start, setup makes
   the account an owner of the Cubitrix organisation.

## Reading the reports from a script

GlitchTip's API, with a token made under Profile → Auth Tokens (read-only scopes), e.g.
`curl -H "Authorization: Bearer $TOKEN" https://cubitrix-reports.yeetus.net/api/0/projects/cubitrix/cubitrix/issues/`.

## If Keycloak is down

The admin account still signs in with a password: `admin@cubitrix-reports.yeetus.net`, its password in
`secret.sops.yaml` (`ADMIN_PASSWORD`).
