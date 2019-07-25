#!/bin/bash
CURDIR=$(dirname $0)

pushd $CURDIR/../

export K8NAMESPACE=kube-system
export ETC_DIR=./config/deployment/minio
export KUBERNETES_TEMPLATE=./templates/minio

export MINIO_ACCESS_KEY=${CLUSTER_NAME}-minio
export MINIO_SECRET_KEY=$KUBERNETES_PASSWORD
export MINIO_REPLICAS=$((MAXTOTALNODES+1))
export MINIO_SERVER_TYPE=daemonset

[ -z "$VLAN_BASE_ADDRESS" ] && export VLAN_BASE_ADDRESS=10.254.253
[ -z "$VLAN_BASE_MASK" ] && export VLAN_BASE_MASK=24

if [ $MAXTOTALNODES -gt 2 ]; then
    SERVER_ARGS='{ "args": [ "server" ] }'

    echo "Setup minio distributed server with ${MINIO_REPLICAS} replicas"

    for INDEX in $(seq 0 $MAXTOTALNODES)
    do
        if [ $INDEX -eq 0 ]; then
            VMNAME="master-${CLUSTER_NAME}"
        else
            VMNAME="worker-${CLUSTER_NAME}-$INDEX"
        fi

        if [ $MINIO_SERVER_TYPE == "statefulset" ]; then
            MINIO_SERVER="http://minio-${INDEX}.minio.${K8NAMESPACE}.svc.cluster.local:9000/data/minio"
        else
            MINIO_SERVER="http://${VMNAME}.$(($INDEX+100)):9000/data/minio"
        fi

        SERVER_ARGS=$(echo $SERVER_ARGS | jq --arg MINIO_SERVER "${MINIO_SERVER}" '.args[.args | length] |= . + $MINIO_SERVER')

        kubectl label nodes ${VMNAME} minio=true --overwrite --kubeconfig=./cluster/config
    done

    SERVER_ARGS=$(echo $SERVER_ARGS | jq .args)

    if [ $MINIO_SERVER_TYPE == "statefulset" ]; then
        cat ${KUBERNETES_TEMPLATE}/${MINIO_SERVER_TYPE}/${MINIO_SERVER_TYPE}.json | jq \
            --argjson SERVER_ARGS "$SERVER_ARGS" \
            --argjson MINIO_REPLICAS "$MINIO_REPLICAS" \
            '.spec.replicas = $MINIO_REPLICAS
            | .spec.template.spec.containers[0].args += $SERVER_ARGS' \
            > ${KUBERNETES_TEMPLATE}/${MINIO_SERVER_TYPE}/deployment.json
    else
        cat ${KUBERNETES_TEMPLATE}/${MINIO_SERVER_TYPE}/${MINIO_SERVER_TYPE}.json | jq \
            --argjson SERVER_ARGS "$SERVER_ARGS" \
            '.spec.template.spec.containers[0].args += $SERVER_ARGS' \
            > ${KUBERNETES_TEMPLATE}/${MINIO_SERVER_TYPE}/deployment.json
    fi

else
    echo "Setup minio standalone server"

    MINIO_SERVER_TYPE=standalone
fi

mkdir -p $ETC_DIR

function deploy {
    echo "Create $ETC_DIR/$1.json"
echo $(eval "cat <<EOF
$(<${KUBERNETES_TEMPLATE}/${MINIO_SERVER_TYPE}/$1.json)
EOF") | jq . > $ETC_DIR/$1.json

kubectl apply -f $ETC_DIR/$1.json --kubeconfig=./cluster/config
}

deploy deployment
deploy service

[ -e "${MINIO_SERVER_TYPE}/ingress.json" ] && deploy ingress
