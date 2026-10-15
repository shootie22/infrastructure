# Network Updates

Everyone on yeetus.net has a room with **Network Updates** (`@updates:yeetus.net`), Synapse's [server notices](https://element-hq.github.io/synapse/latest/server_notices.html). Element pins it as System Alerts. It's read-only, joined without an invite, and it's where news about the server goes: planned maintenance, upgrades, outages. Like Discord's system messages.

`kubernetes/services/matrix/updates.yaml` has all of it:

- **A welcome.** Every 5 minutes the `network-updates` CronJob welcomes accounts that have never had a notices room, so everyone has one within minutes of their first login. Someone who leaves the room isn't welcomed again.
- **Upgrade notices.** The same job announces a new Synapse version once, to everyone, with a link to the release notes. The first run only records the version.
- **Broadcasts by hand**, see below.

The texts are `welcome.txt` and `upgrade.txt` in the `network-updates` ConfigMap; edit them there. The bots (`@canary`, `@updates-admin`) get nothing (`NOTICES_SKIP`).

## Sending a notice

From a server with kubectl:

```sh
kubectl -n matrix exec deploy/synapse -c synapse -- \
  python /network-updates/updates.py send "Planned maintenance tonight 22:00-22:15 (UTC+2): calls may drop once."
```

Only to some people: put their addresses after the text (`... send "Text" @someone:yeetus.net`). It prints each person it reached, and exits non-zero if any send failed.

When to send one:

- planned maintenance or a move on purpose ([moving-matrix.md](moving-matrix.md)), a few hours before;
- an outage that lasted more than a few minutes, once it's over, saying what happened;
- anything users have to do themselves.

Upgrades announce themselves.

## Setup: the admin account (once)

Server notices are sent through Synapse's admin API, which with MAS takes a MAS-issued token that carries admin rights. The job and the Synapse pod use the `updates-admin` account's token. Until the `matrix-admin-token` Secret exists the job only logs that it's waiting.

1. The account, in MAS. No password and no Keycloak link: nobody can sign in as it, only its token works.

   ```sh
   kubectl -n matrix exec deploy/mas -- mas-cli manage register-user --yes \
     --config /config/config.yaml --config /secrets/secrets.yaml \
     --display-name "Network Updates admin" updates-admin
   ```

2. An admin token for it (a compatibility token, which doesn't expire):

   ```sh
   kubectl -n matrix exec deploy/mas -- mas-cli manage issue-compatibility-token \
     --config /config/config.yaml --config /secrets/secrets.yaml \
     --yes-i-want-to-grant-synapse-admin-privileges updates-admin
   ```

   It is a full admin token for Synapse: keep it only in the Secret. Copy it without putting it in your shell history (paste it into the `read -s` below).

3. The Secret, encrypted like the others, on the workstation in this repo:

   ```sh
   read -rs TOKEN
   cat <<EOF | sops --encrypt --filename-override kubernetes/services/matrix/admin-token.sops.yaml /dev/stdin > kubernetes/services/matrix/admin-token.sops.yaml
   apiVersion: isindir.github.com/v1alpha3
   kind: SopsSecret
   metadata:
     name: matrix-admin-token
     namespace: matrix
   spec:
     secretTemplates:
       - name: matrix-admin-token
         stringData:
           token: "$TOKEN"
   EOF
   unset TOKEN
   ```

   Add `admin-token.sops.yaml` to that folder's `hub.yaml`, commit, merge.

4. Check, within 5 minutes of Argo applying it: you have a Network Updates room with the welcome, and

   ```sh
   kubectl -n matrix logs job/$(kubectl -n matrix get jobs -o name | grep network-updates | tail -1 | cut -d/ -f2)
   ```

   says who it welcomed.

To replace the token: `mas-cli manage kill-sessions updates-admin` (in the MAS pod, like above) ends the old one, then steps 2 and 3 again.

## When it goes wrong

`CronJobFailed` fires when the job's last run failed for 15 minutes. Its log says why; the usual ones are Synapse being down (it tries again in 5 minutes) and a token that no longer works (401: replace it as above).
