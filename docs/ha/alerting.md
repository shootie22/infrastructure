# Alerting

How problems reach me, and why it's built this way. Decided 2026-10-01 ([decisions.md](decisions.md#2026-10-01-alerting-with-several-detectors-and-one-notification-per-event)), not built yet.

Two separate questions: who notices, and how it gets to my phone. Each has more than one answer, so one failure never silences everything.

## Who notices

| Detector | Catches | Survives the infra being down |
|---|---|---|
| Alertmanager, in the cluster | everything Prometheus sees: disks, pods, certs, the HA parts | no |
| healthchecks.io | the monitoring itself dying: Alertmanager and the relay ping it every minute, silence is the alert | yes, external |
| UptimeRobot | public sites unreachable from the internet | yes, external |
| Failover checker on the edge ([failover.md](failover.md)) | RO down, failovers | yes, off-site |
| Watchdog laptop with LTE (later) | the home internet down, everything else as a second opinion | yes, own uplink |

## How it reaches me

A small relay on the edge takes every alert and sends it once, through the first channel that accepts it:

1. **Pushover**: primary. Run by a company since 2012, 10,000 messages a month, priorities.
2. **ntfy.sh**: only if Pushover's API fails or times out. A different operator, so one outage doesn't hit both.
3. **Matrix**: only if both failed. Also where the full details go, since the other two aren't end-to-end encrypted.
4. **SMS** from the laptop's LTE stick: last resort, and for a few important events alongside the push, until that gets annoying.

The relay runs on the edge so it survives either site going down. If the relay dies, healthchecks.io notices and alerts through Pushover directly.

"Accepted by the service" is all that can be checked for normal messages. Whether it reached the phone isn't visible.

## Rules

- Grouped: one outage is one message, not twenty. Alertmanager groups, the relay rate-limits.
- Terse: no secrets or internal details in Pushover, ntfy or SMS. Details in Matrix and Grafana.
- Informational, not paging, except for a few events that use Pushover's emergency priority: it repeats until acknowledged, and if nobody acknowledges within 15 minutes the relay tries the next channel. Those are:
  - RO is down and traffic moved to the edge, or failover was needed and didn't happen
  - both sites unreachable from outside
  - a whole node down for more than 10 minutes
  - the dead man's switch fired (the monitoring itself is dead)
- Sleep wins: Critical Alerts stay off for Pushover on the iPhone, so emergency alerts respect Do Not Disturb and Sleep. They keep repeating silently (for up to an hour) and are waiting in the morning.
- As code where the services allow it: healthchecks.io checks and UptimeRobot monitors in OpenTofu, the relay and Alertmanager in the repos. One-time UI setup (notification channels, app logins) in a runbook.

## Known shared dependency

Pushover, ntfy and Matrix on the iPhone all depend on Apple's push service. It rarely fails, but the only paths around it are SMS and email.
