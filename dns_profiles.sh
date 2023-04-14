#!/bin/bash

function openshift_profile(){
    # Create DNS entries for OpenShift API and Ingress
    echo "Creating DNS entries for OpenShift API and Ingress..."
    cd 2_ansible_config/
    sudo python3 dynamic_dns.py --add api "$1" || exit 1
    sudo python3 dynamic_dns.py --add '*.apps' "$2" || exit 1
    cd ..
    ./2_ansible_config/populate-hostnames.sh || exit 1
}

function ansible_aap_profile(){
    # Create DNS entries for Ansible Automation Platform
    echo "Creating DNS entries for Ansible Automation Platform..."
    cd 2_ansible_config/
    sudo python3 dynamic_dns.py --add ansible-aap "$1" || exit 1
    sudo python3 dynamic_dns.py --add ansible-hub "$2" || exit 1
    sudo python3 dynamic_dns.py --add postgres "$2" || exit 1
    cd ..
    ./2_ansible_config/populate-hostnames.sh || exit 1
}

while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        -h|--help)
        echo "Usage: $0 [-h|--help] <profile> <ip_address_1> <ip_address_2>"
        echo "Create DNS entries for a specific profile"
        echo ""
        echo "Options:"
        echo "  -h, --help      Show this help message and exit"
        echo ""
        echo "Arguments:"
        echo "  profile         The profile to use (openshift or ansible-aap)"
        echo "  ip_address_1    The IP address to use for the first DNS entry"
        echo "  ip_address_2    The IP address to use for the second DNS entry (if applicable)"
        exit 0
        ;;
        openshift)
        openshift_profile "$2" "$3"
        shift
        shift
        shift
        ;;
        ansible-aap)
        ansible_aap_profile "$2" "$3"
        shift
        shift
        shift
        ;;
        *)
        echo "Invalid argument: $1"
        echo "Usage: $0 [-h|--help] <profile> <ip_address_1> <ip_address_2>"
        exit 1
        ;;
    esac
done
