#!/bin/bash
#export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -xe	## Uncomment for debugging


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
        exit 1
    fi
}

if [ "$EUID" -ne 0 ]
then 
  export USE_SUDO="sudo"
fi

if [ ! -z "$CICD_PIPELINE" ]; then
  export USE_SUDO="sudo"
fi

if [ "$BASE_OS" == "ROCKY8" ]; then
  source ~/.profile
  export USE_SUDO="sudo"
else 
  checkForProgramAndExit ansiblesafe
fi

if [[ ! -f /var/lib/libvirt/images/rhel8 ]];
then
  echo "RHEL8 image not found"
  echo "Please Run  the following command to download the image"
  echo "sudo kcli download image rhel8"
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

if [ -d ${KCLI_PLANS_PATH} ]; then
  echo "kcli-plan-samples already exists"
else
  exit 1
fi

cd ${KCLI_PLANS_PATH}
${USE_SUDO} /usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
PASSWORD=$(${USE_SUDO} yq eval '.freeipa_server_admin_password' "${ANSIBLE_VAULT_FILE}")
SSH_PASSWORD=${PASSWORD}
RHSM_ORG=$(${USE_SUDO} yq eval '.rhsm_org' "${ANSIBLE_VAULT_FILE}")
RHSM_ACTIVATION_KEY=$(${USE_SUDO} yq eval '.rhsm_activationkey' "${ANSIBLE_VAULT_FILE}")
PULL_SECRET=$(${USE_SUDO} yq eval '.openshift_pull_secret' "${ANSIBLE_VAULT_FILE}")
VM_NAME=freeipa-$(echo $RANDOM | md5sum | head -c 5; echo;)
IMAGE_NAME=rhel8
DNS_FORWARDER=$(${USE_SUDO} yq eval '.dns_forwarder' "${ANSIBLE_ALL_VARIABLES}")
DOMAIN=$(${USE_SUDO} yq eval '.domain' "${ANSIBLE_ALL_VARIABLES}")
DISK_SIZE=50
KCLI_USER=$(${USE_SUDO} yq eval '.admin_user' "${ANSIBLE_ALL_VARIABLES}")

${USE_SUDO} tee /tmp/vm_vars.yaml <<EOF
image: ${IMAGE_NAME}
user: cloud-user
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

# if target server is null run target server is empty if target server is hetzner run hetzner else run default
if [ -z "$TARGET_SERVER" ]; then
  echo "TARGET_SERVER is empty"
  ${USE_SUDO} python3 profile_generator/profile_generator.py update-yaml freeipa freeipa/template.yaml --vars-file /tmp/vm_vars.yaml
elif [ "$TARGET_SERVER" == "hetzner" ]; then
  echo "TARGET_SERVER is hetzner"
  ${USE_SUDO} python3 profile_generator/profile_generator.py update_yaml freeipa freeipa/template.yaml --vars-file /tmp/vm_vars.yaml
else
  echo "TARGET_SERVER is ${TARGET_SERVER}"
 ${USE_SUDO} python3 profile_generator/profile_generator.py update-yaml freeipa freeipa/template.yaml --vars-file /tmp/vm_vars.yaml
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
    ${USE_SUDO} /usr/bin/kcli create vm -p freeipa freeipa -w || exit $?
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
ansible_ssh_user=cloud-user
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
ansible_internal_private_ip=${IP_ADDRESS}
EOF


${USE_SUDO} mv /tmp/inventory  $HOME/.generated/.${IDM_HOSTNAME}.${DOMAIN}/

${USE_SUDO} sed -i  "s/PRIVATE_IP=.*/PRIVATE_IP=${IP_ADDRESS}/g" ${FREEIPA_REPO_LOC}/vars.sh
${USE_SUDO} sed -i  "s/DOMAIN=.*/DOMAIN=${DOMAIN}/g" ${FREEIPA_REPO_LOC}/vars.sh
${USE_SUDO} sed -i  "s/DNS_FORWARDER=.*/DNS_FORWARDER=${DNS_FORWARDER}/g" ${FREEIPA_REPO_LOC}/vars.sh

${USE_SUDO} sshpass -p "$SSH_PASSWORD" ${USE_SUDO} ssh-copy-id -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no cloud-user@${IP_ADDRESS} || exit $?

