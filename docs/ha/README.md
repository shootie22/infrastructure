# High availability

I want my services to stay up when a server or a whole site goes down. Right now almost everything depends on fuji: it's the only control plane node, it holds the cluster database, and Headscale runs on it.

The goal is no single point of failure among my machines. Losing fuji, the RO site, the DK site or the edge VPS should not take services down. Keycloak is the first service to get there, and it becomes the template for the rest.

I'm also trying to keep VPS costs low. The only VPS in this plan is a cheap edge (around 5 €/month) that mostly sits idle.

## Where things are

- [Board](https://github.com/users/shootie22/projects/1): every task, one issue per step
- [Milestones](https://github.com/shootie22/infrastructure/milestones): one per phase
- [plan.md](plan.md): the layout and what each phase does
- [decisions.md](decisions.md): what was decided and why
- [journal.md](journal.md): notes and learnings as it goes
- [runbooks/](runbooks/): procedures, written as they get tested
- [keycloak-sso.md](keycloak-sso.md): the follow-up project, putting services behind Keycloak
- [ideas.md](ideas.md): improvements that might be worth doing later, not part of the plan

Tasks live in issues. Knowledge lives here. Problems found along the way get an issue with the `problem` label.

## Status

Phases 0 to 4 done: DNS, the edge, the thinkcentre on NixOS (Debian still there as a fallback until Phase 7), etcd across fuji, the thinkcentre and the edge over Nebula, and replicated Postgres. Phase 4b is underway: the services move onto Postgres in both sites and their files get copied to the other site. Next: Phase 6, starting the standbys when a site is gone. The OVH VPS is the edge until the swap to a cheaper one in February ([#80](https://github.com/shootie22/infrastructure/issues/80)).

## A note on AI

I use AI (Claude) to speed things up. For example, it drafts the issues on the board and the first version of these docs, which I then edit. The decisions and the hands-on work are mine. More detail in [ai.md](ai.md).
