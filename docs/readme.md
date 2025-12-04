---
layout: page
title: README
permalink: /readme/
---

# FreeIPA Workshop Deployer

A comprehensive solution for deploying FreeIPA/Red Hat Identity Management Server across multiple infrastructure providers (AWS, DigitalOcean, kcli) using Terraform and Ansible.

## System Requirements

- **Operating System:** RHEL 9.5 (Primary supported platform)
- **Memory:** Minimum 4GB RAM (8GB recommended)
- **CPU:** 2+ cores recommended
- **Storage:** 20GB+ available storage
- **Network Ports:**
  - 22 (SSH)
  - 53 (DNS)
  - 80/443 (HTTP/HTTPS)
  - 389/636 (LDAP/LDAPS)
  - 88/464 (Kerberos)
  - 123 (NTP)

### Dependencies

#### System Packages
- git
- curl
- wget
- unzip
- python3
- python3-pip
- firewalld
- ansible-core

#### Python Packages
- dnspython
- netaddr

#### Infrastructure Tools
- Terraform (v0.13.4)
- AWS CLI, DigitalOcean CLI, or kcli

## Quick Start

### 1. Bootstrap the Environment

```bash
# Clone the repository
git clone https://github.com/yourusername/freeipa-workshop-deployer.git
cd freeipa-workshop-deployer

# Run bootstrap script (requires root/sudo)
sudo ./bootstrap.sh
```

The bootstrap script:
- Verifies RHEL 9.5
- Installs required packages
- Sets up Terraform
- Configures Python dependencies
- Sets up firewall rules
- Creates initial configuration

### 2. Validate the Environment

```bash
# Run validation script
sudo ./validate.sh
```

The validation script checks:
- RHEL 9.5 compatibility
- Required packages and tools
- Python dependencies
- Firewall configuration
- Infrastructure provider requirements

### 3. Quick Deployment

The `quick-deploy.sh` script provides a streamlined way to deploy and manage FreeIPA across different providers:

```bash
# Deploy using kcli
./quick-deploy.sh kcli deploy

# Deploy using AWS
AWS_ACCESS_KEY_ID=xxx AWS_SECRET_ACCESS_KEY=yyy ./quick-deploy.sh aws deploy

# Deploy using DigitalOcean
DO_PAT=xxx ./quick-deploy.sh do deploy

# Destroy deployment
./quick-deploy.sh [aws|do|kcli] destroy
```

#### Environment Variables for Customization

Common variables:
- DOMAIN: Custom domain name (default: example.com)
- DNS_FORWARDER: Custom DNS forwarder (default: 1.1.1.1)
- IDM_HOSTNAME: Custom IdM hostname (default: idm)

Provider-specific variables:
```bash
# AWS
AWS_REGION=us-east-2
AWS_VPC_ID=vpc-xxx

# DigitalOcean
DO_DATA_CENTER=nyc3
DO_VPC_CIDR=10.42.0.0/24
DO_NODE_IMAGE=centos-8-x64
DO_NODE_SIZE=s-1vcpu-2gb

# kcli
KCLI_NETWORK=qubinet
COMMUNITY_VERSION=false  # Set to true for CentOS
```

## Traditional Deployment Method

If you prefer the traditional deployment method:

1. Copy `example.vars.sh` to `vars.sh`
2. Configure your provider credentials and settings
3. Run `./total_deployer.sh`

## Monitoring and Alerts

The deployment includes basic monitoring capabilities. For production environments, it's recommended to:
- Set up performance metrics collection
- Configure health checks
- Implement alert notifications
- Monitor service availability
- Track resource utilization

For enhanced monitoring, consider integrating with cloud provider monitoring solutions.

## Backup and Recovery

Implement proper backup procedures for production deployments:
- Regular automated backups
- Point-in-time recovery options
- Backup validation
- Disaster recovery planning

Refer to the [documentation]({% link technical-setup.md %}) for detailed backup configuration.

## Testing

The project includes comprehensive testing covering:
- Environment validation
- Infrastructure deployment
- Service configuration
- DNS management
- Integration testing

For detailed testing information, see the [testing documentation]({% link testing.md %}).

## Connecting to OpenShift

1. Download the CA Cert from `/etc/ipa/ca.crt` or via the IPA Web Console at ***Authentication > Certificates > 1 > Actions > Download Certificate***
2. Configure a new OAuth Identity Provider with these settings:
    - email: mail
    - id: dn
    - name: cn
    - preferredUsername: uid
    - bindDN: 'uid=admin,cn=users,cn=accounts,dc=example,dc=com'
    - bindPassword: (your password)
    - ca: fromDownloadedFile
    - url: ldaps://idm.example.com:636/cn=users,cn=accounts,dc=example,dc=com?uid?sub?(uid=*)
    - name: LDAP

For YAML configuration example:

```yaml
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  annotations:
    release.openshift.io/create-only: 'true'
  name: cluster
spec:
  identityProviders:
    - ldap:
        attributes:
          email:
            - mail
          id:
            - dn
          name:
            - cn
          preferredUsername:
            - uid
        bindDN: 'uid=admin,cn=users,cn=accounts,dc=example,dc=com'
        bindPassword:
          name: ldap-bind-password
        ca:
          name: ldap-ca
        insecure: false
        url: >-
          ldaps://idm.example.com:636/cn=users,cn=accounts,dc=example,dc=com?uid?sub?(uid=*)
      mappingMethod: claim
      name: WorkshopLDAP
      type: LDAP
```

## Documentation

- [Technical Setup]({% link technical-setup.md %})
- [Deployment Guide]({% link deployment.md %})
- [Architecture Overview]({% link architecture.md %})
- [Configuration Scripts]({% link scripts/configuration.md %})
- [Validation and Deployment]({% link scripts/validation.md %})
- [DNS Profiles]({% link dns_profiles.md %})
- [Dynamic DNS Management]({% link dynamic_dns.md %})
- [Testing Guide]({% link testing.md %})
- [OpenShift Integration]({% link integration/openshift.md %})

## Contributing

1. Fork the repository
2. Create your feature branch
3. Submit a pull request

## License

See LICENSE file for details.
