#!/bin/bash
CURDIR=$(dirname $0)

pushd $CURDIR/../

export K8NAMESPACE=kube-system
export ETC_DIR=./config/deployment/minio
export KUBERNETES_TEMPLATE=./templates/minio

export MINIO_ACCESS_KEY=${CLUSTER_NAME}-minio
export MINIO_SECRET_KEY=$KUBERNETES_PASSWORD

mkdir -p $ETC_DIR

function deploy {
    echo "Create $ETC_DIR/$1.json"
echo $(eval "cat <<EOF
$(<$KUBERNETES_TEMPLATE/$1.json)
EOF") | jq . > $ETC_DIR/$1.json

kubectl apply -f $ETC_DIR/$1.json --kubeconfig=./cluster/config
}

if [ $MAXTOTALNODES -gt 2 ]; then
    SERVER_ARGS='{ "args": [ "server" ] }'

    for INDEX in $(seq 0 $MAXTOTALNODES)
    do
        if [ $INDEX -eq 0 ]; then
            VMNAME="master-${CLUSTER_NAME}"
        else
            VMNAME="worker-${CLUSTER_NAME}-$INDEX"
        fi

        MINIO_SERVER="http://minio-${INDEX}.minio.${K8NAMESPACE}.svc.cluster.local:9000/data/minio"
        SERVER_ARGS=$(echo $SERVER_ARGS | jq --arg MINIO_SERVER "${MINIO_SERVER}" '.args[.args | length] |= . + $MINIO_SERVER')

        kubectl label nodes ${VMNAME} minio=true --overwrite --kubeconfig=./cluster/config
    done

    SERVER_ARGS=$(echo $SERVER_ARGS | jq .args)

    cat $KUBERNETES_TEMPLATE/statefulset.json | jq \
        --argjson SERVER_ARGS "$SERVER_ARGS" \
        '.spec.template.spec.containers[0].args += $SERVER_ARGS' \
        > $KUBERNETES_TEMPLATE/deployment.json

    deploy deployment
    deploy headless
else
    deploy alone
    deploy service
fi
