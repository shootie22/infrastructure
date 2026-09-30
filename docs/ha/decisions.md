# Decisions

Newest at the bottom. Each one says what, why, and what else was on the table.

## 2026-09-30: The edge VPS runs no services

It only holds the third etcd vote, passes TCP through to Traefik, and maybe runs DERP. Putting anything stateful there would turn a cheap throwaway box into a single point of failure.

## 2026-09-30: DNS failover instead of two A records

Two A records (RO and edge) would send about half of all traffic through the edge all the time, and I'd end up paying for a faster VPS. With failover, everyday traffic goes straight to RO and the edge only carries traffic during an outage. The cost is 1-3 minutes of downtime while DNS switches.

## 2026-09-30: No Cloudflare in the traffic path

If Cloudflare goes down I still want my services to work. Cloudflare Tunnel was the easy option (free, no port forwarding, handles failover), but it only does HTTP, Cloudflare decrypts the traffic, and it's another outside dependency. Cloudflare stays as one of two DNS providers, DNS only.

## 2026-09-30: DNS lives in Git before anything else

Failover and a second provider both need the records in one place that can push to both. DNSControl, with credentials in SOPS.

## 2026-09-30: Headscale stays in the cluster

Moving it to the edge would make the edge matter. Headscale can't run more than one copy, so it stays in the cluster with its data somewhere replicated, and restarts in the other site if its site dies. How exactly is [#37](https://github.com/shootie22/infrastructure/issues/37).

## 2026-09-30: Tracking in GitHub, not a self-hosted tool

The plan involves taking the cluster down on purpose. Notes about how to bring it back can't live on the cluster. Tasks go in GitHub Issues and the board; knowledge goes in these Markdown files.
