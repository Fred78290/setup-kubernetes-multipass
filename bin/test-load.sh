#!/bin/bash

# This file is intent to deploy dashboard inside the masterkube
CURDIR=$(dirname $0)

pushd $CURDIR/../

export CLUSTER_NAME="$(hostname | tr '[:upper:]' '[:lower:]')"
export DOMAIN_NAME=$(openssl x509 -noout -subject -in ./etc/ssl/cert.pem | awk -F= '{print $NF}' | sed -e 's/^[ \t]*//' | sed 's/\*\.//g')

cmd="while true; do curl -s https://master-$CLUSTER_NAME.$DOMAIN_NAME/ 2>&1 > /dev/null; done"

for index in $(seq 1 100)
do
    bash -c "$cmd" &
done

sleep 1000000000