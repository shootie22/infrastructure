# Switch DNS to the Hetzner standby

For when Cloudflare DNS has been down long enough that waiting it out is worse than a slow switch. The switch itself takes hours to spread, because the TLD servers cache nameservers for up to 2 days. For a short outage, it's better to wait.

nuke.zip is not in the standby and stays on Cloudflare.

## What changes while switched

- Sites are reached directly at the RO IP, with no Cloudflare proxy.
- Only RO serves traffic. The edge and failover (Phase 6) aren't part of this.
- Headlamp's certificate renewals (DNS-01 through Cloudflare) stop working. Everything else renews over HTTP-01.

## Before switching: DNSSEC

radunenu.com, yeetus.net and cubtube.lol have DNSSEC on, signed by Cloudflare, with a DS record at Porkbun. Hetzner doesn't have Cloudflare's keys, so if the nameservers switch while the DS record is still there, validating resolvers reject the zone and the domain goes dark.

For those three zones:
1. Remove the DS record at Porkbun (domain → DNSSEC).
2. Wait for the old DS to expire. `.com` and `.net` cache DS records for up to a day, so check with `dig DS <domain> @1.1.1.1` until it comes back empty.
3. Only then switch the nameservers.

The other zones (byradu.com, kronorite.com, cubi.tube) don't use DNSSEC and can switch straight away.

## Steps

1. **Refresh the standby** so the root domains have RO's current IP. The Cloudflare API may be down, so only touch Hetzner:
   ```sh
   scripts/tofu apply -target=hcloud_zone_rrset.standby
   ```
2. **Check that Hetzner answers correctly:**
   ```sh
   dig +short radunenu.com A @hydrogen.ns.hetzner.com
   dig +short git.radunenu.com @hydrogen.ns.hetzner.com
   ```
3. **Switch the nameservers at the registrars** to:
   `hydrogen.ns.hetzner.com`, `oxygen.ns.hetzner.com`, `helium.ns.hetzner.de`
   - Porkbun: radunenu.com, yeetus.net, byradu.com, cubi.tube, cubtube.lol
   - Namecheap: kronorite.com
4. **Watch it spread.** This asks the TLD servers directly:
   ```sh
   dig +short NS radunenu.com @a.gtld-servers.net
   ```
   Resolvers pick up the change as their cached NS records expire, which can take up to 2 days.
5. **Write down in the journal** when and why.

## Switching back

1. Set the nameservers back to `nola.ns.cloudflare.com` and `phil.ns.cloudflare.com`.
2. In Cloudflare, check that the zones are still there and active. Cloudflare can delete zones that stay pointed elsewhere for too long, so do this soon after switching back.
3. Turn DNSSEC back on in Cloudflare, then add the new DS record at Porkbun.
4. Run `scripts/tofu plan`. It should show no changes. If a zone was recreated, the records need importing again.
