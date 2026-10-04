# 2026-10-03: Element Web half broken for six hours

Element Web at c.nuke.zip loaded its page but failed to start, from about 06:30 to 12:25 UTC. About one request in six came back 404. No alert fired; I noticed when I tried to use it.

## Timeline (UTC)

| Time | What happened |
|---|---|
| ~06:30 | One of the two Element Web pods gets recreated and pulls the `develop` build that's current at that moment, newer than its partner's. From here on, 404s show up in Traefik's numbers. |
| 10:04-10:09 | mixi reboots. Unrelated, but I first blamed it for this. |
| ~12:15 | Noticed Element not working. The page returns 200, and so does the outside check. |
| 12:20 | Same bundle path: 200 on some requests, 404 on others. Two different builds behind one Service. |
| 12:25 | Restarted both replicas through Argo (annotation bump): one build, every file loads. |
| 12:40 | Sticky sessions and an alert for Element's 404s deployed. |

## Cause

Element Web runs two replicas of `vectorim/element-web:develop` with `imagePullPolicy: Always`. The nightly updater restarts both together when there's a new build, so normally they match. Anything else that recreates one pod (a reschedule, an eviction, a node reboot) makes it pull whatever `develop` is right then. Each build only contains its own bundles, under a hashed path. The page came from one pod, and roughly half of its files were then requested from the other, which didn't have them.

## Fix

- Traefik keeps each browser on one pod with a cookie, so the page and its files always come from the same build ([7f7f67c](https://github.com/shootie22/infrastructure/commit/7f7f67c)).
- A check loads Element like a fresh browser every 10 minutes (the page and every file), and `ElementWebBroken` fires when it hasn't passed for 30 minutes. The first version of the alert counted 404s in Traefik instead. It caught the incident, but also fired that afternoon for a single browser tab still holding the old build.

## What made it worse

- The outside check (blackbox and UptimeRobot) only asks for the page, which kept returning 200. A page that loads isn't the same as an app that works.
- Two replicas of a moving tag look like high availability, but they can quietly be two different versions of the app.

## Follow-ups

- Stateless services in both sites ([#89](https://github.com/shootie22/infrastructure/issues/89)): any replicated service on a moving tag needs sticky sessions or one pinned digest for all replicas.
