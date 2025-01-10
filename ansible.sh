#!/bin/bash

# Đặt giá trị mặc định cho các biến nếu chưa được định nghĩa
: "${USERNAME:=ubuntu}"                     # Tên người dùng SSH mặc định
: "${ANSIBLE_HOST_IP:=192.168.198.129}"     # Địa chỉ IP của máy điều khiển (control machine)
: "${RKE2_VERSION:=v1.30.6+rke2r1}"         # Phiên bản RKE2 mặc định
: "${RKE2_MODE:=normal}"                    # Chế độ RKE2 mặc định (normal hoặc ha)
: "${RKE2_TOKEN:=yourSecureToken123}"       # Token RKE2 mặc định
: "${API_IP:=}"                             # Địa chỉ API IP (để trống với chế độ normal)
: "${RKE2_CNI:=canal}"                      # Plugin mạng mặc định (CNI)
: "${RKE2_LOADBALANCER_RANGE:=}"            # Dải IP Load Balancer mặc định
: "${USE_KUBEVIP:=false}"                   # Sử dụng kube-vip (false = dùng keepalived)
: "${RKE2_HA_MODE_KUBEVIP:=false}"          # Chế độ HA sử dụng kube-vip
: "${RKE2_HA_MODE_KEEPALIVED:=true}"        # Chế độ HA sử dụng keepalived (mặc định)

# Danh sách các địa chỉ IP cho các master và worker nodes
MASTER_IPS=(${MASTER_IPS:-192.168.198.141})  # IP của các master nodes
WORKER_IPS=(${WORKER_IPS:-192.168.198.132})  # IP của các worker nodes

# Cài đặt môi trường Ansible
sudo apt update
sudo apt install ansible -y
sudo apt install curl -y
ansible-galaxy install lablabs.rke2 --force

# Kiểm tra và cài đặt OpenSSH Server nếu chưa có
if ! dpkg -l | grep -q openssh-server; then
    echo "OpenSSH Server is not installed. Installing..."
    sudo apt install -y openssh-server
else
    echo "OpenSSH Server is already installed."
fi

# Kích hoạt và khởi chạy dịch vụ SSH nếu chưa hoạt động
if ! systemctl is-active --quiet ssh; then
    echo "Starting SSH service..."
    sudo systemctl enable ssh
    sudo systemctl start ssh
else
    echo "SSH service is already running."
fi

# Tạo SSH key nếu chưa tồn tại
if [ ! -f "$HOME/.ssh/id_rsa" ]; then
    ssh-keygen -t rsa -N "" -f "$HOME/.ssh/id_rsa"
fi

# Sao chép SSH key đến các master và worker nodes
for MASTER_IP in "${MASTER_IPS[@]}"; do
    ssh-copy-id "$USERNAME@$MASTER_IP"
done

for WORKER_IP in "${WORKER_IPS[@]}"; do
    ssh-copy-id "$USERNAME@$WORKER_IP"
done

# Hàm thêm địa chỉ IP vào /etc/hosts
add_to_hosts() {
    local ip=$1
    local hostname=$2

    # Xóa các mục nhập cũ với cùng hostname
    sudo sed -i "/[[:space:]]$hostname$/d" /etc/hosts

    # Thêm mục mới trước phần IPv6
    sudo sed -i "/^# The following lines are desirable for IPv6 capable hosts/i\\$ip $hostname" /etc/hosts
}

# Thêm IP của control machine và các node vào /etc/hosts
add_to_hosts "$ANSIBLE_HOST_IP" "ansible"

for i in "${!MASTER_IPS[@]}"; do
    MASTER_IP=${MASTER_IPS[i]}
    add_to_hosts "$MASTER_IP" "master$((i+1))"
done

for i in "${!WORKER_IPS[@]}"; do
    WORKER_IP=${WORKER_IPS[i]}
    add_to_hosts "$WORKER_IP" "worker$((i+1))"
done

# Tạo file cấu hình Ansible hosts
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

# Hàm lấy phiên bản RKE2 mới nhất từ GitHub
get_latest_rke2_version() {
    curl -s "https://api.github.com/repos/rancher/rke2/releases/latest" | \
    grep '"tag_name":' | \
    sed -E 's/.*"([^"]+)".*/\1/'
}

# Lấy phiên bản RKE2 mới nhất
RKE2_VERSION=$(get_latest_rke2_version)
if [[ -z "$RKE2_VERSION" ]]; then
    echo "Failed to fetch the latest RKE2 version. Using default version: v1.30.6+rke2r1"
    RKE2_VERSION="v1.30.6+rke2r1"
fi

echo "Using RKE2 version: $RKE2_VERSION"

# Yêu cầu mật khẩu sudo cho Ansible
echo "Please enter the become password:"
read -s BECOME_PASS
export ANSIBLE_BECOME_PASS=$BECOME_PASS

# Triển khai RKE2 dựa trên chế độ (normal hoặc ha)
if [[ $RKE2_MODE == "normal" && ${#MASTER_IPS[@]} -eq 1 && ${#WORKER_IPS[@]} -ge 1 ]]; then
    ansible-playbook -i hosts tasks/prepare_vm.yaml
    ansible-playbook -i hosts tasks/deploy_rke2.yaml \
        --extra-vars "rke2_cni=$RKE2_CNI rke2_version=$RKE2_VERSION rke2_token=$RKE2_TOKEN"
    ansible-playbook -i hosts tasks/post_install.yaml --user=root
        
elif [[ $RKE2_MODE == "ha" && ${#MASTER_IPS[@]} -gt 1 && ${#WORKER_IPS[@]} -ge 1 ]]; then
    if [[ -z $API_IP || -z $RKE2_LOADBALANCER_RANGE ]]; then
        echo "In HA mode, API_IP and RKE2_LOADBALANCER_RANGE must be set. Exiting."
        exit 1
    fi

    if [[ "$USE_KUBEVIP" == "true" ]]; then
        HA_MODE_KUBEVIP=true
        HA_MODE_KEEPALIVED=false
    else
        HA_MODE_KUBEVIP=false
        HA_MODE_KEEPALIVED=true
    fi

    ansible-playbook -i hosts tasks/prepare_vm.yaml --extra-vars "api_ip=$API_IP"
    ansible-playbook -i hosts tasks/deploy_rke2_ha.yaml \
        --extra-vars "rke2_cni=$RKE2_CNI rke2_version=$RKE2_VERSION rke2_token=$RKE2_TOKEN rke2_api_ip=$API_IP rke2_loadbalancer_ip_range=range-global:$RKE2_LOADBALANCER_RANGE rke2_ha_mode_kubevip=$HA_MODE_KUBEVIP rke2_ha_mode_keepalived=$HA_MODE_KEEPALIVED"
    ansible-playbook -i hosts tasks/post_install.yaml --user=root

else
    echo "Invalid configuration: Please check RKE2_MODE, MASTER_IPS, and WORKER_IPS."
    exit 1
fi
