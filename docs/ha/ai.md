# How AI is used here

The details behind the short note in the [README](README.md#a-note-on-ai).

Concretely:

- **Issues:** the tasks on the [board](https://github.com/users/shootie22/projects/1) are drafted by Claude from our planning sessions. I read them, change the order and scope, and close them when the work is actually done.
- **These docs:** [decisions.md](decisions.md), [journal.md](journal.md) and the runbooks start as Claude's drafts after each session. I edit or rewrite them.
- **Code and changes:** Claude writes the OpenTofu config and scripts like [porkbun-ds-sync](../../scripts/porkbun-ds-sync) and runs `tofu plan`. Nothing gets applied before I've seen what it changes. The DNS cleanup, for example, was a plan with 29 deletions that I went through first.
- **Research:** comparing options, like the DNSSEC-capable standby providers that led to deSEC.

What stays with me: the decisions (keeping Digi's dynamic DNS instead of building our own updater, deSEC over Hetzner, automatic nameserver failover), anything at the registrars, the tokens and keys, the hardware, and checking that things really work afterwards.
