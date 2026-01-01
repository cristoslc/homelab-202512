# Homelab Infrastructure - Day 1: Media Server Direct Connection

## Overview

Day 1 establishes the core bastion architecture to eliminate Plex relay usage and enable direct connections through a WireGuard tunnel. By end of day, Plex and Jellyfin users connect directly to your home server with zero relay traffic.

**Shipped Value**:
- Plex accessible via `https://plex.yourdomain.com:32400`
- Jellyfin accessible via `https://plex.yourdomain.com:8920`
- Direct connection through secure WireGuard tunnel with SSL termination

## Architecture

```
Internet → plex.yourdomain.com (Cloudflare DNS)
         → Bastion VPS (Hetzner, 10.8.0.1)
           ├─ HAProxy :32400 (SSL) → WireGuard → 10.8.0.2:32400 → Plex
           └─ HAProxy :8920 (SSL)  → WireGuard → 10.8.0.2:8096  → Jellyfin

           WireGuard Tunnel (51820/udp)
             → Home Docker Host (10.8.0.2)
               → Docker Bridge Network (br-*)
                 ├─ Plex Container (:32400)
                 └─ Jellyfin Container (:8096)
```

### Key Design Decisions

**WireGuard Deployment**: Systemd service on Docker host (not containerized)
- Creates `wg0` interface at 10.8.0.2/24
- Preserves Docker network isolation (no `network_mode: host`)
- Custom bridge support: iptables rules for br-+ interfaces
- Standard port publishing: `-p 32400:32400`, `-p 8096:8096`

**HAProxy SSL Termination**: Let's Encrypt certificates on bastion
- SSL/TLS handled at internet edge (bastion)
- Automatic certificate renewal via certbot
- Backend traffic over encrypted WireGuard tunnel (HTTP)
- Single certificate for both Plex and Jellyfin

**DNS Automation**: Terraform Cloudflare provider
- Zero manual DNS configuration
- A record: `plex.yourdomain.com` → Bastion IP
- Provider-portable design (swap for Route53/etc.)

**Infrastructure as Code**: Complete automation
- Terraform: VPS provisioning + DNS
- Ansible: Service configuration + deployment
- Single command: `./scripts/deploy.sh`

## Day 1 Sessions

### Session 1: Terraform Foundation
**Deliverables**:
- `terraform/hetzner/` - VPS, firewall rules, SSH keys
- `terraform/cloudflare/` - DNS A record for plex subdomain
- `terraform/outputs.tf` - Bastion IP for Ansible inventory

**Outputs**: Bastion public IP, WireGuard port, DNS FQDN

### Session 2: Ansible Repository Structure
**Deliverables**:
- Ansible directory structure and roles framework
- Inventory automation from Terraform outputs
- Secrets management (ansible-vault or SOPS)
- WireGuard key pair generation automation

**Outputs**: Empty role templates, inventory generation script

### Session 3: Bastion Playbook
**Deliverables**:
- `roles/wireguard-server/` - WireGuard server config, systemd service
- `roles/haproxy/` - SSL termination + forwarding to Plex/Jellyfin backends
- `roles/certbot/` - Let's Encrypt certificate management
- `roles/ddclient/` - Dynamic DNS updates (if home IP changes)
- `roles/base-security/` - UFW, fail2ban, SSH hardening
- `playbooks/bastion.yml` - Orchestrates bastion host configuration

**Outputs**: Fully configured bastion VPS with HTTPS endpoints

### Session 4: Home Server Playbook
**Deliverables**:
- `roles/wireguard-client/` - WireGuard client config, peer to bastion
- `roles/plex-config/` - Plex container verification, network settings
- `playbooks/homeserver.yml` - Configures home Docker host
- Kernel forwarding: `net.ipv4.ip_forward=1`
- Firewall rules: wg0 ↔ docker0 and wg0 ↔ br-+ (custom bridges)

**Outputs**: Home server connected to bastion, supports custom Docker networks

### Session 5: Deployment & Validation
**Deliverables**:
- `playbooks/site.yml` - Master playbook orchestrating full stack
- Deployment scripts: `scripts/deploy.sh`
- Validation scripts: `scripts/validate-day1.sh`
  - WireGuard tunnel connectivity test
  - Plex port accessibility check
  - External DNS resolution verification
- Integration testing from external network

**Outputs**: Working Plex direct connection, validated externally

## Prerequisites

**Required Tools**:
- Terraform >= 1.6
- Ansible >= 2.15
- SSH key pair for VPS access

**Required Accounts**:
- Hetzner Cloud account + API token
- Cloudflare account + API token (zone managed)
- Domain configured in Cloudflare

**Existing Infrastructure**:
- Docker host running Plex and/or Jellyfin containers
- Plex published on port 32400 (if using Plex)
- Jellyfin published on port 8096 (if using Jellyfin)
- Home network with static or DDNS-updated IP

## Deployment

### Initial Setup

1. **Configure Secrets**:
```bash
# Copy .env template and fill in your values
cp .env.example .env
vi .env  # Fill in all TF_VAR_* and Ansible variables
```

Required variables in `.env`:
- `TF_VAR_hcloud_token` - Hetzner Cloud API token
- `TF_VAR_cloudflare_api_token` - Cloudflare API token
- `TF_VAR_cloudflare_zone_id` - Cloudflare Zone ID
- `TF_VAR_domain` - Your domain name
- `TF_VAR_ssh_public_key` - SSH public key for bastion access
- `CLOUDFLARE_ZONE` - Domain name for ddclient (should match TF_VAR_domain)
- `ANSIBLE_VAULT_PASSWORD` - Vault password for encrypted secrets

See `.env.example` for complete documentation and optional variables.

2. **Run Complete Deployment**:
```bash
# Single command deploys everything
./scripts/deploy.sh

# Or run manually:
source .env && export $(cat .env | xargs)
cd terraform && terraform init && terraform plan && terraform apply
cd ../ansible && ./scripts/generate-inventory.sh
ansible-playbook playbooks/site.yml
```

### Validation

```bash
# Test WireGuard tunnel
ansible bastion -m shell -a "wg show"
ansible homeserver -m shell -a "wg show"

# Verify connectivity
ansible bastion -m shell -a "ping -c 3 10.8.0.2"

# Run validation suite
./scripts/validate-day1.sh
```

**External Test**:
- Plex: `https://plex.yourdomain.com:32400/web` from mobile network
- Jellyfin: `https://plex.yourdomain.com:8920` from mobile network

## Project Structure

```
homelab-202512/
├── README.md                    # This file
├── .env                         # Secrets (gitignored, create from .env.example)
├── .env.example                 # Template with all required variables
├── terraform/
│   ├── main.tf                  # Root module
│   ├── outputs.tf               # Bastion IP, DNS outputs
│   ├── variables.tf             # Input variables
│   ├── hetzner/
│   │   └── main.tf              # VPS, firewall, SSH keys
│   └── cloudflare/
│       └── main.tf              # DNS A record
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/
│   │   └── hosts.yml            # Generated from Terraform
│   ├── playbooks/
│   │   ├── site.yml             # Master orchestrator
│   │   ├── bastion.yml          # Bastion configuration
│   │   └── homeserver.yml       # Home server configuration
│   ├── roles/
│   │   ├── wireguard-server/
│   │   ├── wireguard-client/
│   │   ├── haproxy/
│   │   ├── certbot/
│   │   ├── ddclient/
│   │   ├── base-security/
│   │   └── plex-config/
│   └── scripts/
│       ├── generate-inventory.sh
│       └── validate-day1.sh
└── docs/
    └── architecture.md          # Detailed technical docs
```

## Network Configuration

### WireGuard Network: 10.8.0.0/24

| Host          | IP Address | Role                  |
|---------------|------------|-----------------------|
| Bastion VPS   | 10.8.0.1   | WireGuard server      |
| Home Server   | 10.8.0.2   | WireGuard client      |

### Firewall Rules

**Bastion (Hetzner Cloud + UFW)**:
- 51820/udp: WireGuard (from 0.0.0.0/0)
- 32400/tcp: Plex HTTPS (from 0.0.0.0/0)
- 8920/tcp: Jellyfin HTTPS (from 0.0.0.0/0)
- 80/tcp: HTTP (Let's Encrypt validation)
- 22/tcp: SSH (from 0.0.0.0/0)

**Home Server**:
- wg0 → docker0: FORWARD ACCEPT
- docker0 → wg0: FORWARD ACCEPT
- wg0 → br-+: FORWARD ACCEPT (custom Docker bridges)
- br-+ → wg0: FORWARD ACCEPT (custom Docker bridges)
- Masquerading enabled for WireGuard subnet

## Troubleshooting

### WireGuard Tunnel Not Establishing
```bash
# Check WireGuard status
sudo wg show

# Verify firewall allows 51820/udp
sudo ufw status

# Check systemd service
sudo systemctl status wg-quick@wg0
```

### Media Services Not Accessible
```bash
# Test Plex from bastion
curl -I http://10.8.0.2:32400/web

# Test Jellyfin from bastion
curl -I http://10.8.0.2:8096

# Check HAProxy forwarding
sudo systemctl status haproxy
sudo tail -f /var/log/haproxy.log
ss -tlnp | grep haproxy

# Verify Docker containers
docker ps | grep -E "plex|jellyfin"
docker logs plex
docker logs jellyfin

# Check iptables rules for custom bridges
sudo iptables -L FORWARD -v -n | grep br-
```

### DNS Not Resolving
```bash
# Check Cloudflare record
dig plex.yourdomain.com

# Verify Terraform state
cd terraform && terraform show | grep cloudflare
```

## Next Steps

After Day 1 completion:
- **Day 2**: Add Jellyseerr with Caddy HTTPS reverse proxy
- **Day 3**: Expose *arr stack (Sonarr, Radarr, Prowlarr)
- **Day 4**: Production hardening (monitoring, backups, alerting)
- **Day 5**: Documentation and portability validation

## Context

This is Day 1 of a 5-day infrastructure buildout designed for:
- Daily shipped value (working features each day)
- Zero manual steps (full IaC automation)
- Provider portability (modular Terraform design)
- Maximum LLM leverage (complete modules per session)

See project root for complete roadmap and architectural decisions.
