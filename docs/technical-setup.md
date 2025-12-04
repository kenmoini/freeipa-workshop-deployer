---
layout: page
title: Technical Setup
permalink: /technical-setup/
---

# Technical Setup Guide

This guide covers the technologies, dependencies, and setup requirements for the FreeIPA Workshop Deployer.

## System Requirements

- **Primary OS:** RHEL 9.5
- **Memory:** Minimum 4GB RAM (8GB recommended)
- **Storage:** 20GB+ available storage
- **Network:** Internet connectivity required

## Required Software

### System Packages
```bash
# Core packages
git curl wget unzip python3 python3-pip firewalld ansible-core
```

### Python Packages
```bash
# Python dependencies
pip3 install dnspython netaddr
```

### Infrastructure Tools
- Terraform v0.13.4
- AWS CLI (~3.0) or DigitalOcean CLI or kcli

## Provider Setup

### AWS Configuration
- AWS Access Key
- AWS Secret Key
- VPC configuration
- Route53 DNS zone (if using AWS DNS)

### DigitalOcean Configuration
- Personal Access Token
- DNS zone configuration (if using DO DNS)

### kcli Configuration
- Network configuration
- Storage configuration
- Required VM images

## Ansible Collections

Required collections:
- ansible.posix
- community.general

Install collections:
```bash
ansible-galaxy collection install -r requirements.yml
```

## Network Requirements

### Required Ports
- 22 (SSH)
- 53 (DNS)
- 80/443 (HTTP/HTTPS)
- 389/636 (LDAP/LDAPS)
- 88/464 (Kerberos)
- 123 (NTP)

## Technical Constraints

### Operating System
- Primary support for RHEL 9.5
- Other RHEL/CentOS versions not officially supported
- SELinux must be properly configured
- Firewall management through firewalld

### Access Requirements
- Root/sudo access required
- Internet connectivity needed
- DNS delegation properly configured

### Security Considerations
- Public-facing ports and services require security audit
- Proper firewall rules must be configured
- SSL certificates required for secure services

## Development Environment

### Directory Structure
- `infrastructure/`: Terraform configurations
- `ansible/`: Ansible playbooks and roles
- `scripts/`: Utility scripts and tools
- `docs/`: Project documentation

### Version Control
- All infrastructure code version-controlled
- Terraform state files managed separately
- Configuration templates tracked in Git

### Testing Environment
- Development environments use smaller instances
- Test domains for development work
- Debug logging enabled for troubleshooting

## Monitoring and Management

### Logging
- System logs
- Deployment logs
- Service logs
- Test execution logs

### Metrics
- Deployment time tracking
- Resource utilization monitoring
- Service response times
- DNS propagation monitoring

## Additional Resources

- [DNS Profiles Documentation](dns_profiles.md)
- [Dynamic DNS Documentation](dynamic_dns.md)
- [Testing Documentation](testing.md)
