# SSH Key for Bastion Access
resource "hcloud_ssh_key" "bastion" {
  name       = "${var.server_name}-key"
  public_key = var.ssh_public_key
}

# Firewall for Bastion VPS
resource "hcloud_firewall" "bastion" {
  name = "${var.server_name}-firewall"

  # SSH Access
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # WireGuard VPN
  rule {
    direction = "in"
    protocol  = "udp"
    port      = "51820"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  # Plex Direct Connection
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "32400"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
}

# Bastion VPS
resource "hcloud_server" "bastion" {
  name        = var.server_name
  server_type = var.server_type
  location    = var.server_location
  image       = var.server_image

  ssh_keys = [
    hcloud_ssh_key.bastion.id
  ]

  firewall_ids = [
    hcloud_firewall.bastion.id
  ]

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  labels = {
    purpose     = "plex-bastion"
    environment = "production"
    managed_by  = "terraform"
  }
}
