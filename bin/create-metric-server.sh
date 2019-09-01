#!/bin/bash
echo "Deploy kubernetes metric server"

# This file is intent to deploy dashboard inside the masterkube
CURDIR=$(dirname $0)

pushd $CURDIR/../

export K8NAMESPACE=kube-system
export ETC_DIR=./config/deployment/metrics
export KUBERNETES_TEMPLATE=./templates/metrics

if [ -z "$DOMAIN_NAME" ]; then
    export DOMAIN_NAME=$(openssl x509 -noout -subject -in ./etc/ssl/cert.pem | awk -F= '{print $NF}' | sed -e 's/^[ \t]*//' | sed 's/\*\.//g')
fi

mkdir -p $ETC_DIR

function deploy {
    echo "Create $ETC_DIR/$1.json"
echo $(eval "cat <<EOF
$(<$KUBERNETES_TEMPLATE/$1.json)
EOF") | jq . > $ETC_DIR/$1.json

kubectl apply -f $ETC_DIR/$1.json --kubeconfig=./cluster/config
}

deploy aggregated-metrics-reader
deploy auth-delegator
deploy auth-reader
deploy metrics-apiservice
deploy metrics-server-serviceaccount
deploy metrics-server-deployment
deploy metrics-server-service
deploy resource-reader-clusterrolebinding
deploy resource-reader-clusterrole
