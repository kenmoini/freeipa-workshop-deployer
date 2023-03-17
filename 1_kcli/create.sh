#!/bin/bash

## set -x	## Uncomment for debugging

sudo pwd

## Include vars if the file exists
ls -lath . 
FILE=../vars.sh
if [ -f "$FILE" ]; then
    source ../vars.sh
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

if [ -d /opt/qubinode-installer/kcli-plan-samples ]; then
  echo "kcli-plan-samples already exists"
else
  exit 1
fi

cd /opt/qubinode-installer/kcli-plan-samples
ansiblesafe -f "${ANSIBLE_VAULT_FILE}" -o 2
PASSWORD=$(yq eval '.admin_user_password' "${ANSIBLE_VAULT_FILE}")
RHSM_ORG=$(yq eval '.rhsm_org' "${ANSIBLE_VAULT_FILE}")
RHSM_ACTIVATION_KEY=$(yq eval '.admin_user_password' "${ANSIBLE_VAULT_FILE}")
sudo python3 profile_generator/profile_generator.py update_yaml freeipa rhel9/template.yaml --image rhel-baseos-9.1-x86_64-kvm.qcow2 --user $USER --user-password ${PASSWORD} --rhnorg ${RHSM_ORG} --rhnactivationkey ${RHSM_ACTIVATION_KEY}