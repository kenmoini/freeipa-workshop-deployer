#!/bin/bash

## set -x	## Uncomment for debugging

sudo pwd

## Include vars if the file exists
FILE=./vars.sh
if [ -f "$FILE" ]; then
    source ./vars.sh
else
    echo "No variable file found!"
    exit 1
fi

if [ $INFRA_PROVIDER = "aws" ]; then
  ./1_infra_aws/create.sh
fi

if [ $INFRA_PROVIDER = "digitalocean" ]; then
  ./1_infra_digitalocean/create.sh
fi

if [ $INFRA_PROVIDER = "kcli" ]; then
  ./1_kcli/create.sh
fi

#./2_ansible_config/configure.sh