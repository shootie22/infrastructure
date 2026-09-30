# Cold standby: the same zones at Hetzner, DNS only. The registrars point at
# Cloudflare, so nothing queries these unless we switch nameservers
# (see docs/ha/decisions.md). Everything is derived from local.dns_records.

# Apex CNAMEs only work on Cloudflare (CNAME flattening). Every apex CNAME
# here ends up at the RO site, so on Hetzner the apex gets RO's current IP,
# looked up at apply time. Refreshed on every apply until #68 takes over.
data "dns_a_record_set" "ro" {
  host = "noc-studios.go.ro"
}

locals {
  hetzner_records = flatten([
    for k, r in local.dns_records : (
      r.type == "CNAME" && r.name == "@" ? [
        for ip in data.dns_a_record_set.ro.addrs : { zone = r.zone, name = "@", type = "A", value = ip }
        ] : [{
          zone = r.zone
          name = r.name
          type = r.type
          value = (
            r.type == "CNAME" ? "${r.content}." :
            r.type == "MX" ? "${r.priority} ${r.content}." :
            r.type == "SRV" ? "${r.data.priority} ${r.data.weight} ${r.data.port} ${r.data.target}." :
            # TXT: Cloudflare keeps some values already quoted (and long DKIM keys
            # already split into 255-character strings); those are valid as is.
            # Unquoted ones get quoted, split if needed.
            r.type == "TXT" && startswith(r.content, "\"") ? r.content :
            r.type == "TXT" ? join(" ", [for c in regexall(".{1,255}", trimsuffix(trimprefix(r.content, "\""), "\"")) : "\"${c}\""]) :
            r.content
          )
      }]
    )
  ])

  hetzner_rrsets = {
    for rec in local.hetzner_records : "${rec.zone}/${rec.name}/${rec.type}" => rec...
  }
}

resource "hcloud_zone" "standby" {
  for_each = local.cloudflare_zone_ids

  name = each.key
  mode = "primary"
  ttl  = 300
}

resource "hcloud_zone_rrset" "standby" {
  for_each = local.hetzner_rrsets

  zone    = hcloud_zone.standby[each.value[0].zone].name
  name    = each.value[0].name
  type    = each.value[0].type
  ttl     = 300
  records = [for r in each.value : { value = r.value }]
}

output "hetzner_nameservers" {
  description = "Nameservers to set at the registrars if we ever switch to the standby."
  value       = { for z, zone in hcloud_zone.standby : z => zone.authoritative_nameservers.assigned }
}
