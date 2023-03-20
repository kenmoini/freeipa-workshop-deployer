#!/bin/bash

## set -x	## Uncomment for debugging

sudo pwd

## Include vars if the file exists
FILE=vars.sh
if [ -f "$FILE" ]; then
    source vars.sh
else
    echo "No variable file found!"
    exit 1
fi

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
checkForProgramAndExit ansiblesafe

if [ -d ${KCLI_PLANS_PATH} ]; then
  echo "kcli-plan-samples already exists"
else
  exit 1
fi

cd ${KCLI_PLANS_PATH}
ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
PASSWORD=$(yq eval '.admin_user_password' "${ANSIBLE_VAULT_FILE}")
sudo python3 profile_generator/profile_generator.py update_yaml freeipa freeipa/template.yaml --image CentOS-Stream-GenericCloud-8-20220913.0.x86_64.qcow2 --user $USER --user-password ${PASSWORD} 
cat  kcli-profiles.yml
sleep 10s
cp kcli-profiles.yml ${KCLI_CONFIG_DIR}/profiles.yml
sudo cp kcli-profiles.yml /root/.kcli/profiles.yml
sudo kcli create vm -p freeipa freeipa -w
IP_ADDRESS=$(sudo kcli info vm freeipa | grep ip: | awk '{print $2}')
echo "IP Address: ${IP_ADDRESS}"
echo "${IP_ADDRESS} ${IDM_HOSTNAME}" | sudo tee -a /etc/hosts
ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 1

if [ -d $HOME/.generated/.${IDM_HOSTNAME}.${DOMAIN} ]; then
  echo "generated directory already exists"
else
  sudo mkdir -p  $HOME/.generated/.${IDM_HOSTNAME}.${DOMAIN}
fi

cat >/tmp/inventory<<EOF
## Ansible Inventory template file used by Terraform to create an ./inventory file populated with the nodes it created

[idm]
${IDM_HOSTNAME}

[all:vars]
ansible_ssh_private_key_file=/root/.ssh/id_rsa
ansible_ssh_user=centos
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
ansible_internal_private_ip=${IP_ADDRESS}
EOF

sudo mv /tmp/inventory  $HOME/.generated/.${IDM_HOSTNAME}.${DOMAIN}/

sudo sed -i  "s/freeipa/${IP_ADDRESS}/g" ${FREEIPA_REPO_LOC}/vars.sh
