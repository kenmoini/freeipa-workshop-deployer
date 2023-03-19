## FreeIPA on Whatever with Terraform and Ansible

This collection of content will utilize Terraform to provision the infrastructure needed to deploy a single FreeIPA/Red Hat Identity Management Server.  Currently it supports deploying to AWS and DigitalOcean, but other cloud providers are easy to adapt to by just creating a new set of Terraform files.

Tested on CentOS/RHEL 8.x

## Deploying

1. Copy over the `example.vars.sh` file to `vars.sh`
2. Paste in your DigitalOcean API Token, modify other variables as needed
3. Run `./total_deployer.sh` to fully provision the entire stack

## Connecting to OpenShift

1. Download the CA Cert from `/etc/ipa/ca.crt` or via the IPA Web Console at ***Authentication > Certificates > 1 > Actions > Download Certificate***
2. Configure a new OAuth Identity Provider as such:
    - email: mail
    - id: dn
    - name: cn
    - preferredUsername: uid
    - bindDN: 'uid=admin,cn=users,cn=accounts,dc=kemo,dc=network'
    - bindPassword: DUHHHH
    - ca: fromDownloadedFile
    - url: ldaps://idm.kemo.network:636/cn=users,cn=accounts,dc=kemo,dc=network?uid?sub?(uid=*)
    - name: LDAP
3. Alternatively, here is the YAML formatted configuration

```yaml
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  annotations:
    release.openshift.io/create-only: 'true'
  creationTimestamp: '2020-10-19T02:48:58Z'
  generation: 6
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
        bindDN: 'uid=admin,cn=users,cn=accounts,dc=kemo,dc=network'
        bindPassword:
          name: ldap-bind-password-njtgt
        ca:
          name: ldap-ca-fbkpt
        insecure: false
        url: >-
          ldaps://idm.kemo.network:636/cn=users,cn=accounts,dc=kemo,dc=network?uid?sub?(uid=*)
      mappingMethod: claim
      name: WorkshopLDAP
      type: LDAP
```