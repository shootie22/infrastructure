# Cloudflare cache rules. Keycloak answers a missing file under /resources/
# with a 404 that says max-age=2678400, and Cloudflare kept one such 404 for
# a month after a theme rollout (yeetus #22: the resource tag doesn't change
# with the image, so for a minute one replica can serve the new page and the
# other a 404 for its files). Errors there are never cached at the edge now;
# good answers still follow Keycloak's own headers.
locals {
  # Zones with a Keycloak name: the new one and the old one, still served.
  keycloak_zones = toset(["yeetus.net", "radunenu.com"])

  # Rules made by hand in the dashboard before this file, kept as they were.
  # A zone has one cache ruleset, so they live in the same one.
  earlier_cache_rules = {
    "yeetus.net" = [{
      description       = "websocket audiobookshelf"
      expression        = "(http.request.full_uri wildcard r\"https://books.yeetus.net/socket.io/*\")"
      action            = "set_cache_settings"
      action_parameters = { cache = false }
      enabled           = false
    }]
  }
}

# yeetus.net already had its cache ruleset (made in the dashboard in 2025),
# and a zone can't have two: tofu takes that one over.
import {
  to = cloudflare_ruleset.cache["yeetus.net"]
  id = "zones/50d92439a525c2ba9d25b5c8f673d195/d318e1c178f0413fa67315fbf13e8598"
}

resource "cloudflare_ruleset" "cache" {
  for_each = local.keycloak_zones

  zone_id     = local.cloudflare_zone_ids[each.key]
  name        = "default"
  description = "Managed in the infrastructure repo (tofu/cache-rules.tf)"
  kind        = "zone"
  phase       = "http_request_cache_settings"

  rules = concat(lookup(local.earlier_cache_rules, each.key, []), [{
    description = "Keycloak resources: never keep an error"
    expression  = "(http.host eq \"auth.${each.key}\" and starts_with(http.request.uri.path, \"/resources/\"))"
    action      = "set_cache_settings"
    action_parameters = {
      cache = true
      edge_ttl = {
        mode = "respect_origin"
        # -1 is no-store: a 4xx or 5xx is fetched again every time.
        status_code_ttl = [{
          status_code_range = { from = 400, to = 599 }
          value             = -1
        }]
      }
    }
  }])
}
