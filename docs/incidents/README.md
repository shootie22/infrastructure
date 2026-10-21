# Incidents

Short write-ups of outages: what happened, why, and what changed afterwards. Newest at the bottom.

Every incident gets two plain sentences, here and at the top of its write-up: **what went wrong**, and **what fixes it** (done, or being done). The fix has to stop that kind of failure, not only this one.

- [2026-10-01: All sites down for about an hour](2026-10-01-all-sites-down.md).
  **What went wrong:** fuji lost its LAN address when the early-boot DHCP lease ran out, so nothing could reach the cluster, and nothing alerted.
  **Fix:** NetworkManager always owns fuji's network with a declared profile; alerts now go to the phone, and the edge with DNS failover means one site's address is no longer the only way in.
- [2026-10-03: Element Web half broken for six hours](2026-10-03-element-web-half-broken.md).
  **What went wrong:** two replicas ran different Element builds, so the page loaded but its files 404'd, and the outside check only looked at the page.
  **Fix:** each browser sticks to one replica, and a check loads Element like a real browser every 10 minutes and alerts when it doesn't work.
- [2026-10-14: fuji cut off from the cluster, sites down behind RO](2026-10-14-fuji-cut-off.md).
  **What went wrong:** a deploy left fuji refusing all traffic to itself while its Traefik still answered, so DNS failover thought RO was fine and sites were down about 28 minutes.
  **Fix:** failover checks that a site really reaches the cluster, deploys roll out one host at a time, and a deploy that cuts a host off rolls itself back.
- [2026-10-20: thinkcentre's disk full, its services down, nothing moved](2026-10-20-thinkcentre-disk-pressure.md).
  **What went wrong:** a CI job filled the thinkcentre's disk, Kubernetes stopped running nearly everything there, and failover didn't move anything because the node still looked healthy; afterwards the databases stayed on the wrong side, which made Gitea too slow for CI until the next morning.
  **Fix:** failover now moves services off a node that's up but can't run them, the disk is watched and CI waits for room, and databases follow their apps; next, a placement controller brings everything back to its right place by itself after any failover.
