# Every DNS record managed here, keyed "zone/name/type". "@" is the zone apex.
# Defaults: proxied = false, ttl = 1 (automatic). See dns.tf.
locals {
  dns_records = {
    "byradu.com/7zile7arte/CNAME" = {
      zone    = "byradu.com", name = "7zile7arte", type = "CNAME"
      content = "archive.radunenu.com"
      proxied = true
    }
    "byradu.com/@/CNAME" = {
      zone    = "byradu.com", name = "@", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "byradu.com/@/MX/fwd1" = {
      zone     = "byradu.com", name = "@", type = "MX"
      content  = "fwd1.porkbun.com"
      priority = 1
    }
    "byradu.com/@/MX/fwd2" = {
      zone     = "byradu.com", name = "@", type = "MX"
      content  = "fwd2.porkbun.com"
      priority = 1
    }
    "byradu.com/@/TXT/google" = {
      zone    = "byradu.com", name = "@", type = "TXT"
      content = "google-site-verification=buFo61QtIYP7b4wHlIsKkomRVcqavB_DQHFnSWU59qA"
      ttl     = 3600
    }
    "byradu.com/@/TXT/spf" = {
      zone    = "byradu.com", name = "@", type = "TXT"
      content = "v=spf1 mx ~all"
    }
    "byradu.com/_autodiscover._tcp/SRV" = {
      zone     = "byradu.com", name = "_autodiscover._tcp", type = "SRV"
      data     = { priority = 10, weight = 10, port = 443, target = "webmail.porkbun.com" }
      priority = 10
    }
    "byradu.com/analytics/CNAME" = {
      zone    = "byradu.com", name = "analytics", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "byradu.com/api/CNAME" = {
      zone    = "byradu.com", name = "api", type = "CNAME"
      content = "api.radunenu.com"
      proxied = true
    }
    "byradu.com/www/CNAME" = {
      zone    = "byradu.com", name = "www", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "cubi.tube/@/CNAME" = {
      zone    = "cubi.tube", name = "@", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "cubi.tube/www/CNAME" = {
      zone    = "cubi.tube", name = "www", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "cubtube.lol/@/CNAME" = {
      zone    = "cubtube.lol", name = "@", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "cubtube.lol/www/CNAME" = {
      zone    = "cubtube.lol", name = "www", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "kronorite.com/@/CNAME" = {
      zone    = "kronorite.com", name = "@", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "kronorite.com/aki/CNAME" = {
      zone    = "kronorite.com", name = "aki", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "kronorite.com/discord/CNAME" = {
      zone    = "kronorite.com", name = "discord", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "kronorite.com/git/CNAME" = {
      zone    = "kronorite.com", name = "git", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "kronorite.com/kairi/CNAME" = {
      zone    = "kronorite.com", name = "kairi", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "kronorite.com/news/CNAME" = {
      zone    = "kronorite.com", name = "news", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "kronorite.com/stats/CNAME" = {
      zone    = "kronorite.com", name = "stats", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "kronorite.com/www/CNAME" = {
      zone    = "kronorite.com", name = "www", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/20250913-vafn._domainkey/TXT" = {
      zone    = "radunenu.com", name = "20250913-vafn._domainkey", type = "TXT"
      content = "\"v=DKIM1;k=rsa;p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwT3r4FOCAJvPJKaD+ZGFxj+rXkp5yHD9nmJ3BmtHlDu69hJn1UzzpSuD0HzHjEQM9l3TmsCunfPGnFw7RnQt/PKvC9GgEyJDeQmtUfV9FUboLvjF0+rEHZqpqRfRl659hFUri71vUatL26EwSFmXBaFqqiCMObENI8oMq/7DDdff3KpRzKjjXiGTFWHN7S6Dwb8\" \"7h2T+XIzu3KxnJ2nQRmcyNrx71dhgzhjL8gjV7KSodzoLKpaEE+eoxhgq4UjhRmc6je4x4viIh7NS3F4WTa4inM5Ob+/ZOLxSFPR322+xcuXOKlxkHUzuiQswRW9wbhwifpUx+AVFfAFmr6FgCwIDAQAB\""
    }
    "radunenu.com/@/CNAME" = {
      zone    = "radunenu.com", name = "@", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/@/MX/smtp1" = {
      zone     = "radunenu.com", name = "@", type = "MX"
      content  = "smtp1.mailfence.com"
      priority = 10
    }
    "radunenu.com/@/MX/smtp2" = {
      zone     = "radunenu.com", name = "@", type = "MX"
      content  = "smtp2.mailfence.com"
      priority = 10
    }
    "radunenu.com/@/TXT/spf" = {
      # Mailfence, plus the edge, which sends alert emails directly (alert
      # relay). When the edge moves to a new VPS, its IP changes here too.
      zone    = "radunenu.com", name = "@", type = "TXT"
      content = "\"v=spf1 include:_spf.mailfence.com ip4:141.95.67.178 ~all\""
    }
    # DMARC: what receivers should do with mail that claims to be from
    # radunenu.com but fails SPF and DKIM. p=none only asks for reports for now.
    "radunenu.com/_dmarc/TXT" = {
      zone    = "radunenu.com", name = "_dmarc", type = "TXT"
      content = "\"v=DMARC1; p=none; rua=mailto:alerts@radunenu.com; adkim=r; aspf=r\""
    }
    "radunenu.com/@/TXT/google" = {
      zone    = "radunenu.com", name = "@", type = "TXT"
      content = "google-site-verification=Pe00awN0OgFayUIxOe1N_KpBGqiBrZTH99Tse7Tr9Mo"
      ttl     = 3600
    }
    "radunenu.com/analytics/CNAME" = {
      zone    = "radunenu.com", name = "analytics", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/api-old/CNAME" = {
      zone    = "radunenu.com", name = "api-old", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/archive/CNAME" = {
      zone    = "radunenu.com", name = "archive", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/argocd-webhook/CNAME" = {
      zone    = "radunenu.com", name = "argocd-webhook", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/auth/CNAME" = {
      zone    = "radunenu.com", name = "auth", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/beacon/CNAME" = {
      zone    = "radunenu.com", name = "beacon", type = "CNAME"
      content = "ro.radunenu.com"
      proxied = true
    }
    "radunenu.com/cal/CNAME" = {
      zone    = "radunenu.com", name = "cal", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/cats/CNAME" = {
      zone    = "radunenu.com", name = "cats", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/git/CNAME" = {
      zone    = "radunenu.com", name = "git", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/hs/CNAME" = {
      zone    = "radunenu.com", name = "hs", type = "CNAME"
      content = "ro.radunenu.com"
    }
    "radunenu.com/mon/CNAME" = {
      zone    = "radunenu.com", name = "mon", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/pbin/CNAME" = {
      zone    = "radunenu.com", name = "pbin", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/puml/CNAME" = {
      zone    = "radunenu.com", name = "puml", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    # Hub's public incident API (hub-public, infra-hub #40), later the status page.
    "radunenu.com/status/CNAME" = {
      zone    = "radunenu.com", name = "status", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/share/CNAME" = {
      zone    = "radunenu.com", name = "share", type = "CNAME"
      content = "beacon.radunenu.com"
    }
    "radunenu.com/www/CNAME" = {
      zone    = "radunenu.com", name = "www", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "yeetus.net/20250921-n4s4._domainkey/TXT" = {
      zone    = "yeetus.net", name = "20250921-n4s4._domainkey", type = "TXT"
      content = "\"v=DKIM1;k=rsa;p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAy1H3bNnKI3X1KWWKhEL8CRE/yt7m+j5ho1T8wFkWVGyfku5+MQqsrgRXsWpzThMa41F/UQVVLMsI8/5quRQE2dHNGlRGecx4QTYjIVmYHDKFPJBD6uG/xvHrzf/tluRHAQZutbIvK7vTUl3waKlBwMFm59LB7f9Cf/x8aoEJnnVeZjJsFsKgSY3E/vCmshgCFmb\" \"4lx11NBFvniB1XCfS1D7CRjS5mJTq/EIUwNei7tgH9pJq9nWrGotU5yt1sEUH3BtChcIbz497jTM0ul8YpKM4cGZ55nBxFJqIMAD/yhk8lV846NSO7c56L7pWrCRenPQBqcSkv18ZxRGGIB8ETQIDAQAB\""
    }
    "yeetus.net/@/CNAME" = {
      zone    = "yeetus.net", name = "@", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "yeetus.net/@/MX/smtp1" = {
      zone     = "yeetus.net", name = "@", type = "MX"
      content  = "smtp1.mailfence.com"
      priority = 10
    }
    "yeetus.net/@/MX/smtp2" = {
      zone     = "yeetus.net", name = "@", type = "MX"
      content  = "smtp2.mailfence.com"
      priority = 10
    }
    "yeetus.net/@/TXT" = {
      zone    = "yeetus.net", name = "@", type = "TXT"
      content = "\"v=spf1 include:_spf.mailfence.com ~all\""
    }
    "yeetus.net/books/CNAME" = {
      zone    = "yeetus.net", name = "books", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "yeetus.net/n/CNAME" = {
      zone    = "yeetus.net", name = "n", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "yeetus.net/ownercheck/TXT" = {
      zone    = "yeetus.net", name = "ownercheck", type = "TXT"
      content = "\"f4f6f4d3\""
    }
    "yeetus.net/vw/CNAME" = {
      zone    = "yeetus.net", name = "vw", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "yeetus.net/www/CNAME" = {
      zone    = "yeetus.net", name = "www", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }

    # The one record that says where RO is, DNS only. Everything else points
    # here (DNS-only names) or at beacon (proxied names). Failover changes this.
    "radunenu.com/ro/CNAME" = {
      zone    = "radunenu.com", name = "ro", type = "CNAME"
      content = "noc-studios.go.ro"
    }

    # Where Element Web is served (#160): c.nuke.zip is a CNAME to this.
    # The edge normally, which serves it itself; RO's front door while the
    # edge is down (the front checkers on mixi and fuji switch it).
    "radunenu.com/element/CNAME" = {
      zone    = "radunenu.com", name = "element", type = "CNAME"
      content = "edge.radunenu.com"
    }

    # The tailnet's own relay (DERP) on the edge (#38), next to Tailscale's.
    "radunenu.com/derp/CNAME" = {
      zone    = "radunenu.com", name = "derp", type = "CNAME"
      content = "edge.radunenu.com"
    }

    # The edge VPS. ro points here during a failover (dns-failover.tf).
    "radunenu.com/edge/A" = {
      zone    = "radunenu.com", name = "edge", type = "A"
      content = "141.95.67.178"
    }

    # Game servers: one DNS-only name pointing at RO, everything else CNAMEs to it.
    "radunenu.com/games/CNAME" = {
      zone    = "radunenu.com", name = "games", type = "CNAME"
      content = "ro.radunenu.com"
    }
    "radunenu.com/mc/CNAME" = {
      zone    = "radunenu.com", name = "mc", type = "CNAME"
      content = "games.radunenu.com"
    }
    "radunenu.com/play/CNAME" = {
      zone    = "radunenu.com", name = "play", type = "CNAME"
      content = "games.radunenu.com"
    }
    "kronorite.com/mc/CNAME" = {
      zone    = "kronorite.com", name = "mc", type = "CNAME"
      content = "games.radunenu.com"
    }
    "yeetus.net/crosty/CNAME" = {
      zone    = "yeetus.net", name = "crosty", type = "CNAME"
      content = "games.radunenu.com"
    }
    "yeetus.net/play/CNAME" = {
      zone    = "yeetus.net", name = "play", type = "CNAME"
      content = "games.radunenu.com"
    }
    "yeetus.net/bopl/CNAME" = {
      zone    = "yeetus.net", name = "bopl", type = "CNAME"
      content = "games.radunenu.com"
    }

    # Mail protection (docs/ha/decisions.md, 2026-10-02). Domains that send
    # mail publish DMARC in report-only mode first; domains that never send
    # mail say so (SPF -all) and ask receivers to reject anything claiming
    # otherwise. Reports for all of them go to alerts@radunenu.com.
    "yeetus.net/_dmarc/TXT" = {
      zone    = "yeetus.net", name = "_dmarc", type = "TXT"
      content = "\"v=DMARC1; p=none; rua=mailto:alerts@radunenu.com; adkim=r; aspf=r\""
    }
    "byradu.com/_dmarc/TXT" = {
      zone    = "byradu.com", name = "_dmarc", type = "TXT"
      content = "\"v=DMARC1; p=none; rua=mailto:alerts@radunenu.com; adkim=r; aspf=r\""
    }
    "kronorite.com/@/TXT" = {
      zone    = "kronorite.com", name = "@", type = "TXT"
      content = "\"v=spf1 -all\""
    }
    "kronorite.com/_dmarc/TXT" = {
      zone    = "kronorite.com", name = "_dmarc", type = "TXT"
      content = "\"v=DMARC1; p=reject; rua=mailto:alerts@radunenu.com; adkim=s; aspf=s\""
    }
    "cubi.tube/@/TXT" = {
      zone    = "cubi.tube", name = "@", type = "TXT"
      content = "\"v=spf1 -all\""
    }
    "cubi.tube/_dmarc/TXT" = {
      zone    = "cubi.tube", name = "_dmarc", type = "TXT"
      content = "\"v=DMARC1; p=reject; rua=mailto:alerts@radunenu.com; adkim=s; aspf=s\""
    }
    "cubtube.lol/@/TXT" = {
      zone    = "cubtube.lol", name = "@", type = "TXT"
      content = "\"v=spf1 -all\""
    }
    "cubtube.lol/_dmarc/TXT" = {
      zone    = "cubtube.lol", name = "_dmarc", type = "TXT"
      content = "\"v=DMARC1; p=reject; rua=mailto:alerts@radunenu.com; adkim=s; aspf=s\""
    }
    "radunenu.com/yeetus.net._report._dmarc/TXT" = {
      zone    = "radunenu.com", name = "yeetus.net._report._dmarc", type = "TXT"
      content = "\"v=DMARC1\""
    }
    "radunenu.com/byradu.com._report._dmarc/TXT" = {
      zone    = "radunenu.com", name = "byradu.com._report._dmarc", type = "TXT"
      content = "\"v=DMARC1\""
    }
    "radunenu.com/kronorite.com._report._dmarc/TXT" = {
      zone    = "radunenu.com", name = "kronorite.com._report._dmarc", type = "TXT"
      content = "\"v=DMARC1\""
    }
    "radunenu.com/cubi.tube._report._dmarc/TXT" = {
      zone    = "radunenu.com", name = "cubi.tube._report._dmarc", type = "TXT"
      content = "\"v=DMARC1\""
    }
    "radunenu.com/cubtube.lol._report._dmarc/TXT" = {
      zone    = "radunenu.com", name = "cubtube.lol._report._dmarc", type = "TXT"
      content = "\"v=DMARC1\""
    }
  }
}
