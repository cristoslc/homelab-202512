# DNS A Record for Plex
resource "cloudflare_record" "plex" {
  zone_id = var.cloudflare_zone_id
  name    = var.plex_subdomain
  content  = var.bastion_ip
  type    = "A"
  ttl     = 300
  proxied = false

  comment = "Plex direct connection via bastion - managed by Terraform"
}
