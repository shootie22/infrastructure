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
- [2026-10-29: fuji's network card hung, sites down behind RO for about 4 minutes](2026-10-29-fuji-network-card-hang.md).
  **What went wrong:** fuji's onboard Intel network card (I219-LM, e1000e) stopped sending packets, a known fault of these chips, and the driver couldn't recover it, so fuji was cut off until it was power-cycled.
  **Fix:** fuji and the thinkcentre turn off the card's segmentation offload and power saving at boot, which avoids the known triggers, and a watchdog resets the card by itself if it hangs anyway.
- [2026-10-30: Gitea slow under a scraper on thousands of home IPs](2026-10-30-gitea-scraper-swarm.md).
  **What went wrong:** a scraper spread over about 6,500 residential IP addresses walked Gitea's most expensive pages for over an hour, on a thinkcentre already at full CPU with a CI build, so every page took seconds and some requests failed.
  **Fix:** Cloudflare challenges anonymous visitors on Gitea's expensive pages, on both names; next, Gitea itself keeps those pages for signed-in users and CI can't take all of the thinkcentre's CPU.
