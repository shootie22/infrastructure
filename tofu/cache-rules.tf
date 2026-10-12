# Cloudflare cache rules. Keycloak answers a missing file under /resources/
# with a 404 that says max-age=2678400, and Cloudflare kept one such 404 for
# a month after a theme rollout (yeetus #22: the resource tag doesn't change
# with the image, so for a minute one replica can serve the new page and the
# other a 404 for its files). Errors there are never cached at the edge now;
# good answers still follow Keycloak's own headers.
locals {
  # Zones with a Keycloak name: the new one and the old one, still served.
  keycloak_zones = toset(["yeetus.net", "radunenu.com"])
}

resource "cloudflare_ruleset" "cache" {
  for_each = local.keycloak_zones

  zone_id     = local.cloudflare_zone_ids[each.key]
  name        = "Cache rules"
  description = "Managed in the infrastructure repo (tofu/cache-rules.tf)"
  kind        = "zone"
  phase       = "http_request_cache_settings"

  rules = [{
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
  }]
}
