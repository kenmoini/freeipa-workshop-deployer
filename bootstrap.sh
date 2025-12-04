#!/bin/bash

# Function to check if a command exists
command_exists() {
  command -v "$1" &> /dev/null
}

# Exit on error
set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Print functions for formatted output
print_section() {
    echo -e "\n${YELLOW}=== $1 ===${NC}"
}

print_info() {
    echo -e "${GREEN}➜ ${NC}$1"
}

print_status() {
    local message=$1
    local status=$2
    if [ $status -eq 0 ]; then
        echo -e "${GREEN}✓ $message${NC}"
    else
        echo -e "${RED}✗ $message${NC}"
    fi
}

echo -e "${GREEN}FreeIPA Workshop Deployer Bootstrap${NC}"
echo "======================================"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Check RHEL version
if [ -f /etc/redhat-release ]; then
    RHEL_VERSION=$(cat /etc/redhat-release | grep -oP '(?<=release )\d+\.\d+')
    MAJOR_VERSION=$(echo $RHEL_VERSION | cut -d. -f1)
    if [ "$MAJOR_VERSION" != "9" ]; then
        echo -e "${RED}This script requires RHEL 9.x${NC}"
        exit 1
    fi
else
    echo -e "${RED}This script requires RHEL${NC}"
    exit 1
fi

# Function to check and install packages
check_and_install() {
    if ! rpm -q $1 &> /dev/null; then
        echo -e "${YELLOW}Installing $1...${NC}"
        dnf install -y $1
    else
        echo -e "${GREEN}$1 is already installed${NC}"
    fi
}

# Update system packages
echo "Updating system packages..."
dnf update -y

# Install EPEL repository
echo "Installing EPEL repository..."
dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm -y

# Install required packages
echo "Installing required packages..."
REQUIRED_PACKAGES=(
    git
    curl
    wget
    unzip
    python3
    python3-pip
    python3-devel
    gcc
    openssl-devel
    bind
    bind-utils
    firewalld
    ansible-core
)

for package in "${REQUIRED_PACKAGES[@]}"; do
    check_and_install $package
done

# Install yq
if ! yq -v  &> /dev/null
then
    VERSION=v4.45.1
    BINARY=yq_linux_amd64
    sudo wget https://github.com/mikefarah/yq/releases/download/${VERSION}/${BINARY} -O /usr/bin/yq &&\
    sudo chmod +x /usr/bin/yq
fi


# Install Terraform
TERRAFORM_VERSION="0.13.4"
if ! command -v terraform &> /dev/null; then
    echo "Installing Terraform ${TERRAFORM_VERSION}..."
    wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
    unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip
    mv terraform /usr/local/bin/
    rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip
    echo -e "${GREEN}Terraform ${TERRAFORM_VERSION} installed successfully${NC}"
else
    echo -e "${GREEN}Terraform is already installed${NC}"
fi

# Install required Python packages
echo "Installing required Python packages..."
pip3 install --upgrade pip
sudo pip3 install dnspython netaddr click

# Install required Ansible collections
echo "Installing required Ansible collections..."
ansible-galaxy collection install ansible.posix
ansible-galaxy collection install community.general


# Configure firewalld
echo "Configuring firewall..."
systemctl enable --now firewalld
sudo firewall-cmd --permanent --add-service=dns
sudo firewall-cmd --permanent --add-service=freeipa-ldap
sudo firewall-cmd --permanent --add-service=freeipa-ldaps
sudo firewall-cmd --reload

# Create vars.sh from example if it doesn't exist
if [ ! -f vars.sh ] && [ -f example.vars.sh ]; then
    echo "Creating vars.sh from example..."
    cp example.vars.sh vars.sh
    echo -e "${YELLOW}Please edit vars.sh with your specific configuration${NC}"
fi

print_section "Installing Libvirt"
dnf install -y libvirt libvirt-daemon libvirt-daemon-driver-qemu qemu-kvm qemu-kvm-core libvirt-daemon-kvm virt-install
print_status "Libvirt and dependencies installed" $?

# Start and enable libvirtd service
systemctl start libvirtd
systemctl enable libvirtd
print_status "Libvirt service started and enabled" $?

# Verify Libvirt version
LIBVIRT_VERSION=$(libvirtd --version | awk '{print $3}')
if [[ "$(printf '%s\n' "8.0.0" "$LIBVIRT_VERSION" | sort -V | head -n1)" = "8.0.0" ]]; then
    print_status "Libvirt version $LIBVIRT_VERSION meets requirements" 0
else
    print_status "Libvirt version $LIBVIRT_VERSION does not meet minimum requirement of 8.0.0" 1
fi

print_section "Installing kcli"
if ! command_exists kcli; then
    print_info "Installing kcli..."
    curl -s https://raw.githubusercontent.com/karmab/kcli/main/install.sh | bash
    if [ ! -f /home/lab-user/.vault ];
    then 
        bash -c "openssl rand -base64 32 > /home/lab-user/.vault && chmod 600 /home/lab-user/.vault"
        mkdir -p kcli-plans
        mkdir -p /home/lab-user/.kcli/
    fi
    if [ $? -eq 0 ]; then
        print_status "kcli installed successfully" 0
    else
        print_status "Failed to install kcli" 1
        exit 1
    fi
else
    print_status "kcli is already installed" 0
fi


# Set up Ansible vault password
print_section "Setting up Ansible vault"
if [ ! -f .vault_password ]; then
    print_info "Creating vault password file..."
    openssl rand -base64 32 > .vault_password
    chmod 600 .vault_password
    print_status "Vault password file created" 0
else
    print_status "Vault password file already exists" 0
fi

print_section "Setting up ansiblesafe"
version="v0.0.14"
url="https://github.com/tosin2013/ansiblesafe/releases/download/v0.0.12/ansiblesafe-${version}-linux-amd64.tar.gz"
dest="/usr/local/bin/ansiblesafe"

if ! command_exists ansiblesafe; then
    echo -e "${YELLOW}Installing ansiblesafe...${NC}"
    curl -OL $url 
    tar -zxvf ansiblesafe-${version}-linux-amd64.tar.gz
    mv ansiblesafe-linux-amd64 $dest
    chmod +x $dest
    #ansiblesafe -h
    rm ansiblesafe-${version}-linux-amd64.tar.gz
    print_status "ansiblesafe installed successfully" $?
else
    print_status "ansiblesafe is already installed" 0
fi

# Function to prompt for value with default
prompt_with_default() {
    local prompt=$1
    local default=$2
    local value

    read -p "$prompt [$default]: " value
    echo ${value:-$default}
}

print_section "Setting up SSH keys"
if [ ! -f "/root/.ssh/id_rsa" ]; then
    print_info "Generating SSH keys..."
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N '' -C "root@$(hostname)"
    chmod 600 /root/.ssh/id_rsa
    chmod 644 /root/.ssh/id_rsa.pub
    print_status "SSH keys generated" $?
else
    print_status "SSH keys already exist" 0
fi

# Ensure proper permissions on SSH directory and keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/id_rsa
chmod 644 /root/.ssh/id_rsa.pub

print_section "Setting up libvirt storage pool"
# Check existing storage pools
if virsh pool-list --all | grep -q "kvm_pool"; then
    print_info "Found existing kvm_pool..."
    # Ensure the pool is active
    if ! virsh pool-info kvm_pool | grep -q "State.*running"; then
        print_info "Starting kvm_pool..."
        virsh pool-start kvm_pool
    fi
    print_status "kvm_pool is ready" 0
else
    # Check if we have the LVM volume group and logical volumes
    if vgs vg_data >/dev/null 2>&1; then
        print_info "Setting up storage pool using vg_data/lv_images..."
        # Define a new storage pool using the LVM volume
        virsh pool-define-as --name kvm_pool --type dir --target /var/lib/libvirt/images
        virsh pool-build kvm_pool
        virsh pool-start kvm_pool
        virsh pool-autostart kvm_pool
        print_status "Storage pool created and started using vg_data" $?
    else
        print_info "Creating default storage pool..."
        mkdir -p /var/lib/libvirt/images
        virsh pool-define-as --name kvm_pool --type dir --target /var/lib/libvirt/images
        virsh pool-build kvm_pool
        virsh pool-start kvm_pool
        virsh pool-autostart kvm_pool
        print_status "Default storage pool created and started" $?
    fi
fi

# Update KCLI configuration to use kvm_pool
if [ -f "/root/.kcli/config.yml" ]; then
    print_info "Updating kcli configuration..."
    # Backup existing config
    cp /root/.kcli/config.yml /root/.kcli/config.yml.bak
    # Update or add pool configuration
    sed -i 's/pool: default/pool: kvm_pool/' /root/.kcli/config.yml || \
    echo -e "\ndefault:\n  pool: kvm_pool" >> /root/.kcli/config.yml
    print_status "kcli configuration updated" 0
else
    mkdir -p /root/.kcli
    echo -e "default:\n  pool: kvm_pool" > /root/.kcli/config.yml
    print_status "kcli configuration created" 0
fi


print_section "RHEL 8 KVM Image Setup"
if [ ! -f "/var/lib/libvirt/images/rhel8" ]; then
    print_info "Downloading RHEL 8 KVM image using kcli..."
    if sudo kcli download image rhel8; then
        # Create a symlink if kcli downloads to a different location
        if [ ! -f "/var/lib/libvirt/images/rhel8" ] && [ -f "/root/.kcli/pool/rhel8" ]; then
            ln -s /root/.kcli/pool/rhel8 /var/lib/libvirt/images/rhel8
            chown root:root /var/lib/libvirt/images/rhel8
            chmod 644 /var/lib/libvirt/images/rhel8
            # Set proper SELinux context
            restorecon -Rv /var/lib/libvirt/images/rhel8
        fi
        print_status "RHEL 8 KVM image downloaded successfully" 0
    else
        print_status "Failed to download RHEL 8 KVM image" 1
        print_info "Please try manual download:"
        echo "1. Visit: https://access.redhat.com/downloads/content/479/ver=/rhel---8/8.10/x86_64/product-software"
        echo "2. Log in with your Red Hat account"
        echo "3. Download the 'Red Hat Enterprise Linux 8.10 KVM Guest Image'"
        echo "4. Once downloaded, move it to /var/lib/libvirt/images/rhel8"
        echo ""
        print_info "Example commands after downloading:"
        echo "sudo mv ~/Downloads/rhel-8.10-x86_64-kvm /var/lib/libvirt/images/rhel8"
        echo "sudo chown root:root /var/lib/libvirt/images/rhel8"
        echo "sudo chmod 644 /var/lib/libvirt/images/rhel8"
        echo "sudo restorecon -Rv /var/lib/libvirt/images/rhel8"
    fi
else
    # Ensure proper permissions and SELinux context even if image exists
    chown root:root /var/lib/libvirt/images/rhel8
    chmod 644 /var/lib/libvirt/images/rhel8
    restorecon -Rv /var/lib/libvirt/images/rhel8
    print_status "RHEL 8 KVM image already exists" 0
fi

print_section "CentOS 9 Stream KVM Image Setup"
if [ ! -f "/var/lib/libvirt/images/centos9stream" ]; then
    print_info "Downloading CentOS 9 Stream KVM image using kcli..."
    if sudo kcli download image centos9stream; then
        # Create a symlink if kcli downloads to a different location
        if [ ! -f "/var/lib/libvirt/images/centos9stream" ] && [ -f "/root/.kcli/pool/centos9stream" ]; then
            ln -s /root/.kcli/pool/centos9stream /var/lib/libvirt/images/centos9stream
            chown root:root /var/lib/libvirt/images/centos9stream
            chmod 644 /var/lib/libvirt/images/centos9stream
            # Set proper SELinux context
            restorecon -Rv /var/lib/libvirt/images/centos9stream
        fi
        print_status "CentOS 9 Stream KVM image downloaded successfully" 0
    else
        print_status "Failed to download CentOS 9 Stream KVM image" 1
        print_info "Please try manual download from https://cloud.centos.org/centos/9-stream/x86_64/images/"
    fi
else
    # Ensure proper permissions and SELinux context even if image exists
    chown root:root /var/lib/libvirt/images/centos9stream
    chmod 644 /var/lib/libvirt/images/centos9stream
    restorecon -Rv /var/lib/libvirt/images/centos9stream
    print_status "CentOS 9 Stream KVM image already exists" 0
fi

print_section "CentOS 10 Stream KVM Image Setup"
if [ ! -f "/var/lib/libvirt/images/centos10stream" ]; then
    print_info "Downloading CentOS 10 Stream KVM image using kcli..."
    if sudo kcli download image centos10stream; then
        # Create a symlink if kcli downloads to a different location
        if [ ! -f "/var/lib/libvirt/images/centos10stream" ] && [ -f "/root/.kcli/pool/centos10stream" ]; then
            ln -s /root/.kcli/pool/centos10stream /var/lib/libvirt/images/centos10stream
            chown root:root /var/lib/libvirt/images/centos10stream
            chmod 644 /var/lib/libvirt/images/centos10stream
            # Set proper SELinux context
            restorecon -Rv /var/lib/libvirt/images/centos10stream
        fi
        print_status "CentOS 10 Stream KVM image downloaded successfully" 0
    else
        print_status "Failed to download CentOS 10 Stream KVM image" 1
        print_info "Please try manual download from https://cloud.centos.org/centos/10-stream/x86_64/images/"
    fi
else
    # Ensure proper permissions and SELinux context even if image exists
    chown root:root /var/lib/libvirt/images/centos10stream
    chmod 644 /var/lib/libvirt/images/centos10stream
    restorecon -Rv /var/lib/libvirt/images/centos10stream
    print_status "CentOS 10 Stream KVM image already exists" 0
fi

# Create basic vault.yml if it doesn't exist
if [ ! -f vault.yml ]; then
    print_info "Creating vault.yml..."
    print_info "Please provide the following information:"
    
    # Prompt for vault values
    ADMIN_PASSWORD=$(prompt_with_default "Enter FreeIPA admin password" "changeme")
    RHSM_ORG=$(prompt_with_default "Enter Red Hat Subscription Manager Organization ID" "")
    RHSM_KEY=$(prompt_with_default "Enter Red Hat Subscription Manager Activation Key" "")
    
    cat > vault.yml <<EOL
---
freeipa_server_admin_password: "${ADMIN_PASSWORD}"
rhsm_org: "${RHSM_ORG}"
rhsm_activationkey: "${RHSM_KEY}"
EOL
    ansible-vault encrypt vault.yml --vault-password-file .vault_password
    print_status "vault.yml created and encrypted" 0
else
    print_status "vault.yml already exists" 0
    print_info "To recreate vault.yml, delete the existing file and run bootstrap.sh again"
fi

# Create basic all.yml if it doesn't exist
if [ ! -f all.yml ]; then
    print_info "Creating all.yml..."
    print_info "Please provide the following information:"
    
    # Prompt for all.yml values
    DNS_FORWARDER=$(prompt_with_default "Enter DNS forwarder" "1.1.1.1")
    DOMAIN=$(prompt_with_default "Enter domain name" "example.com")
    ADMIN_USER=$(prompt_with_default "Enter admin username" "$(whoami)")
    
    cat > all.yml <<EOL
---
dns_forwarder: "${DNS_FORWARDER}"
domain: "${DOMAIN}"
admin_user: "${ADMIN_USER}"
EOL
    print_status "all.yml created" 0
else
    print_status "all.yml already exists" 0
    print_info "To recreate all.yml, delete the existing file and run bootstrap.sh again"
fi

print_section "Setting up Cockpit"
# Install Cockpit and required packages
print_info "Installing Cockpit and plugins..."
dnf install -y cockpit cockpit-machines cockpit-pcp cockpit-packagekit cockpit-storaged
print_status "Cockpit packages installed" $?

# Enable and start Cockpit socket
systemctl enable --now cockpit.socket
print_status "Cockpit service enabled and started" $?

# Configure firewall for Cockpit
firewall-cmd --permanent --add-service=cockpit
firewall-cmd --reload
print_status "Firewall configured for Cockpit" $?

systemctl restart libvirtd
print_status "Libvirt configured for Cockpit integration" $?

print_info "Cockpit is available at: https://$(hostname):9090"

# Final checks
echo -e "\n${GREEN}Bootstrap Complete!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Edit vars.sh with your specific configuration"
echo "2. Edit vault.yml and all.yml with your specific settings"
echo "3. Run validate.sh to verify the environment"
echo "4. Run ./total_deployer.sh to deploy FreeIPA"
