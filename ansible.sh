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
: "${RANCHER_HOSTNAME:=rancher.mylab.com}"  # Default Rancher hostname
: "${RANCHER_BOOTSTRAP_PASSWORD:=admin}"       # Default Rancher bootstrap password
: "${RANCHER_REPLICAS:=1}"                    # Default number of Rancher replicas
: "${LONGHORN_HOSTNAME:=longhorn.mylab.com}"  # Default LONGHORN hostname
: "${LONGHORN_REPLICAS:=1}"                    # Default number of LONGHORN replicas

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

# Function to get the latest RKE2 version from GitHub
get_latest_rke2_version() {
    curl -s "https://api.github.com/repos/rancher/rke2/releases/latest" | \
    grep '"tag_name":' | \
    sed -E 's/.*"([^"]+)".*/\1/'
}

# Set the RKE2_VERSION dynamically
RKE2_VERSION=$(get_latest_rke2_version)
if [[ -z "$RKE2_VERSION" ]]; then
    echo "Failed to fetch the latest RKE2 version. Using default version: v1.30.6+rke2r1"
    RKE2_VERSION="v1.30.6+rke2r1"
fi

echo "Using RKE2 version: $RKE2_VERSION"

# Prompt for the 'become' password (sudo access)
echo "Please enter the become password:"
read -s BECOME_PASS

# Set the ANSIBLE_BECOME_PASS environment variable for Ansible
export ANSIBLE_BECOME_PASS=$BECOME_PASS

# Deploy RKE2 based on the mode (normal or ha)
if [[ $RKE2_MODE == "normal" && ${#MASTER_IPS[@]} -eq 1 && ${#WORKER_IPS[@]} -ge 1 ]]; then
    ansible-playbook -i hosts tasks/prepare_vm.yaml

    # Normal mode: one master and one or more workers
    ansible-playbook -i hosts tasks/deploy_rke2.yaml \
        --extra-vars "rke2_cni=$RKE2_CNI rke2_version=$RKE2_VERSION rke2_token=$RKE2_TOKEN"

    # Run the post_install.yaml playbook for additional setup on master nodes
    ansible-playbook -i hosts tasks/post_install.yaml --user=root

    # Run the install_rancher.yaml playbook with extra variables for Rancher installation
    ansible-playbook -i hosts tasks/install_rancher.yaml \
        --extra-vars "hostname=$RANCHER_HOSTNAME bootstrapPassword=$RANCHER_BOOTSTRAP_PASSWORD replicas=$RANCHER_REPLICAS" \
        --user=root

    # Run the install_longhorn.yaml playbook with extra variables for Longhorn installation
    ansible-playbook -i hosts tasks/install_longhorn.yaml \
        --extra-vars "ingress_host=$LONGHORN_HOSTNAME replica_count=$LONGHORN_REPLICAS" \
        --user=root
        
elif [[ $RKE2_MODE == "ha" && ${#MASTER_IPS[@]} -gt 1 && ${#WORKER_IPS[@]} -ge 1 ]]; then
    # HA mode: multiple masters and one or more workers
    if [[ -z $API_IP || -z $RKE2_LOADBALANCER_RANGE ]]; then
        echo "In HA mode, API_IP and RKE2_LOADBALANCER_RANGE must be set. Exiting."
        exit 1
    fi
    # Run the Ansible playbooks for setup and deployment
    ansible-playbook -i hosts tasks/prepare_vm.yaml --extra-vars "api_ip=$API_IP"
    ansible-playbook -i hosts tasks/deploy_rke2_ha.yaml \
        --extra-vars "rke2_cni=$RKE2_CNI rke2_version=$RKE2_VERSION rke2_token=$RKE2_TOKEN rke2_api_ip=$API_IP rke2_loadbalancer_ip_range=range-global:$RKE2_LOADBALANCER_RANGE"
    
    # Run the post_install.yaml playbook for additional setup on master nodes
    ansible-playbook -i hosts tasks/post_install.yaml --user=root

    # Run the install_rancher.yaml playbook with extra variables for Rancher installation
    ansible-playbook -i hosts tasks/install_rancher.yaml \
        --extra-vars "hostname=$RANCHER_HOSTNAME bootstrapPassword=$RANCHER_BOOTSTRAP_PASSWORD replicas=$RANCHER_REPLICAS" \
        --user=root

    # Run the install_longhorn.yaml playbook with extra variables for Longhorn installation
    ansible-playbook -i hosts tasks/install_longhorn.yaml \
        --extra-vars "ingress_host=$LONGHORN_HOSTNAME replica_count=$LONGHORN_REPLICAS" \
        --user=root

else
    echo "Invalid configuration: Please check RKE2_MODE, MASTER_IPS, and WORKER_IPS."
    exit 1
fi

