  #!/bin/bash

  #set -x	## Uncomment for debugging

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

  function checkforvault() {
    if [ -f /opt/qubinode_navigator/ansible_vault_setup.sh ];
    then
        ~/qubinode_navigator/ansible_vault_setup.sh
    else
      echo "No ansible_vault_setup.sh file found!"        
      if [ -f ansible_vault_setup.sh  ];
      then
        ${USE_SUDO} ./ansible_vault_setup.sh
      else
        curl -OL https://gist.githubusercontent.com/tosin2013/022841d90216df8617244ab6d6aceaf8/raw/92400b9e459351d204feb67b985c08df6477d7fa/ansible_vault_setup.sh
        chmod +x ansible_vault_setup.sh
        ${USE_SUDO} ./ansible_vault_setup.sh
      fi
    fi
  }

  if [ "$EUID" -ne 0 ]
  then 
    export USE_SUDO="sudo"
  fi

  if [ ! -z "$CICD_PIPELINE" ]; then
    export USE_SUDO="sudo"
  fi


  #checkForProgramAndExit ansible-playbook
  ANSIBLE_COMMAND="/usr/local/bin/ansible-playbook"
  ANSIBLE_GALAXY="/usr/local/bin/ansible-galaxy"

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

  if [ -f ~/.vault_password ]; then
      echo "Vault password file found, proceeding..."
  else
      echo "No vault password file found!"
      checkforvault
  fi


  ## Include inventory if the file exists
  if [ $INFRA_PROVIDER = "kcli" ]; then
    INVENTORY=$HOME/.generated/.${IDM_HOSTNAME}.${DOMAIN}/inventory
    ${ANSIBLE_GALAXY} install --force -r "2_ansible_config/collections/requirements.yaml" 
    ${USE_SUDO} ${ANSIBLE_GALAXY} install --force -r "2_ansible_config/collections/requirements.yaml"
    ${ANSIBLE_GALAXY}  collection install freeipa.ansible_freeipa
    ${USE_SUDO} ${ANSIBLE_GALAXY}  collection install freeipa.ansible_freeipa
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

  if [ $INFRA_PROVIDER = "kcli" ]; then
    ${USE_SUDO} ${ANSIBLE_COMMAND} -i  $HOME/.generated/.${IDM_HOSTNAME}.${DOMAIN}/inventory \
    --extra-vars "idm_hostname=${IDM_HOSTNAME}" \
    --extra-vars "private_ip=${PRIVATE_IP}" \
    --extra-vars "domain=${DOMAIN}" \
    --extra-vars "dns_forwarder=${DNS_FORWARDER}" \
    2_ansible_config/deploy_idm.yaml  || exit $?
  else
      ${ANSIBLE_COMMAND}  -i ../.generated/.${IDM_HOSTNAME}.${DOMAIN}/inventory \
      --extra-vars "idm_hostname=${IDM_HOSTNAME}" \
      --extra-vars "domain=${DOMAIN}" \
      --extra-vars "dns_forwarder=${DNS_FORWARDER}" \
      deploy_idm.yaml  || exit $?
  fi

  echo "Login to the FreeIPA server the as admin user:"
  echo "https://${IDM_HOSTNAME}.${DOMAIN}"
  echo "${PRIVATE_IP}"
  echo "USERNAME: admin"
  PASSWORD=$(yq eval '.freeipa_server_admin_password' 2_ansible_config/vars/main.yml)
  echo "PASSWORD: ${PASSWORD}"



