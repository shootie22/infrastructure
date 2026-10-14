# The canary's account

The canary (`kubernetes/services/matrix/canary.yaml`) sends a message to its own room once a minute and reads it back, through the public path. It needs an account, a room and a token, made once by hand. Until the `matrix-canary` Secret exists it only logs that it's waiting.

1. The account, in MAS. No password and no Keycloak link: nobody can sign in as it, only its token works.

   ```sh
   kubectl -n matrix exec deploy/mas -- mas-cli manage register-user --yes \
     --config /config/config.yaml --config /secrets/secrets.yaml \
     --display-name Canary canary
   ```

2. A token for it (a compatibility token, which doesn't expire; it is not an admin token):

   ```sh
   kubectl -n matrix exec deploy/mas -- mas-cli manage issue-compatibility-token \
     --config /config/config.yaml --config /secrets/secrets.yaml canary
   ```

   Copy the token without putting it in your shell history (paste it into the `read -s` below).

3. Its room:

   ```sh
   read -rs TOKEN
   curl -s -X POST -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
     -d '{"name":"canary","preset":"private_chat"}' \
     https://matrix.yeetus.net/_matrix/client/v3/createRoom
   # -> {"room_id":"!...:yeetus.net"}
   ```

4. The Secret, encrypted like the others (`kubernetes/services/matrix/canary.sops.yaml`), then list it in that folder's `hub.yaml` and commit:

   ```sh
   cat <<EOF | sops --encrypt --filename-override kubernetes/services/matrix/canary.sops.yaml /dev/stdin > kubernetes/services/matrix/canary.sops.yaml
   apiVersion: isindir.github.com/v1alpha3
   kind: SopsSecret
   metadata:
     name: matrix-canary
     namespace: matrix
   spec:
     secretTemplates:
       - name: matrix-canary
         stringData:
           token: "$TOKEN"
           room: "!...:yeetus.net"
   EOF
   unset TOKEN
   ```

5. Check: `kubectl -n matrix logs deploy/canary -c canary` stops saying it's waiting, and in Prometheus `matrix_canary_success` is 1.

`MatrixCanaryFailing` fires when the send-and-read-back has failed for 5 minutes. During a drill, the gap in `matrix_canary_last_success_timestamp_seconds` is the downtime users saw.
