# Kubernetes monitoring

This directory is discovered by the Argo CD services ApplicationSet. It intentionally
contains no ingress and does not alter the OVH monitoring deployment.

Grafana requires a `grafana-auth` Secret created by the SOPS Secrets Operator before
it can start. Copy `grafana-secret.sops.yaml.example`, provide real values, encrypt
the `secretTemplates` field with the repository's Age recipient, then save it as
`grafana-secret.sops.yaml`. The `.example` file is not applied by Argo.

The legacy OVH FRP targets are documented in `transitional-external-targets.md` but
are deliberately not included in Prometheus until K3s connectivity is validated.
