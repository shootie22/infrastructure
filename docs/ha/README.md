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

Tasks live in issues. Knowledge lives here. Problems found along the way get an issue with the `problem` label.

## Status

Phase 0 (DNS) nearly done. All DNS except nuke.zip is in OpenTofu, with a deSEC standby, every domain except kronorite.com runs multi-signer DNSSEC, and `ro.radunenu.com` is the one record failover will change. Left: kronorite.com ([#76](https://github.com/shootie22/infrastructure/issues/76)) and optional CI ([#8](https://github.com/shootie22/infrastructure/issues/8)).

## A note on AI

I use AI (Claude) on this project, and here's concretely what that looks like:

- **Issues:** the tasks on the [board](https://github.com/users/shootie22/projects/1) are drafted by Claude from our planning sessions. I read them, change the order and scope, and close them when the work is actually done.
- **These docs:** [decisions.md](decisions.md), [journal.md](journal.md) and the runbooks start as Claude's drafts after each session. I edit or rewrite them.
- **Code and changes:** Claude writes the OpenTofu config and scripts like [porkbun-ds-sync](../../scripts/porkbun-ds-sync) and runs `tofu plan`. Nothing gets applied before I've seen what it changes. The DNS cleanup, for example, was a plan with 29 deletions that I went through first.
- **Research:** comparing options, like the DNSSEC-capable standby providers that led to deSEC.

What stays with me: the decisions (keeping Digi's dynamic DNS instead of building our own updater, deSEC over Hetzner, automatic nameserver failover), anything at the registrars, the tokens and keys, the hardware, and checking that things really work afterwards.
