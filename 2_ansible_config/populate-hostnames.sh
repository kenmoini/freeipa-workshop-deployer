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

## Include inventory if the file exists
if [ $INFRA_PROVIDER = "kcli" ]; then
  INVENTORY=$HOME/.generated/.${IDM_HOSTNAME}.${DOMAIN}/inventory
  ansible-galaxy install --force -r "2_ansible_config/collections/requirements.yaml" 
  sudo ansible-galaxy install --force -r "2_ansible_config/collections/requirements.yaml"
  ansible-galaxy collection install freeipa.ansible_freeipa
  sudo ansible-galaxy collection install freeipa.ansible_freeipa
else
  INVENTORY=.generated/.${IDM_HOSTNAME}.${DOMAIN}/inventory
fi

if [ -f "$INVENTORY" ]; then
    echo "Inventory found, proceeding..."
else
    echo "No inventory file found - run the infrastructure deployer first!"
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

checkForProgramAndExit ansible-playbook

## Include inventory if the file exists
if [ $INFRA_PROVIDER = "kcli" ]; then
    sudo ansible-playbook -i  $HOME/.generated/.${IDM_HOSTNAME}.${DOMAIN}/inventory \
        --extra-vars "idm_hostname=${IDM_HOSTNAME}" \
        --extra-vars "domain=${DOMAIN}" \
        2_ansible_config/populate-hostnames.yaml
else
    ansible-playbook -i .generated/.${IDM_HOSTNAME}.${DOMAIN}/inventory \
        --extra-vars "idm_hostname=${IDM_HOSTNAME}" \
        --extra-vars "domain=${DOMAIN}" \
        populate-hostnames.yaml
fi