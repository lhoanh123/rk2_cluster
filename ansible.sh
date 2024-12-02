#!/bin/bash

# Default values for variables
: "${USERNAME:=ubuntu}"                # SSH username
: "${ANSIBLE_HOST_IP:=192.168.198.129}" # Control machine IP
: "${RKE2_VERSION:=v1.30.6+rke2r1}"     # Default RKE2 version
: "${RKE2_MODE:=normal}"               # Default mode (normal or ha)
: "${CLUSTER_NAME:=oanh-cluster}"      # Default cluster name
: "${RKE2_TOKEN:=yourSecureToken123}"  # Default RKE2 token
: "${API_IP:=}"                        # Default API IP (empty for normal mode)
: "${RKE2_CNI:=canal}"                 # Default CNI (Container Network Interface)
: "${RKE2_LOADBALANCER_RANGE:=}"       # Default load balancer IP range

# Arrays of IPs for masters and workers
MASTER_IPS=(${MASTER_IPS:-192.168.198.141})
WORKER_IPS=(${WORKER_IPS:-192.168.198.132})

# Update and install OpenSSH server
sudo apt update
sudo apt install -y openssh-server

# Enable and start SSH service
sudo systemctl enable ssh
sudo systemctl start ssh

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

    # Check if the entry already exists in the IPv4 section
    if ! grep -q "^$ip" /etc/hosts; then
        # Append to the IPv4 section, ensuring it's added before the IPv6 section
        sudo sed -i "/^# The following lines are desirable for IPv6 capable hosts/i\\$ip $hostname" /etc/hosts
    fi
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

# Install Ansible Galaxy role for RKE2
ansible-galaxy install lablabs.rke2 --force

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

# Function to calculate the IP range for the load balancer
calculate_range() {
    local subnet_prefix=${API_IP%.*}   # Extract the subnet (e.g., 192.168.9)
    local exclude_ips=("${MASTER_IPS[@]}" "${WORKER_IPS[@]}" "$API_IP")
    local start_range=26
    local end_range=126
    local range=()

    # Generate the IP range excluding master, worker, and API IPs
    for i in $(seq $start_range $end_range); do
        candidate="$subnet_prefix.$i"
        if [[ ! " ${exclude_ips[@]} " =~ " $candidate " ]]; then
            range+=("$candidate")
        fi
    done

    echo "${range[0]}-${range[-1]}"    # Return the range in the required format
}

# Calculate load balancer IP range if API_IP is provided
if [[ -n $API_IP ]]; then
    RKE2_LOADBALANCER_RANGE=$(calculate_range)
else
    echo "API_IP is not set. Exiting."
    exit 1
fi

# Prompt for the 'become' password (sudo access)
echo "Please enter the become password:"
read -s BECOME_PASS

# Set the ANSIBLE_BECOME_PASS environment variable for Ansible
export ANSIBLE_BECOME_PASS=$BECOME_PASS

# Run the Ansible playbooks for setup and deployment
ansible-playbook -i hosts prepare_vm.yaml --extra-vars "api_ip=$API_IP"

# Deploy RKE2 based on the mode (normal or ha)
if [[ $RKE2_MODE == "normal" && ${#MASTER_IPS[@]} -eq 1 && ${#WORKER_IPS[@]} -ge 1 ]]; then
    # Normal mode: one master and one or more workers
    ansible-playbook -i hosts deploy_rke2_normal.yaml \
        --extra-vars "rke2_cni=$RKE2_CNI rke2_version=$RKE2_VERSION rke2_cluster_name=$CLUSTER_NAME rke2_token=$RKE2_TOKEN"
elif [[ $RKE2_MODE == "ha" && ${#MASTER_IPS[@]} -gt 1 && ${#WORKER_IPS[@]} -ge 1 ]]; then
    # HA mode: multiple masters and one or more workers
    if [[ -z $API_IP || -z $RKE2_LOADBALANCER_RANGE ]]; then
        echo "In HA mode, API_IP and RKE2_LOADBALANCER_RANGE must be set. Exiting."
        exit 1
    fi
    ansible-playbook -i hosts deploy_rke2_ha.yaml \
        --extra-vars "rke2_cni=$RKE2_CNI rke2_version=$RKE2_VERSION rke2_cluster_name=$CLUSTER_NAME rke2_token=$RKE2_TOKEN rke2_api_ip=$API_IP rke2_loadbalancer_ip_range=range-global:$RKE2_LOADBALANCER_RANGE"
else
    echo "Invalid configuration: Please check RKE2_MODE, MASTER_IPS, and WORKER_IPS."
    exit 1
fi

# Run post-install and Rancher installation playbooks
ansible-playbook -i hosts post_install.yaml
ansible-playbook -i hosts install_rancher.yaml
