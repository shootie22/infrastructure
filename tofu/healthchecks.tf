# Dead man's switches on healthchecks.io (docs/ha/alerting.md): each one
# expects a ping every minute and alerts when they stop. Notifications go
# straight to Pushover (emergency when down, normal when up again), not
# through the relay, since the relay may be what died. The Pushover channel
# is set up once in the healthchecks.io web UI.
data "healthchecksio_channel" "pushover" {
  kind = "po"
}

locals {
  dead_mans_switches = {
    alert-relay = "The alert relay on the edge. Silence means the edge or the relay is down, and other alerts may not reach the phone."
    alertmanager = "Alertmanager's Watchdog alert, sent every minute. Silence means Prometheus or Alertmanager on fuji stopped, so in-cluster alerts would go nowhere."
  }
}

resource "healthchecksio_check" "this" {
  for_each = local.dead_mans_switches

  name     = each.key
  desc     = each.value
  timeout  = 60  # a ping every minute
  grace    = 120 # two missed pings before alerting
  channels = [data.healthchecksio_channel.pushover.id]
}

output "healthchecks_ping_urls" {
  description = "Ping URLs, one per check. Anyone with one can fake a heartbeat, so they go into SOPS, not the docs."
  value       = { for k, c in healthchecksio_check.this : k => c.ping_url }
  sensitive   = true
}
