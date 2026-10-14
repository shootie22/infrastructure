# Incidents

Short write-ups of outages: what happened, why, and what changed afterwards. Newest at the bottom.

- [2026-10-01: All sites down for about an hour](2026-10-01-all-sites-down.md). fuji lost its LAN address when the initrd's DHCP lease expired.
- [2026-10-03: Element Web half broken for six hours](2026-10-03-element-web-half-broken.md). Two replicas on different develop builds; the outside check only saw the page.
- [2026-10-14: fuji cut off from the cluster, sites down behind RO](2026-10-14-fuji-cut-off.md). Open. fuji dropped off Nebula and Tailscale right after a deploy but kept answering on 443, so DNS failover never moved; sites down about 28 minutes until RO's port forwards were turned off.
