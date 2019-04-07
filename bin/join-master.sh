#!/bin/bash
echo "Kubernetes pod on $(hostname) will join manager at `cat /etc/cluster/manager-ip`"

if [ ! -f /etc/kubernetes/kubelet.conf ]; then
    # https://github.com/kubernetes/kubernetes/issues/57709
    sed -e 's/^search/#search/' -i /etc/resolv.conf

    kubeadm join \
        --token `cat  /etc/cluster/token` \
        `cat /etc/cluster/manager-ip` \
        --discovery-token-ca-cert-hash sha256:`cat /etc/cluster/ca.cert` \
        --ignore-preflight-errors=All

    # https://github.com/kubernetes/kubernetes/issues/57709
    sed -e 's/^#search/search/' -i /etc/resolv.conf
else
    echo "Node k8 already set"
fi