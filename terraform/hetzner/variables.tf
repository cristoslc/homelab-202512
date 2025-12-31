variable "server_name" {
  description = "Name for the Hetzner bastion VPS"
  type        = string
}

variable "server_type" {
  description = "Hetzner server type (e.g., cx11, cx21)"
  type        = string
}

variable "server_location" {
  description = "Hetzner server location (e.g., nbg1, fsn1, hel1)"
  type        = string
}

variable "server_image" {
  description = "Server OS image"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for bastion access"
  type        = string
}
