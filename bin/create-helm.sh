#!/bin/bash

[ -z $(command -v helm) ] && (curl -L https://git.io/get_helm.sh | sudo bash)

kubectl create serviceaccount --namespace kube-system tiller --kubeconfig=./cluster/config
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller --kubeconfig=./cluster/config
helm init --service-account tiller  --kubeconfig=./cluster/config
