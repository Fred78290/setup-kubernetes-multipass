#!/bin/bash

CURDIR=$(dirname $0)

pushd $CURDIR/../

export K8NAMESPACE=kube-system
export ETC_DIR=./config/deployment/influxdb
export DATA_DIR=./data/influxdb
export KUBERNETES_TEMPLATE=./templates/influxdb

mkdir -p $ETC_DIR
mkdir -p $DATA_DIR

chmod 777 $DATA_DIR

function deploy {
    echo "Create $ETC_DIR/$1.json"
echo $(eval "cat <<EOF
$(<$KUBERNETES_TEMPLATE/$1.json)
EOF") | jq . > $ETC_DIR/$1.json

kubectl apply -f $ETC_DIR/$1.json --kubeconfig=./cluster/config
}

kubectl create configmap config-influxdb -n $K8NAMESPACE \
    --from-literal=INFLUXDB_ADMIN_ENABLED=true \
	--from-literal=INFLUXDB_ADMIN_USER=admin \
	--from-literal=INFLUXDB_ADMIN_PASSWORD=admin \
	--from-literal=INFLUXDB_USER=user \
	--from-literal=INFLUXDB_USER_PASSWORD=1234

deploy pv
deploy pvc
deploy deployment
deploy service