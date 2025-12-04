#!/bin/bash
#export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x

## Functions
function checkForProgram() {
    command -v $1
    if [[ $? -eq 0 ]]; then
        printf '%-72s %-7s\n' $1 "PASSED!";
    else
        printf '%-72s %-7s\n' $1 "FAILED!";
    fi
}
function checkForProgramAndExit() {
    command -v $1
    if [[ $? -eq 0 ]]; then
        printf '%-72s %-7s\n' $1 "PASSED!";
    else
        printf '%-72s %-7s\n' $1 "FAILED!";
            fi
}

if [ "$EUID" -ne 0 ]
then 
  export USE_SUDO="sudo"
fi

if [ ! -z "$CICD_PIPELINE" ]; then
  export USE_SUDO="sudo"
fi

COMMUNITY_VERSION="$(echo -e "${COMMUNITY_VERSION}" | tr -d '[:space:]')"

echo "COMMUNITY_VERSION is set to: $COMMUNITY_VERSION"

if [ "$COMMUNITY_VERSION" == "true" ]; then
  echo "Community version"
  export IMAGE_NAME=centos8stream
  export TEMPLATE_NAME=template-centos.yaml
  export LOGIN_USER=centos
  echo "IMAGE_NAME: $IMAGE_NAME"
  echo "TEMPLATE_NAME: $TEMPLATE_NAME"
elif [ "$COMMUNITY_VERSION" == "false" ]; then
  echo "Enterprise version"
  export IMAGE_NAME=rhel8
  export TEMPLATE_NAME=template.yaml
  export LOGIN_USER=cloud-user
  echo "IMAGE_NAME: $IMAGE_NAME"
  echo "TEMPLATE_NAME: $TEMPLATE_NAME"
else
  echo "Correct $COMMUNITY_VERSION not set"
  fi

if [[ ! -f /var/lib/libvirt/images/${IMAGE_NAME} ]];
then
  echo "${IMAGE_NAME} image not found"
  echo "Please Run  the following command to download the image"
  echo "sudo kcli download image ${IMAGE_NAME}"
  exit 1
fi

${USE_SUDO} pwd

## Include vars if the file exists
FILE=vars.sh
if [ -f "$FILE" ]; then
    source vars.sh
elif [ -f "/opt/freeipa-workshop-deployer/${FILE}" ]; then
    source /opt/freeipa-workshop-deployer/${FILE}
else
    echo "No variable file found!"
    exit 1
fi

# @description This function will set the variables for the installer
# ANSIBLE_SAFE_VERSION - The version of the ansiblesafe binary
# ANSIBLE_VAULT_FILE - The location of the vault file
# KCLI_CONFIG_DIR - The location of the kcli config directory
# KCLI_CONFIG_FILE - The location of the kcli config file
# PROFILES_FILE - The name of the kcli profiles file
# SECURE_DEPLOYMENT - The value of the secure deployment variable
# INSTALL_RHEL_IMAGES - Set the vault to true if you want to install the RHEL images

checkForProgramAndExit wget
checkForProgramAndExit jq
checkForProgramAndExit kcli
checkForProgramAndExit sshpass

# Set up working directory for KCLI plans
if [ -d "${KCLI_PLANS_PATH}" ]; then
  echo "Using existing KCLI plans directory: ${KCLI_PLANS_PATH}"
  cd "${KCLI_PLANS_PATH}"
else
  echo "Creating KCLI plans directory in current location"
  mkdir -p "kcli-plans"
  cd "kcli-plans"
  # Here you might want to add code to initialize the plans directory if needed
fi

# Get configuration values with fallbacks
if [ -f "${ANSIBLE_VAULT_FILE}" ] && command -v ansiblesafe &> /dev/null; then
  echo "Using Ansible vault configuration"
  ${USE_SUDO} /usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
  PASSWORD=$(${USE_SUDO} yq eval '.freeipa_server_admin_password' "${ANSIBLE_VAULT_FILE}")
  RHSM_ORG=$(${USE_SUDO} yq eval '.rhsm_org' "${ANSIBLE_VAULT_FILE}")
  RHSM_ACTIVATION_KEY=$(${USE_SUDO} yq eval '.rhsm_activationkey' "${ANSIBLE_VAULT_FILE}")
  PULL_SECRET=$(${USE_SUDO} yq eval '.openshift_pull_secret' "${ANSIBLE_VAULT_FILE}")
else
  echo "Using direct configuration from vars.sh"
  if [ -z "${FREEIPA_ADMIN_PASSWORD}" ]; then
    echo "Error: FREEIPA_ADMIN_PASSWORD must be set in vars.sh when not using Ansible vault"
    exit 1
  fi
  PASSWORD="${FREEIPA_ADMIN_PASSWORD}"
  RHSM_ORG="${RHSM_ORG}"
  RHSM_ACTIVATION_KEY="${RHSM_ACTIVATION_KEY}"
  PULL_SECRET=""
fi

SSH_PASSWORD=${PASSWORD}
VM_NAME=freeipa-$(echo $RANDOM | md5sum | head -c 5; echo;)
IMAGE_NAME=${IMAGE_NAME}

# Get DNS and domain settings
if [ -f "${ANSIBLE_ALL_VARIABLES}" ]; then
  echo "Using Ansible variables for DNS configuration"
  DNS_FORWARDER=$(${USE_SUDO} yq eval '.dns_forwarder' "${ANSIBLE_ALL_VARIABLES}")
  DOMAIN=$(${USE_SUDO} yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")
  # Get admin user from Ansible vars if not set directly
  if [ -z "${KCLI_USER}" ]; then
    KCLI_USER=$(${USE_SUDO} yq eval '.admin_user' "${ANSIBLE_ALL_VARIABLES}")
  fi
elif [ -f "${DNS_VARIABLES_FILE}" ]; then
  echo "Using custom DNS variables file"
  DNS_FORWARDER=$(${USE_SUDO} yq eval '.dns_forwarder' "${DNS_VARIABLES_FILE}")
  DOMAIN=$(${USE_SUDO} yq eval '.domain' "${DNS_VARIABLES_FILE}")
  # Get admin user from DNS vars file if not set directly
  if [ -z "${KCLI_USER}" ]; then
    KCLI_USER=$(${USE_SUDO} yq eval '.admin_user' "${DNS_VARIABLES_FILE}")
  fi
else
  echo "Using DNS settings from vars.sh"
  # These values should already be set in vars.sh
  if [ -z "${DNS_FORWARDER}" ] || [ -z "${DOMAIN}" ]; then
    echo "Error: DNS_FORWARDER and DOMAIN must be set in vars.sh when not using Ansible variables"
    exit 1
  fi
fi

DISK_SIZE=50
# Use LOGIN_USER as fallback if KCLI_USER is not set
KCLI_USER=${KCLI_USER}

if [ "$IMAGE_NAME" == "centos8stream" ]; then
  echo "Community version"
${USE_SUDO} tee /tmp/vm_vars.yaml <<EOF
image: ${IMAGE_NAME}
user: ${LOGIN_USER}
user_password: ${PASSWORD}
disk_size: ${DISK_SIZE} 
numcpus: 4
memory: 8184
net_name: ${KCLI_NETWORK} 
reservedns: ${DNS_FORWARDER}
domainname: ${DOMAIN}
EOF
elif [ "$IMAGE_NAME" == "rhel8" ]; then
  echo "Enterprise version"
${USE_SUDO} tee /tmp/vm_vars.yaml <<EOF
image: ${IMAGE_NAME}
user: ${LOGIN_USER}
user_password: ${PASSWORD}
disk_size: ${DISK_SIZE} 
numcpus: 4
memory: 8184
net_name: ${KCLI_NETWORK} 
reservedns: ${DNS_FORWARDER}
domainname: ${DOMAIN}
rhnorg: ${RHSM_ORG}
rhnactivationkey: ${RHSM_ACTIVATION_KEY} 
EOF
else
  echo "Correct IMAGE_NAME: $IMAGE_NAME not set"
  exit 1
fi

# if target server is null run target server is empty if target server is hetzner run hetzner else run default
if [ -z "$TARGET_SERVER" ]; then
  echo "TARGET_SERVER is empty"
  ${USE_SUDO} python3 profile_generator.py update-yaml freeipa ${TEMPLATE_NAME} --vars-file /tmp/vm_vars.yaml
elif [ "$TARGET_SERVER" == "hetzner" ] || [ "$TARGET_SERVER" == "rhel9-equinix" ]; then
  echo "TARGET_SERVER is $TARGET_SERVER"
  ${USE_SUDO} python3 profile_generator.py update-yaml freeipa ${TEMPLATE_NAME}  --vars-file /tmp/vm_vars.yaml
else
  echo "TARGET_SERVER is ${TARGET_SERVER}"
 ${USE_SUDO} python3 profile_generator.py update-yaml freeipa ${TEMPLATE_NAME} --vars-file /tmp/vm_vars.yaml
fi

#cat  kcli-profiles.yml
sleep 10s
${USE_SUDO} cp kcli-profiles.yml ${KCLI_CONFIG_DIR}/profiles.yml
${USE_SUDO} cp kcli-profiles.yml /root/.kcli/profiles.yml

IN_INSTALLED=$(sudo kcli list vm | grep freeipa | awk '{print $2}')

if [ -n "$IN_INSTALLED" ]; then
    echo "FreeIPA is installed on VM $IN_INSTALLED"
else
    echo "FreeIPA is not installed"
    ${USE_SUDO} /usr/bin/kcli create vm -p freeipa freeipa  || exit $?
fi

IP_ADDRESS=$(${USE_SUDO} /usr/bin/kcli info vm freeipa | grep ip: | awk '{print $2}')
echo "IP Address: ${IP_ADDRESS}"
echo "${IP_ADDRESS} ${IDM_HOSTNAME}.${DOMAIN}" | ${USE_SUDO} tee -a /etc/hosts
echo "${IP_ADDRESS} ${IDM_HOSTNAME}" | ${USE_SUDO} tee -a /etc/hosts
${USE_SUDO} /usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 1

if [ -d $HOME/.generated/.${IDM_HOSTNAME}.${DOMAIN} ]; then
  echo "generated directory already exists"
else
  ${USE_SUDO} mkdir -p  $HOME/.generated/.${IDM_HOSTNAME}.${DOMAIN}
fi

sudo tee /tmp/inventory <<EOF
## Ansible Inventory template file used by Terraform to create an ./inventory file populated with the nodes it created

[idm]
${IDM_HOSTNAME}

[all:vars]
ansible_ssh_private_key_file=/root/.ssh/id_rsa
ansible_ssh_user=${KCLI_USER}
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
ansible_internal_private_ip=${IP_ADDRESS}
EOF

${USE_SUDO} mv /tmp/inventory  $HOME/.generated/.${IDM_HOSTNAME}.${DOMAIN}/

# Create a test playbook
${USE_SUDO} tee /tmp/test_connection.yml <<EOF
---
- hosts: idm
  gather_facts: no
  tasks:
    - name: Test connection
      ping:
EOF

# Continue with the rest of the script only if the test passed
${USE_SUDO} sed -i  "s/PRIVATE_IP=.*/PRIVATE_IP=${IP_ADDRESS}/g" ${FREEIPA_REPO_LOC}/vars.sh
${USE_SUDO} sed -i  "s/DOMAIN=.*/DOMAIN=${DOMAIN}/g" ${FREEIPA_REPO_LOC}/vars.sh
${USE_SUDO} sed -i  "s/DNS_FORWARDER=.*/DNS_FORWARDER=${DNS_FORWARDER}/g" ${FREEIPA_REPO_LOC}/vars.sh

${USE_SUDO} sshpass -p "$SSH_PASSWORD" ${USE_SUDO} ssh-copy-id -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no ${KCLI_USER}@${IP_ADDRESS} || exit $?

# Test the inventory with ansible-playbook
${USE_SUDO} export ANSIBLE_HOST_KEY_CHECKING=False
${USE_SUDO} ansible-playbook -i $HOME/.generated/.${IDM_HOSTNAME}.${DOMAIN}/inventory /tmp/test_connection.yml
if [ $? -ne 0 ]; then
    echo "Ansible inventory test failed. Please check the connection details and try again."
    exit 1
fi
