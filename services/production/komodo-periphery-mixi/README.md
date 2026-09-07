# Komodo Periphery tunnel for mixi

This stack runs the public FRP server on the edge host. The matching FRP client
is managed by NixOS on `mixi` and forwards the local TLS-enabled Periphery
listener at `127.0.0.1:8120`.

- The edge address, FRP control port, and Periphery endpoint port are stored in
  the encrypted frpc environment. They are intentionally absent from Git.

The tracked `.env` files are SOPS-encrypted. On each deployment host, decrypt
only the file for that side of the tunnel:

```bash
# Edge host
scripts/decrypt-service-secrets services/production/komodo-periphery-mixi/frps
cd services/production/komodo-periphery-mixi/frps
docker compose --env-file runtime.env up -d
```

On mixi, decrypt `frpc/.env` and install the resulting environment file for the
NixOS FRP service:

```bash
scripts/decrypt-service-secrets services/production/komodo-periphery-mixi/frpc
sudo install -m 600 \
  services/production/komodo-periphery-mixi/frpc/runtime.env \
  /etc/frp-komodo-periphery.env
sudo systemctl restart frp-komodo-periphery
```
