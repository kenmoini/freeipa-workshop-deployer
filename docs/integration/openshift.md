---
layout: page
title: OpenShift Integration
permalink: /integration/openshift/
---

# OpenShift Integration with FreeIPA

This guide explains how to integrate your OpenShift cluster with FreeIPA for authentication and user management.

## Prerequisites

- A running FreeIPA server
- Access to OpenShift cluster with administrator privileges
- FreeIPA CA certificate

## Setup Steps

### 1. Obtain the CA Certificate

You can obtain the CA certificate in two ways:

#### Option 1: From the File System
```bash
# Copy from the FreeIPA server
scp root@idm.example.com:/etc/ipa/ca.crt ./
```

#### Option 2: From the Web Console
1. Navigate to the FreeIPA Web Console
2. Go to: **Authentication > Certificates**
3. Click on certificate "1"
4. Select **Actions > Download Certificate**

### 2. Configure OAuth Identity Provider

Create a new OAuth configuration for your OpenShift cluster that integrates with FreeIPA's LDAP.

#### Required Settings

| Setting | Value | Description |
|---------|-------|-------------|
| email | mail | Email attribute mapping |
| id | dn | Distinguished Name for unique identification |
| name | cn | Common Name for display |
| preferredUsername | uid | User ID for login |
| bindDN | uid=admin,cn=users,cn=accounts,dc=example,dc=com | LDAP bind account |
| bindPassword | (your password) | Authentication for bind account |
| ca | fromDownloadedFile | CA certificate from step 1 |
| url | ldaps://idm.example.com:636/cn=users,cn=accounts,dc=example,dc=com?uid?sub?(uid=*) | LDAP connection URL |

### 3. Apply the Configuration

Apply the following YAML configuration to your OpenShift cluster:

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

Apply this configuration using:
```bash
oc apply -f oauth-config.yaml
```

## Verification

1. Log out of OpenShift console
2. Click "Log in with WorkshopLDAP" on the login page
3. Enter FreeIPA credentials
4. Verify successful authentication and correct user details

## Troubleshooting

### Common Issues

1. **Certificate Issues**
   - Verify CA certificate is correctly copied
   - Check certificate permissions
   - Ensure certificate is properly configured in OAuth

2. **LDAP Connection Issues**
   - Verify LDAP URL is correct
   - Check firewall rules allow LDAPS (636)
   - Confirm bindDN has proper permissions

3. **Authentication Failures**
   - Verify user exists in FreeIPA
   - Check user has proper group memberships
   - Review OpenShift authentication logs

### Debug Commands

```bash
# Check OAuth configuration
oc get oauth cluster -o yaml

# View authentication logs
oc logs deployment/oauth-openshift -n openshift-authentication

# Test LDAP connection
ldapsearch -H ldaps://idm.example.com:636 -D "uid=admin,cn=users,cn=accounts,dc=example,dc=com" -W -b "cn=users,cn=accounts,dc=example,dc=com"
```

## Security Considerations

1. Always use LDAPS (never plain LDAP)
2. Keep the CA certificate secure
3. Use a service account for bindDN
4. Regularly rotate bindDN password
5. Implement proper RBAC in both FreeIPA and OpenShift

## Next Steps

1. Configure group synchronization
2. Set up role bindings for FreeIPA groups
3. Implement automated user provisioning
4. Set up monitoring for authentication issues
