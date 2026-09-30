# tofu

OpenTofu for things outside the cluster. For now that's DNS: Cloudflare, plus a DNS-only standby copy at Hetzner. See [docs/ha/decisions.md](../docs/ha/decisions.md).

Run everything through the wrapper, which decrypts [secrets.sops.yaml](secrets.sops.yaml) into the environment:

```sh
scripts/tofu plan
scripts/tofu apply
```

Needs `sops`, `opentofu` and an age key that can decrypt the secrets (fuji's or the personal one).

State is encrypted with OpenTofu's state encryption and committed next to the config. Commit it after every apply.

To create the secrets file again: `scripts/create-tofu-secrets`.
