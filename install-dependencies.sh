#!/bin/bash

#Kind tööriista paigaldus.
#https://kind.sigs.k8s.io/docs/user/quick-start/#installing-from-release-binaries
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64
chmod +x ./kind && mv ./kind /usr/bin/kind

#Kubernetese kliendi paigaldus.
#https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-binary-with-curl-on-linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && mv kubectl /usr/bin/kubectl

#Kubernetese kliendi käsu automaatne arvamine tabulaatoriga.
#https://kubernetes.io/docs/tasks/tools/included/optional-kubectl-configs-bash-linux/
kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null

#Helm tarkvara paigaldus.
#https://helm.sh/docs/intro/install/#from-script
wget -O helm.tar.gz https://get.helm.sh/helm-v3.8.0-rc.1-linux-amd64.tar.gz
tar xvzf helm.tar.gz && mv linux-amd64/helm /usr/bin/helm

#Kubectl-neat tarkvara paigaldus.
wget -O kubectl-neat.tar.gz https://github.com/itaysk/kubectl-neat/releases/download/v2.0.3/kubectl-neat_darwin_amd64.tar.gz
tar xvzf kubectl-neat.tar.gz && mv kubectl-neat /usr/bin/kubectl-neat 

#Docker tarkvara paigaldus.
curl -fsSL https://get.docker.com/ | sudo sh

#Konteineritele vajalike limiitide tõstmine.
echo "fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=524288" > /etc/sysctl.d/local.conf
sysctl -p /etc/sysctl.d/local.conf

#Lisatakse kasutaja mida koolitatav kasutab.
/usr/sbin/useradd -m -s /bin/bash user$1
#Lubatakse kasutajal docker käske kasutada
gpasswd -a user$1 docker
#Seadistatakse kasutaja parooli.
usermod --password "$(sudo openssl passwd -1 KindLab$1)" user$1
#Lubatakse SSH ühendustes kasutada paroolig autentimist.
sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config
systemctl restart sshd
#Lubatakse kasutajal sudo käsu kasutamist ilma paroolita.
echo "user$1 ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/91-lab-user

#Laeme alla repositooriumist vajalikud skriptid ja seadistused.
cd /home/user$1 && git clone https://github.com/martivo/kind-lab.git && chown -R user$1:user$1 kind-lab
