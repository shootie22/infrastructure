# Records the failover checkers own (docs/ha/failover.md). OpenTofu creates
# them with their normal values and then leaves their content alone, so a
# failover isn't undone by the next apply:
# - ro.radunenu.com, on Cloudflare and deSEC: noc-studios.go.ro normally,
#   edge.radunenu.com during a failover
# - element.radunenu.com, on Cloudflare and deSEC: edge.radunenu.com
#   normally, noc-studios.go.ro while the edge is down (#160)
# - the zone apexes on deSEC, which can't be CNAMEs there: RO's address
#   normally, the edge's during a failover. The checkers also keep them on
#   RO's current address when it changes.
locals {
  failover_cloudflare_keys = toset(["radunenu.com/ro/CNAME", "radunenu.com/element/CNAME"])
  failover_desec_keys = toset(concat(
    ["radunenu.com/ro/CNAME", "radunenu.com/element/CNAME"],
    [for k in keys(local.standby_rrsets) : k if endswith(k, "/@/A")],
  ))
}

resource "cloudflare_dns_record" "failover" {
  for_each = local.failover_cloudflare_keys

  zone_id = local.cloudflare_zone_ids[local.dns_records[each.key].zone]
  name    = "${local.dns_records[each.key].name}.${local.dns_records[each.key].zone}"
  type    = local.dns_records[each.key].type
  content = local.dns_records[each.key].content
  proxied = false
  ttl     = 60

  lifecycle {
    ignore_changes = [content]
  }
}

resource "desec_rrset" "failover" {
  for_each = local.failover_desec_keys

  domain  = desec_domain.standby[local.standby_rrsets[each.key][0].zone].name
  subname = local.standby_rrsets[each.key][0].name == "@" ? "" : local.standby_rrsets[each.key][0].name
  type    = local.standby_rrsets[each.key][0].type
  ttl     = max(3600, desec_domain.standby[local.standby_rrsets[each.key][0].zone].minimum_ttl)
  records = [for r in local.standby_rrsets[each.key] : r.value]

  lifecycle {
    ignore_changes = [records]
  }
}

moved {
  from = cloudflare_dns_record.this["radunenu.com/ro/CNAME"]
  to   = cloudflare_dns_record.failover["radunenu.com/ro/CNAME"]
}

moved {
  from = desec_rrset.standby["radunenu.com/ro/CNAME"]
  to   = desec_rrset.failover["radunenu.com/ro/CNAME"]
}

moved {
  from = desec_rrset.standby["byradu.com/@/A"]
  to   = desec_rrset.failover["byradu.com/@/A"]
}

moved {
  from = desec_rrset.standby["cubi.tube/@/A"]
  to   = desec_rrset.failover["cubi.tube/@/A"]
}

moved {
  from = desec_rrset.standby["cubtube.lol/@/A"]
  to   = desec_rrset.failover["cubtube.lol/@/A"]
}

moved {
  from = desec_rrset.standby["kronorite.com/@/A"]
  to   = desec_rrset.failover["kronorite.com/@/A"]
}

moved {
  from = desec_rrset.standby["radunenu.com/@/A"]
  to   = desec_rrset.failover["radunenu.com/@/A"]
}

moved {
  from = desec_rrset.standby["yeetus.net/@/A"]
  to   = desec_rrset.failover["yeetus.net/@/A"]
}
