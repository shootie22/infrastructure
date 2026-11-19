# Updates

How things get new versions without anyone remembering to check, while still pinning exact versions and never updating behind my back.

## Three lanes

| Lane | What | How it updates |
|---|---|---|
| NixOS hosts | flake.lock: kernel, k3s, system packages | fuji proposes a pull request on dotfiles every Saturday, with what changes per host ([#84](https://github.com/shootie22/infrastructure/issues/84)). Merging rolls it out through comin. |
| Services | container images and Helm charts in this repo: Gitea, Vaultwarden, PrivateBin, Grafana, cert-manager... | Renovate runs every night and keeps one pull request for image patches, one for rebuilds of the same version, one for the other minor and patch updates, plus a separate one for each major update and for anything labelled careful (databases, cert-manager, sops-secrets-operator, headscale, PHP), with versions and release notes. Versions stay pinned (tag plus digest) until merged; Argo rolls it out ([#108](https://github.com/shootie22/infrastructure/issues/108)). The safe ones merge themselves, see below. |
| Vulnerability scan | every image in kubernetes/ | Every morning Trivy checks every image for HIGH and CRITICAL CVEs that already have a fix (scripts/image-scan). They go into one issue labelled image-scan; a new one gets a comment, which notifies. Nothing changes by itself: the fix is the Renovate PR, or a rebuild of our own images. |
| Fast lane | things meant to be on the newest build: Element Web (develop), game servers in active development | an in-cluster updater restarts them when a new image is published. Renovate leaves these alone. |

## Pinning

A service image is written as `name:tag@sha256:digest`. The tag says which version it is (and lets Renovate find the next one and its release notes); the digest makes sure exactly that build runs, even if someone re-pushes the tag. Images pinned by digest alone, or by a moving tag like `latest` or `alpine`, can't be tracked and get converted to this form.

Digest-only is worse than unreadable. Renovate treats an image with no tag as `latest`, so its "rebuilt image" PR (#116) would actually have moved Joplin's and Gitea's Postgres from 15 and 14 to 18, and Postgres won't start on an older major's data. The same PR would have taken ClickHouse from 25.4 to 26.9, switched Baikal from nginx to apache, and put the sftp sidecar on a 2024 Debian build. Closed it and gave every image its real tag.

Exception: atmoz/sftp publishes no version tags, only `alpine` and `debian`, so it stays on `alpine@sha256:...` and its updates show up as rebuilds of that tag.

## What merges itself

Renovate merges a pull request by itself, on its nightly run, once every check on it has passed and nobody else has pushed to its branch (`automerge` in renovate.json):

- patch updates of images (the `service patches` PR), rebuilds of the same version (`rebuilt images (same versions)`) and pinning a digest, as long as the tag names a version
- patch updates and new digests of the workflows' actions (`workflow actions`)

Everything else waits for me: minor and major updates, new builds of a moving tag (`main`, `latest`, `java25`, `alpine`, which go into `rebuilt images (careful)`), Helm charts and tofu providers, and anything that holds data or that everything else depends on. That's the databases (CloudNativePG and its Postgres images, ClickHouse, Redis), Gitea and its runners, Keycloak, k3s, Argo CD, cert-manager, sops-secrets-operator, whatever is labelled careful, and the game servers, since a restart kicks the players. The NixOS side (kernel, k3s, flake.lock) is the dotfiles repo's and doesn't change.

Renovate does the merge itself instead of turning on GitHub's auto-merge (`platformAutomerge: false`). main needs an approving review, which the Renovate app can only skip as a bypass actor of the ruleset, and with a bypass GitHub's auto-merge wouldn't wait for the required checks. Renovate only merges when all of them are green.

## Game servers: dev and stable

A game in active development should update as soon as there's a new build; a game people actually play shouldn't change mid-session. That's a choice per game, made through the image tags the game's own CI publishes:

- **dev**: CI pushes `:dev` (or `:latest`) on every build. The server runs that tag in the fast lane and restarts on new builds, like Crosty does today.
- **stable**: CI also pushes a version tag (`v1.4.0`) when a build is released. The server is pinned to that version and Renovate proposes the next release like any other service.

A game can have both: a dev server for testing and a stable one for players. This needs version tags in each game's CI first ([#109](https://github.com/shootie22/infrastructure/issues/109)).

## Build machines

Building happens wherever Nix runs the build, and NixOS updates can mean compiling packages that aren't in a binary cache yet. fuji (a 4-core i3 that also runs the control plane and RO's Traefik) is the wrong place for that: the first weekly update run pushed its load to 12-13. So:

- fuji runs the weekly job (fetching, comparing, writing the report, pushing), which is light, and builds only the servers. The desktops are only evaluated there; the workstation builds them in the background (dotfiles modules/nixos/desktop-prebuild.nix), because their rustc, Electron apps and CachyOS kernel took fuji hours.
- For now, fuji's nix-daemon builds at idle CPU and IO priority with at most 2 cores, so it can't starve the cluster.
- The plan ([#111](https://github.com/shootie22/infrastructure/issues/111)): Nix remote builders over the tailnet. x86_64 builds go to the thinkcentre once it runs NixOS (and to the workstation when it's on), aarch64 builds to minima on the Mac mini, which also gives mixi and minima real build checks. fuji only builds itself when no builder is reachable.
- Build results aren't kept: the weekly garbage collection removes them.
