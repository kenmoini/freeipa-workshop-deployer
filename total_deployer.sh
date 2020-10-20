#!/bin/bash

## set -x	## Uncomment for debugging

./1_infra_digitalocean/create.sh

./2_ansible_config/configure.sh