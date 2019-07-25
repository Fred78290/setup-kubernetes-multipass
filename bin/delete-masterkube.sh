#!/bin/bash
CURDIR=$(dirname $0)
CLUSTER_NAME=$1

echo "Delete master-${CLUSTER_NAME} previous instance"

pushd $CURDIR/../

if [ -f ./cluster/config ]; then
    for vm in $(kubectl get node -o json --kubeconfig ./cluster/config | jq '.items| .[] | .metadata.labels["kubernetes.io/hostname"]')
    do
        vm=$(echo -n $vm | tr -d '"')
        echo "Delete multipass VM: $vm"
        multipass delete $vm -p &> /dev/null
    done
fi

for INDEX in $(seq 0 $MAXTOTALNODES)
do
    if [ $INDEX -eq 0 ]; then
	    VMNAME="master-${CLUSTER_NAME}"
    else
	    VMNAME="worker-${CLUSTER_NAME}-$INDEX"
    fi

    multipass delete $VMNAME -p &> /dev/null
done

./bin/kubeconfig-delete.sh master-${CLUSTER_NAME} &> /dev/null

find cluster ! -name '*.md' -type f -exec rm -f "{}" "+"
find config ! -name '*.md' -type f -exec rm -f "{}" "+"
find kubernetes ! -name '*.md' -type f -exec rm -f "{}" "+"

rm -rf config/deployment

popd