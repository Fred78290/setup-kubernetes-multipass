#!/bin/bash
CURDIR=$(dirname $0)

pushd $CURDIR/../

export K8NAMESPACE=kube-system
export ETC_DIR=./config/deployment/heapster
export KUBERNETES_TEMPLATE=./templates/heapster

mkdir -p $ETC_DIR

function deploy {
    echo "Create $ETC_DIR/$1.json"
echo $(eval "cat <<EOF
$(<$KUBERNETES_TEMPLATE/$1.json)
EOF") | jq . > $ETC_DIR/$1.json

kubectl apply -f $ETC_DIR/$1.json --kubeconfig=./cluster/config
}

deploy rbac
deploy role
deploy serviceaccount
deploy deployment
deploy service