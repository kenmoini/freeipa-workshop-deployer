#!/bin/bash

## set -x	## Uncomment for debugging
if [ "$EUID" -ne 0 ]
then 
  export USE_SUDO="sudo"
fi


## Include vars if the file exists
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



echo "Destroying the infrastructure..."
echo "${USE_SUDO} kcli delete vm freeipa"
${USE_SUDO} kcli delete vm freeipa

rm -rf ../.generated/
cat >/tmp/resolv.conf<<EOF
search ${DOMAIN}
domain ${DOMAIN}
nameserver ${DNS_FORWARDER}
EOF
${USE_SUDO} mv /tmp/resolv.conf /etc/resolv.conf
${USE_SUDO} sed -i '/${IDM_HOSTNAME}.${DOMAIN}/d' /etc/hosts
${USE_SUDO} sed -i '/${IDM_HOSTNAME}/d' /etc/hosts
