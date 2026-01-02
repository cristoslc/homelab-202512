# Product Requirements Document - Day 4: Production Hardening

## Overview

Implement production-grade monitoring, backups, alerting, and security hardening for the entire homelab infrastructure.

## Goals

- Monitoring visibility into system health
- Automated backups of critical data
- Alerting for infrastructure failures
- Security hardening beyond base configuration
- Disaster recovery procedures documented

## Target Architecture

```
Monitoring:
  Prometheus (metrics collection)
  Grafana (visualization)
  Loki (log aggregation)
  Alertmanager (notifications)

Backups:
  Restic (encrypted backups)
  B2/S3 (remote storage)
  Automated daily snapshots
```

## Success Criteria

### Monitoring
- [ ] Prometheus collecting metrics from bastion and home server
- [ ] Grafana dashboards for infrastructure health
- [ ] WireGuard tunnel status monitoring
- [ ] Service uptime tracking (Plex, Jellyfin, *arr stack)
- [ ] Resource usage dashboards (CPU, RAM, disk, network)

### Alerting
- [ ] Alertmanager configured for critical alerts
- [ ] Notification channel (email, Slack, Discord, etc.)
- [ ] Alerts for:
  - WireGuard tunnel down
  - Services unreachable
  - Disk space >80%
  - High CPU/memory usage
  - SSL certificate expiry warnings

### Backups
- [ ] Automated daily backups of:
  - Ansible vault files
  - Terraform state
  - Application configs (*arr, Plex metadata)
  - Let's Encrypt certificates
- [ ] Encrypted backup storage (Restic)
- [ ] Retention policy (7 daily, 4 weekly, 12 monthly)
- [ ] Backup restoration tested

### Security Hardening
- [ ] fail2ban active on bastion
- [ ] SSH key-only auth (password disabled)
- [ ] UFW configured with minimal surface area
- [ ] Automated security updates
- [ ] Log rotation configured
- [ ] Intrusion detection (OSSEC or similar)

## Technical Requirements

### Monitoring Stack
- Prometheus: Port 9090 (WireGuard-only access)
- Grafana: Port 3000 (public via Caddy reverse proxy)
- Node Exporter: Metrics from both hosts
- WireGuard Exporter: Tunnel health metrics

### Backup Strategy
- Tool: Restic
- Storage: Backblaze B2 or AWS S3
- Schedule: Daily at 2 AM (cron)
- Encryption: Repository password in ansible-vault
- Pruning: Automated cleanup of old snapshots

### Security Tools
- fail2ban: SSH brute force protection
- unattended-upgrades: Automated security patches
- OSSEC or Wazuh: Host intrusion detection
- rkhunter: Rootkit detection

## Out of Scope

- Advanced SIEM or threat intelligence
- Multi-region redundancy
- Load balancing
- Database replication

## Dependencies

- Days 1-3 complete (all services operational)
- Backblaze B2 or AWS account for backup storage
- Notification service credentials (email SMTP, Slack webhook, etc.)

## Deliverables

### Code
- `ansible/roles/prometheus/` - Metrics collection
- `ansible/roles/grafana/` - Dashboard visualization
- `ansible/roles/alertmanager/` - Alert routing
- `ansible/roles/backup/` - Restic backup automation
- `ansible/roles/security-hardening/` - Advanced security config
- `terraform/` - Backup bucket provisioning (if using S3)

### Documentation
- `docs/monitoring.md` - Dashboard access and usage
- `docs/backup-restore.md` - Disaster recovery procedures
- `docs/runbook.md` - Operational procedures
- `docs/security.md` - Security hardening details

### Dashboards
- Infrastructure overview (CPU, RAM, disk)
- Service health (uptime, response times)
- WireGuard tunnel status
- Backup job status

## Validation Checklist

```bash
# 1. Prometheus collecting metrics
curl http://10.8.0.1:9090/api/v1/targets

# 2. Grafana accessible
curl -I https://grafana.yourdomain.com

# 3. Test alert firing
# (Temporarily stop WireGuard, verify alert received)

# 4. Backup created
restic -r $BACKUP_REPO snapshots

# 5. Restore test
restic -r $BACKUP_REPO restore latest --target /tmp/restore-test

# 6. Security tools active
sudo systemctl status fail2ban
sudo systemctl status unattended-upgrades
```

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Monitoring overhead impacts performance | Use resource limits, monitor the monitors |
| Backup storage costs | Implement retention policy, monitor usage |
| Alert fatigue | Tune thresholds, use alert grouping |
| Backup restore untested | Regular quarterly restore drills |

## Cost Estimate

- Monitoring: $0 (self-hosted)
- Backups: ~$1-5/month (B2 storage, depends on data size)
- **Total added cost: ~$1-5/month**

## Open Questions

- [ ] Which notification channel to use?
- [ ] On-premise backup in addition to cloud?
- [ ] Should we add uptime monitoring (UptimeRobot, Better Uptime)?
