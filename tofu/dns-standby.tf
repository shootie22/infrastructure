# Cold standby: the same zones at deSEC, DNS only. The registrars point at
# Cloudflare, so nothing queries these unless we switch nameservers
# (docs/ha/runbooks/dns-switch-to-standby.md). Everything is derived from
# local.dns_records. deSEC signs the zones with DNSSEC, which is why it
# replaced Hetzner (docs/ha/decisions.md).

# Apex CNAMEs only work on Cloudflare (CNAME flattening). Every apex CNAME
# here ends up at the RO site, so on the standby the apex gets RO's current
# IP, looked up at apply time.
data "dns_a_record_set" "ro" {
  host = "noc-studios.go.ro"
}

locals {
  standby_records = flatten([
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
            # TXT: Cloudflare keeps some values already quoted (and long DKIM
            # keys already split into 255-character strings); those are valid
            # as is. Unquoted ones get quoted, split if needed.
            r.type == "TXT" && startswith(r.content, "\"") ? r.content :
            r.type == "TXT" ? join(" ", [for c in regexall(".{1,255}", r.content) : "\"${c}\""]) :
            r.content
          )
      }]
    )
  ])

  standby_rrsets = {
    for rec in local.standby_records : "${rec.zone}/${rec.name}/${rec.type}" => rec...
  }
}

resource "desec_domain" "standby" {
  for_each = local.cloudflare_zone_ids

  name = each.key
}

resource "desec_rrset" "standby" {
  for_each = { for k, v in local.standby_rrsets : k => v if !contains(local.failover_desec_keys, k) }

  domain  = desec_domain.standby[each.value[0].zone].name
  subname = each.value[0].name == "@" ? "" : each.value[0].name
  type    = each.value[0].type
  ttl     = max(3600, desec_domain.standby[each.value[0].zone].minimum_ttl)
  records = [for r in each.value : r.value]
}

output "standby_nameservers" {
  description = "Nameservers to set at the registrars if we ever switch to the standby."
  value       = ["ns1.desec.io", "ns2.desec.org"]
}
