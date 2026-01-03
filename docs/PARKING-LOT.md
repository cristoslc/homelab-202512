# Architecture Parking Lot

This document captures architecture ideas and discussions that are out of scope for current work but worth revisiting in future planning sessions.

## SSL/TLS Architecture

### Centralized Certificate Management (Bastion)

**Status:** Deferred from Day 1.5
**Last Updated:** 2026-01-02

**Concept:**
Move SSL termination from Caddy (home server) to HAProxy (bastion) using certbot for Let's Encrypt certificate management.

**Pros:**
- Centralized certificate management at network edge
- Better observability (all TLS termination in one place)
- No dependency on home network for certificate renewals
- Easier to add multiple services behind HAProxy

**Cons:**
- Requires Ansible HAProxy role changes
- Need certbot cron job for auto-renewal
- Need HAProxy reload mechanism (graceful, zero-downtime)
- Must choose: decrypt/re-encrypt (more secure) or HTTP-only backends (simpler but less secure tunnel)

**Implementation Considerations:**
- Certbot DNS-01 challenge (requires Cloudflare API token on bastion)
- HAProxy certificate reloading: `systemctl reload haproxy` or SIGUSR2
- Backend security: Keep TLS on tunnel (decrypt/re-encrypt) or accept HTTP for simplicity?
- Monitoring: Certificate expiry alerts, renewal success/failure

**When to revisit:**
- Day 4 (Production Hardening) if monitoring requirements justify centralization
- If adding 5+ services that need public HTTPS (certificate sprawl becomes issue)
- If home network becomes unreliable for certificate renewals

---

## Port Consolidation for Media Services

### Migrate Plex/Jellyfin to Port 443 with SNI Routing

**Status:** Deferred from Day 1.5
**Last Updated:** 2026-01-02

**Concept:**
Use HAProxy SNI routing to serve multiple services on port 443 instead of dedicated ports (32400 for Plex, 8920 for Jellyfin).

**Current Architecture:**
```
Internet :443  → HAProxy SNI → Caddy :8443 → Jellyseerr
Internet :32400 → HAProxy TCP → Plex :32400
Internet :8920  → HAProxy TCP → Jellyfin :8096
```

**Proposed Architecture:**
```
Internet :443 → HAProxy SNI Router
                ├─ requests.theblueroost.me → Caddy → Jellyseerr
                ├─ plex.theblueroost.me → Plex :32400
                └─ watch.theblueroost.me → Jellyfin :8096
```

**Pros:**
- Professional appearance (all services on standard port)
- Works through corporate firewalls that block non-standard ports
- Easier to explain to users ("just visit https://...")
- Single port to manage in firewall rules

**Cons:**
- Plex clients may expect port 32400 (compatibility risk)
- Requires testing with mobile apps, smart TVs, etc.
- May break existing user bookmarks/saved connections
- SNI routing adds complexity to HAProxy config

**Implementation Considerations:**
- Test Plex client compatibility with SNI routing
- Migration strategy: Support both ports during transition?
- Update all Plex server settings to advertise new URL
- Communication plan for users (update bookmarks)

**When to revisit:**
- Day 2+ when adding more public services
- If user feedback indicates port confusion
- After validating Plex client compatibility in test environment

---

## Cloudflare Proxy Mode

### Enable Cloudflare's Proxy for DDoS Protection

**Status:** Deferred from Day 1.5
**Last Updated:** 2026-01-02

**Concept:**
Change DNS records from DNS-only mode to Cloudflare proxy mode (orange cloud).

**Current:** DNS-only (gray cloud) - direct connection to bastion IP
**Proposed:** Proxy mode (orange cloud) - traffic routed through Cloudflare's network

**Pros:**
- Free DDoS protection (Cloudflare absorbs attacks)
- Web Application Firewall (WAF) available
- Automatic HTTPS (Cloudflare handles certificates at edge)
- Bot protection, rate limiting, analytics
- Hides bastion IP from public

**Cons:**
- Cloudflare sees all traffic (privacy concern)
- Added latency (extra hop through Cloudflare network)
- Less control over TLS configuration
- Potential issues with Plex/Jellyfin media streaming (large files)

**Portability Impact:**
- Locks into Cloudflare ecosystem
- Harder to migrate to different DNS provider
- But: Can disable proxy mode instantly if needed

**Implementation Considerations:**
- Test media streaming performance through Cloudflare proxy
- Evaluate latency impact for real-time services
- Configure Cloudflare SSL mode (Full or Full Strict)
- Review Cloudflare rate limiting vs. HAProxy rate limiting

**When to revisit:**
- If abuse/attacks occur on bastion IP
- If DDoS mitigation becomes necessary
- Day 4 (Production Hardening) security review
- If bastion IP becomes target of scanners/bots

**Migration Path:**
- Toggle proxy mode in Cloudflare dashboard (instant)
- Test all services still work
- Monitor performance for 24 hours
- Can revert instantly if issues occur

---

## Future Topics to Add

- Multi-region bastion failover (HA architecture)
- IPv6 support and dual-stack considerations
- Split-brain DNS (internal vs. external resolution)
- Service mesh for inter-container communication
- Monitoring and alerting architecture (Prometheus/Grafana)
- Backup and disaster recovery strategies

---

**Document Usage:**

This parking lot serves as a knowledge base for deferred decisions. When planning future days:
1. Review relevant sections for context
2. Evaluate whether conditions have changed
3. Move items to active PRDs if ready to implement
4. Update status and last updated date
5. Add implementation notes or test results
