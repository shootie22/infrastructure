variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "hcloud_token" {
  type      = string
  sensitive = true
}

variable "state_passphrase" {
  type      = string
  sensitive = true
}
