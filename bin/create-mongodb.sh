#!/bin/bash

CURDIR=$(dirname $0)
pushd $CURDIR/..

mkdir -p ./config/deployment/mongodb/

MONGODB_PRIVATE_KEY=$(uuidgen | cut -d '-' -f 5)
MONGODB_PASSWORD=$(uuidgen | cut -d '-' -f 5)
MONGODB_ORGID=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | tr '[:upper:]' '[:lower:]' | fold -w 24 | head -n 1)

cat > ./config/deployment/mongodb/env <<EOF
export MONGODB_PRIVATE_KEY=${MONGODB_PRIVATE_KEY}
export MONGODB_PASSWORD=${MONGODB_PASSWORD}
export MONGODB_ORGID=${MONGODB_ORGID}
EOF

if [ -z "$DOMAIN_NAME" ]; then
    export DOMAIN_NAME=$(openssl x509 -noout -subject -in ./etc/ssl/cert.pem | awk -F= '{print $NF}' | sed -e 's/^[ \t]*//' | sed 's/\*\.//g')
    echo "domain:$DOMAIN_NAME"
fi

kubectl create namespace mongodb --kubeconfig=./cluster/config
kubectl create secret generic mongodb --from-literal="user=mongodb" --from-literal="publicApiKey=${MONGODB_PRIVATE_KEY}" -n mongodb --kubeconfig=./cluster/config
kubectl create secret generic ops-manager-admin-secret  --from-literal=Username="mongodb" --from-literal=Password="${MONGODB_PASSWORD}" --from-literal=FirstName="Mongo" --from-literal=LastName="User" -n mongodb --kubeconfig=./cluster/config

kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-enterprise-kubernetes/master/crds.yaml --kubeconfig=./cluster/config
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-enterprise-kubernetes/master/mongodb-enterprise.yaml --kubeconfig=./cluster/config

cat > ./config/deployment/mongodb/project.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: masterkube-mongodb
  namespace: mongodb
data:
  projectName: MasterKube
  orgId: $MONGODB_ORGID
  baseUrl: http://ops-manager-svc.mongodb.svc.cluster.local
EOF

cat > ./config/deployment/mongodb/ops-manager.yaml <<EOF
apiVersion: mongodb.com/v1
kind: MongoDBOpsManager
metadata:
  name: ops-manager
spec:
  version: 4.2.0
  adminCredentials: ops-manager-admin-secret
  configuration:
    mms.fromEmailAddr: "ops-manager-admin@$DOMAIN_NAME"

  applicationDatabase:
    members: 3
    version: 4.2.0
    persistent: true
    type: ReplicaSet
    podSpec:
      cpu: '0.25'
EOF

kubectl apply -f ./config/deployment/mongodb/ops-manager.yaml --kubeconfig=./cluster/config