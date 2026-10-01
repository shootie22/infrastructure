# SaveHub deployment

Source and CI live at `git.radunenu.com/radu/savehub`. Main pushes run checks on the existing `linux-amd64-thinkcentre` runner, build the application/worker and exact-base Keycloak theme, publish commit-tagged containers to Gitea and publish one paired OCI release record. This repository’s `savehub-release.yaml` workflow polls it every five minutes and commits verified immutable digests using the built-in GitHub token. ArgoCD's existing services ApplicationSet automatically syncs main. The wave-0 Sync migration Job gates wave-2 API/worker rollout.

The source workflow is `.gitea/workflows/release.yaml`; the standalone `scripts/savehub-release.mjs` updater patches only the API/worker/migration and existing Keycloak image values. It preserves Keycloak's fuji data mount, realm defaults and other settings and refuses an unexpected base-version change. No cross-forge personal access token is required. Registry publication uses the automatic Gitea job token.

Initial resources remain `.yaml.example` until authenticated bootstrap provisions the Keycloak client, encrypted secrets, image-pull authentication if needed, host paths, DNS and backups. CI can pin candidates but never creates plaintext secrets or activates incomplete resources. From the SaveHub repository, `scripts/render-release.ts` renders non-secret YAML with a required published image digest and hostname after those checks. Seal the real secret with the existing SOPS recipients separately.

Create `/home/main/storage/savehub/{objects,uploads,scratch,inbox}` owned by 1000:1000 and `/home/main/services/savehub/postgres` owned by 999:999 on thinkcentre. Directory mounts prevent writing onto an absent archive disk. Verify actual live capacity and the host Borg/B2 script before rollout. Use DNS-only ingress for large transfers.

The Keycloak theme derives from 26.5.5. CI updates only the existing `keycloak.yaml` image field. Do not deploy a second Keycloak. The SaveHub client-level login theme leaves realm defaults unchanged.

Default-deny policies permit only DNS, PostgreSQL, Traefik and monitoring. Verify actual Keycloak DNS/hairpin routing against the cluster CNI; the worker has no internet egress. Application documentation records local verification and remaining external checks.
