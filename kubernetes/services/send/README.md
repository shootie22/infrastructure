# Send

[timvisee/send](https://github.com/timvisee/send) at https://share.radunenu.com,
end-to-end encrypted file transfer. It replaces Hemmelig; one-time text secrets
live in PrivateBin.

- Uploading needs a Keycloak login with the client role `share:upload`
  (oauth2-proxy + Traefik forwardAuth, see `ingress.yaml`). Download links
  work for anyone who has them.
- Max 50 GiB per upload. The uploader picks expiry (1h to 14 days) and
  download limit (1 to 100); change the lists in `deployment.yaml`.
- Files (ciphertext only) live in `/home/main/storage/send-uploads` on
  thinkcentre, the 4 TB LUKS disk. `send-cleanup` deletes anything older
  than 14 days every hour. The folder is not backed up and must not be.
- Cloudflare: `share.radunenu.com` is DNS only (grey cloud).

## First-time setup

1. On thinkcentre, create the upload folder owned by the image's app user:

   ```sh
   sudo install -d -o 1000 -g 1000 -m 0750 /home/main/storage/send-uploads
   ```

2. In Keycloak (https://auth.radunenu.com), in the realm to log in with:
   - Clients → Create client: OpenID Connect, Client ID `share`, Client
     authentication on, only Standard flow. Valid redirect URI
     `https://share.radunenu.com/oauth2/callback`, Web origin
     `https://share.radunenu.com`.
   - Client `share` → Roles → create `upload`, then give it to each user
     who may upload (Users → Role mapping → Assign role → filter by clients).
   - Client `share` → Client scopes → `share-dedicated` → Configure a new
     mapper → Audience: Included Client Audience `share`, Add to access token
     on. oauth2-proxy rejects tokens without it.
   - Users need a verified email address, or oauth2-proxy refuses the login.

3. From the repository root, with the client secret from the client's
   Credentials tab:

   ```sh
   nix shell nixpkgs#sops -c bash scripts/create-send-oauth2-secret.sh
   ```

## Taking a file down

Download links look like `https://share.radunenu.com/download/<id>/#<key>`.
Only `<id>` is needed:

```sh
kubectl -n send exec deploy/send -c redis -- redis-cli del <id>
kubectl -n send exec deploy/send -c send -- sh -c 'rm -v /uploads/*-<id>'
```
