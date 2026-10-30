# 2026-10-30: Gitea slow under a scraper on thousands of home IPs

**What went wrong:** A scraper spread over about 6,500 residential IP addresses walked Gitea's most expensive pages (compares, filtered issue lists, commits, blame) for over an hour, on a thinkcentre already at full CPU with a CI build, so every page took seconds and some requests failed.

**Fix:** Cloudflare challenges anonymous visitors on Gitea's expensive pages, on both names; next, Gitea itself keeps those pages for signed-in users and CI can't take all of the thinkcentre's CPU.

**Mitigated.** From about 20:57 UTC git.yeetus.net was slow: the front page and sign-in page took 1.7-2.2 s, the repo list 2.4 s, filtered issue lists and compares 3-12 s, some of them 500. The CI runners' `FetchTask` calls got 500s too. After the challenge rules went in (about 22:00-22:15 UTC) pages answered in 0.2-0.3 s again.

## Timeline (UTC)

Gitea logs in the thinkcentre's local time (CET, UTC+1); converted here.

| Time | What happened |
|---|---|
| 20:57 | First request from the swarm in Traefik's log, on git.radunenu.com. |
| 21:00-21:55 | Steady at 120-166 logged requests a minute (peak 21:22). Gitea logs "slow" for filtered issue lists, compares, `.diff`/`.patch`, blame and `src/commit` at 3-4 s each, some ending in 500 after 10-12 s. |
| ~21:25 | Investigation. From outside: `/` 1.7 s, `/user/login` 1.7 s, `/explore/repos` 2.4 s, `/api/v1/version` 0.2 s, static files 40 ms. |
| ~21:30 | Gitea and its Postgres primary are on the same node (thinkcentre), so not a cross-site database (the first suspicion, after the 29 Oct failover). Straight to the pod, `/api/v1/version` takes 1 s and `/user/login` 2.2 s: the thinkcentre itself. It's at 99% CPU (3995m of 4 cores), 84% memory; `ci-thinkcentre` alone uses about 2 cores. |
| later | Cloudflare "Block AI bots" turned on. No visible effect: the swarm doesn't identify itself. |
| ~22:00 | The swarm's logged requests drop from about 100 a minute to a handful. What caused the drop isn't settled (see below). |
| after | WAF custom rule `gitea-expensive-pages` (Managed Challenge) deployed in the yeetus.net zone, then in radunenu.com. Checked: compare, blame, `.patch` and filtered issue lists answer 403 (the challenge) to anonymous clients on both names; repo pages, the API and `git clone` over HTTPS still 200. `/user/login` 0.23 s, `/explore/repos` 0.21 s. |

## The traffic

From Traefik's access log, 19:48-22:14 UTC: about 8,800 requests to Gitea through Cloudflare, with the client's real address (`Cf-Connecting-Ip`) and user agent.

**The swarm, 6,643 requests:**

- **6,457 different IP addresses**; 6,330 of all addresses in the window sent exactly one request. 5,142 IPv4, 1,399 IPv6.
- **1,292 networks**, nearly all home and mobile broadband: Comcast (234), Orange FR (199), Virgin Media (196), Viettel (163), SFR (157), Sky UK (141), AT&T (120), Bouygues (109), Telefónica ES (99), Bell Canada (98) and so on. Countries: US 1,164, GB 659, FR 603, ES 577, BR 555, CA 392, VN 305, IT 300, MY 180, DE 134.
- **One user agent**, desktop Chrome on macOS (`Mac OS X 10_15_7`), with only the Chrome version changing (116 to 146). No bot name, no contact.
- **All on git.radunenu.com**, the old name, none on git.yeetus.net.
- **What it asked for:** `compare` 2,009, `issues` (label, milestone and sort combinations) 1,885, `src` 1,251, then `commit`, `commits`, `milestone`, `raw`, `archive`. Repos: radu/cubitrix 4,942, radu/megabopl3d 1,576, a few others.
- **How it went:** median 6.7 s per logged request, 90th percentile 15 s. 1,851 ended in 499 (the client gave up), 4 in 500.

One request per address from home connections all over the world is how residential proxy networks are used: someone rents exit nodes on people's devices to get around rate limits and IP blocks. Who's behind it can't be told from here. Blocking addresses or networks would do nothing.

**Crawlers that say who they are** (small, usual):

| Who | Requests | Notes |
|---|---|---|
| OpenAI OAI-SearchBot | about 300 | 52 addresses in 74.7.x.x |
| Anthropic Claude-SearchBot | 136 | 216.73.216.138, mostly `compare` |
| SemrushBot | 80 | |
| bingbot | 7 | |
| A WordPress scanner | 18 | 85.204.70.88, `wlwmanifest.xml` |
| Headless Chrome on Google Cloud | 306 | 34.7.129.126, pages with their JS chunks; maybe a preview or monitoring service |

The rest is our own: the CI runners (`gitea-runner/v3.1.0`), yeetus-api and scripts (curl, Go), the DK blackbox checks, people browsing.

**Limits of the data.** Traefik only logs requests that take over a second or end in 4xx/5xx (`traefik-config.yaml`), so the counts are a lower bound. They also can't tell whether the swarm stopped at about 22:00 or its requests just got faster than a second once the load dropped. The challenge rule for git.radunenu.com, where all of the swarm was, went in after that. Cloudflare's Security Events for the radunenu.com zone show what it challenges from then on.

## Why it hurt

1. **Anonymous visitors could ask for any compare, diff, blame or filtered list.** Each one is a git process or a heavy query. A crawler that follows every link gets an endless supply of them.
2. **The thinkcentre had no CPU left.** A CI build took half of its 4 cores, and Gitea, its Postgres primary and the rest shared what was left, so even `/api/v1/version` took a second.
3. **Nothing in front of Gitea limited this.** Cloudflare proxied everything to it, and a challenge for bots that don't say they're bots needed a rule.

## Follow-ups

- **Done 30 Oct:** WAF custom rule `gitea-expensive-pages` in both zones (Managed Challenge on `/commit/`, `/compare/`, `/blame/`, and `/issues` or `/pulls` with a query string; never `/api/`). "Block AI bots" on.
- **Rule gaps:** after 22:00 the swarm's remaining requests were all to pages the rule lets through: `src/tag`, `raw/tag`, `commits/tag`, `milestone/<n>?labels=...`, `archive/<sha>.bundle`. Add `/archive/`, and `/milestone/` with a query string.
- **In Gitea:** `GITEA__service__REQUIRE_SIGNIN_VIEW=expensive`, so these pages need a sign-in even if a challenge is passed.
- **CI's CPU:** cap `ci-thinkcentre` so a build can't starve Gitea, or run heavy builds on mixi (14% CPU at the time).
- **The rules in tofu:** both rules live only in Cloudflare's dashboard; put them next to `cache-rules.tf`.
- **Real addresses in Gitea's log:** Gitea logs Cloudflare's addresses; trust Cloudflare's ranges and read `CF-Connecting-IP` (`REVERSE_PROXY_TRUSTED_PROXIES`).
- **Separate, seen on the way:** the RO runner gets 500 from `FetchTask` on git.radunenu.com even when Gitea is fast; pulling `cubitrix-build` image blobs from Gitea's registry takes 160-210 s each; `gitea-7894f44c7-hddjm` (ContainerStatusUnknown, 18 days) is left over.
