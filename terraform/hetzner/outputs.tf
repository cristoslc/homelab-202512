output "bastion_ip" {
  description = "Public IPv4 address of the bastion VPS"
  value       = hcloud_server.bastion.ipv4_address
}

output "bastion_ipv6" {
  description = "Public IPv6 address of the bastion VPS"
  value       = hcloud_server.bastion.ipv6_address
}

output "server_id" {
  description = "Hetzner server ID"
  value       = hcloud_server.bastion.id
}

output "server_status" {
  description = "Server status"
  value       = hcloud_server.bastion.status
}

output "firewall_id" {
  description = "Firewall ID"
  value       = hcloud_firewall.bastion.id
}
