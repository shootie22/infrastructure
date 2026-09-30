locals {
  # Cloudflare zone IDs. nuke.zip is left out on purpose: it belongs to the Matrix stack.
  cloudflare_zone_ids = {
    "byradu.com"    = "1bd7a08f7a996303834428c1611f3fe4"
    "cubi.tube"     = "c61dd1dbb5cc7612e419a8db1037bd2f"
    "cubtube.lol"   = "217ce9c468a9a8b77a86a4d443942c4f"
    "kronorite.com" = "922ff0aef54f6aa92451517a0116163f"
    "radunenu.com"  = "96f437f9336f69441170543832a79db0"
    "yeetus.net"    = "50d92439a525c2ba9d25b5c8f673d195"
  }
}
