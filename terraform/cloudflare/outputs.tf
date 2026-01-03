output "plex_fqdn" {
  description = "Fully qualified domain name for Plex"
  value       = "${var.plex_subdomain}.${var.domain}"
}

output "dns_record_id" {
  description = "Cloudflare DNS record ID"
  value       = cloudflare_record.plex.id
}

output "dns_record_hostname" {
  description = "DNS record hostname"
  value       = cloudflare_record.plex.hostname
}

output "jellyseerr_fqdn" {
  description = "Fully qualified domain name for Jellyseerr"
  value       = "requests.${var.domain}"
}

output "jellyseerr_dns_record_id" {
  description = "Cloudflare DNS record ID for Jellyseerr"
  value       = cloudflare_record.jellyseerr.id
}

output "jellyseerr_proxied" {
  description = "Whether Jellyseerr DNS is proxied through Cloudflare"
  value       = cloudflare_record.jellyseerr.proxied
}
