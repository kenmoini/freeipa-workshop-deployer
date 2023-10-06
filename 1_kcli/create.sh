#!/bin/bash
#export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -xe	## Uncomment for debugging

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


${USE_SUDO} pwd

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

if [ -d ${KCLI_PLANS_PATH} ]; then
  echo "kcli-plan-samples already exists"
else
  exit 1
fi

cd ${KCLI_PLANS_PATH}
 /usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
PASSWORD=$(yq eval '.admin_user_password' "${ANSIBLE_VAULT_FILE}")
${USE_SUDO} python3 profile_generator/profile_generator.py update_yaml freeipa freeipa/template.yaml --image rhel8 --user cloud-user --user-password ${PASSWORD} --net-name ${KCLI_NETWORK}
#cat  kcli-profiles.yml
sleep 10s
${USE_SUDO} cp kcli-profiles.yml ${KCLI_CONFIG_DIR}/profiles.yml
${USE_SUDO} cp kcli-profiles.yml /root/.kcli/profiles.yml

IN_INSTALLED=$(sudo kcli list vm | grep freeipa | awk '{print $2}')

if [ -n "$IN_INSTALLED" ]; then
    echo "FreeIPA is installed on VM $IN_INSTALLED"
else
    echo "FreeIPA is not installed"
    ${USE_SUDO} /usr/bin/kcli create vm -p freeipa freeipa -w
fi

IP_ADDRESS=$(${USE_SUDO} /usr/bin/kcli info vm freeipa | grep ip: | awk '{print $2}')
echo "IP Address: ${IP_ADDRESS}"
echo "${IP_ADDRESS} ${IDM_HOSTNAME}.${DOMAIN}" | ${USE_SUDO} tee -a /etc/hosts
echo "${IP_ADDRESS} ${IDM_HOSTNAME}" | ${USE_SUDO} tee -a /etc/hosts
 /usr/local/bin/ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 1

if [ -d $HOME/.generated/.${IDM_HOSTNAME}.${DOMAIN} ]; then
  echo "generated directory already exists"
else
  ${USE_SUDO} mkdir -p  $HOME/.generated/.${IDM_HOSTNAME}.${DOMAIN}
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

${USE_SUDO} mv /tmp/inventory  $HOME/.generated/.${IDM_HOSTNAME}.${DOMAIN}/

${USE_SUDO} sed -i  "s/freeipa/${IP_ADDRESS}/g" ${FREEIPA_REPO_LOC}/vars.sh
