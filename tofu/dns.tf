resource "cloudflare_dns_record" "this" {
  for_each = local.dns_records

  zone_id  = local.cloudflare_zone_ids[each.value.zone]
  name     = each.value.name == "@" ? each.value.zone : "${each.value.name}.${each.value.zone}"
  type     = each.value.type
  content  = lookup(each.value, "content", null)
  data     = lookup(each.value, "data", null)
  priority = lookup(each.value, "priority", null)
  proxied  = lookup(each.value, "proxied", false)
  ttl      = lookup(each.value, "ttl", 1)
}
