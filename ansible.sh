#!/bin/bash

# Default values for variables
: "${USERNAME:=ubuntu}"                # SSH username
: "${ANSIBLE_HOST_IP:=192.168.198.129}" # Control machine IP
: "${RKE2_VERSION:=v1.30.6+rke2r1}"     # Default RKE2 version
: "${RKE2_MODE:=normal}"               # Default mode (normal or ha)
: "${RKE2_TOKEN:=yourSecureToken123}"  # Default RKE2 token
: "${API_IP:=}"                        # Default API IP (empty for normal mode)
: "${RKE2_CNI:=canal}"                 # Default CNI (Container Network Interface)
: "${RKE2_LOADBALANCER_RANGE:=}"       # Default load balancer IP range

# Arrays of IPs for masters and workers
MASTER_IPS=(${MASTER_IPS:-192.168.198.141})
WORKER_IPS=(${WORKER_IPS:-192.168.198.132})

# Prepare Ansible machine
sudo apt update
sudo apt install ansible -y
ansible-galaxy install lablabs.rke2 --force

# Check if SSH is installed; if not, install it
if ! dpkg -l | grep -q openssh-server; then
    echo "OpenSSH Server is not installed. Installing..."
    sudo apt install -y openssh-server
else
    echo "OpenSSH Server is already installed."
fi

# Enable and start SSH service if not already running
if ! systemctl is-active --quiet ssh; then
    echo "Starting SSH service..."
    sudo systemctl enable ssh
    sudo systemctl start ssh
else
    echo "SSH service is already running."
fi

# Generate SSH keys if they don’t already exist
if [ ! -f "$HOME/.ssh/id_rsa" ]; then
    ssh-keygen -t rsa -N "" -f "$HOME/.ssh/id_rsa"
fi

# Copy SSH keys to master and worker nodes
for MASTER_IP in "${MASTER_IPS[@]}"; do
    ssh-copy-id "$USERNAME@$MASTER_IP"
done

for WORKER_IP in "${WORKER_IPS[@]}"; do
    ssh-copy-id "$USERNAME@$WORKER_IP"
done

# Function to add IPv4 entries to /etc/hosts
add_to_hosts() {
    local ip=$1
    local hostname=$2

    # Remove any existing entry with the same hostname, regardless of IP
    sudo sed -i "/[[:space:]]$hostname$/d" /etc/hosts

    # Add the new entry, ensuring it's added before the IPv6 section
    sudo sed -i "/^# The following lines are desirable for IPv6 capable hosts/i\\$ip $hostname" /etc/hosts
}

# Add control machine and node IPs to /etc/hosts
add_to_hosts "$ANSIBLE_HOST_IP" "ansible"

# Update master nodes in /etc/hosts
for i in "${!MASTER_IPS[@]}"; do
    MASTER_IP=${MASTER_IPS[i]}
    add_to_hosts "$MASTER_IP" "master$((i+1))"
done

# Update worker nodes in /etc/hosts
for i in "${!WORKER_IPS[@]}"; do
    WORKER_IP=${WORKER_IPS[i]}
    add_to_hosts "$WORKER_IP" "worker$((i+1))"
done

# Create an Ansible hosts file with master and worker configurations
cat > hosts <<EOF
[masters]
EOF

for i in "${!MASTER_IPS[@]}"; do
    MASTER_IP=${MASTER_IPS[i]}
    echo "master$((i+1)) ansible_host=$MASTER_IP ansible_user=$USERNAME rke2_type=server" >> hosts
done

cat >> hosts <<EOF

[workers]
EOF

for i in "${!WORKER_IPS[@]}"; do
    WORKER_IP=${WORKER_IPS[i]}
    echo "worker$((i+1)) ansible_host=$WORKER_IP ansible_user=$USERNAME rke2_type=agent" >> hosts
done

cat >> hosts <<EOF

[k8s_cluster:children]
masters
workers
EOF

# Run the single playbook with all the required variables
ansible-playbook -i hosts site.yaml \
    --extra-vars "rke2_cni=$RKE2_CNI rke2_version=$RKE2_VERSION rke2_token=$RKE2_TOKEN rke2_mode=$RKE2_MODE api_ip=$API_IP rke2_loadbalancer_ip_range=range-global:$RKE2_LOADBALANCER_RANGE" \
    --ask-become-pass
# # Prompt for the 'become' password (sudo access)
# echo "Please enter the become password:"
# read -s BECOME_PASS

# # Set the ANSIBLE_BECOME_PASS environment variable for Ansible
# export ANSIBLE_BECOME_PASS=$BECOME_PASS

# # Deploy RKE2 based on the mode (normal or ha)
# if [[ $RKE2_MODE == "normal" && ${#MASTER_IPS[@]} -eq 1 && ${#WORKER_IPS[@]} -ge 1 ]]; then
#     ansible-playbook -i hosts tasks/prepare_vm.yaml
#     # Normal mode: one master and one or more workers
#     ansible-playbook -i hosts tasks/deploy_rke2.yaml \
#         --extra-vars "rke2_cni=$RKE2_CNI rke2_version=$RKE2_VERSION rke2_token=$RKE2_TOKEN"
# elif [[ $RKE2_MODE == "ha" && ${#MASTER_IPS[@]} -gt 1 && ${#WORKER_IPS[@]} -ge 1 ]]; then
#     # HA mode: multiple masters and one or more workers
#     if [[ -z $API_IP || -z $RKE2_LOADBALANCER_RANGE ]]; then
#         echo "In HA mode, API_IP and RKE2_LOADBALANCER_RANGE must be set. Exiting."
#         exit 1
#     fi
#     # Run the Ansible playbooks for setup and deployment
#     ansible-playbook -i hosts tasks/prepare_vm.yaml --extra-vars "api_ip=$API_IP"
#     ansible-playbook -i hosts tasks/deploy_rke2_ha.yaml \
#         --extra-vars "rke2_cni=$RKE2_CNI rke2_version=$RKE2_VERSION rke2_token=$RKE2_TOKEN rke2_api_ip=$API_IP rke2_loadbalancer_ip_range=range-global:$RKE2_LOADBALANCER_RANGE"
# else
#     echo "Invalid configuration: Please check RKE2_MODE, MASTER_IPS, and WORKER_IPS."
#     exit 1
# fi

# # Run post-install and Rancher installation playbooks
# ansible-playbook -i hosts tasks/post_install.yaml
# ansible-playbook -i hosts tasks/install_rancher.yaml
