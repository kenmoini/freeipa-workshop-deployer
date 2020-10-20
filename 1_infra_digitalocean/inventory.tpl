## Ansible Inventory template file used by Terraform to create an ./inventory file populated with the nodes it created

[idm]
${idm_node}

[all:vars]
ansible_ssh_private_key_file=${ssh_private_file}
ansible_ssh_user=root
ansible_ssh_common_args='-o StrictHostKeyChecking=no'