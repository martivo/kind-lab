#!/bin/bash

curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64
chmod +x ./kind && mv ./kind /usr/bin/kind

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && mv kubectl /usr/bin/kubectl

wget -O kubeseal.tar.gz https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.17.2/kubeseal-0.17.2-linux-amd64.tar.gz
tar xvzf kubeseal.tar.gz && mv kubeseal /usr/bin/kubeseal

wget -O helm.tar.gz https://get.helm.sh/helm-v3.8.0-rc.1-linux-amd64.tar.gz
tar xvzf helm.tar.gz && mv linux-amd64/helm /usr/bin/helm


wget -O kubectl-neat.tar.gz https://github.com/itaysk/kubectl-neat/releases/download/v2.0.3/kubectl-neat_darwin_amd64.tar.gz
tar xvzf kubectl-neat.tar.gz && mv kubectl-neat /usr/bin/kubectl-neat 

curl -fsSL https://get.docker.com/ | sudo sh


echo "fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=524288" > /etc/sysctl.d/local.conf
sysctl -p /etc/sysctl.d/local.conf

/usr/sbin/useradd -m -s /bin/bash user$1
gpasswd -a user$1 docker
usermod --password "$(sudo openssl passwd -1 KindLab$1)" user$1
sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config
systemctl restart sshd

cd /home/user$1 && git clone https://github.com/martivo/kind-lab.git
