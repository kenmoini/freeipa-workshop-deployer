---
layout: page
title: Validation and Deployment Scripts
permalink: /scripts/validation/
---

# Validation and Deployment Scripts

## validate.sh

The validation script performs comprehensive checks of your environment to ensure all requirements are met before deployment.

### System Validation

#### Operating System Check
- Verifies RHEL 9.5 installation
- Checks RedHat release version
- Validates OS compatibility

#### Command Availability
Verifies the following commands are installed:
- terraform
- ansible
- git
- python3
- pip3

#### Package Validation
Checks for required system packages:
- bind
- bind-utils
- firewalld
- ansible-core
- python3-pip
- python3-devel
- openssl-devel
- gcc

#### Python Package Validation
Verifies Python dependencies:
- ansible-core
- dnspython
- netaddr

### Security Configuration

#### Firewall Validation
- Checks if firewalld is running
- Validates required services are enabled:
  - dns
  - freeipa-ldap
  - freeipa-ldaps

### Infrastructure Validation

#### Terraform Version Check
- Verifies Terraform version >= 0.13.4
- Checks compatibility with infrastructure providers

#### Configuration Files
- Validates presence of vars.sh
- Checks configuration file syntax
- Verifies required variables are set

### Error Handling
- Maintains an error counter
- Provides detailed error messages
- Offers suggestions for fixing issues
- Returns appropriate exit codes

## total_deployer.sh

The main deployment script that orchestrates the entire FreeIPA deployment process.

### Workflow Overview

1. **Initialization**
   - Sources configuration from vars.sh
   - Validates sudo access
   - Sets up error handling

2. **Provider Selection**
   Based on INFRA_PROVIDER variable:
   ```bash
   INFRA_PROVIDER="aws|digitalocean|kcli"
   ```

3. **Infrastructure Deployment**
   - For AWS:
     ```bash
     ./1_infra_aws/create.sh
     ```
   - For DigitalOcean:
     ```bash
     ./1_infra_digitalocean/create.sh
     ```
   - For KCLI:
     ```bash
     ./1_kcli/create.sh
     ```

4. **Configuration**
   ```bash
   ./2_ansible_config/configure.sh
   ```
   - Runs Ansible playbooks
   - Configures FreeIPA
   - Sets up DNS
   - Configures certificates

### Provider-Specific Deployments

#### AWS Deployment
- Creates VPC resources
- Deploys EC2 instances
- Configures security groups
- Sets up Route53 DNS

#### DigitalOcean Deployment
- Creates Droplets
- Configures networking
- Sets up DNS records
- Configures firewalls

#### KCLI Deployment
- Sets up local virtualization
- Creates virtual machines
- Configures networking
- Sets up local DNS

### Error Handling
- Exit on error (set -e)
- Provider-specific error handling
- Ansible configuration error handling
- Deployment validation checks

### Usage

```bash
# 1. First ensure vars.sh is configured:
cp example.vars.sh vars.sh
vi vars.sh

# 2. Run the validation script:
./validate.sh

# 3. If validation passes, run the deployment:
./total_deployer.sh
```

### Monitoring Deployment
- Check Ansible logs for configuration progress
- Monitor provider-specific resources
- Verify FreeIPA services are running
- Test DNS resolution and LDAP connectivity

### Troubleshooting
- Check /var/log/messages for system errors
- Review Ansible logs in /var/log/ansible.log
- Verify provider-specific resource creation
- Test network connectivity and DNS resolution
