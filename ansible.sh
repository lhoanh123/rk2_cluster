#!/bin/bash

# Define default values (can be overridden by export or direct assignment before running)
: "${USERNAME:=master1}"            # Username for SSH
: "${ANSIBLE_HOST_IP:=192.168.198.129}"
: "${MASTER_IP:=192.168.198.141}"
: "${WORKER1_IP:=192.168.198.132}"
: "${WORKER2_IP:=}"                 # Optional, leave blank if there's only one worker

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
ssh-copy-id "$USERNAME@$MASTER_IP"
ssh-copy-id "$USERNAME@$WORKER1_IP"
if [ -n "$WORKER2_IP" ]; then
    ssh-copy-id "$USERNAME@$WORKER2_IP"
fi

# Append IPs to /etc/hosts if not already present
if ! grep -q "$ANSIBLE_HOST_IP ansible" /etc/hosts; then
    echo "$ANSIBLE_HOST_IP ansible" | sudo tee -a /etc/hosts
fi

if ! grep -q "$MASTER_IP master1" /etc/hosts; then
    echo "$MASTER_IP master1" | sudo tee -a /etc/hosts
fi

if ! grep -q "$WORKER1_IP worker1" /etc/hosts; then
    echo "$WORKER1_IP worker1" | sudo tee -a /etc/hosts
fi

if [ -n "$WORKER2_IP" ] && ! grep -q "$WORKER2_IP worker2" /etc/hosts; then
    echo "$WORKER2_IP worker2" | sudo tee -a /etc/hosts
fi

# Install Ansible Galaxy role for RKE2
ansible-galaxy install lablabs.rke2

# Update Ansible hosts file in the current folder
cat > hosts <<EOF
[masters]
master1 ansible_host=$MASTER_IP ansible_user=$USERNAME rke2_type=server

[workers]
worker1 ansible_host=$WORKER1_IP ansible_user=$USERNAME rke2_type=agent
EOF

if [ -n "$WORKER2_IP" ]; then
    cat >> hosts <<EOF
worker2 ansible_host=$WORKER2_IP ansible_user=$USERNAME rke2_type=agent
EOF
fi

cat >> hosts <<EOF

[k8s_cluster:children]
masters
workers
EOF

# Run the Ansible playbook with elevated privileges
ansible-playbook -i hosts site.yaml --ask-become-pass
