terraform {
  required_version = ">= 1.6"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Hetzner Cloud Provider
provider "hcloud" {
  token = var.hcloud_token
}

# Cloudflare Provider
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Hetzner Bastion VPS Module
module "hetzner" {
  source = "./hetzner"

  server_name    = var.server_name
  server_type    = var.server_type
  server_location = var.server_location
  server_image   = var.server_image
  ssh_public_key = var.ssh_public_key
}

# Cloudflare DNS Module
module "cloudflare" {
  source = "./cloudflare"

  cloudflare_zone_id = var.cloudflare_zone_id
  domain             = var.domain
  bastion_ip         = module.hetzner.bastion_ip
  plex_subdomain     = var.plex_subdomain
}
