"""
Airflow DAG: FreeIPA Identity Management Server Deployment
ADR-0039: FreeIPA and VyOS Airflow DAG Integration
ADR-0043: Airflow Container Host Network Access

This DAG automates the complete deployment of FreeIPA including:
- VM provisioning via kcli
- FreeIPA server installation via Ansible
- DNS configuration
- Service validation

Follows the kcli-pipelines and freeipa-workshop-deployer patterns.
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import BranchPythonOperator

# Default arguments
default_args = {
    'owner': 'qubinode',
    'depends_on_past': False,
    'start_date': datetime(2025, 11, 27),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=3),
}

# DAG definition
dag = DAG(
    'freeipa_deployment',
    default_args=default_args,
    description='Deploy FreeIPA Identity Management Server via kcli and Ansible',
    schedule=None,  # Manual trigger only
    catchup=False,
    tags=['qubinode', 'freeipa', 'identity', 'infrastructure', 'kcli-pipelines'],
    params={
        'action': 'create',  # create or destroy
        'community_version': 'true',  # true for CentOS, false for RHEL
        'os_version': '9',  # 8 or 9
        'domain': 'example.com',
        'idm_hostname': 'idm',
        'dns_forwarder': '8.8.8.8',
        'run_ansible_install': 'true',  # Run Ansible to install FreeIPA
    },
)

# Paths - using host paths since we run with host network (ADR-0043)
FREEIPA_DEPLOYER = '/opt/freeipa-workshop-deployer'
QUBINODE_NAV = '/opt/qubinode_navigator'


def decide_action(**context):
    """Branch based on action parameter (create or destroy)."""
    action = context['params'].get('action', 'create')
    if action == 'destroy':
        return 'destroy_freeipa'
    return 'validate_environment'


# Task: Decide action
decide_action_task = BranchPythonOperator(
    task_id='decide_action',
    python_callable=decide_action,
    dag=dag,
)

# =============================================================================
# CREATE WORKFLOW
# =============================================================================

# Task: Validate environment
validate_environment = BashOperator(
    task_id='validate_environment',
    bash_command='''
    echo "========================================"
    echo "Validating FreeIPA Deployment Environment"
    echo "========================================"
    
    COMMUNITY_VERSION="{{ params.community_version }}"
    OS_VERSION="{{ params.os_version }}"
    
    echo "Community Version: $COMMUNITY_VERSION"
    echo "OS Version: $OS_VERSION"
    
    # Determine image name
    if [ "$COMMUNITY_VERSION" == "true" ]; then
        if [ "$OS_VERSION" == "9" ]; then
            IMAGE_NAME="centos9stream"
        else
            IMAGE_NAME="centos8stream"
        fi
    else
        if [ "$OS_VERSION" == "9" ]; then
            IMAGE_NAME="rhel9"
        else
            IMAGE_NAME="rhel8"
        fi
    fi
    echo "Image: $IMAGE_NAME"
    
    # Check kcli
    if ! command -v kcli &> /dev/null; then
        echo "[ERROR] kcli not installed"
        exit 1
    fi
    echo "[OK] kcli installed: $(kcli --version 2>&1 | head -1)"
    
    # Check image exists
    if kcli list images | grep -q "$IMAGE_NAME"; then
        echo "[OK] Image $IMAGE_NAME available"
    else
        echo "[WARN]  Image $IMAGE_NAME not found, downloading..."
        kcli download image $IMAGE_NAME || {
            echo "[ERROR] Failed to download image"
            exit 1
        }
    fi
    
    # Check vault.yml exists
    VAULT_FILE="/opt/qubinode_navigator/inventories/localhost/group_vars/control/vault.yml"
    if [ -f "$VAULT_FILE" ]; then
        echo "[OK] vault.yml found"
    else
        echo "[ERROR] vault.yml not found at $VAULT_FILE"
        echo "Run: deploy-qubinode-with-airflow.sh to create it"
        exit 1
    fi
    
    # Check freeipa-workshop-deployer
    if [ -d "/opt/freeipa-workshop-deployer" ]; then
        echo "[OK] freeipa-workshop-deployer found"
    else
        echo "[WARN]  Cloning freeipa-workshop-deployer..."
        git clone https://github.com/tosin2013/freeipa-workshop-deployer.git /opt/freeipa-workshop-deployer
    fi
    
    echo ""
    echo "[OK] Environment validation complete"
    ''',
    dag=dag,
)

# Task: Create FreeIPA VM
create_freeipa_vm = BashOperator(
    task_id='create_freeipa_vm',
    bash_command='''
    echo "========================================"
    echo "Creating FreeIPA VM"
    echo "========================================"
    
    COMMUNITY_VERSION="{{ params.community_version }}"
    OS_VERSION="{{ params.os_version }}"
    DOMAIN="{{ params.domain }}"
    IDM_HOSTNAME="{{ params.idm_hostname }}"
    
    # Determine image
    if [ "$COMMUNITY_VERSION" == "true" ]; then
        [ "$OS_VERSION" == "9" ] && IMAGE_NAME="centos9stream" || IMAGE_NAME="centos8stream"
        LOGIN_USER="cloud-user"
    else
        [ "$OS_VERSION" == "9" ] && IMAGE_NAME="rhel9" || IMAGE_NAME="rhel8"
        LOGIN_USER="cloud-user"
    fi
    
    VM_NAME="freeipa"
    
    # Check if VM exists
    if kcli info vm $VM_NAME &>/dev/null; then
        echo "[WARN]  VM $VM_NAME already exists"
        kcli info vm $VM_NAME
        exit 0
    fi
    
    echo "Creating VM: $VM_NAME"
    echo "  Image: $IMAGE_NAME"
    echo "  Memory: 4096 MB"
    echo "  CPUs: 2"
    echo "  Disk: 50 GB"
    
    # Create VM
    kcli create vm $VM_NAME \
        -i $IMAGE_NAME \
        -P memory=4096 \
        -P numcpus=2 \
        -P disks=[50] \
        -P nets=[default] \
        --wait || {
        echo "[ERROR] Failed to create VM"
        exit 1
    }
    
    echo ""
    echo "[OK] VM created successfully"
    kcli info vm $VM_NAME
    ''',
    execution_timeout=timedelta(minutes=10),
    dag=dag,
)

# Task: Wait for VM and get IP
wait_for_vm = BashOperator(
    task_id='wait_for_vm',
    bash_command='''
    echo "========================================"
    echo "Waiting for FreeIPA VM to be Ready"
    echo "========================================"
    
    VM_NAME="freeipa"
    MAX_ATTEMPTS=60
    
    echo "Waiting for VM to get IP address..."
    
    for i in $(seq 1 $MAX_ATTEMPTS); do
        # Get IP from kcli
        VM_INFO=$(kcli info vm $VM_NAME 2>/dev/null)
        IP=$(echo "$VM_INFO" | grep "^ip:" | awk '{print $2}')
        
        if [ -n "$IP" ] && [ "$IP" != "None" ] && [ "$IP" != "" ]; then
            echo "[OK] VM IP: $IP"
            
            # Wait for SSH
            echo "Waiting for SSH..."
            for j in $(seq 1 30); do
                if nc -z -w5 $IP 22 2>/dev/null; then
                    echo "[OK] SSH is available"
                    
                    # Save IP for next tasks
                    echo "$IP" > /tmp/freeipa_ip.txt
                    
                    echo ""
                    echo "========================================"
                    echo "FreeIPA VM Ready"
                    echo "========================================"
                    echo "VM Name: $VM_NAME"
                    echo "IP Address: $IP"
                    echo "SSH: ssh cloud-user@$IP"
                    exit 0
                fi
                echo "  Attempt $j/30: SSH not ready..."
                sleep 5
            done
            
            echo "[WARN]  SSH not available after 30 attempts"
            exit 0
        fi
        
        echo "  Attempt $i/$MAX_ATTEMPTS: Waiting for IP..."
        sleep 5
    done
    
    echo "[ERROR] Failed to get VM IP after $MAX_ATTEMPTS attempts"
    exit 1
    ''',
    execution_timeout=timedelta(minutes=10),
    dag=dag,
)

# Task: Prepare Ansible Inventory
prepare_ansible = BashOperator(
    task_id='prepare_ansible',
    bash_command='''
    echo "========================================"
    echo "Preparing Ansible for FreeIPA Installation"
    echo "========================================"
    
    DOMAIN="{{ params.domain }}"
    IDM_HOSTNAME="{{ params.idm_hostname }}"
    DNS_FORWARDER="{{ params.dns_forwarder }}"
    COMMUNITY_VERSION="{{ params.community_version }}"
    
    # Get IP
    VM_NAME="freeipa"
    export PATH="/home/airflow/.local/bin:/usr/local/bin:$PATH"
    IP=$(kcli info vm $VM_NAME 2>/dev/null | grep "^ip:" | awk '{print $2}')
    
    if [ -z "$IP" ] || [ "$IP" == "None" ]; then
        echo "[ERROR] Could not get VM IP"
        exit 1
    fi
    
    echo "VM IP: $IP"
    echo "Domain: $DOMAIN"
    echo "IDM Hostname: $IDM_HOSTNAME"
    
    # Determine login user
    [ "$COMMUNITY_VERSION" == "true" ] && LOGIN_USER="cloud-user" || LOGIN_USER="cloud-user"
    
    # Create inventory directory
    INVENTORY_DIR="$HOME/.generated/.${IDM_HOSTNAME}.${DOMAIN}"
    mkdir -p "$INVENTORY_DIR"
    
    # Create Ansible inventory
    cat > "$INVENTORY_DIR/inventory" << EOF
[idm]
${IDM_HOSTNAME}

[all:vars]
ansible_ssh_private_key_file=/root/.ssh/id_rsa
ansible_ssh_user=${LOGIN_USER}
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
ansible_host=${IP}
ansible_internal_private_ip=${IP}
EOF
    
    echo "[OK] Inventory created at $INVENTORY_DIR/inventory"
    cat "$INVENTORY_DIR/inventory"
    
    # Update /etc/hosts
    grep -v "${IDM_HOSTNAME}" /etc/hosts > /tmp/hosts.tmp || true
    echo "${IP} ${IDM_HOSTNAME}.${DOMAIN} ${IDM_HOSTNAME}" >> /tmp/hosts.tmp
    cp /tmp/hosts.tmp /etc/hosts
    echo "[OK] Updated /etc/hosts"
    
    # Test SSH connectivity
    echo ""
    echo "Testing SSH connectivity..."
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ${LOGIN_USER}@${IP} "hostname" || {
        echo "[WARN]  SSH test failed - may need to wait longer"
    }
    
    # Install Ansible collections
    echo ""
    echo "Installing Ansible collections..."
    cd /opt/freeipa-workshop-deployer
    if [ -f "2_ansible_config/collections/requirements.yaml" ]; then
        ansible-galaxy install --force -r /opt/freeipa-workshop-deployer/2_ansible_config/collections/requirements.yaml 2>/dev/null || true
        ansible-galaxy collection install freeipa.ansible_freeipa 2>/dev/null || true
    fi
    
    echo ""
    echo "[OK] Ansible preparation complete"
    ''',
    dag=dag,
)

# Task: Install FreeIPA via Ansible
# ADR-0046: Use SSH to run Ansible on host to avoid version conflicts
install_freeipa = BashOperator(
    task_id='install_freeipa',
    bash_command="""
    export PATH="/home/airflow/.local/bin:/usr/local/bin:$PATH"
    set -e
    echo "========================================"
    echo "Installing FreeIPA via Ansible"
    echo "========================================"
    
    RUN_ANSIBLE="{{ params.run_ansible_install }}"
    
    if [ "$RUN_ANSIBLE" != "true" ]; then
        echo "SKIP: Ansible installation skipped"
        exit 0
    fi
    
    DOMAIN="{{ params.domain }}"
    IDM_HOSTNAME="{{ params.idm_hostname }}"
    DNS_FORWARDER="{{ params.dns_forwarder }}"
    
    VM_NAME="freeipa"
    IP=$(kcli info vm $VM_NAME 2>/dev/null | grep "^ip:" | awk '{print $2}')
    
    if [ -z "$IP" ]; then
        echo "ERROR: Could not get VM IP"
        exit 1
    fi
    
    INVENTORY_DIR="/root/.generated/.${IDM_HOSTNAME}.${DOMAIN}"
    PLAYBOOK_DIR="/root/freeipa-workshop-deployer"
    
    echo "Running Ansible playbook on host via SSH..."
    echo "  Inventory: $INVENTORY_DIR/inventory"
    echo "  Playbook: $PLAYBOOK_DIR/2_ansible_config/deploy_idm.yaml"
    echo "  Domain: $DOMAIN"
    echo "  IDM Hostname: $IDM_HOSTNAME"
    echo "  DNS Forwarder: $DNS_FORWARDER"
    echo "  VM IP: $IP"
    
    # Execute Ansible on host via SSH (ADR-0046)
    # This ensures we use the host's Ansible version and collections
    ssh -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        root@localhost \
        "cd $PLAYBOOK_DIR && \
         ANSIBLE_HOST_KEY_CHECKING=False \
         ansible-playbook \
         -i $INVENTORY_DIR/inventory \
         --extra-vars 'idm_hostname=${IDM_HOSTNAME}' \
         --extra-vars 'private_ip=${IP}' \
         --extra-vars 'domain=${DOMAIN}' \
         --extra-vars 'dns_forwarder=${DNS_FORWARDER}' \
         2_ansible_config/deploy_idm.yaml \
         -v"
    
    echo ""
    echo "========================================"
    echo "FreeIPA Installation Complete!"
    echo "========================================"
    echo "FreeIPA Web UI: https://${IDM_HOSTNAME}.${DOMAIN}"
    echo "IP Address: ${IP}"
    echo "Username: admin"
    """,
    execution_timeout=timedelta(minutes=30),
    dag=dag,
)

# Task: Validate FreeIPA Installation
validate_freeipa = BashOperator(
    task_id='validate_freeipa',
    bash_command="""
    export PATH="/home/airflow/.local/bin:/usr/local/bin:$PATH"
    echo "========================================"
    echo "Validating FreeIPA Installation"
    echo "========================================"
    
    DOMAIN="{{ params.domain }}"
    IDM_HOSTNAME="{{ params.idm_hostname }}"
    RUN_ANSIBLE="{{ params.run_ansible_install }}"
    
    VM_NAME="freeipa"
    export PATH="/home/airflow/.local/bin:/usr/local/bin:$PATH"
    IP=$(kcli info vm $VM_NAME 2>/dev/null | grep "^ip:" | awk '{print $2}')
    
    echo "Checking FreeIPA services on $IP..."
    
    if [ "$RUN_ANSIBLE" == "true" ]; then
        ssh -o StrictHostKeyChecking=no cloud-user@$IP "sudo ipactl status" 2>/dev/null || echo "Note: Could not verify FreeIPA services yet"
    else
        echo "Note: Ansible installation was skipped"
    fi
    
    echo ""
    echo "========================================"
    echo "FreeIPA Deployment Summary"
    echo "========================================"
    echo "VM Name: $VM_NAME"
    echo "IP Address: $IP"
    echo "FQDN: ${IDM_HOSTNAME}.${DOMAIN}"
    echo ""
    echo "Access:"
    echo "  SSH: ssh cloud-user@$IP"
    echo "  Web UI: https://${IDM_HOSTNAME}.${DOMAIN}"
    echo "  Username: admin"
    """,
    dag=dag,
)

# =============================================================================
# DESTROY WORKFLOW
# =============================================================================

destroy_freeipa = BashOperator(
    task_id='destroy_freeipa',
    bash_command='''
    echo "========================================"
    echo "Destroying FreeIPA VM"
    echo "========================================"
    
    VM_NAME="freeipa"
    
    if kcli info vm $VM_NAME &>/dev/null; then
        echo "Deleting VM: $VM_NAME"
        kcli delete vm $VM_NAME -y
        echo "[OK] VM deleted"
    else
        echo "[WARN]  VM $VM_NAME does not exist"
    fi
    
    # Clean up inventory
    DOMAIN="{{ params.domain }}"
    IDM_HOSTNAME="{{ params.idm_hostname }}"
    rm -rf "$HOME/.generated/.${IDM_HOSTNAME}.${DOMAIN}" 2>/dev/null || true
    
    # Clean up /etc/hosts
    grep -v "${IDM_HOSTNAME}" /etc/hosts > /tmp/hosts.tmp 2>/dev/null || true
    cp /tmp/hosts.tmp /etc/hosts 2>/dev/null || true
    
    echo ""
    echo "[OK] FreeIPA cleanup complete"
    ''',
    dag=dag,
)

# =============================================================================
# DAG WORKFLOW
# =============================================================================

# Create workflow
decide_action_task >> validate_environment >> create_freeipa_vm >> wait_for_vm >> prepare_ansible >> install_freeipa >> validate_freeipa

# Destroy workflow
decide_action_task >> destroy_freeipa

# DAG documentation
dag.doc_md = """
# FreeIPA Deployment DAG

This DAG automates the complete deployment of FreeIPA Identity Management Server.

## Workflow

### Create (action=create)
1. **validate_environment** - Check kcli, images, vault.yml
2. **create_freeipa_vm** - Create VM via kcli
3. **wait_for_vm** - Wait for IP and SSH
4. **prepare_ansible** - Create inventory, install collections
5. **install_freeipa** - Run Ansible playbook to install FreeIPA
6. **validate_freeipa** - Verify services are running

### Destroy (action=destroy)
1. **destroy_freeipa** - Delete VM and cleanup

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| action | create | create or destroy |
| community_version | true | true=CentOS, false=RHEL |
| os_version | 9 | 8 or 9 |
| domain | example.com | Domain name |
| idm_hostname | idm | Hostname for FreeIPA |
| dns_forwarder | 8.8.8.8 | DNS forwarder |
| run_ansible_install | true | Run Ansible to install FreeIPA |

## Prerequisites

- vault.yml with freeipa_server_admin_password
- kcli configured with libvirt
- Base OS image (centos9stream or rhel9)

## Related ADRs

- ADR-0039: FreeIPA and VyOS Airflow DAG Integration
- ADR-0042: FreeIPA Base OS Upgrade to RHEL 9
- ADR-0043: Airflow Container Host Network Access
"""
