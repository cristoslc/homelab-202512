# Product Requirements Document - Day 2: Jellyseerr with HTTPS

## Overview

Add Jellyseerr (media request management) with Caddy reverse proxy providing HTTPS termination on a dedicated subdomain.

## Goals

- Users can request media via web interface
- HTTPS access through Caddy reverse proxy
- Separate subdomain for clean separation (e.g., `requests.yourdomain.com`)
- Integration with existing Plex/Jellyfin and *arr stack
- Maintain zero manual configuration approach

## Target Architecture

```
Internet → requests.yourdomain.com (Cloudflare DNS)
         → Bastion VPS (10.8.0.1)
           → Caddy :443 (SSL) → WireGuard → 10.8.0.2:5055 → Jellyseerr
```

## Success Criteria

### Infrastructure
- [ ] New Cloudflare DNS record for Jellyseerr subdomain
- [ ] Caddy installed and configured on bastion
- [ ] Automatic Let's Encrypt certificate management
- [ ] Reverse proxy routing to home Jellyseerr instance

### Functionality
- [ ] Jellyseerr accessible at `https://requests.yourdomain.com`
- [ ] Valid SSL certificate (not self-signed)
- [ ] User can log in with Plex/Jellyfin credentials
- [ ] Can submit media requests

### Automation
- [ ] Terraform updated with new DNS record
- [ ] New Ansible role: `caddy` for reverse proxy
- [ ] Deployment through `./scripts/deploy.sh`

## Technical Requirements

### Caddy Configuration
- Automatic HTTPS (Let's Encrypt)
- Reverse proxy to `http://10.8.0.2:5055`
- HSTS headers
- Security headers (CSP, X-Frame-Options, etc.)

### Jellyseerr
- Docker container on home server
- Port: 5055 (internal)
- Exposed through WireGuard tunnel only
- No direct internet exposure

### Firewall Updates
- Bastion: Add 443/tcp for Caddy HTTPS
- Home: No changes (WireGuard tunnel only)

## Out of Scope

- Full *arr stack configuration (Day 3)
- Advanced monitoring (Day 4)
- User management beyond basic auth

## Dependencies

- Day 1 complete (WireGuard tunnel operational)
- Jellyseerr container deployed on home server
- Plex or Jellyfin configured for OAuth

## Deliverables

### Code
- `terraform/cloudflare/` - Updated with requests subdomain
- `ansible/roles/caddy/` - Caddy installation and configuration
- `ansible/roles/jellyseerr/` - Jellyseerr container validation

### Documentation
- Updated README with Jellyseerr access info
- Caddy configuration examples

## Validation Checklist

```bash
# 1. DNS resolves
dig requests.yourdomain.com

# 2. HTTPS accessible
curl -I https://requests.yourdomain.com

# 3. Valid SSL certificate
openssl s_client -connect requests.yourdomain.com:443 -servername requests.yourdomain.com

# 4. Jellyseerr responds
curl https://requests.yourdomain.com/api/v1/status
```

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Caddy conflicts with HAProxy | Use different ports, or migrate HAProxy to Caddy |
| Certificate rate limits | Test with Let's Encrypt staging first |
| OAuth integration fails | Fallback to local auth |

## Open Questions

- [ ] Should we migrate HAProxy to Caddy for consistency?
- [ ] Do we need authentication middleware (Authelia, etc.)?
