# Dynamic DNS Script

This script is used to create DNS entries for different profiles, such as OpenShift or Ansible Automation Platform.

[dns_profiles.sh](dns_profiles.sh)

## Requirements
* Python 3
* click and pyyaml Python packages (installed with pip)
* sudo access

## Usage
```bash
Usage: dynamic_dns.sh [-h|--help] <profile> <ip_address_1> <ip_address_2>

Create DNS entries for a specific profile

Options:
  -h, --help      Show this help message and exit

Arguments:
  profile         The profile to use (openshift or ansible-aap)
  ip_address_1    The IP address to use for the first DNS entry
  ip_address_2    The IP address to use for the second DNS entry (if applicable)
```
## Examples

**Create DNS entries for OpenShift:**

```bash
./dynamic_dns.sh openshift 192.168.1.102 192.168.1.103
```

**Create DNS entries for Ansible Automation Platform:**
```bash
./dynamic_dns.sh ansible-aap 192.168.1.102 192.168.1.103
```

## Functionality
The script uses two functions, openshift_profile and ansible_aap_profile, to create DNS entries for the respective profiles. These functions call a Python script (dynamic_dns.py) to add the entries to a YAML file containing the DNS names and IP addresses. The populate-hostnames.sh script is then called to update the local hosts file with the new entries.

## License
