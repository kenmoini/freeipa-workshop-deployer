#!/bin/bash

# Exit on error
set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}FreeIPA Workshop Deployer Validation${NC}"
echo "======================================"

# Initialize error counter
ERRORS=0

# Function to check command existence
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}✗ $1 is not installed${NC}"
        ERRORS=$((ERRORS + 1))
        return 1
    else
        echo -e "${GREEN}✓ $1 is installed${NC}"
        return 0
    fi
}

# Function to check package installation
check_package() {
    if ! rpm -q $1 &> /dev/null; then
        echo -e "${RED}✗ Package $1 is not installed${NC}"
        ERRORS=$((ERRORS + 1))
        return 1
    else
        echo -e "${GREEN}✓ Package $1 is installed${NC}"
        return 0
    fi
}

# Function to check Python package installation
check_pip_package() {
    if ! pip3 list | grep -E "^$1[[:space:]]+" &> /dev/null; then
        echo -e "${RED}✗ Python package $1 is not installed${NC}"
        ERRORS=$((ERRORS + 1))
        return 1
    else
        echo -e "${GREEN}✓ Python package $1 is installed${NC}"
        return 0
    fi
}

# Function to check firewall service
check_firewall_service() {
    if ! sudo firewall-cmd --list-services | grep -w "$1" &> /dev/null; then
        echo -e "${RED}✗ Firewall service $1 is not enabled${NC}"
        ERRORS=$((ERRORS + 1))
        return 1
    else
        echo -e "${GREEN}✓ Firewall service $1 is enabled${NC}"
        return 0
    fi
}

echo "Checking RHEL version..."
if [ -f /etc/redhat-release ]; then
    RHEL_VERSION=$(cat /etc/redhat-release)
    if [[ $RHEL_VERSION == *"Red Hat Enterprise Linux release 9.5"* ]]; then
        echo -e "${GREEN}✓ RHEL 9.5 detected${NC}"
    else
        echo -e "${RED}✗ This script requires RHEL 9.5${NC}"
        echo -e "${RED}Current version: $RHEL_VERSION${NC}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}✗ This script requires RHEL${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo -e "\nChecking required commands..."
COMMANDS=(
    "terraform"
    "ansible"
    "git"
    "python3"
    "pip3"
)

for cmd in "${COMMANDS[@]}"; do
    check_command $cmd
done

echo -e "\nChecking required packages..."
PACKAGES=(
    "bind"
    "bind-utils"
    "firewalld"
    "ansible-core"
    "python3-pip"
    "python3-devel"
    "openssl-devel"
    "gcc"
)

for pkg in "${PACKAGES[@]}"; do
    check_package $pkg
done

echo -e "\nChecking Python packages..."
PIP_PACKAGES=(
    "ansible-core"
    "dnspython"
    "netaddr"
)

for pkg in "${PIP_PACKAGES[@]}"; do
    check_pip_package $pkg
done

echo -e "\nChecking firewall configuration..."
if systemctl is-active firewalld &> /dev/null; then
    echo -e "${GREEN}✓ Firewalld is running${NC}"
else
    echo -e "${RED}✗ Firewalld is not running${NC}"
    ERRORS=$((ERRORS + 1))
fi

FIREWALL_SERVICES=(
    "dns"
    "freeipa-ldap"
    "freeipa-ldaps"
)

for service in "${FIREWALL_SERVICES[@]}"; do
    check_firewall_service $service
done

echo -e "\nChecking configuration files..."
if [ -f "vars.sh" ]; then
    echo -e "${GREEN}✓ vars.sh exists${NC}"
else
    echo -e "${RED}✗ vars.sh not found${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check Terraform version
if command -v terraform &> /dev/null; then
    TERRAFORM_VERSION=$(terraform version | head -n1 | cut -d'v' -f2)
    if [[ $(echo -e "0.13.4\n$TERRAFORM_VERSION" | sort -V | head -n1) == "0.13.4" ]]; then
        echo -e "${GREEN}✓ Terraform version >= 0.13.4${NC}"
    else
        echo -e "${RED}✗ Terraform version must be >= 0.13.4 (current: $TERRAFORM_VERSION)${NC}"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Final summary
echo -e "\n======================================"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}All validation checks passed!${NC}"
    echo -e "You can proceed with running ./total_deployer.sh"
    exit 0
else
    echo -e "${RED}Validation failed with $ERRORS error(s)${NC}"
    echo -e "Please fix the issues above before proceeding"
    exit 1
fi

chmod +x validate.sh
