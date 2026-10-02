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

variable "desec_token" {
  type      = string
  sensitive = true
}

variable "healthchecks_api_key" {
  type      = string
  sensitive = true
}

variable "uptimerobot_api_key" {
  type      = string
  sensitive = true
}

# Pushover's email gateway: mail sent there becomes a push notification.
# Anyone who has it can push to the phone, so it lives in SOPS.
variable "pushover_email" {
  type      = string
  sensitive = true
}
