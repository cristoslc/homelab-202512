# Product Requirements Document - Day 3: *arr Stack Exposure

## Overview

Expose Sonarr, Radarr, and Prowlarr through the bastion with HTTPS reverse proxy, enabling remote management of media acquisition.

## Goals

- HTTPS access to all *arr applications
- Subdomains or path-based routing
- Secure authentication
- Integration with Jellyseerr from Day 2
- Maintain automation-first approach

## Target Architecture

```
Internet → sonarr.yourdomain.com → Bastion → Caddy → WireGuard → 10.8.0.2:8989 → Sonarr
         → radarr.yourdomain.com → Bastion → Caddy → WireGuard → 10.8.0.2:7878 → Radarr
         → prowlarr.yourdomain.com → Bastion → Caddy → WireGuard → 10.8.0.2:9696 → Prowlarr
```

## Success Criteria

### Infrastructure
- [ ] Cloudflare DNS records for each *arr app
- [ ] Caddy virtual hosts configured
- [ ] Let's Encrypt certificates for all subdomains
- [ ] Optional: Authentication middleware (Authelia/OAuth)

### Functionality
- [ ] Sonarr accessible at `https://sonarr.yourdomain.com`
- [ ] Radarr accessible at `https://radarr.yourdomain.com`
- [ ] Prowlarr accessible at `https://prowlarr.yourdomain.com`
- [ ] All apps show valid SSL certificates
- [ ] Can manage downloads remotely

### Automation
- [ ] Terraform manages all DNS records
- [ ] Caddy configuration templated via Ansible
- [ ] Single deployment updates all services

## Technical Requirements

### *arr Applications
- Sonarr: Port 8989
- Radarr: Port 7878
- Prowlarr: Port 9696
- All Docker containers on home server
- API keys secured in ansible-vault

### Caddy Configuration
- Wildcard SSL or individual certificates
- Reverse proxy to each service via WireGuard
- Rate limiting headers
- API endpoint protection

### Security
- Consider authentication layer (Authelia, OAuth Proxy)
- API key rotation strategy
- Firewall: Only 443/tcp exposed publicly

## Out of Scope

- Download client configuration (assumed existing)
- Indexer setup (manual user configuration)
- Advanced monitoring (Day 4)

## Dependencies

- Day 1: WireGuard tunnel
- Day 2: Caddy reverse proxy configured
- Existing *arr containers on home server

## Deliverables

### Code
- `terraform/cloudflare/` - DNS records for all *arr apps
- `ansible/roles/caddy/` - Updated with *arr virtual hosts
- `ansible/group_vars/` - *arr service URLs and ports

### Documentation
- *arr access URLs
- API authentication guide
- Integration with Jellyseerr

## Validation Checklist

```bash
# 1. DNS resolution
dig sonarr.yourdomain.com
dig radarr.yourdomain.com
dig prowlarr.yourdomain.com

# 2. HTTPS access
curl -I https://sonarr.yourdomain.com
curl -I https://radarr.yourdomain.com
curl -I https://prowlarr.yourdomain.com

# 3. API connectivity
curl -H "X-Api-Key: $SONARR_API_KEY" https://sonarr.yourdomain.com/api/v3/system/status
```

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Too many public services | Consider authentication gateway |
| API keys exposed | Use ansible-vault, rotate regularly |
| Certificate limit (Let's Encrypt) | Use wildcard cert or staging testing |

## Open Questions

- [ ] Subdomain per service vs. path-based routing?
- [ ] Single authentication gateway (Authelia) vs. per-app auth?
- [ ] Wildcard certificate vs. individual certs?
