# FreeIPA Workshop Deployer Testing Guide

This document provides comprehensive testing procedures for the FreeIPA Workshop Deployer across all supported deployment patterns.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Test Environment Setup](#test-environment-setup)
3. [Testing Procedures](#testing-procedures)
4. [Provider-Specific Tests](#provider-specific-tests)
5. [Troubleshooting](#troubleshooting)
6. [Test Result Interpretation](#test-result-interpretation)

## Prerequisites

### General Requirements
- RHEL 9.5 system
- Root/sudo access
- Internet connectivity
- Git installed
- Ansible Core installed
- Python 3.x installed

### Provider-Specific Requirements

#### AWS Testing
- AWS account with appropriate permissions
- AWS CLI installed and configured
- Valid AWS access and secret keys
- Existing VPC or permissions to create one
- Route53 zone for DNS management
- Sufficient quota for m5.xlarge instances

#### DigitalOcean Testing
- DigitalOcean account
- Valid API token
- DNS zone configured in DigitalOcean
- Sufficient droplet quota

#### KCLI Testing
- KCLI installed and configured
- Libvirt/KVM environment set up
- Required VM images downloaded
- Local network configured

## Test Environment Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/freeipa-workshop-deployer.git
   cd freeipa-workshop-deployer
   ```

2. Run bootstrap script:
   ```bash
   sudo ./bootstrap.sh
   ```

3. Prepare configuration:
   ```bash
   cp example.vars.sh vars.sh
   # Edit vars.sh with your specific configuration
   ```

4. Validate environment:
   ```bash
   sudo ./validate.sh
   ```

## Testing Procedures

### 1. Base Environment Tests

```bash
# Test system requirements
cat /etc/redhat-release  # Should show RHEL 9.5
rpm -qa | grep -E "git|curl|wget|unzip|python3|ansible-core"  # Verify packages

# Test configuration
source vars.sh
echo $DOMAIN  # Verify variables are loaded
```

### 2. Infrastructure Tests

For each provider (aws/digitalocean/kcli), run:

```bash
# Deploy infrastructure
./total_deployer.sh

# Verify resources
# AWS
aws ec2 describe-instances --filters "Name=tag:Name,Values=idm"

# DigitalOcean
doctl compute droplet list

# KCLI
kcli list vm
```

### 3. Service Tests

```bash
# Test FreeIPA web UI access
curl -k https://${IDM_HOSTNAME}.${DOMAIN}

# Test DNS resolution
dig @${IP_ADDRESS} ${IDM_HOSTNAME}.${DOMAIN}

# Test LDAP
ldapsearch -x -h ${IDM_HOSTNAME}.${DOMAIN}
```

## Provider-Specific Tests

### AWS Deployment Tests

1. Infrastructure Verification:
   ```bash
   # Check instance status
   aws ec2 describe-instance-status

   # Verify security groups
   aws ec2 describe-security-groups

   # Test DNS records
   aws route53 list-resource-record-sets --hosted-zone-id $ZONE_ID
   ```

2. Network Tests:
   ```bash
   # Test security group connectivity
   nc -zv ${IP_ADDRESS} 443
   nc -zv ${IP_ADDRESS} 389
   ```

### DigitalOcean Deployment Tests

1. Infrastructure Verification:
   ```bash
   # Check droplet status
   doctl compute droplet get ${DROPLET_ID}

   # Verify firewall rules
   doctl compute firewall list

   # Test DNS records
   doctl compute domain records list ${DOMAIN}
   ```

2. Network Tests:
   ```bash
   # Test firewall rules
   nc -zv ${IP_ADDRESS} 443
   nc -zv ${IP_ADDRESS} 389
   ```

### KCLI Deployment Tests

1. Infrastructure Verification:
   ```bash
   # Check VM status
   kcli info vm freeipa

   # Verify network
   kcli list network

   # Test local DNS
   dig @${IP_ADDRESS} ${IDM_HOSTNAME}.${DOMAIN}
   ```

## Troubleshooting

### Common Issues

1. DNS Resolution Failures
   - Verify DNS forwarder configuration
   - Check DNS zone delegation
   - Validate record creation

2. Service Access Issues
   - Verify security group/firewall rules
   - Check service status on the instance
   - Validate network connectivity

3. Deployment Failures
   - Check resource quotas
   - Verify credentials
   - Review deployment logs

### Log Collection

Gather logs for troubleshooting:
```bash
# System logs
journalctl -xe

# FreeIPA logs
sudo tail -f /var/log/ipaserver-install.log

# Deployment logs
sudo tail -f /var/log/messages
```

## Test Result Interpretation

### Success Criteria

1. Environment Setup
   - All required packages installed
   - Configuration loaded correctly
   - Network prerequisites met

2. Infrastructure Deployment
   - Resources created successfully
   - Network connectivity established
   - DNS records propagated

3. Service Configuration
   - FreeIPA installed and running
   - Web UI accessible
   - LDAP services operational
   - User provisioning successful

### Test Reporting

Document test results including:
- Test date and environment
- Provider-specific details
- Test cases executed
- Issues encountered
- Resolution steps taken

### Cleanup Procedures

After testing, clean up resources:

```bash
# AWS
./1_infra_aws/destroy.sh

# DigitalOcean
./1_infra_digitalocean/destroy.sh

# KCLI
./1_kcli/destroy.sh
```

## References

- [FreeIPA Documentation](https://www.freeipa.org/page/Documentation)
- [AWS Testing Best Practices](https://aws.amazon.com/testing-tools/)
- [DigitalOcean API Documentation](https://docs.digitalocean.com/reference/api/)
- [KCLI Documentation](https://kcli.readthedocs.io/)
