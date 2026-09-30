# Switch DNS to the deSEC standby

This is the manual fallback. The plan is for this to happen automatically ([#77](https://github.com/shootie22/infrastructure/issues/77)).

For when Cloudflare DNS has been down long enough that waiting it out is worse than a slow switch. The switch takes hours to spread, because the `.com` servers let resolvers cache nameservers for up to 2 days. For a short outage, it's better to wait.

nuke.zip is not in the standby and stays on Cloudflare.

Not run for real yet.

## What changes while switched

- Sites are reached directly at the RO IP, with no Cloudflare proxy.
- Record changes take up to an hour to spread (deSEC's minimum TTL), instead of 5 minutes.
- Only RO serves traffic. The edge and failover (Phase 6) aren't part of this.
- Headlamp's certificate renewals (DNS-01 through Cloudflare) stop working. Everything else renews over HTTP-01.

## Before switching: check DNSSEC

Once a zone runs multi-signer DNSSEC (Cloudflare and deSEC, both DS records at the registrar), it switches with DNSSEC intact and there's nothing to do here. Check the zone's status in [decisions.md](../decisions.md) and on the board.

For a zone that is signed by Cloudflare only (a DS record at the registrar, but no deSEC one yet):
1. Remove the DS record at the registrar.
2. Wait until `dig DS <domain> @1.1.1.1` comes back empty, up to a day.
3. Then switch.

## Steps

1. **Refresh the standby** so the root domains have RO's current IP. The Cloudflare API may be down, so only touch deSEC:
   ```sh
   scripts/tofu apply -target=desec_rrset.standby -parallelism=1
   ```
2. **Check that deSEC answers correctly:**
   ```sh
   dig +short radunenu.com A @ns1.desec.io
   dig +short git.radunenu.com @ns1.desec.io
   ```
3. **Switch the nameservers at the registrars** to `ns1.desec.io` and `ns2.desec.org`:
   - Porkbun: radunenu.com, yeetus.net, byradu.com, cubi.tube, cubtube.lol
   - Namecheap: kronorite.com
4. **Watch it spread:**
   ```sh
   dig +short NS radunenu.com @a.gtld-servers.net
   ```
5. **Write down in the journal** when and why.

## Switching back

1. Set the nameservers back to `nola.ns.cloudflare.com` and `phil.ns.cloudflare.com`.
2. In Cloudflare, check that the zones are still there and active. Cloudflare can delete zones that stay pointed elsewhere for too long.
3. Run `scripts/tofu plan`. It should show no changes. If a zone was recreated, the records need importing again, and its DNSSEC keys change, so the DS records at the registrar need updating.
