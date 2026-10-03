# Updates

How things get new versions without anyone remembering to check, while still pinning exact versions and never updating behind my back.

## Three lanes

| Lane | What | How it updates |
|---|---|---|
| NixOS hosts | flake.lock: kernel, k3s, system packages | fuji proposes a pull request on dotfiles every Saturday, with what changes per host ([#84](https://github.com/shootie22/infrastructure/issues/84)). Merging rolls it out through comin. |
| Services | container images and Helm charts in this repo: Gitea, Vaultwarden, PrivateBin, Grafana, cert-manager... | Renovate proposes a pull request per service, weekly, with the release notes or a changelog link. Versions stay pinned (tag plus digest) until merged; Argo rolls it out ([#108](https://github.com/shootie22/infrastructure/issues/108)). |
| Fast lane | things meant to be on the newest build: Element Web (develop), game servers in active development | an in-cluster updater restarts them when a new image is published. Renovate leaves these alone. |

## Pinning

A service image is written as `name:tag@sha256:digest`. The tag says which version it is (and lets Renovate find the next one and its release notes); the digest makes sure exactly that build runs, even if someone re-pushes the tag. Images pinned by digest alone, or by a moving tag like `latest` or `alpine`, can't be tracked and get converted to this form.

## Game servers: dev and stable

A game in active development should update as soon as there's a new build; a game people actually play shouldn't change mid-session. That's a choice per game, made through the image tags the game's own CI publishes:

- **dev**: CI pushes `:dev` (or `:latest`) on every build. The server runs that tag in the fast lane and restarts on new builds, like Crosty does today.
- **stable**: CI also pushes a version tag (`v1.4.0`) when a build is released. The server is pinned to that version and Renovate proposes the next release like any other service.

A game can have both: a dev server for testing and a stable one for players. This needs version tags in each game's CI first ([#109](https://github.com/shootie22/infrastructure/issues/109)).

## Build machines

Building happens wherever Nix runs the build, and NixOS updates can mean compiling packages that aren't in a binary cache yet. fuji (a 4-core i3 that also runs the control plane and RO's Traefik) is the wrong place for that: the first weekly update run pushed its load to 12-13. So:

- fuji runs the weekly job (fetching, comparing, writing the report, pushing), which is light.
- For now, fuji's nix-daemon builds at idle CPU and IO priority with at most 2 cores, so it can't starve the cluster.
- The plan ([#111](https://github.com/shootie22/infrastructure/issues/111)): Nix remote builders over the tailnet. x86_64 builds go to the thinkcentre once it runs NixOS (and to the workstation when it's on), aarch64 builds to minima on the Mac mini, which also gives mixi and minima real build checks. fuji only builds itself when no builder is reachable.
- Build results aren't kept: the weekly garbage collection removes them.
