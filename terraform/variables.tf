variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with DNS edit permissions"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for your domain"
  type        = string
}

variable "server_name" {
  description = "Name for the Hetzner bastion VPS"
  type        = string
  default     = "bastion-plex"
}

variable "server_type" {
  description = "Hetzner server type (e.g., cx11, cx21)"
  type        = string
  default     = "cx11"
}

variable "server_location" {
  description = "Hetzner server location (e.g., ash, hil, nbg1, fsn1, hel1)"
  type        = string
  default     = "ash"
}

variable "server_image" {
  description = "Server OS image"
  type        = string
  default     = "ubuntu-24.04"
}

variable "ssh_public_key" {
  description = "SSH public key for bastion access"
  type        = string
}

variable "domain" {
  description = "Your domain name (e.g., example.com)"
  type        = string
}

variable "plex_subdomain" {
  description = "Subdomain for Plex (e.g., plex)"
  type        = string
  default     = "plex"
}
