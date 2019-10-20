#!/bin/bash
#set -ex

echo "Deploy registry"

CURDIR=$(dirname $0)

pushd $CURDIR/../

export K8NAMESPACE=kube-registry
export ETC_DIR=./config/deployment/registry
export KUBERNETES_TEMPLATE=./templates/registry
export SUBPATH_POD_NAME='$(POD_NAME)'
export REWRITE_TARGET='/$1'
export REGISTRY_USERNAME=${CLUSTER_NAME}-registry
export REGISTRY_PASSWORD=$KUBERNETES_PASSWORD
export REGISTRY_HTPASSWORD=$ETC_DIR/htpassword
export REGISTRY_PASSWORD_FILE=$ETC_DIR/password
export REGISTRY_NAME=masterkube-registry
export HTPASSWORD_PLAIN=$(htpasswd -bn $REGISTRY_USERNAME $REGISTRY_HTPASSWORD)

if [ -z "$DOMAIN_NAME" ]; then
    export DOMAIN_NAME=$(openssl x509 -noout -subject -in ./etc/ssl/cert.pem | awk -F= '{print $NF}' | sed -e 's/^[ \t]*//' | sed 's/\*\.//g')
    echo "domain:$DOMAIN_NAME"
fi

mkdir -p $ETC_DIR

echo $HTPASSWORD_PLAIN > $REGISTRY_HTPASSWORD
echo $REGISTRY_USERNAME:$REGISTRY_PASSWORD > $REGISTRY_PASSWORD_FILE

kubectl create ns $K8NAMESPACE --kubeconfig=./cluster/config

kubectl create secret docker-registry $REGISTRY_NAME \
    --docker-username=$REGISTRY_USERNAME \
    --docker-password=$REGISTRY_PASSWORD \
    --docker-server=$REGISTRY_NAME \
    --docker-email=root@localhost \
	-n kube-system

kubectl create secret tls $K8NAMESPACE -n $K8NAMESPACE \
    --key ./etc/ssl/privkey.pem \
    --cert ./etc/ssl/fullchain.pem \
    --kubeconfig=./cluster/config

kubectl create secret generic registry-auth-data \
    --from-file="htpasswd=$REGISTRY_HTPASSWORD" \
    --kubeconfig=./cluster/config \
    -n $K8NAMESPACE

kubectl create secret generic registry-tls-data \
    --from-file="tls.key=./etc/ssl/privkey.pem" \
    --from-file="tls.crt=./etc/ssl/fullchain.pem" \
    --kubeconfig=./cluster/config \
    -n $K8NAMESPACE

function deploy {
    echo "Create $ETC_DIR/$1.json"
echo $(eval "cat <<EOF
$(<$KUBERNETES_TEMPLATE/$1.json)
EOF") | jq . > $ETC_DIR/$1.json

kubectl apply -f $ETC_DIR/$1.json --kubeconfig=./cluster/config
}

deploy pv
deploy pvc
deploy deployment
deploy service
deploy ingress
