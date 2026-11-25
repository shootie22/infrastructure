# 2026-11-25: Synapse wouldn't start after its database moved back to fuji

**What went wrong:** Postgres logs a sequence up to 32 values ahead of what it has handed out, and a replica only ever sees the logged value, so synapse-db's two instances disagreed on some of Synapse's counters. While the primary was on the thinkcentre, Synapse recorded stream positions in that gap. When the quiet-hours move switched the primary back to fuji, fuji's lower counters were behind those positions, and Synapse refused to start: `Postgres sequence 'account_data_sequence' is inconsistent with associated stream position of 'account_data'`.

**Fix:** Synapse's pod moves any sequence that's behind its stream position up to it before Synapse starts (a `sequences` init container, `synapse.yaml`). The databases keep following Synapse between sites (decision 2026-11-25).

**Resolved.** yeetus.net was down on 25 Nov from 01:04 to 13:19 UTC, and on 24 Nov from 01:59 to 02:03 and from 02:32 to 03:46 UTC. No data was lost: the switchovers were clean, the counters only disagreed.

## Timeline (UTC)

| Time | What happened |
|---|---|
| 24 Nov 01:59 | Synapse starts while synapse-db's primary is synapse-db-1 (fuji) and fails the sequence check, again every minute. |
| 24 Nov 02:02 | The primary goes to synapse-db-2 (thinkcentre); Synapse starts at 02:03. |
| 24 Nov 02:32 | The primary goes back to synapse-db-1; Synapse is restarted and crash-loops again. |
| 24 Nov 03:46 | The primary goes to synapse-db-2; Synapse starts at 03:46 and runs for the day. |
| 25 Nov 01:00 | Quiet-hours move of Matrix home to fuji: Synapse starts there at 01:00:57 and works. |
| 25 Nov 01:03:51 | site-failover switches synapse-db's primary from synapse-db-2 to synapse-db-1 to follow it. Clean switchover (the old primary needed no rewind past its shutdown checkpoint). mas-db moved the same way at 01:01:57. |
| 25 Nov 01:04:36 | site-failover restarts Synapse after the switch (`restart-on-switch`). It fails the sequence check and crash-loops from here on. |
| 25 Nov 01:04:49 | MatrixCanaryFailing and MatrixSynapseDown page. The canary only restarts Synapse after HTTP 500s; here it got 502/503, and a restart couldn't have helped anyway. |
| 25 Nov 13:17 | Radu runs a script on fuji: read-only look at both instances, then `setval` on the two sequences that were behind, then a restart. |
| 25 Nov 13:19 | Synapse starts; the canary's next send works at about 13:21. |

What both instances showed before the fix (synapse-db-1 primary, synapse-db-2 replica), with the same `stream_positions` on both:

| | synapse-db-1 | synapse-db-2 | stream position |
|---|---|---|---|
| `account_data_sequence` | 34 (log_cnt 32) | 66 | 56 |
| `profile_updates_sequence` | 562 | | 591 |

The other streams (events, receipts, to_device, presence, device lists) were fine on synapse-db-1 too: they change often enough that their sequences had been logged again since.

## Causes

- **Sequences differ between a primary and its replica.** Postgres writes a sequence to WAL only every 32 values, with the value 32 ahead. The primary's own page has the real value; a replica replays the one 32 ahead. Both are correct for Postgres, which only promises that values are never handed out twice. A sequence that hasn't been used since (account data changes rarely) keeps the lower value on the instance that was primary when it was last used.
- **The primary moves back and forth.** After a switch to the replica, Synapse sees the higher value and records stream positions up to it. After a switch back, the old instance still has the lower value, and Synapse's startup check fails. Each failover and each quiet-hours move home is a switch, so this can come back any night the primary changes twice.
- **The restart after a switch is what hit it.** `restart-on-switch` (added after 2026-11-19) restarts Synapse right after every promotion; a running Synapse never checks again, a starting one does.
- **The canary can't help with a Synapse that doesn't start.** It only restarts on 500s, and a restart doesn't change the database.

## Follow-ups

- Synapse moves sequences that are behind up to their stream position before every start (this change). Its list of streams has to match the Synapse it runs with: `scripts/check-synapse-sequences` reads that release's source in CI and fails the pull request (a Renovate bump too) when Synapse has a stream the list doesn't.
- The Matrix databases keep following Synapse ([decision](../ha/decisions.md), 2026-11-25).
