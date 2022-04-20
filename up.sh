#!/bin/bash

#Kontrollitakse kas esimeseks parameetriks on antud koolitatava number.
if [ "$1" == "" ]
then
  echo "Skripti esimene parameeter peab olema koolitatava number."
  exit 1
fi

#Luuakse kaks kubernetese kobarat kind tööriistaga.
kind create cluster --config kind-test.yaml
kind create cluster --config kind-prod.yaml

#Kuvame kubernetese seadistusse tekkinud kobarad.
kubectl config get-contexts | grep kind

#Käivitatakse argocd tarkvara.
kubectl --context kind-test create ns argocd && \
  helm template argocd-yaml/argocd/ | kubectl --context kind-test apply -n argocd -f- #https://argo-cd.readthedocs.io/en/stable/getting_started/ and https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/

kubectl --context kind-prod create ns argocd && \
  helm template argocd-yaml/argocd/ | kubectl --context kind-prod apply -n argocd -f- #https://argo-cd.readthedocs.io/en/stable/getting_started/ and https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/

#Oodatakse et argocd tarkvara oleks käivitunud ja kuvatakse veebiliidese kasutja ja parool.
kind get clusters | while read cluster
do
  echo "Waiting for argocd on cluster $cluster"
  while [ 1 -lt 2 ]
  do
	kubectl --context kind-$cluster -n argocd get secret argocd-initial-admin-secret && break
	sleep 10
  done
  echo -n "Argocd user is admin and password for $cluster is "
  kubectl --context kind-$cluster -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
done

#Luuakse argocd Application objektid, mis laevad järgmised objektid tarkvara repositooriumist alla.
helm template argocd-yaml/app-of-apps/ --set runenv="test" --set number=$1 | kubectl --context kind-test apply -n argocd -f-
helm template argocd-yaml/app-of-apps/ --set runenv="prod" --set number=$1 | kubectl --context kind-prod apply -n argocd -f-



#Suuname internetist tuleva 80 ja 8080 pordid prod ja test kobara HAproxy teenuse IP peale.
prod_ip=""
while [ $prod_ip == "" ]
do
  prod_ip=$(kubectl --context=kind-prod get svc -n haproxy haproxy-ingress --output jsonpath='{.status.loadBalancer.ingress[0].ip}')  
  echo "Waiting for prod cluster HAproxy loadbalancer service."
  sleep 10
done

sudo iptables -I FORWARD -p tcp -d $prod_ip --match multiport --dports 80 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
sudo iptables -t nat -I PREROUTING -p tcp -i ens5 --dport 80 -j DNAT --to-destination $prod_ip:80

test_ip=""
while [ $prod_ip == "" ]
do
  test_ip=$(kubectl --context=kind-test get svc -n haproxy haproxy-ingress --output jsonpath='{.status.loadBalancer.ingress[0].ip}')  
  echo "Waiting for prod cluster HAproxy loadbalancer service."
  sleep 10
done
sudo iptables -I FORWARD -p tcp -d $test_ip --match multiport --dports 80 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
sudo iptables -t nat -I PREROUTING -p tcp -i ens5 --dport 8080 -j DNAT --to-destination $test_ip:80
