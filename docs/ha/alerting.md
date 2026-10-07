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

## How it reaches me

A small relay on the edge takes every alert and sends it once, through the first channel that accepts it:

1. **Pushover**: primary. Run by a company since 2012, 10,000 messages a month, priorities.
2. **Email** to alerts@radunenu.com: only if Pushover's API fails or times out. The edge delivers straight to Mailfence's mail servers without a login; radunenu.com's SPF record allows the edge to send. A different path from Pushover, and it leaves a written record.
3. **Matrix**: only if both failed. Also where the full details go, since the other two aren't end-to-end encrypted.
4. **SMS**: only if the optional LTE laptop gets built (below).

The relay runs on the edge so it survives either site going down. If the relay dies, healthchecks.io notices and alerts through Pushover directly.

mixi runs a standby copy of the relay ([#156](https://github.com/shootie22/infrastructure/issues/156)). Alertmanager and the failover checkers send to both, and the standby only passes an alert on while the edge's relay doesn't answer its health check, so nothing arrives twice. Found missing in the edge drill: with the edge off, Prometheus's alerts went nowhere until it was back. Tested 2026-10-07: with the edge's relay up the standby stayed quiet, with it stopped the standby delivered.

"Accepted by the service" is all that can be checked for normal messages. Whether it reached the phone isn't visible.

## Rules

- Grouped: one outage is one message, not twenty. Alertmanager groups, the relay rate-limits.
- Terse: no secrets or internal details in Pushover, email or SMS. Details in Matrix and Grafana.
- Informational, not paging, except for a few events that use Pushover's emergency priority: it repeats until acknowledged, and if nobody acknowledges within 15 minutes the relay tries the next channel. Those are:
  - RO is down and traffic moved to the edge, or failover was needed and didn't happen
  - both sites unreachable from outside
  - a whole node down for more than 10 minutes
  - the dead man's switch fired (the monitoring itself is dead)
- Sleep wins: Critical Alerts stay off for Pushover on the iPhone, so emergency alerts respect Do Not Disturb and Sleep. They keep repeating silently (for up to an hour) and are waiting in the morning.
- As code where the services allow it: healthchecks.io checks and UptimeRobot monitors in OpenTofu, the relay and Alertmanager in the repos. One-time UI setup (notification channels, app logins) in a runbook.

## Known shared dependency

Pushover and Matrix on the iPhone depend on Apple's push service. It rarely fails; email and SMS don't depend on it.

## The LTE laptop is optional

healthchecks.io and UptimeRobot already notice "everything at home is down" from outside, so the old laptop with its own LTE uplink isn't needed for alerting. What it would still add: telling apart why RO is down, SMS as a path that doesn't depend on Apple's push service, and above all a way into the LAN when the home internet is out (power-cycling through the smart plugs, unlocking fuji's disk after a power cut). That's out-of-band access, kept as an optional project ([#101](https://github.com/shootie22/infrastructure/issues/101)).
