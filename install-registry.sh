#!/bin/bash
apt install -y git vim curl
curl -fsSL https://get.docker.com/ | sh

echo '{"dns":["8.8.8.8"]}' > /etc/docker/daemon.json
systemctl restart docker
systemctl enable docker

curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-Linux-x86_64" -o /usr/bin/docker-compose && chmod +x /usr/bin/docker-compose
wget https://github.com/goharbor/harbor/releases/download/v2.3.2/harbor-online-installer-v2.3.2.tgz && tar xvzf harbor-online-installer-v2.3.2.tgz

cat << EOF >  harbor/harbor.yml
hostname: kreg.learn.entigo.io
http:
  port: 8080
  relativeurls: true
external_url: https://kreg.learn.entigo.io:443
internal_tls:
  enabled: false
data_volume: /data
harbor_admin_password: Harbor12345
database:
  password: root123
  max_idle_conns: 50
  max_open_conns: 1000
clair:
  updaters_interval: 0
trivy:
  ignore_unfixed: true
  skip_update: false
  insecure: true

jobservice:
  max_job_workers: 10
notification:
  webhook_job_max_retry: 10
chart:
  absolute_url: disabled
log:
  level: info
  local:
    rotate_count: 50
    rotate_size: 200M
    location: /var/log/harbor
_version: 2.0.0
proxy:
  http_proxy:
  https_proxy:
  no_proxy:
  components:
    - core
    - jobservice
    - clair
    - trivy
EOF

cd harbor/ && ./install.sh

registryurl="https://kreg.learn.entigo.io"

code=0
while [ $code -ne 200 ]
do
  echo "Waiting for harbor to be ready."
  sleep 5
  code=$(curl --write-out '%{http_code}' --silent --output /dev/null $registryurl)
done

curl "$registryurl/api/v2.0/registries" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  -H "Origin: $registryurl" \
  -H 'Sec-Fetch-Site: same-origin' \
  -H 'Sec-Fetch-Mode: cors' \
  -H 'Sec-Fetch-Dest: empty' \
  -H 'Accept-Language: en-US,en;q=0.9,et-EE;q=0.8,et;q=0.7' \
  -u "admin:Harbor12345" \
  --data-raw '{"credential":{"access_key":"","access_secret":"","type":"basic"},"description":"","insecure":false,"name":"hub","type":"docker-hub","url":"https://hub.docker.com"}' \
  --compressed
sleep 1
curl "$registryurl/api/v2.0/projects" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  -H "Origin: $registryurl" \
  -H 'Sec-Fetch-Site: same-origin' \
  -H 'Sec-Fetch-Mode: cors' \
  -H 'Sec-Fetch-Dest: empty' \
  -H 'Accept-Language: en-US,en;q=0.9,et-EE;q=0.8,et;q=0.7' \
  -u "admin:Harbor12345" \
  --data-raw '{"project_name":"hub","registry_id":1,"metadata":{"public":"true"},"storage_limit":-1}' \
  --compressed
sleep 1
curl "$registryurl/api/v2.0/projects" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  -H "Origin: $registryurl" \
  -H 'Sec-Fetch-Site: same-origin' \
  -H 'Sec-Fetch-Mode: cors' \
  -H 'Sec-Fetch-Dest: empty' \
  -H 'Accept-Language: en-US,en;q=0.9,et-EE;q=0.8,et;q=0.7' \
  -u "admin:Harbor12345" \
  --data-raw '{"project_name":"test","registry_id":null,"metadata":{"public":"true"},"storage_limit":-1}' \
  --compressed
sleep 1
curl "$registryurl/api/v2.0/users" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  -H "Origin: $registryurl" \
  -H 'Sec-Fetch-Site: same-origin' \
  -H 'Sec-Fetch-Mode: cors' \
  -H 'Sec-Fetch-Dest: empty' \
  -H 'Accept-Language: en-US,en;q=0.9,et-EE;q=0.8,et;q=0.7' \
  -u "admin:Harbor12345" \
  --data-raw '{"username":"user","email":"user@example.com","realname":"user user","password":"KubeLab321","comment":null}' \
  --compressed
sleep 1
curl "$registryurl/api/v2.0/projects/3/members" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  -H "Origin: $registryurl" \
  -H 'Sec-Fetch-Site: same-origin' \
  -H 'Sec-Fetch-Mode: cors' \
  -H 'Sec-Fetch-Dest: empty' \
  -H 'Accept-Language: en-US,en;q=0.9,et-EE;q=0.8,et;q=0.7' \
  -u "admin:Harbor12345" \
  --data-raw '{"role_id":1,"member_user":{"username":"user"}}' \
  --compressed

