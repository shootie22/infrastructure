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
    "kronorite.com/mc/CNAME" = {
      zone    = "kronorite.com", name = "mc", type = "CNAME"
      content = "beacon.radunenu.com"
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
    "kronorite.com/status/CNAME" = {
      zone    = "kronorite.com", name = "status", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "kronorite.com/www/CNAME" = {
      zone    = "kronorite.com", name = "www", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/*/CNAME" = {
      zone    = "radunenu.com", name = "*", type = "CNAME"
      content = "pixie.porkbun.com"
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
      zone    = "radunenu.com", name = "@", type = "TXT"
      content = "\"v=spf1 include:_spf.mailfence.com ~all\""
    }
    "radunenu.com/@/TXT/google" = {
      zone    = "radunenu.com", name = "@", type = "TXT"
      content = "google-site-verification=Pe00awN0OgFayUIxOe1N_KpBGqiBrZTH99Tse7Tr9Mo"
      ttl     = 3600
    }
    "radunenu.com/_acme-challenge/TXT/1" = {
      zone    = "radunenu.com", name = "_acme-challenge", type = "TXT"
      content = "P5lRLYDrnsoqqmoFqP3GKXzdlr1TBz30Ym3pwD6V6N0"
    }
    "radunenu.com/_acme-challenge/TXT/2" = {
      zone    = "radunenu.com", name = "_acme-challenge", type = "TXT"
      content = "RlicbhMOGVCgH65MOBISRFb1iMUNBqtqpHK7u80JyXg"
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
    "radunenu.com/api/CNAME" = {
      zone    = "radunenu.com", name = "api", type = "CNAME"
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
      content = "noc-studios.go.ro"
      proxied = true
    }
    "radunenu.com/auth/CNAME" = {
      zone    = "radunenu.com", name = "auth", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/beacon/CNAME" = {
      zone    = "radunenu.com", name = "beacon", type = "CNAME"
      content = "noc-studios.go.ro"
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
    "radunenu.com/chat/CNAME" = {
      zone    = "radunenu.com", name = "chat", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/cloud/CNAME" = {
      zone    = "radunenu.com", name = "cloud", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/cubitube/CNAME" = {
      zone    = "radunenu.com", name = "cubitube", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/dev/CNAME" = {
      zone    = "radunenu.com", name = "dev", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/filestorage-monitor/CNAME" = {
      zone    = "radunenu.com", name = "filestorage-monitor", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/gamesv-monitor/CNAME" = {
      zone    = "radunenu.com", name = "gamesv-monitor", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/git/CNAME" = {
      zone    = "radunenu.com", name = "git", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/graphs/CNAME" = {
      zone    = "radunenu.com", name = "graphs", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/hl/CNAME" = {
      zone    = "radunenu.com", name = "hl", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/hs/CNAME" = {
      zone    = "radunenu.com", name = "hs", type = "CNAME"
      content = "noc-studios.go.ro"
    }
    "radunenu.com/img/CNAME" = {
      zone    = "radunenu.com", name = "img", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/kanban/A" = {
      zone    = "radunenu.com", name = "kanban", type = "A"
      content = "141.95.67.178"
      proxied = true
    }
    "radunenu.com/komodo/CNAME" = {
      zone    = "radunenu.com", name = "komodo", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/lt/CNAME" = {
      zone    = "radunenu.com", name = "lt", type = "CNAME"
      content = "translate.radunenu.com"
      proxied = true
    }
    "radunenu.com/mc/A" = {
      zone    = "radunenu.com", name = "mc", type = "A"
      content = "141.95.67.178"
    }
    "radunenu.com/mon/CNAME" = {
      zone    = "radunenu.com", name = "mon", type = "CNAME"
      content = "noc-studios.go.ro"
      proxied = true
    }
    "radunenu.com/monitor/CNAME" = {
      zone    = "radunenu.com", name = "monitor", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/ocean/A" = {
      zone    = "radunenu.com", name = "ocean", type = "A"
      content = "167.172.191.19"
      proxied = true
    }
    "radunenu.com/panel/CNAME" = {
      zone    = "radunenu.com", name = "panel", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/pbin/CNAME" = {
      zone    = "radunenu.com", name = "pbin", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/pinga/CNAME" = {
      zone    = "radunenu.com", name = "pinga", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/play/A" = {
      zone    = "radunenu.com", name = "play", type = "A"
      content = "195.201.129.220"
    }
    "radunenu.com/puml/CNAME" = {
      zone    = "radunenu.com", name = "puml", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/s/CNAME" = {
      zone    = "radunenu.com", name = "s", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/sb/CNAME" = {
      zone    = "radunenu.com", name = "sb", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/scratchpad-monitor/CNAME" = {
      zone    = "radunenu.com", name = "scratchpad-monitor", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/sd/CNAME" = {
      zone    = "radunenu.com", name = "sd", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/services/CNAME" = {
      zone    = "radunenu.com", name = "services", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/share/CNAME" = {
      zone    = "radunenu.com", name = "share", type = "CNAME"
      content = "beacon.radunenu.com"
    }
    "radunenu.com/skynet-monitor/CNAME" = {
      zone    = "radunenu.com", name = "skynet-monitor", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/status/CNAME" = {
      zone    = "radunenu.com", name = "status", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/translate/CNAME" = {
      zone    = "radunenu.com", name = "translate", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
    }
    "radunenu.com/webservers-monitor/CNAME" = {
      zone    = "radunenu.com", name = "webservers-monitor", type = "CNAME"
      content = "beacon.radunenu.com"
      proxied = true
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
      content = "noc-studios.go.ro"
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
    "yeetus.net/ass/CNAME" = {
      zone    = "yeetus.net", name = "ass", type = "CNAME"
      content = "mc.radunenu.com"
    }
    "yeetus.net/books/CNAME" = {
      zone    = "yeetus.net", name = "books", type = "CNAME"
      content = "noc-studios.go.ro"
      proxied = true
    }
    "yeetus.net/bopl/A" = {
      zone    = "yeetus.net", name = "bopl", type = "A"
      content = "141.95.67.178"
    }
    "yeetus.net/n/CNAME" = {
      zone    = "yeetus.net", name = "n", type = "CNAME"
      content = "noc-studios.go.ro"
      proxied = true
    }
    "yeetus.net/ownercheck/TXT" = {
      zone    = "yeetus.net", name = "ownercheck", type = "TXT"
      content = "\"f4f6f4d3\""
    }
    "yeetus.net/play/CNAME" = {
      zone    = "yeetus.net", name = "play", type = "CNAME"
      content = "mc.radunenu.com"
    }
    "yeetus.net/tits/CNAME" = {
      zone    = "yeetus.net", name = "tits", type = "CNAME"
      content = "mc.radunenu.com"
    }
    "yeetus.net/vw/CNAME" = {
      zone    = "yeetus.net", name = "vw", type = "CNAME"
      content = "noc-studios.go.ro"
      proxied = true
    }
    "yeetus.net/www/CNAME" = {
      zone    = "yeetus.net", name = "www", type = "CNAME"
      content = "noc-studios.go.ro"
      proxied = true
    }
  }
}
