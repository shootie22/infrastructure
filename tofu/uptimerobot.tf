# Outside checks of the public sites (docs/ha/alerting.md). UptimeRobot
# visits them every 5 minutes like a user would, so it notices when visitors
# can't get in even if everything inside thinks it's fine (like the
# 2026-10-01 outage). The free plan only does email, so alerts go to
# Pushover's email gateway (a push on the phone) and to alerts@radunenu.com.
resource "uptimerobot_alert_contact" "pushover" {
  name                    = "Pushover"
  type                    = "email"
  value                   = var.pushover_email
  notification_events     = "up_and_down"
  ssl_expiration_reminder = true
  is_active               = true
}

resource "uptimerobot_alert_contact" "email" {
  name                    = "alerts@radunenu.com"
  type                    = "email"
  value                   = "alerts@radunenu.com"
  notification_events     = "up_and_down"
  ssl_expiration_reminder = true
  is_active               = true
}

locals {
  uptime_http_monitors = {
    "radunenu.com" = "https://radunenu.com/"
    "Gitea"        = "https://git.radunenu.com/"
    "Vaultwarden"  = "https://vw.yeetus.net/alive"
    "Headscale"    = "https://hs.radunenu.com/health"
    "yeetus.net"   = "https://yeetus.net/"
    "Keycloak"     = "https://auth.radunenu.com/"
    "Element Web"  = "https://c.nuke.zip/"
  }
}

resource "uptimerobot_monitor" "http" {
  for_each = local.uptime_http_monitors

  name     = each.key
  type     = "HTTP"
  url      = each.value
  interval = 300

  assigned_alert_contacts = [
    for c in [uptimerobot_alert_contact.pushover, uptimerobot_alert_contact.email] :
    { alert_contact_id = c.id, threshold = 0, recurrence = 0 }
  ]
}

# The edge's public HTTPS port. If it's closed, failover has nowhere to go.
resource "uptimerobot_monitor" "edge" {
  name     = "Edge (HTTPS port)"
  type     = "PORT"
  url      = "edge.radunenu.com"
  port     = 443
  interval = 300

  assigned_alert_contacts = [
    for c in [uptimerobot_alert_contact.pushover, uptimerobot_alert_contact.email] :
    { alert_contact_id = c.id, threshold = 0, recurrence = 0 }
  ]
}
