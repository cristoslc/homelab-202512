output "bastion_ip" {
  description = "Public IP address of the bastion VPS"
  value       = module.hetzner.bastion_ip
}

output "bastion_ipv6" {
  description = "Public IPv6 address of the bastion VPS"
  value       = module.hetzner.bastion_ipv6
}

output "bastion_server_id" {
  description = "Hetzner server ID"
  value       = module.hetzner.server_id
}

output "plex_fqdn" {
  description = "Fully qualified domain name for Plex"
  value       = module.cloudflare.plex_fqdn
}

output "wireguard_port" {
  description = "WireGuard port (static)"
  value       = 51820
}

output "ansible_inventory" {
  description = "Ansible inventory snippet"
  value = {
    bastion = {
      ansible_host = module.hetzner.bastion_ip
      ansible_user = "root"
    }
    homeserver = {
      ansible_connection = "local"
    }
  }
}
