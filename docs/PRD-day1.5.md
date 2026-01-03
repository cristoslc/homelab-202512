# Product Requirements Document - Day 1.5: Jellyseerr Public Access

## Overview

Expose Jellyseerr to the internet through bastion HAProxy, enabling immediate cancellation of ISP static IP service. Use SNI filtering to expose ONLY Jellyseerr publicly while keeping all other services (Sonarr/Radarr/*arr stack) internal-only via Tailscale.

## Critical Business Goal

**Eliminate ISP static IP dependency within 24 hours** to enable cancellation of Fidium ISP service.

**Cost Savings:** $80/month (switch to GoNetSpeed-only instead of dual ISP setup)

## Current State Discovery

**Home Network (homelab_SPS_instance):**
- Caddy reverse proxy running on port 8443
- Self-signed certificates (`local_certs` in Caddyfile)
- Services behind Caddy:
  - `requests.theblueroost.me:8443` → Jellyseerr (PUBLIC CANDIDATE)
  - `jellyseerr.lab2.theblueroost.me:8443` → Jellyseerr (INTERNAL ONLY)
  - `sonarr.lab2.theblueroost.me:8443` → Sonarr (INTERNAL ONLY)
  - `radarr.lab2.theblueroost.me:8443` → Radarr (INTERNAL ONLY)
  - `prowlarr.lab2.theblueroost.me:8443` → Prowlarr (INTERNAL ONLY)
  - `nzbget.lab2.theblueroost.me:8443` → NZBGet (INTERNAL ONLY)
  - `bazarr.lab2.theblueroost.me:8443` → Bazarr (INTERNAL ONLY)
  - `agregarr.lab2.theblueroost.me:8443` → Agregarr (INTERNAL ONLY)

**Day 1 Completed:**
- Bastion VPS operational with WireGuard tunnel
- HAProxy configured for Plex (:32400) and Jellyfin (:8920)
- Let's Encrypt certificates managed by certbot

**Security Decision:**
- **PUBLIC**: `requests.theblueroost.me` only (Jellyseerr for user requests)
- **INTERNAL**: All `*.lab2.theblueroost.me` services (access via Tailscale)

## Target Architecture

```
Internet → requests.theblueroost.me:443 (Cloudflare DNS)
         → Bastion VPS (10.8.0.1)
           ├─ HAProxy :32400 → WireGuard → 10.8.0.2:32400 → Plex
           ├─ HAProxy :8920  → WireGuard → 10.8.0.2:8096  → Jellyfin
           └─ HAProxy :443 (SNI filter) → WireGuard → 10.8.0.2:8443 → Caddy
                                                                       └─ Jellyseerr

Tailscale → *.lab2.theblueroost.me:8443 → Home Network → Caddy
                                                          ├─ Sonarr
                                                          ├─ Radarr
                                                          ├─ Prowlarr
                                                          └─ Other *arr services
```

**Key Design Decisions:**

1. **Standard HTTPS port**: Public traffic uses 443 (no weird ports for users)
2. **SNI filtering**: HAProxy inspects TLS SNI, only forwards `requests.theblueroost.me`
3. **Port mapping**: 443 (public) → 8443 (home Caddy)
4. **Sequential deployment**: Infrastructure first (quick wins), then certificates (polish)
5. **Same-day completion**: Both steps executed back-to-back, no waiting period

## Implementation Steps

This deployment consists of two sequential steps executed on the same day. Step 1 establishes connectivity and enables immediate business value (static IP cancellation). Step 2 immediately follows to polish the user experience with valid certificates.

### Step 1: HAProxy Port Mapping & SNI Filter

**Duration:** 1 hour

**Goal:** Enable public Jellyseerr access with immediate business value

**Deliverables:**
- HAProxy 443→8443 TCP passthrough with SNI filtering
- Bastion firewall allows 443/tcp
- Cloudflare DNS: `requests.theblueroost.me` → bastion IP
- Validation: Jellyseerr accessible (with browser cert warning)
- ✅ **Static IP can be cancelled**

**HAProxy Configuration:**
```haproxy
frontend https_443
    bind *:443
    mode tcp
    option tcplog

    # Enhanced logging for security monitoring
    log-format "%ci:%cp [%t] %ft %b/%s %Tw/%Tc/%Tt %B %ts %ac/%fc/%bc/%sc/%rc %sq/%bq %{+Q}r"

    # Inspect TLS SNI without decryption
    tcp-request inspect-delay 5s
    tcp-request content accept if { req_ssl_hello_type 1 }

    # Only allow requests.theblueroost.me
    acl is_jellyseerr req_ssl_sni -i requests.theblueroost.me

    # Edge case: clients that don't send SNI (old browsers, bots)
    acl has_sni req_ssl_sni -m found

    # Route allowed traffic, reject others with logging
    use_backend home_caddy if is_jellyseerr
    use_backend reject_no_sni if !has_sni
    default_backend reject_connection

backend home_caddy
    mode tcp
    server homelab 10.8.0.2:8443 check

backend reject_connection
    mode tcp
    # No server configured - connection rejected
    # Logged for security monitoring

backend reject_no_sni
    mode tcp
    # Reject connections without SNI (legacy clients or scanners)
    # Logged separately for analysis
```

**SNI Filtering Edge Case Mitigation:**

1. **Logging**: Enhanced `log-format` captures all connection attempts including rejected ones
2. **No-SNI handling**: Explicit backend for clients that don't send SNI (prevents undefined behavior)
3. **Monitoring**: Review `/var/log/haproxy.log` for rejected connections to identify false positives
4. **Fallback option**: If legitimate clients are blocked, can temporarily route no-SNI traffic to Caddy (which will reject at Layer 7)

**Rate Limiting Configuration:**

```haproxy
# Add to frontend https_443 after bind directive
frontend https_443
    # ... existing config ...

    # Rate limiting: max 20 connections per second per IP
    stick-table type ip size 100k expire 30s store conn_rate(10s)
    tcp-request connection track-sc0 src
    tcp-request connection reject if { sc_conn_rate(0) gt 20 }
```

**Rate Limiting Rationale:**
- **Proactive protection**: Prevents abuse before it impacts service
- **Conservative limit**: 20 connections/second allows legitimate usage (browsing, API calls)
- **Short window**: 10-second measurement window catches bursts without penalizing normal users
- **Memory efficient**: 100k IP table (~4MB RAM) handles large-scale attacks

**Terraform Changes:**
```hcl
# terraform/hetzner/firewall.tf
resource "hcloud_firewall" "bastion" {
  # ... existing rules ...

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
}
```

**Cloudflare DNS:**
```hcl
# terraform/cloudflare/dns.tf
resource "cloudflare_record" "requests" {
  zone_id = var.cloudflare_zone_id
  name    = "requests"
  type    = "A"
  value   = var.bastion_ip
  ttl     = 1  # Auto (required when proxied = true)
  proxied = true  # Orange cloud: DDoS protection, WAF, bot mitigation for Jellyseerr
}
```

**Cloudflare Proxy Strategy Decision:**
- ✅ `requests.theblueroost.me` (Jellyseerr): **Proxied** - Benefits from DDoS protection, WAF, rate limiting
- ✅ `watch.theblueroost.me` (Jellyfin): **DNS-only** - Direct connection for optimal media streaming performance
- ✅ `plex.theblueroost.me` (Plex): **DNS-only** - Direct connection (existing Day 1 config)

**Cloudflare SSL/TLS Configuration (Manual - One Time Setup):**

**IMPORTANT:** After Terraform creates the DNS record, configure SSL/TLS mode in Cloudflare Dashboard:

1. Log in to **Cloudflare Dashboard** → Select zone → **SSL/TLS** tab
2. Click **Overview**
3. Select encryption mode: **Full (strict)**

**Encryption Flow:**
```
Internet → Cloudflare Edge (Cloudflare Universal SSL cert)
         → Bastion HAProxy :443 (SNI passthrough, TCP mode - no TLS termination)
           → WireGuard Tunnel (encrypted)
             → Home Caddy :8443 (Let's Encrypt cert from Step 2)
               → Jellyseerr container
```

**Why Full (strict)?**
- ✅ End-to-end encryption maintained (meets requirement: "still want TLS for cloudflare connection")
- ✅ Cloudflare validates Caddy's Let's Encrypt certificate (MITM protection)
- ✅ HAProxy passes through encrypted TLS without decryption (maintains privacy)
- ✅ Cloudflare provides outer DDoS/WAF layer, inner encryption preserved

**How it Works:**
- Client → Cloudflare: HTTPS with Cloudflare's certificate (trusted by browsers)
- Cloudflare → HAProxy: New HTTPS connection with SNI `requests.theblueroost.me`
- HAProxy: TCP passthrough (inspects SNI, doesn't decrypt), forwards to WireGuard
- Caddy: Terminates TLS with Let's Encrypt certificate, Cloudflare validates it

**Note:** This is NOT traditional SSL termination at Cloudflare. HAProxy operates in TCP mode, so the TLS connection from Cloudflare → Caddy remains encrypted through the bastion.

**Expected User Experience:**
- Navigate to `https://requests.theblueroost.me`
- ⚠️ Browser shows certificate warning (self-signed cert from Caddy)
- User clicks "Advanced" → "Proceed anyway"
- Jellyseerr loads normally

**Validation Checklist:**
```bash
# 1. HAProxy listening on 443
ansible bastion -m shell -a "ss -tlnp | grep :443"

# 2. SNI filtering works
curl -Ik --resolve requests.theblueroost.me:443:<bastion_ip> https://requests.theblueroost.me

# 3. Other domains rejected
curl -Ik --resolve badactor.com:443:<bastion_ip> https://badactor.com  # Should fail

# 4. DNS resolution
dig requests.theblueroost.me  # Should return bastion IP

# 5. External access test
curl -Ik https://requests.theblueroost.me  # Accept self-signed cert warning
```

### Step 2: Valid Let's Encrypt Certificates

**Duration:** 1 hour

**Goal:** Obtain valid Let's Encrypt certificates, eliminate browser warnings

**Note:** This step executes immediately after Step 1 validation. No waiting period required.

**Architectural Decision: Certificate Location**

Two options for SSL termination:

**Option A: Caddy on Home Server (RECOMMENDED - Selected)**
- ✅ **Pros**: Caddy already running, automatic renewal built-in, DNS-01 already configured for other services
- ✅ **IaC Simplicity**: No Ansible changes needed, just home server configuration
- ✅ **Portability**: Caddy config stays with application stack
- ⚠️ **Cons**: DNS-01 requires Cloudflare API access from home network

**Option B: HAProxy with Certbot on Bastion**
- ✅ **Pros**: Centralized certificate management, no home network dependency for renewals
- ✅ **Better observability**: All TLS termination at edge, easier to monitor
- ⚠️ **Cons**: Requires Ansible HAProxy role changes, certbot cron setup, certificate reloading logic
- ⚠️ **Complexity**: Must decrypt/re-encrypt or change Caddy to HTTP-only backend

**Decision Rationale:** Option A (Caddy) minimizes changes and leverages existing infrastructure. Option B deferred to future architecture discussion (see `docs/PARKING-LOT.md`).

**Deliverables:**
- Caddyfile updated for DNS-01 ACME challenge
- Caddy environment with Cloudflare API token
- Automatic certificate issuance and renewal
- ✅ **No browser warnings**

**Caddyfile Changes:**
```caddyfile
# Global settings
{
    # Remove this line:
    # local_certs

    # Add DNS-01 challenge with Cloudflare
    acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}
}

# Jellyseerr - Public access (already configured)
requests.theblueroost.me:8443 {
    reverse_proxy jellyseerr:5055 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
    }

    # Security headers
    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        X-XSS-Protection "1; mode=block"
        Referrer-Policy strict-origin-when-cross-origin
        -Server
    }

    # Logging
    log {
        output file /var/log/caddy/requests.log
        format json
    }
}

# All existing lab2 entries remain unchanged
# ...
```

**Docker Compose Changes (homelab_SPS_instance):**
```yaml
services:
  caddy:
    image: caddy:2-alpine
    container_name: caddy-reverse-proxy
    ports:
      - "8443:8443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - proxy
    restart: unless-stopped
    environment:
      - CADDY_DISABLE_HTTP_CHALLENGE=true
      - CLOUDFLARE_API_TOKEN=${CLOUDFLARE_API_TOKEN}  # <-- ADD THIS
```

**Cloudflare API Token Setup:**

1. Log in to Cloudflare Dashboard → My Profile → API Tokens
2. Click "Create Token"
3. Use "Edit zone DNS" template (or create custom token):
   - **Permissions**: `Zone:DNS:Edit`
   - **Zone Resources**: Include → Specific zone → `theblueroost.me`
   - **TTL**: No expiry (or set to 1 year+ with calendar reminder)
4. Copy token (only shown once!)

**Required Token Permissions (minimum):**
```
Zone:DNS:Edit - Allows creating/modifying DNS records for ACME challenges
```

**Security Note:** Do NOT grant broader permissions (Account, Zone Settings, etc.). Caddy only needs DNS record creation for Let's Encrypt validation.

**Home Server .env Addition:**
```bash
# Add to homelab_SPS_instance/.env
CLOUDFLARE_API_TOKEN=your_cloudflare_api_token_here  # Zone:DNS:Edit permission only
```

**Deployment Process (Automated via Ansible):**

**Decision:** Use Ansible role for IaC compliance (Zero manual steps principle)

The `caddy-jellyseerr` Ansible role (stored in `homelab-202512/ansible/roles/`) will:
1. Validate Caddy container exists on home server
2. Template Caddyfile with DNS-01 ACME configuration
3. Add CLOUDFLARE_API_TOKEN to `.env` file (using `lineinfile` module)
4. Update `docker-compose.yml` to pass environment variable to Caddy container
5. Restart Caddy via `docker-compose down && docker-compose up -d`
6. Wait for and validate certificate acquisition

**Execution:**
```bash
# From homelab-202512 repository
cd ansible

# Run playbook (uses ansible_connection: local for home server)
ansible-playbook playbooks/homeserver.yml --tags caddy

# Monitor Caddy logs for cert acquisition
ansible homeserver -m shell -a "docker logs --tail 50 caddy-reverse-proxy"
# Should see: "certificate obtained successfully"
```

**Role Variables (defined in group_vars or role defaults):**
```yaml
caddy_home_path: /home/cristos/git/homelab_SPS_instance/reverse-proxy
cloudflare_api_token: "{{ lookup('env', 'CLOUDFLARE_API_TOKEN') }}"
acme_server: https://acme-v02.api.letsencrypt.org/directory  # Production
# acme_server: https://acme-staging-v02.api.letsencrypt.org/directory  # Staging
```

**Expected Behavior:**
- Caddy contacts Cloudflare API
- Creates TXT record: `_acme-challenge.requests.theblueroost.me`
- Let's Encrypt validates via DNS
- Certificate issued and stored in `caddy_data` volume
- Auto-renewal every 60 days

**Validation Checklist:**
```bash
# 1. Valid certificate installed
openssl s_client -connect requests.theblueroost.me:443 -servername requests.theblueroost.me \
  | grep -A2 "Verify return code"
# Should show: "Verify return code: 0 (ok)"

# 2. Certificate issuer is Let's Encrypt
curl -vI https://requests.theblueroost.me 2>&1 | grep "issuer"
# Should contain: "Let's Encrypt"

# 3. No browser warnings
# Open in browser: https://requests.theblueroost.me
# Should show green padlock, no warnings

# 4. Auto-renewal configured
docker exec caddy-reverse-proxy caddy list-certificates
# Should show expiry date ~90 days in future
```

## Success Criteria

### Step 1 Complete
- [ ] Terraform state backed up
- [ ] HAProxy listening on port 443
- [ ] HAProxy rate limiting active (20 conn/sec per IP)
- [ ] SNI filtering allows only `requests.theblueroost.me`
- [ ] SNI filtering logs rejected connections
- [ ] DNS resolves to bastion IP
- [ ] Jellyseerr accessible (with cert warning acceptable)
- [ ] Layer 7 health check passes (API returns version)
- [ ] Plex and Jellyfin still working (no regression)
- [ ] **Static IP NAT rules can be removed**
- [ ] **ISP static IP service can be cancelled**

### Step 2 Complete
- [ ] Staging Let's Encrypt test successful
- [ ] Caddy obtains production Let's Encrypt certificate
- [ ] Browser shows valid certificate (green padlock)
- [ ] No security warnings when accessing Jellyseerr
- [ ] Certificate auto-renewal configured
- [ ] Layer 7 health check passes with valid cert
- [ ] All internal `*.lab2.*` services still accessible via Tailscale

## Out of Scope

- Exposing *arr stack publicly (intentionally internal-only)
- Migrating Caddy to bastion
- Authentication middleware (Jellyseerr has built-in auth)
- Port 443 for Plex/Jellyfin (keep current ports for media streaming)

## Dependencies

### Prerequisites
- Day 1 complete (WireGuard tunnel operational)
- Caddy running on home network port 8443
- Jellyseerr container running
- Cloudflare API token with DNS edit permissions

### Required Access
- Cloudflare account (for DNS and API token)
- Home server SSH access (for Caddy restart in Phase 1.5b)

## Deliverables

### Code - Infrastructure as Code (Terraform + Ansible)

**Step 1: Infrastructure**
- `terraform/hetzner/firewall.tf` - Add 443/tcp firewall rule
- `terraform/cloudflare/dns.tf` - Add `requests.theblueroost.me` A record (proxied=true)
- `ansible/roles/haproxy/templates/haproxy.cfg.j2` - Add 443 frontend with:
  - SNI filtering (allow only requests.theblueroost.me)
  - Rate limiting (20 conn/sec per IP)
  - Enhanced logging for security monitoring
  - No-SNI edge case handling

**Step 2: Caddy Automation (NEW)**
- `ansible/roles/caddy-jellyseerr/` - Complete Ansible role for home server Caddy management
  - `tasks/main.yml` - Container validation, Caddyfile templating, .env updates, Caddy restart
  - `templates/Caddyfile.j2` - Jinja2 template with DNS-01 ACME configuration
  - `templates/docker-compose.yml.j2` - Docker Compose with CLOUDFLARE_API_TOKEN env var
  - `defaults/main.yml` - Default variables (acme_server, caddy_home_path)
  - `handlers/main.yml` - Caddy restart handler
- `ansible/playbooks/homeserver.yml` - Updated to include caddy-jellyseerr role
- `ansible/inventory/group_vars/homeserver/caddy.yml` - Caddy-specific variables

**Note:** All home server configuration managed via `ansible_connection: local` from homelab-202512 repo. Maintains "Zero manual steps" IaC principle.

### Validation Scripts
- `scripts/test-sni-filter.sh` - SNI filtering tests + Layer 7 health checks
  - Tests allowed domain (requests.theblueroost.me)
  - Tests rejected domains (security validation)
  - Jellyseerr API health check (`/api/v1/status`)
  - Web UI HTML validation
- `scripts/validate-certificates.sh` - Certificate validation
  - Verify certificate issuer (Let's Encrypt)
  - Check expiry date (90 days)
  - Validate certificate chain

### Documentation
- `docs/PRD-day1.5.md` - This document (updated with decisions)
- `docs/PARKING-LOT.md` - Future architecture discussions (NEW)
  - Centralized SSL termination on bastion
  - Port consolidation for media services
  - Cloudflare proxy mode trade-offs
- `README.md` - Updated with Jellyseerr public access URL
- Cloudflare SSL/TLS mode setup instructions (Full strict)

## Migration Procedure

### Step 1 Deployment (Zero Downtime)

**Prerequisites:**
```bash
# Verify Day 1 complete
./scripts/validate-day1.sh

# Backup Terraform state before changes
cd terraform
cp terraform.tfstate terraform.tfstate.backup-$(date +%Y%m%d-%H%M%S)
cd ..
```

1. **Update Terraform** (5 min)
   ```bash
   cd terraform
   terraform plan  # Review firewall and DNS changes
   terraform apply
   ```

2. **Deploy Ansible** (5 min)
   ```bash
   cd ansible
   # HAProxy config automatically updated
   ansible-playbook playbooks/bastion.yml
   ```

3. **Validate** (5 min)
   ```bash
   # Test SNI filtering
   curl -Ik --resolve requests.theblueroost.me:443:<bastion_ip> https://requests.theblueroost.me

   # Confirm other domains rejected
   curl -Ik --resolve test.example.com:443:<bastion_ip> https://test.example.com
   ```

4. **Update DNS** (5 min)
   - Terraform already created record
   - Wait 2-5 minutes for propagation
   - Test: `dig requests.theblueroost.me`

5. **External Validation** (5 min)
   - Mobile network or VPN
   - Access `https://requests.theblueroost.me`
   - Accept certificate warning
   - Verify Jellyseerr loads

6. **Monitor** (24-48 hours)
   - Confirm all services accessible through bastion
   - Check HAProxy logs for rejected connections
   - Verify no ISP static IP traffic

7. **Remove ISP NAT Rules** (2 min)
   - Disable port forwards on home router
   - Confirm services still accessible

8. **Cancel Static IP Service** (varies by ISP)
   - Contact ISP to cancel static IP
   - Immediate monthly cost savings

### Step 2 Deployment (Automated via Ansible)

**Note:** Execute immediately after Step 1 validation completes.

**Prerequisites:**
```bash
# Ensure CLOUDFLARE_API_TOKEN is in environment (from .env)
source .env
echo $CLOUDFLARE_API_TOKEN  # Should show token value

# Backup current Caddy configuration (Ansible does this automatically, but verify)
ansible homeserver -m shell -a "cd /home/cristos/git/homelab_SPS_instance/reverse-proxy && cp Caddyfile Caddyfile.backup-\$(date +%Y%m%d-%H%M%S)"
```

**2a. Test with Staging Certificates First** (10 min - RECOMMENDED)

```bash
# From homelab-202512 repository
cd ansible

# Set staging ACME server via extra vars
ansible-playbook playbooks/homeserver.yml --tags caddy \
  --extra-vars "acme_server=https://acme-staging-v02.api.letsencrypt.org/directory"

# Monitor Caddy logs
ansible homeserver -m shell -a "docker logs --tail 100 -f caddy-reverse-proxy" &

# Watch for "certificate obtained successfully" in logs
# Ctrl+C to stop log monitoring

# Validate staging cert obtained
curl -Ik https://requests.theblueroost.me  # Will show staging cert warning (expected)

# If successful, proceed to production. If failed, debug before production attempt.
```

**2b. Deploy Production Certificates** (5 min)

```bash
# Run playbook with production ACME server (default)
ansible-playbook playbooks/homeserver.yml --tags caddy

# Or explicitly set production URL:
# ansible-playbook playbooks/homeserver.yml --tags caddy \
#   --extra-vars "acme_server=https://acme-v02.api.letsencrypt.org/directory"

# Monitor certificate acquisition
ansible homeserver -m shell -a "docker logs --tail 100 caddy-reverse-proxy"
# Watch for "certificate obtained successfully"
```

**2c. Validate** (5 min)

```bash
# Check certificate validity
openssl s_client -connect requests.theblueroost.me:443 \
  -servername requests.theblueroost.me | grep "Verify return code"
# Should show: "Verify return code: 0 (ok)"

# Browser test (open in browser)
# https://requests.theblueroost.me - should show green padlock, no warnings

# Run full validation suite
cd /home/cristos/git/homelab-202512
./scripts/test-sni-filter.sh  # Includes Layer 7 health check

# Verify certificate expiry
ansible homeserver -m shell -a "docker exec caddy-reverse-proxy caddy list-certificates"
# Should show ~90 days until expiry
```

**Rollback (if needed):**
```bash
# Restore backed-up Caddyfile
ansible homeserver -m shell -a "cd /home/cristos/git/homelab_SPS_instance/reverse-proxy && cp Caddyfile.backup-TIMESTAMP Caddyfile && docker-compose restart caddy"
```

### Rollback Plan

**Step 1 Rollback:**
1. Revert Cloudflare DNS to ISP static IP (Terraform: `terraform destroy` specific resource)
2. Re-enable NAT rules on home router
3. Restore Terraform state from backup if needed: `cp terraform.tfstate.backup-TIMESTAMP terraform.tfstate`
4. Services immediately accessible again (5-60 min DNS propagation globally)

**Step 2 Rollback:**
1. Restore backed-up Caddyfile: `cp Caddyfile.backup-TIMESTAMP Caddyfile`
2. Restart Caddy: `docker-compose restart caddy`
3. Self-signed certs restored (services work, browser warnings return)

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| SNI filtering blocks legitimate traffic | Test with curl before DNS cutover, verify `requests.theblueroost.me` whitelisted |
| DNS-01 challenge fails (wrong API token) | Test token with `curl` before Caddy restart, use Cloudflare API docs |
| Caddy can't reach Cloudflare API | Ensure home network allows outbound HTTPS, check firewall rules |
| Let's Encrypt rate limit hit | Use staging environment first (`acme_ca https://acme-staging-v02.api.letsencrypt.org/directory`) |
| Certificate renewal fails in 60 days | Set calendar reminder, check Caddy logs monthly |
| Users access `*.lab2.*` domains from internet | Not possible - DNS records don't exist publicly, Tailscale-only access |

## Security Considerations

### SNI Filtering Benefits
- Only `requests.theblueroost.me` accessible from internet
- All `*.lab2.*` services invisible to public scanners
- Reduces attack surface (only Jellyseerr exposed)
- Silent rejection of unknown domains (no info disclosure)

### Certificate Security
- DNS-01 challenge doesn't expose internal services
- Let's Encrypt certificates auto-renew (no manual process)
- Cloudflare API token scoped to DNS edit only (not full account access)

### Internal Service Protection
- Sonarr/Radarr/Prowlarr accessible only via Tailscale
- No public DNS records for `*.lab2.*` domains
- Caddy still validates requests internally (second layer of security)

## Cost Impact

**Monthly Savings:**
- Cancel Fidium ISP entirely: $80/month
- Switch to GoNetSpeed-only (no static IP needed)
- Bastion VPS cost: €4.51/month (~$4.75/month - already deployed in Day 1)

**Net Savings:** $80 - $4.75 = **$75.25/month** (~$903/year)

**No Additional Infrastructure Cost:** Using existing bastion VPS, Cloudflare free tier.

**ROI:** Bastion pays for itself in perpetuity while providing additional benefits (WireGuard VPN, reverse proxy platform for future services).

## Open Questions

**Resolved:**
- ✅ Which reverse proxy? **Caddy (discovered in homelab_SPS_instance)**
- ✅ Which services to expose? **Only Jellyseerr (requests.theblueroost.me)**
- ✅ Public port? **443 (standard HTTPS)**
- ✅ Certificate strategy? **Step 1: self-signed (quick), Step 2: DNS-01 Let's Encrypt (staging then production)**
- ✅ Rate limiting? **Yes, added HAProxy stick-table (20 conn/sec per IP)**
- ✅ SSL termination location? **Caddy on home server (Option A) - bastion termination deferred**
- ✅ **Cloudflare proxy mode?** **Yes, for Jellyseerr only (requests.theblueroost.me), Full (strict) SSL/TLS**
- ✅ **Home server automation?** **Yes, Ansible role (caddy-jellyseerr) stored in homelab-202512 repo**

**Deferred to PARKING-LOT.md:**
- [ ] Should Plex/Jellyfin migrate to 443 with SNI routing?
- [ ] Centralized SSL termination on bastion (HAProxy + certbot)?
- [ ] Cloudflare proxy for media streaming services?

## Timeline

**Step 1: 1-2 hours**
- Terraform state backup: 1 min
- Terraform/Ansible deployment: 30 min
- DNS propagation: 5-10 min
- Validation (SNI + Layer 7 health check): 15 min
- Monitoring before static IP cancellation: 24-48 hours (passive)

**Step 2: 1-2 hours** (execute immediately after Step 1 validation)
- Configuration backup: 1 min
- Staging Let's Encrypt test: 10 min
- Production certificate acquisition: 10-15 min
- Validation (cert + Layer 7 health check): 10 min

**Total Active Work: 2-4 hours** (same day, sequential execution)
**Passive Monitoring: 24-48 hours** before ISP cancellation

## Validation Scripts

### SNI Filter & Layer 7 Health Check
```bash
#!/bin/bash
# test-sni-filter.sh

BASTION_IP=$(terraform output -raw bastion_ip)

echo "=== SNI Filtering Tests ==="
echo ""

echo "Testing allowed domain (requests.theblueroost.me)..."
curl -Ik --resolve requests.theblueroost.me:443:$BASTION_IP https://requests.theblueroost.me
if [ $? -eq 0 ]; then
    echo "✅ Allowed domain passes"
else
    echo "❌ Allowed domain blocked (FAIL)"
    exit 1
fi

echo ""
echo "Testing rejected domain (badactor.com)..."
curl -Ik --connect-timeout 5 --resolve badactor.com:443:$BASTION_IP https://badactor.com
if [ $? -ne 0 ]; then
    echo "✅ Rejected domain blocked"
else
    echo "❌ Rejected domain allowed (SECURITY ISSUE)"
    exit 1
fi

echo ""
echo "=== Layer 7 Application Health Check ==="
echo ""

# Test actual Jellyseerr API endpoint (requires valid response)
echo "Testing Jellyseerr API endpoint..."
RESPONSE=$(curl -sk https://requests.theblueroost.me/api/v1/status)

if echo "$RESPONSE" | grep -q '"version"'; then
    echo "✅ Jellyseerr API responding (Layer 7 OK)"
    echo "Response: $RESPONSE"
else
    echo "❌ Jellyseerr API not responding correctly"
    echo "Response: $RESPONSE"
    exit 1
fi

# Test HTML page load (ensure reverse proxy headers work)
echo ""
echo "Testing Jellyseerr web UI..."
HTML_RESPONSE=$(curl -sk https://requests.theblueroost.me/ | head -n 20)

if echo "$HTML_RESPONSE" | grep -qi "jellyseerr\|overseerr"; then
    echo "✅ Jellyseerr web UI loading"
else
    echo "⚠️ Unexpected HTML response (may still work, check manually)"
fi

echo ""
echo "=== All Tests Complete ==="
```

### Certificate Validation
```bash
#!/bin/bash
# validate-certificates.sh

echo "Checking certificate for requests.theblueroost.me..."
CERT_OUTPUT=$(echo | openssl s_client -connect requests.theblueroost.me:443 \
  -servername requests.theblueroost.me 2>&1)

if echo "$CERT_OUTPUT" | grep -q "Verify return code: 0"; then
    echo "✅ Valid certificate installed"
    echo "$CERT_OUTPUT" | grep "issuer"
else
    echo "⚠️ Certificate validation failed (expected in Phase 1.5a)"
    echo "$CERT_OUTPUT" | grep "Verify return code"
fi

# Check expiry
EXPIRY=$(echo "$CERT_OUTPUT" | openssl x509 -noout -enddate 2>/dev/null)
echo "Certificate expiry: $EXPIRY"
```

## Success Metrics

**Step 1:**
- Terraform state safely backed up
- HAProxy 443 frontend active with rate limiting
- SNI ACL blocking non-whitelisted domains (with logging)
- `requests.theblueroost.me` resolving to bastion
- Jellyseerr accessible and Layer 7 health check passing
- No regression to existing services (Plex, Jellyfin)
- Static IP service can be cancelled after monitoring period

**Step 2:**
- Staging Let's Encrypt test successful (validates DNS-01 flow)
- Valid production Let's Encrypt certificate obtained
- Browser green padlock on `requests.theblueroost.me`
- Certificate expiry 90 days in future
- Auto-renewal configured
- Layer 7 health check passing with valid certificate

**Overall:**
- Zero manual steps required (IaC principle maintained)
- Monthly cost savings achieved: **$75.25/month**
- Security posture improved (SNI filtering + rate limiting + valid certs + logging)
- User experience: standard port 443, no browser warnings, professional appearance
- Platform ready for Day 2+ service additions
