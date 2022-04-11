#!/bin/bash

kind get clusters | while read cluster
do
echo "Deleting kind cluster $cluster"

kind delete cluster --name $cluster
done
