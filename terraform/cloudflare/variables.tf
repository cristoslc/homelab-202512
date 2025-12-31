variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for your domain"
  type        = string
}

variable "domain" {
  description = "Your domain name (e.g., example.com)"
  type        = string
}

variable "bastion_ip" {
  description = "Bastion VPS IP address"
  type        = string
}

variable "plex_subdomain" {
  description = "Subdomain for Plex (e.g., plex)"
  type        = string
}
