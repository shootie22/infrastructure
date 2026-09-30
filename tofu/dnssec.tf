# Multi-signer DNSSEC (RFC 8901, model 2): Cloudflare and deSEC each sign with
# their own keys and each publishes the other's, so the standby can take over
# without breaking DNSSEC. Both DS records sit at the registrar.
# Rolled out one zone at a time (#74, #75).
locals {
  multi_signer_zones = toset(["cubi.tube", "byradu.com", "cubtube.lol"])
}

resource "cloudflare_zone_dnssec" "this" {
  for_each = local.multi_signer_zones

  zone_id             = local.cloudflare_zone_ids[each.key]
  status              = "active"
  dnssec_multi_signer = true

  # Cloudflare reports "pending" until the DS record is at the registrar.
  # Re-sending "active" would be a pointless change on every apply.
  lifecycle {
    ignore_changes = [status]
  }
}

# Cloudflare's zone-signing key per zone, as published at Cloudflare's
# nameservers once multi-signer is on (dig DNSKEY <zone> @nola.ns.cloudflare.com,
# the flags 256 one). deSEC has to publish it too. A new zone gets its entry
# after the first apply, once Cloudflare has generated the key.
locals {
  cloudflare_zsk = {
    "cubi.tube"   = "256 3 13 oJMRESz5E4gYzS/q6XDrvU1qMPYIjCWzJaOau8XNEZeqCYKD5ar0IRd8KqXXFJkqmVfRvMGPmM1x8fGAa2XhSA=="
    "byradu.com"  = "256 3 13 oJMRESz5E4gYzS/q6XDrvU1qMPYIjCWzJaOau8XNEZeqCYKD5ar0IRd8KqXXFJkqmVfRvMGPmM1x8fGAa2XhSA=="
    "cubtube.lol" = "256 3 13 oJMRESz5E4gYzS/q6XDrvU1qMPYIjCWzJaOau8XNEZeqCYKD5ar0IRd8KqXXFJkqmVfRvMGPmM1x8fGAa2XhSA=="
  }

  # deSEC signs with a single combined key (flags 257). Its key list also
  # shows keys we added ourselves, like Cloudflare's ZSK, so pick the CSK.
  desec_dnskey = { for z in local.multi_signer_zones : z => split(" ", one([for k in desec_domain.standby[z].keys : k if k.keytype == "csk"]).dnskey) }
}

# deSEC's key, published by Cloudflare.
resource "cloudflare_dns_record" "desec_dnskey" {
  for_each = local.multi_signer_zones

  zone_id = local.cloudflare_zone_ids[each.key]
  name    = each.key
  type    = "DNSKEY"
  ttl     = 3600
  data = {
    flags      = tonumber(local.desec_dnskey[each.key][0])
    protocol   = tonumber(local.desec_dnskey[each.key][1])
    algorithm  = tonumber(local.desec_dnskey[each.key][2])
    public_key = local.desec_dnskey[each.key][3]
  }

  depends_on = [cloudflare_zone_dnssec.this]
}

# Cloudflare's ZSK, published by deSEC next to its own key.
resource "desec_rrset" "cloudflare_dnskey" {
  for_each = local.cloudflare_zsk

  domain  = desec_domain.standby[each.key].name
  subname = ""
  type    = "DNSKEY"
  ttl     = 3600
  records = [local.cloudflare_zsk[each.key]]
}

# The DS records to put at the registrar, one per provider.
output "ds_records" {
  value = {
    for z in local.multi_signer_zones : z => {
      cloudflare = cloudflare_zone_dnssec.this[z].ds
      desec      = [for ds in one([for k in desec_domain.standby[z].keys : k if k.keytype == "csk"]).ds : ds if split(" ", ds)[2] == "2"]
    }
  }
}
