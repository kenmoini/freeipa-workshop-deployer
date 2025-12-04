---
layout: page
title: Deployment Guide
permalink: /deployment/
---

# Deployment Guide

This guide covers both development and production deployment procedures for the FreeIPA Workshop Deployer.

## Development Deployment

### Prerequisites
- Development environment set up according to [Technical Setup](technical-setup.md)
- Access to chosen infrastructure provider (AWS/DigitalOcean/kcli)
- Proper DNS configuration

### Steps

1. **Bootstrap Environment**
   ```bash
   sudo ./bootstrap.sh
   ```
   This sets up the development environment with required dependencies.

2. **Configure Variables**
   - Copy example configuration:
     ```bash
     cp example.vars.sh vars.sh
     ```
   - Edit `vars.sh` with your specific configuration

3. **Validate Environment**
   ```bash
   ./validate.sh
   ```
   Ensures all prerequisites are met.

4. **Choose Provider**
   Select your infrastructure provider:
   - AWS: Use `sudo ./total_deployer.sh aws`
   - DigitalOcean: Use `sudo ./total_deployer.sh digitalocean`
   - kcli: Use `sudo ./total_deployer.sh kcli`

5. **Verify Installation**
   - Access FreeIPA web UI
   - Test user provisioning
   - Verify DNS configuration

### Development Notes
- Use smaller instance sizes for cost efficiency
- Test domains recommended for development
- Debug logging enabled by default
- Consider using local kcli deployment for testing


## Deployment Caveats

### Assumptions
- RHEL 9.5 is the primary supported platform
- Root/sudo access is available
- Internet connectivity for package installation
- DNS delegation is properly configured

### Known Limitations
- Other RHEL/CentOS versions not officially supported
- Cloud provider quotas may affect deployment
- DNS propagation may take time
- Certificate provisioning requires public DNS resolution

## Troubleshooting

### Common Issues
1. **DNS Issues**
   - Verify DNS delegation
   - Check record propagation
   - Validate DNS configuration

2. **Connectivity Problems**
   - Verify network configuration
   - Check security groups/firewall rules
   - Validate port accessibility

3. **Certificate Issues**
   - Verify DNS resolution
   - Check certificate configuration
   - Validate SSL setup

### Getting Help
- Check service logs
- Review deployment logs
- Consult documentation
- Examine system metrics

## Additional Resources
- [DNS Profiles Guide](dns_profiles.md)
- [Dynamic DNS Setup](dynamic_dns.md)
- [Testing Procedures](testing.md)
