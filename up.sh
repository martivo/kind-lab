#!/bin/bash

#Create kind kubernetes clusters
kind create cluster --config kind-test.yaml
kind create cluster --config kind-prod.yaml

#List kind clusters
kubectl config get-contexts | grep kind

#Argocd launch
kubectl --context kind-test create ns argocd && \
  helm template argocd-yaml/argocd/ | kubectl --context kind-test apply -n argocd -f- #https://argo-cd.readthedocs.io/en/stable/getting_started/ and https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/

kubectl --context kind-test create ns argocd && \
  helm template argocd-yaml/argocd/ | kubectl --context kind-prod apply -n argocd -f- #https://argo-cd.readthedocs.io/en/stable/getting_started/ and https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/

#Create app of apps in argocd
helm template argocd-yaml/app-of-apps/ --set runenv="test" --set internaldomain="argocd-$1.learn.entigo.io" --set externaldomain="kind-$1.learn.entigo.io" --set iprange="10.250.1.200-10.250.1.209" | kubectl --context kind-test apply -n argocd -f-
helm template argocd-yaml/app-of-apps/ --set runenv="prod" --set internaldomain="argocd-$1.learn.entigo.io" --set externaldomain="kind-$1.learn.entigo.io" --set iprange="10.250.1.210-10.250.1.219" | kubectl --context kind-prod apply -n argocd -f-


i=0
kind get clusters | while read cluster
do
  echo "Waiting for argocd $cluster"
  while [ 1 -lt 2 ]
  do
	kubectl --context kind-$cluster -n argocd get secret argocd-initial-admin-secret && break
	sleep 10
  done
  echo -n "Argocd password for $cluster is "
  kubectl --context kind-$cluster -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
  let i++
  echo "##################"
done

