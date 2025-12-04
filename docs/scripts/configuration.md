---
layout: page
title: Configuration Scripts
permalink: /scripts/configuration/
---

# Configuration Scripts

This page documents the key configuration and deployment scripts used in the FreeIPA Workshop Deployer.

## example.vars.sh

The `example.vars.sh` script serves as a template for configuring your deployment environment. Copy this file to `vars.sh` and customize the variables for your environment.

### Key Configuration Variables

#### General Settings
```bash
DOMAIN="example.com"                # Your domain name
DNS_FORWARDER="1.1.1.1"            # DNS forwarder
IDM_HOSTNAME="idm"                  # FreeIPA server hostname
INFRA_PROVIDER="aws"                # Provider: aws, digitalocean, or kcli
```

#### AWS Configuration
```bash
AWS_VPC_ID="vpc-something"         # Your AWS VPC ID
AWS_REGION="us-east-2"             # AWS region
```

#### DigitalOcean Configuration
```bash
DO_DATA_CENTER="nyc3"              # DO datacenter
DO_VPC_CIDR="10.42.0.0/24"        # VPC CIDR range
DO_NODE_IMAGE="centos-8-x64"       # Node image
DO_NODE_SIZE="s-1vcpu-2gb"        # Node size
```

#### Authentication Configuration
```bash
FREEIPA_ADMIN_PASSWORD=""          # Required when not using ANSIBLE_VAULT_FILE
RHSM_ORG=""                       # Required for RHEL
RHSM_ACTIVATION_KEY=""            # Required for RHEL
```

#### KCLI Configuration
```bash
KCLI_NETWORK="default"            # KCLI network name
COMMUNITY_VERSION="false"         # Use "true" for centos9stream, "false" for rhel8
```

## bootstrap.sh

The `bootstrap.sh` script prepares your environment for FreeIPA deployment. It must be run as root and performs the following tasks:

### System Checks
- Verifies RHEL 9.x
- Checks root privileges
- Updates system packages

### Package Installation
- Installs EPEL repository
- Installs required system packages:
  - git, curl, wget, unzip
  - python3 and dependencies
  - firewalld
  - ansible-core
  - libvirt and dependencies
- Installs Terraform 0.13.4
- Installs kcli
- Installs Python packages:
  - dnspython
  - netaddr

### Configuration
- Sets up firewall rules for:
  - DNS
  - FreeIPA LDAP
  - FreeIPA LDAPS
  - Cockpit
- Configures libvirt:
  - Sets up storage pool
  - Configures network
- Sets up SSH keys
- Creates and configures:
  - vars.sh (from example.vars.sh)
  - vault.yml (encrypted)
  - all.yml

### Image Setup
Downloads and configures KVM images for:
- RHEL 8
- CentOS 9 Stream
- CentOS 10 Stream

### Cockpit Setup
- Installs and configures Cockpit
- Sets up required plugins
- Configures firewall rules

## validate.sh

The validation script verifies your environment configuration and checks:
- RHEL 9.5 compatibility
- Required packages and tools
- Python dependencies
- Firewall configuration
- Infrastructure provider requirements
- Storage pool configuration
- Network configuration
- SSH key setup
- Required image availability

## total_deployer.sh

The main deployment script that:
1. Reads configuration from vars.sh
2. Validates the environment
3. Deploys infrastructure using the selected provider (AWS/DO/kcli)
4. Configures the FreeIPA server using Ansible
5. Sets up DNS and certificates
6. Configures initial users and groups

### Usage

```bash
# After configuring vars.sh:
./total_deployer.sh
```

### Workflow
1. Sources configuration from vars.sh
2. Validates environment and dependencies
3. Creates infrastructure using provider-specific Terraform configurations
4. Runs Ansible playbooks for FreeIPA configuration
5. Sets up DNS records and certificates
6. Performs final validation checks
