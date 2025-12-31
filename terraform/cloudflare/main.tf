terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# Data source to find existing plex A records
data "cloudflare_zone" "domain" {
  zone_id = var.cloudflare_zone_id
}

# Cleanup script to remove duplicate DNS records before creating the new one
resource "null_resource" "cleanup_duplicate_dns" {
  triggers = {
    bastion_ip = var.bastion_ip
    zone_id    = var.cloudflare_zone_id
    subdomain  = var.plex_subdomain
    zone_name  = data.cloudflare_zone.domain.name
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/cleanup-dns.sh"
    environment = {
      CF_API_TOKEN = var.cloudflare_api_token
      CF_ZONE_ID   = var.cloudflare_zone_id
      DNS_NAME     = "${var.plex_subdomain}.${data.cloudflare_zone.domain.name}"
      NEW_IP       = var.bastion_ip
    }
  }
}

# DNS A Record for Plex
resource "cloudflare_record" "plex" {
  zone_id         = var.cloudflare_zone_id
  name            = var.plex_subdomain
  content         = var.bastion_ip
  type            = "A"
  ttl             = 300
  proxied         = false
  allow_overwrite = true

  comment = "Plex direct connection via bastion - managed by Terraform"

  depends_on = [null_resource.cleanup_duplicate_dns]
}
