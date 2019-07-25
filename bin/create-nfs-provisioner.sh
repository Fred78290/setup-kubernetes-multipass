#!/bin/bash

echo "Create NFS Provisioner"

CURDIR=$(dirname $0)

pushd $CURDIR/../

export K8NAMESPACE=kube-system
export ETC_DIR=./config/deployment/nfs-provisioner
export KUBERNETES_TEMPLATE=./templates/nfs-provisioner

mkdir -p $ETC_DIR

function deploy {
    echo "Create $ETC_DIR/$1.json"
echo $(eval "cat <<EOF
$(<$KUBERNETES_TEMPLATE/$1.json)
EOF") | jq . > $ETC_DIR/$1.json

kubectl apply -f $ETC_DIR/$1.json --kubeconfig=./cluster/config
}

deploy clusterrole
deploy clusterrolebinding
deploy role
deploy rolebinding

deploy psp

deploy serviceaccount
deploy statefulset
deploy class
deploy service
