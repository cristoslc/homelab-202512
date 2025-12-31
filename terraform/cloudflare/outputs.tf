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
