#!/bin/bash

################################################################################
# Script Name:    k8s_installer.sh
# Description:    This script to create a kubernetes cluster
# Usage:          ./k8s_installer
# Author:         [Ghassen Riahi]
# Date:           [09/05/2024]
# Version:        1.0.0
################################################################################


# Create directories inside the project
echo "Creating directories..."
mkdir roles
mkdir roles/docker-containerd
mkdir roles/kubernetes
mkdir roles/master-worker
mkdir roles/pre-install
mkdir roles/update-k8s

mkdir roles/docker-containerd/tasks
mkdir roles/kubernetes/defaults
mkdir roles/kubernetes/tasks
mkdir roles/master-worker/defaults
mkdir roles/master-worker/tasks
mkdir roles/pre-install/tasks
mkdir roles/update-k8s/defaults
mkdir roles/update-k8s/tasks


# Creating empty files
echo "Creating empty files..."
touch copy_id.sh
touch install-cluster.yaml
touch update-k8s.yaml
touch inventory.ini
touch install-cluster.sh
touch update-k8s.sh

# Creating files for Docker Containerd role
echo "Creating files for Docker Containerd role..."
touch roles/docker-containerd/tasks/main.yaml

# Creating files for Kubernetes role
echo "Creating files for Kubernetes role..."
touch roles/kubernetes/defaults/main.yaml
touch roles/kubernetes/tasks/main.yaml

# Creating files for Master-Worker role
echo "Creating files for Master-Worker role..."
touch roles/master-worker/defaults/main.yaml
touch roles/master-worker/tasks/main.yaml

# Creating files for Pre-Install role
echo "Creating files for Pre-Install role..."
touch roles/pre-install/tasks/main.yaml

# Creating files for Update-K8s role
echo "Creating files for Update-K8s role..."
touch roles/update-k8s/defaults/main.yaml
touch roles/update-k8s/tasks/main.yaml

# Add content to inventory.ini
echo "Creating inventory.ini..."
cat << 'EOF' > inventory.ini
[masters]
master-node ansible_host=192.168.0.170 ansible_user=root ansible_become=yes ansible_become_pass=[rootpassword]

[workers]
worker-node-1 ansible_host=192.168.0.171 ansible_user=root ansible_become=yes ansible_become_pass=[rootpassword]
worker-node-2 ansible_host=192.168.0.172 ansible_user=root ansible_become=yes ansible_become_pass=[rootpassword]


[kube-cluster:children]
masters
workers

EOF


# Add content to  copy_id.sh
echo "Creating  copy_id.sh..."
cat << 'EOF' > copy_id.sh
#!/bin/bash 

# Define the path to the inventory file
inventory_file="inventory.ini"

# Retrieve the list of IP addresses from the inventory file
vms=($(awk '/ansible_host/{split($2, arr, "="); print arr[2]}' "$inventory_file"))

#Generate SSH key pair
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa

# Copy SSH keys to target VMs
for vm in "${vms[@]}"
do
    ssh-copy-id -i ~/.ssh/id_rsa.pub "root@$vm"
done
EOF
chmod +x copy_id.sh

# Add content to update-k8s.yaml
echo "Creating update-k8s.yaml..."
cat << EOF > update-k8s.yaml
- name: Update Kubernetes Cluster Using Kubeadm
  hosts: kube-cluster
  gather_facts: yes
  become: yes
  roles:
    - update-k8s
EOF

# Add content to install-cluster.yaml
echo "Creating install-cluster.yaml..."
cat << EOF > install-cluster.yaml
- name: Set up a Kubernetes Cluster with kubeadm
  hosts: kube-cluster
  gather_facts: yes
  become: yes
  roles:
    - pre-install
    - docker-containerd
    - kubernetes
    - master-worker
EOF

# Add content to install-cluster.sh
echo "Creating install-cluster.sh..."
cat << 'EOF' > install-cluster.sh
ansible-playbook -i inventory.ini install-cluster.yaml
EOF

chmod +x install-cluster.sh

# Add content to update-k8s.sh
echo "Creating update-k8s.sh..."
cat << 'EOF' > update-k8s.sh
ansible-playbook -i inventory.ini update-k8s.yaml
EOF

chmod +x update-k8s.sh

# Add content to roles/docker-containerd/tasks/main.yaml
echo "Creating main.yaml for Docker Containerd role..."
cat << 'EOF' > roles/docker-containerd/tasks/main.yaml
- name: Remove Docker related packages
  apt:
    name: "{{ item }}"
    state: absent
  loop:
    - docker.io
    - docker-doc
    - docker-compose
    - docker-compose-v2
    - podman-docker
    - containerd
    - runc

- name: Add Docker's official GPG key
  shell: |
     apt-get update
     apt-get install ca-certificates curl
     install -m 0755 -d /etc/apt/keyrings
     curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
     chmod a+r /etc/apt/keyrings/docker.asc

- name: Add the repo to apt sources
  shell : |
     echo \
       "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
       $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
       sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
     sudo apt-get update     


- name: Add Kubernetes repository to Apt sources
  shell: |
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gpg
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list


- name: Update Apt sources
  shell: sudo apt-get update

- name: Install Docker related packages
  apt:
    name: containerd.io
    state: present
    force_apt_get: yes

- name: Add containerd Configuration
  shell: |
    containerd config default > /etc/containerd/config.toml
    sed -e 's/SystemdCgroup = false/SystemdCgroup = true/g' -i /etc/containerd/config.toml
 
- name: Enable containerd service, and start it.
  systemd:
    name: containerd
    state: restarted
    enabled: yes
    daemon-reload: yes

EOF

# Add content to roles/kubernetes/defaults/main.yaml
echo "Creating main.yaml for Kubernetes role..."
cat << EOF > roles/kubernetes/defaults/main.yaml
k8s_version: "1.28"
EOF

# Add content to roles/kubernetes/tasks/main.yaml
echo "Creating main.yaml for Kubernetes role..."
cat << EOF > roles/kubernetes/tasks/main.yaml
- name: Install Dependencies
  apt:
    name: "{{ item }}"
    state: present
  with_items:
    - curl
    - gpg
    - apt-transport-https
    - ca-certificates

- name: add Kubernetes apt-key
  get_url:
     url: https://pkgs.k8s.io/core:/stable:/v{{ k8s_version }}/deb/Release.key
     dest: /etc/apt/keyrings/kubernetes-apt-keyring.gpg
     mode: '0644'
     force: true

- name: add Kubernetes' APT repository
  command: echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v{{ k8s_version }}/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list


- name: Update apt cache and install Kubernetes packages
  apt:
    name: "{{ item }}"
    state: present

  loop:
    - kubelet
    - kubeadm
    - kubectl
EOF

# Add content to roles/master-worker/defaults/main.yaml
echo "Creating main.yaml for Master-Worker role..."
cat << EOF > roles/master-worker/defaults/main.yaml
pod_network_cidr: "10.204.0.0/16"
EOF

# Add content to roles/master-worker/tasks/main.yaml
echo "Creating main.yaml for Master-Worker role..."
cat << EOF > roles/master-worker/tasks/main.yaml
- name: Initialize the cluster
  shell: kubeadm init --pod-network-cidr={{ pod_network_cidr }}
  when: inventory_hostname == groups['masters'][0]

- name: Copy admin.conf to user's kube config
  shell: |
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown \$(id -u):\$(id -g) $HOME/.kube/config
    echo 'export KUBECONFIG=\$HOME/.kube/config' >> \$HOME/.bashrc
  when: inventory_hostname == groups['masters'][0]

- name: Install Calico Pod network
  shell: |
    curl https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/calico.yaml -O
    kubectl apply -f calico.yaml
  when: inventory_hostname == groups['masters'][0]

- name: Get join command
  shell: kubeadm token create --print-join-command
  register: worker_join_command
  when: inventory_hostname == groups['masters'][0]

- name: Set join command
  set_fact:
    worker_join_command: "{{ worker_join_command.stdout_lines[0] }}"
  when: inventory_hostname == groups['masters'][0]

- name: Join cluster
  shell: "{{ hostvars[groups['masters'][0]].worker_join_command }}"
  when: inventory_hostname in groups['workers']
EOF

# Add content to roles/pre-install/tasks/main.yaml
echo "Creating main.yaml for Pre-Install role..."
cat << EOF > roles/pre-install/tasks/main.yaml
- name: Set hostname
  ansible.builtin.hostname:
    name: "{{ inventory_hostname }}"

- name: Update /etc/hosts
  ansible.builtin.lineinfile:
    path: /etc/hosts
    line: "{{ hostvars[item]['ansible_host'] }} {{ item }}"
    state: present
    create: yes
    insertafter: EOF
    regexp: "^{{ hostvars[item]['ansible_host'] }}"
  loop: "{{ ansible_play_batch }}"

- name: Disable Swap
  command: swapoff -a

- name: Remove swap entry from /etc/fstab
  replace:
    path: /etc/fstab
    regexp: '^.*?\sswap\s+.*$'
    replace: ''

- name: Configure module for containerd.
  shell: |
     tee /etc/modules-load.d/containerd.conf <<EOF
     overlay
     br_netfilter
     EOF
     modprobe overlay
     modprobe br_netfilter
     
- name: Configure sysctl params for Kubernetes.
  shell: |
     tee /etc/sysctl.d/kubernetes.conf <<EOT
     net.bridge.bridge-nf-call-ip6tables = 1
     net.bridge.bridge-nf-call-iptables = 1
     net.ipv4.ip_forward = 1
     EOT

- name: Apply sysctl params without reboot.
  command: sysctl --system

- name: Check if UFW is installed
  command: ufw status
  register: ufw_status
  ignore_errors: yes

- name: Disable and stop UFW if it exists
  systemd:
    name: ufw
    state: stopped
    enabled: no
  when: ufw_status.rc == 0
EOF


# Add content to roles/update-k8s/defaults/main.yaml
echo "Creating main.yaml for Update-K8s role..."
cat << EOF > roles/update-k8s/defaults/main.yaml
k8s_version: "1.29"
release: 1.29.0
EOF

# Add content to roles/update-k8s/tasks/main.yaml
echo "Creating main.yaml for Update-K8s role..."
cat << EOF > roles/update-k8s/tasks/main.yaml

- name: Upgrade kubeadm
  yum:
    name: kubeadm-{{ release }}-*
    state: latest
    disable_excludes: kubernetes

- name: Upgrade Control Plane Node
  shell:
    kubeadm upgrade apply v{{ release }} -y
  when: inventory_hostname == groups['masters'][0]

- name: Call the kubeadm upgrade
  command: kubeadm upgrade node
  when: inventory_hostname == groups['workers'][0]

- name: Drain Worker Nodes
  command: kubectl drain {{ item }} --ignore-daemonsets 
  loop: "{{ groups['workers'] }}"
  when: inventory_hostname == groups['masters'][0]

- name: Drain Master Node
  command: kubectl drain {{ item }} --ignore-daemonsets 
  loop: "{{ groups['masters'] }}"
  when: inventory_hostname == groups['masters'][0]

- name: Upgrade kubelet and kubectl
  yum:
    name:
      - "kubelet-{{ release }}-*"
      - "kubectl-{{ release }}-*"
    state: latest
    disable_excludes: kubernetes

- name: Uncordon Worker Node
  command: kubectl uncordon {{ item }}
  loop: "{{ groups['masters'] + groups['workers'] }}"
  when: inventory_hostname == groups['masters'][0]

- name: Restart Kubelet
  systemd:
    name: kubelet
    state: restarted
    daemon_reload: yes

EOF



echo "All files and directories created successfully."
