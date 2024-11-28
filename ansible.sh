#!/bin/bash

# Define default values (can be overridden by export or direct assignment before running)
: "${USERNAME:=master1}"            # Username for SSH
: "${ANSIBLE_HOST_IP:=192.168.198.129}"

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

# Update the Ansible control node
add_to_hosts "$ANSIBLE_HOST_IP" "ansible"

# Update master nodes
for i in "${!MASTER_IPS[@]}"; do
    MASTER_IP=${MASTER_IPS[i]}
    add_to_hosts "$MASTER_IP" "master$((i+1))"
done

# Update worker nodes
for i in "${!WORKER_IPS[@]}"; do
    WORKER_IP=${WORKER_IPS[i]}
    add_to_hosts "$WORKER_IP" "worker$((i+1))"
done

# Install Ansible Galaxy role for RKE2
ansible-galaxy install lablabs.rke2

# Update Ansible hosts file in the current folder
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

# Run the Ansible playbook with elevated privileges
ansible-playbook -i hosts site.yaml --ask-become-pass
