terraform {
  required_version = ">= 1.10"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.54"
    }
    desec = {
      source  = "Valodim/desec"
      version = "~> 0.6"
    }
    dns = {
      source  = "hashicorp/dns"
      version = "~> 3.4"
    }
  }

  # State and plans are encrypted, so terraform.tfstate can live in Git.
  # The passphrase comes from tofu/secrets.sops.yaml via scripts/tofu.
  encryption {
    key_provider "pbkdf2" "main" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "main" {
      keys = key_provider.pbkdf2.main
    }
    state {
      method   = method.aes_gcm.main
      enforced = true
    }
    plan {
      method   = method.aes_gcm.main
      enforced = true
    }
  }
}
