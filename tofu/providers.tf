provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "desec" {
  api_token = var.desec_token
}

provider "healthchecksio" {
  api_key = var.healthchecks_api_key
}
