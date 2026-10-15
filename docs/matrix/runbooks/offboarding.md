# Someone leaves yeetus.net's Matrix

Signing in goes through Keycloak, but sessions that already exist live in MAS: removing someone from Keycloak alone stops new sign-ins, not the phone that's already signed in.

1. Keycloak, realm `network-yeetus`: remove them from the group **`chat`** (or disable the user, if they're leaving everything).
2. End their Matrix sessions:

   ```sh
   kubectl -n matrix exec deploy/mas -- mas-cli manage kill-sessions \
     --config /config/config.yaml --config /secrets/secrets.yaml <username>
   ```

3. If they must never come back as the same account: lock it (and deactivate, which also removes them from rooms and can't be undone):

   ```sh
   kubectl -n matrix exec deploy/mas -- mas-cli manage lock-user \
     --config /config/config.yaml --config /secrets/secrets.yaml [--deactivate] <username>
   ```

Their messages stay in the rooms. A Matrix ID is never reused: a new person with the same Keycloak username after a deactivation can't get it back.
