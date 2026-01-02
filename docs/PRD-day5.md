# Product Requirements Document - Day 5: Documentation & Portability

## Overview

Finalize documentation, validate provider portability, create migration guides, and ensure the infrastructure can be easily reproduced or moved to different providers.

## Goals

- Complete, accurate documentation for all components
- Proven portability (demonstrate switching VPS/DNS providers)
- Onboarding guide for new contributors
- Architecture decision records (ADRs)
- Knowledge transfer materials

## Success Criteria

### Documentation
- [ ] Complete README with architecture overview
- [ ] Step-by-step deployment guide
- [ ] Troubleshooting runbook
- [ ] API/service integration docs
- [ ] Disaster recovery procedures
- [ ] Cost breakdown and optimization guide

### Portability Validation
- [ ] Test migration from Hetzner to different provider (DigitalOcean, Linode, AWS)
- [ ] Test DNS provider swap (Cloudflare → Route53)
- [ ] Terraform modules work with alternative providers
- [ ] Ansible playbooks are provider-agnostic

### Knowledge Transfer
- [ ] Architecture decision records (why WireGuard not Tailscale, etc.)
- [ ] Video walkthrough or detailed guide
- [ ] Common pitfalls and gotchas documented
- [ ] Contribution guide for extending the stack

### Quality Assurance
- [ ] End-to-end test suite automated
- [ ] Clean deployment from scratch (no manual steps)
- [ ] All secrets properly managed
- [ ] Code passes linting/formatting checks

## Technical Requirements

### Documentation Structure
```
docs/
├── PRD-day1.md → PRD-day5.md    # Product requirements
├── architecture.md               # Technical architecture
├── deployment.md                 # Step-by-step deployment
├── troubleshooting.md            # Common issues
├── monitoring.md                 # Observability guide
├── backup-restore.md             # DR procedures
├── security.md                   # Security hardening
├── cost-optimization.md          # Cost analysis
└── ADR/                          # Architecture Decision Records
    ├── 001-wireguard-bastion.md
    ├── 002-terraform-modules.md
    └── 003-ansible-structure.md
```

### Portability Testing
- Create Terraform modules for:
  - `modules/vps/` - Abstract VPS provisioning
  - `modules/dns/` - Abstract DNS management
  - `modules/firewall/` - Abstract firewall rules
- Provider implementations:
  - `providers/hetzner/`
  - `providers/digitalocean/`
  - `providers/aws/`
  - `providers/cloudflare-dns/`
  - `providers/route53-dns/`

### Quality Gates
- Terraform: `terraform fmt`, `terraform validate`
- Ansible: `ansible-lint`, YAML linting
- Scripts: shellcheck
- Markdown: markdownlint
- Pre-commit hooks for all checks

## Deliverables

### Documentation
- Complete `docs/` directory with all guides
- Inline code comments for complex logic
- README badges (build status, license, etc.)
- FAQ document
- Glossary of terms

### Portability
- Abstracted Terraform modules
- At least 2 provider implementations tested
- Migration guide between providers
- Cost comparison across providers

### Testing
- `scripts/test-deployment.sh` - Full E2E test
- `scripts/test-portability.sh` - Provider swap test
- CI/CD pipeline (GitHub Actions)
- Automated validation on PR

### Videos/Guides
- Architecture walkthrough video
- Deployment demo video
- Troubleshooting common issues video

## Validation Checklist

```bash
# 1. Clean deployment test
git clone <repo>
cp .env.example .env
# Fill in .env
./scripts/deploy.sh
# Should complete with no manual steps

# 2. Portability test
# Swap provider in terraform config
terraform apply
# Should work with minimal changes

# 3. Documentation completeness
# Every feature should be documented
# Every script should have --help
# Every config should have comments

# 4. Quality checks
terraform fmt -check
terraform validate
ansible-lint ansible/
shellcheck scripts/*.sh
markdownlint docs/

# 5. Disaster recovery test
# Delete everything
terraform destroy
# Restore from backups
./scripts/restore-from-backup.sh
# Verify all services operational
```

## Out of Scope

- Multi-region deployments
- High availability / failover
- Advanced CI/CD (beyond basic testing)
- Production SLA guarantees

## Dependencies

- Days 1-4 complete
- All services operational and monitored
- Backups tested and working

## Deliverables: Architecture Decision Records

### ADR-001: WireGuard Bastion vs. Tailscale/Cloudflare Tunnel
**Decision**: Use self-hosted WireGuard bastion
**Rationale**: Full control, no third-party dependencies, learning opportunity

### ADR-002: Terraform Module Structure
**Decision**: Provider-specific modules with abstraction layer
**Rationale**: Portability without over-engineering

### ADR-003: Ansible Host-Based Playbooks
**Decision**: Configure entire host in one playbook, not service-per-playbook
**Rationale**: Simpler dependencies, clearer deployment order

### ADR-004: WireGuard on Host vs. Container
**Decision**: Run WireGuard as systemd service on Docker host
**Rationale**: Preserves Docker network isolation, avoids `network_mode: host`

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Documentation becomes stale | Automated doc validation in CI |
| Portability not actually tested | Regular provider swap tests |
| Knowledge locked in one person | Pair programming, detailed docs |
| Complexity grows over time | Regular refactoring, simplicity reviews |

## Success Metrics

- [ ] Fresh deployment completes in <30 minutes
- [ ] Zero manual configuration steps
- [ ] Documentation enables new contributor to deploy in <2 hours
- [ ] Provider swap tested successfully
- [ ] All quality gates passing

## Open Questions

- [ ] Should we publish this as a template repository?
- [ ] License choice (MIT, Apache 2.0)?
- [ ] Blog post or guide series?
