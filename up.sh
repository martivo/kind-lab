#!/bin/bash

#Create kind kubernetes clusters
kind create cluster --config kind-test.yaml
kind create cluster --config kind-prod.yaml

#List kind clusters
kubectl config get-contexts | grep kind

#Argocd launch
kubectl --context kind-test create ns argocd && \
  helm template argocd-yaml/argocd/ | kubectl --context kind-test apply -n argocd -f- #https://argo-cd.readthedocs.io/en/stable/getting_started/ and https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/

kubectl --context kind-prod create ns argocd && \
  helm template argocd-yaml/argocd/ | kubectl --context kind-prod apply -n argocd -f- #https://argo-cd.readthedocs.io/en/stable/getting_started/ and https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/

#Wait for clusters to be ready and print argocd login info.
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

#Create app of apps in argocd
helm template argocd-yaml/app-of-apps/ --set runenv="test" --set number="$1" | kubectl --context kind-test apply -n argocd -f-
helm template argocd-yaml/app-of-apps/ --set runenv="prod" --set number="$1" | kubectl --context kind-prod apply -n argocd -f-

exit 0
prod_ip=$(kubectl --context=kind-prod get svc -n haproxy haproxy-ingress --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
iptables -I FORWARD -p tcp -d $prod_ip --match multiport --dports 80,443 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -t nat -I PREROUTING -p tcp -i ens5 --dport 80 -j DNAT --to-destination $prod_ip:80
iptables -t nat -I PREROUTING -p tcp -i ens5 --dport 443 -j DNAT --to-destination $prod_ip:443

test_ip=$(kubectl --context=kind-test get svc -n haproxy haproxy-ingress --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
iptables -I FORWARD -p tcp -d $test_ip --match multiport --dports 80,443 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -t nat -I PREROUTING -p tcp -i ens5 --dport 8080 -j DNAT --to-destination $test_ip:80
iptables -t nat -I PREROUTING -p tcp -i ens5 --dport 8444 -j DNAT --to-destination $test_ip:443
