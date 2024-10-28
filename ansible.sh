#!/bin/bash

# Define default IPs (can be overridden by export or direct assignment before running)
: "${ANSIBLE_HOST_IP:=192.168.198.129}"
: "${MASTER_IP:=192.168.198.141}"
: "${WORKER1_IP:=192.168.198.132}"
: "${WORKER2_IP:=192.168.198.133}"

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
ssh-copy-id "master1@$MASTER_IP"
ssh-copy-id "master1@$WORKER1_IP"
ssh-copy-id "master1@$WORKER2_IP"

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

if ! grep -q "$WORKER2_IP worker2" /etc/hosts; then
    echo "$WORKER2_IP worker2" | sudo tee -a /etc/hosts
fi

# Update Ansible hosts file in the current folder
cat > hosts <<EOF
[masters]
master1 ansible_host=$MASTER_IP rke2_type=server

[workers]
worker1 ansible_host=$WORKER1_IP rke2_type=agent
worker2 ansible_host=$WORKER2_IP rke2_type=agent

[k8s_cluster:children]
masters
workers
EOF

# Run the Ansible playbook with elevated privileges
ansible-playbook -i hosts site.yaml --ask-become-pass
