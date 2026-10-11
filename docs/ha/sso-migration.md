# Moving accounts to Keycloak

The goal: one Yippie Network account for everything, and no local logins left in the apps. Nobody loses data or gets a fresh empty account. Each app's existing account gets linked to the Keycloak one, so repos, listening progress, notes and vaults stay where they are.

Matrix is not part of this; it moves through MAS as its own project.

## Before any app

These apply to every app below, so they come first.

- **Inventory.** For each app, the list of local accounts with username and email. Every person gets a Yippie Network account with the same username and email before their app moves. Linking happens by email or username, so a mismatch means a new empty account.
- **Lock email and username.** Joplin and the email matching in the other apps trust whatever email Keycloak sends. If people can change their own email on the account page, anyone could set theirs to someone else's address and be logged into that person's notes. So in network-yippie's user profile, email and username become admin-only (I change them on request). Keycloak also marks a changed email as unverified, which Vaultwarden refuses, but Joplin and Audiobookshelf don't check that.
- **Access per app in Keycloak.** Several apps create an account for anyone Keycloak lets through. Each app gets a client role `access`, a group per app grants it (`audiobooks`, `notes`, ...), and the client's login flow denies sign-in without it ("Condition - user role" + "Deny access"). The same groups decide what Home shows as Open or Ask.
- **Backups.** A fresh CNPG backup (or a copy of the data dir for the SQLite apps) right before each switch. Linking only adds a row per user, but the rollback should be one restore.
- **Order.** Easiest first: Audiobookshelf, Joplin, Vaultwarden, Gitea last. Local login stays on until every account of that app has signed in once through Keycloak, then it goes off.

## Per app

### Send (share.radunenu.com)

Already done. Uploads sit behind oauth2-proxy with group `share-uploaders`, downloads are links. Send has no accounts of its own, nothing to move.

### PrivateBin (pbin.radunenu.com)

No accounts at all. Stays public.

### Audiobookshelf (books.yeetus.net), 2.36.1

Has OpenID Connect built in, set up in its web UI (Settings, Authentication).

- "Match existing users by" email (or username) links the existing user on first SSO login. It's the same user record, so libraries, progress and bookmarks stay.
- Auto register off: only people who already have an account, plus the Keycloak gate.
- Group claim maps `admin` / `user` / `guest` groups to roles. Optional; the Keycloak gate already decides who gets in.
- The phone apps support it (redirect `audiobookshelf://oauth`).
- Turning off password login is a checkbox. Test first: if OIDC breaks after that, the way back is editing its database by hand. `?autoLaunch=0` on the login page still shows the password form while it's on.

Risk: low.

### Joplin Server (n.yeetus.net), 3.5.2

Supports SAML (not OIDC), which Keycloak does. Apps log in with "Login with SSO": the browser shows a 9-digit code you paste into the app.

- Users are matched by email only (`ssoLogin` in the server code: find by email, else create). Existing accounts keep all notes because it's the same user.
- Any email it doesn't know becomes a new account. That's why the Keycloak gate and the locked email above matter most here.
- `LOCAL_AUTH_ENABLED=false` turns off passwords once everyone has moved.
- Needs `APP_BASE_URL` and `API_BASE_URL` to be the same URL, an IdP and SP metadata file, and the SAML client in Keycloak sending `email` and `displayName`.
- Each device signs in again once. Notes are already on the device and the server, nothing gets re-downloaded from scratch. If someone uses end-to-end encryption, their E2EE password stays theirs, separate from the login.

Risk: medium, mostly the email matching. Try it on a copy of the database first.

### Vaultwarden (vw.yeetus.net), 1.37.3

SSO is built in since 1.35.

- `SSO_SIGNUPS_MATCH_EMAIL=true` (the default) links an existing user with the same, verified email on first SSO login. It stores `{issuer}/{subject}` after that, so later email changes don't matter.
- The master password stays. It's what encrypts the vault, and Keycloak never sees it. SSO replaces the email+password step, then the app still asks for the master password to unlock. Nothing about the vault data changes.
- `SSO_ONLY=true` removes the email login once everyone has linked.
- Phone apps need 2026.1.0 or newer; browser extensions and desktop work.
- Keycloak's access token for this client has to live 10 minutes or more (default is 5), and the client needs the `offline_access` scope.

Risk: low for the data (the vault can't be touched by this). The main thing is people knowing they still need their master password.

### Gitea (git.radunenu.com), 1.27.3

OpenID Connect as an auth source, added with `gitea admin auth add-oauth`. This is the one to be most careful with.

- Repos, issues, stars and keys belong to the user ID. Linking adds an external login to that same user, so nothing moves or gets renamed.
- `ACCOUNT_LINKING=login` (the default): on first SSO login Gitea asks for the old local password once and links them. Safer than `auto`, which links by matching username or email. With the inventory done, `auto` would also work.
- `USERNAME=preferred_username`, so a new account's name is the Keycloak username.
- `--admin-group` gives Gitea admin to a Keycloak group, and `--required-claim-name/value` is a second gate next to the Keycloak one. `--skip-local-2fa` for people who had Gitea 2FA.
- After everyone has linked: `ENABLE_PASSWORD_SIGNIN_FORM=false` and `ENABLE_BASIC_AUTHENTICATION=false`. SSH keys, access tokens, the CI runners, Renovate and the GitHub mirror all keep working. Pushing over HTTPS needs a token instead of the password.
- Break glass: `gitea admin user` inside the pod still works if Keycloak is down.
- Which realm: network-yippie, like everything people other than me use. My Gitea admin rights come from a group, not from network-admin.
- `UPDATE_AVATAR=true` takes the profile picture from Keycloak at each login.

Risk: medium. Do it on a copy of the database first (CNPG can clone it) and check a repo, an issue and an SSH push.

### Baïkal (cal.radunenu.com), 0.10.1

CalDAV and CardDAV clients (phones, Thunderbird, DAVx5) only do a username and password. There's no way to send them through a Keycloak login page, so OIDC is out for the sync itself. Baïkal's other option is LDAP, and Keycloak can read LDAP but not be one.

Options:
1. Keep Baïkal's own accounts. Calendars keep syncing exactly as now. Home lists it as "own password".
2. A small proxy that checks the DAV username and password against Keycloak (password grant) and passes the user to Baïkal. Same password everywhere, but it breaks for anyone with a two-step code, and the password grant is on its way out.
3. Move to a DAV server with app passwords tied to SSO (Nextcloud does this). Big change for one calendar, and every device needs setting up again.

I'd go with 1. Nothing breaks and nobody touches their phones.

### Minecraft servers

Accounts are Microsoft accounts, nothing to move. Home shows the server addresses with a copy button.

### Element / Matrix

Not now. Separate migration through MAS.

## Profile pictures

Keycloak has nowhere to keep images, only text attributes. The plan:

- A small avatars service: upload from the account page (a Change picture button, crop to a square), resized to 256 px WebP, kept in its own small Postgres (CNPG, so it's on both sites like everything else).
- It sets the user's `picture` attribute in Keycloak to the image's address, so it shows up as the standard `picture` claim. The account page, Home and Gitea (`UPDATE_AVATAR`) use it. The other apps don't read it.
- Uploads are checked with the person's own Keycloak token. Writing the attribute uses a service account that can only manage users.
