# Journal

Short dated notes: what happened, what broke, what I learned. Newest at the bottom.

## 2026-09-30: Planning

Started out wanting everything behind Keycloak, and quickly found that Keycloak running on one node on fuji would just become the thing that takes everything down. And it's not only Keycloak: fuji is the only control plane node, the cluster database is a single SQLite file on it, and Headscale runs there too.

So the SSO project waits, and HA comes first. The main thing I learned is that two sites aren't enough for automatic failover. Neither side can tell whether the other one is down or just unreachable. A cheap VPS in a third location fixes that by being the tiebreaker.

Also found that the Keycloak cert is a static one in SOPS rather than managed by cert-manager, and that alert rules exist but nothing actually sends them anywhere. Both are on the board now.
