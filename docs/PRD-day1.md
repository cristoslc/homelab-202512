# Product Requirements Document - Day 1: Media Server Direct Connection

## Overview

Establish a WireGuard bastion architecture to eliminate Plex/Jellyfin relay usage and enable direct connections from the internet to a home media server.

## Goals

- Zero Plex relay traffic (all connections direct)
- HTTPS access to Plex and Jellyfin through public domain
- Secure WireGuard tunnel between bastion and home network
- Complete Infrastructure as Code automation (Terraform + Ansible)
- Shipped working product by end of Day 1

## Target Architecture

```
Internet → plex.yourdomain.com (Cloudflare DNS)
         → Bastion VPS (Hetzner, 10.8.0.1)
           ├─ HAProxy :32400 (SSL) → WireGuard → 10.8.0.2:32400 → Plex
           └─ HAProxy :8920 (SSL)  → WireGuard → 10.8.0.2:8096  → Jellyfin
```

## Success Criteria

### Infrastructure
- [ ] Hetzner VPS provisioned via Terraform
- [ ] Cloudflare DNS record created automatically
- [ ] WireGuard tunnel established (bastion ↔ home)
- [ ] Let's Encrypt SSL certificates installed
- [ ] HAProxy configured for SSL termination

### Functionality
- [ ] Plex accessible at `https://plex.yourdomain.com:32400/web`
- [ ] Jellyfin accessible at `https://plex.yourdomain.com:8920`
- [ ] No relay connections (100% direct)
- [ ] External validation from mobile network succeeds

### Automation
- [ ] Single command deployment: `./scripts/deploy.sh`
- [ ] Validation script passes: `./scripts/validate-day1.sh`
- [ ] All configuration in code (zero manual steps)

## Technical Requirements

### WireGuard Network
- Network: `10.8.0.0/24`
- Bastion: `10.8.0.1` (WireGuard server)
- Home: `10.8.0.2` (WireGuard client)
- Port: `51820/udp`

### Firewall Rules (Bastion)
- `22/tcp` - SSH
- `51820/udp` - WireGuard
- `32400/tcp` - Plex HTTPS
- `8920/tcp` - Jellyfin HTTPS
- `80/tcp` - Let's Encrypt validation

### Home Server Configuration
- WireGuard as systemd service (NOT containerized)
- IP forwarding enabled: `net.ipv4.ip_forward=1`
- iptables rules: `wg0 ↔ docker0` and `wg0 ↔ br-*` (custom bridges)
- Docker containers: standard port publishing (`-p 32400:32400`, `-p 8096:8096`)

## Out of Scope (Future Days)

- Jellyseerr (Day 2)
- *arr stack (Day 3)
- Monitoring/backups (Day 4)
- Advanced hardening beyond base security

## Dependencies

### Tools
- Terraform >= 1.6
- Ansible >= 2.15
- SSH key pair

### Accounts
- Hetzner Cloud (with API token)
- Cloudflare (with API token and zone)
- Domain configured in Cloudflare

### Existing Infrastructure
- Docker host running Plex and/or Jellyfin
- Plex on port 32400, Jellyfin on port 8096

## Estimated Cost

- Hetzner CX11 VPS: ~€4.51/month
- Cloudflare DNS: Free
- **Total: ~€4.51/month**

## Deliverables

### Code
- `terraform/` - VPS, firewall, DNS automation
- `ansible/roles/wireguard-server/` - WireGuard server configuration
- `ansible/roles/wireguard-client/` - WireGuard client configuration
- `ansible/roles/haproxy/` - SSL termination and traffic forwarding
- `ansible/roles/certbot/` - Let's Encrypt certificate management
- `ansible/roles/ddclient/` - Dynamic DNS updates
- `ansible/roles/base-security/` - UFW, fail2ban, SSH hardening
- `ansible/roles/plex-config/` - Plex container validation

### Scripts
- `scripts/deploy.sh` - One-command deployment
- `scripts/validate-day1.sh` - Automated validation

### Documentation
- `README.md` - Updated with Day 1 completion status
- `terraform/README.md` - Terraform quick start
- `ansible/README.md` - Ansible configuration guide

## Validation Checklist

```bash
# 1. WireGuard tunnel established
ansible bastion -m shell -a "wg show" | grep handshake
ansible homeserver -m shell -a "wg show" | grep handshake

# 2. Ping across tunnel
ansible bastion -m shell -a "ping -c 3 10.8.0.2"

# 3. HAProxy listening
ansible bastion -m shell -a "ss -tlnp | grep haproxy"

# 4. Plex accessible via tunnel
ansible bastion -m shell -a "curl -I http://10.8.0.2:32400/web"

# 5. DNS resolves correctly
dig plex.yourdomain.com

# 6. External HTTPS access
curl -I https://plex.yourdomain.com:32400/web
curl -I https://plex.yourdomain.com:8920
```

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| WireGuard tunnel fails to establish | Test firewall rules, verify keys, check systemd service |
| SSL certificates fail to issue | Use staging Let's Encrypt first, verify DNS resolves |
| Docker network isolation broken | Use systemd WireGuard (not container), preserve port publishing |
| Home IP changes | Configure ddclient for dynamic DNS updates |

## Timeline

This is a single-day implementation with 5 sessions:
1. Terraform infrastructure
2. Ansible repository structure
3. Bastion playbook
4. Home server playbook
5. Deployment and validation
