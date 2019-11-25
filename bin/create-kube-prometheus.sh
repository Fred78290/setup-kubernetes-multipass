#!/bin/bash
set -e

echo "Deploy kube-prometheus"

CURDIR=$(dirname $0)
KUBE_PROMETHEUS_VERSION=0.2.0
KUBE_PROMETHEUS_DIR=./templates/kube-prometheus

#mkdir -p ${KUBE_PROMETHEUS_DIR}
#mkdir -p ${KUBE_PROMETHEUS_DIR}/kube-prometheus/setup
#mkdir -p ${KUBE_PROMETHEUS_DIR}/kube-prometheus/manifests

#curl -L https://github.com/coreos/kube-prometheus/archive/v${KUBE_PROMETHEUS_VERSION}.tar.gz | tar -xz -C /tmp

#mv /tmp/kube-prometheus-${KUBE_PROMETHEUS_VERSION}/manifests/{00namespace-namespace.yaml,0prometheus-operator-*} ${KUBE_PROMETHEUS_DIR}/kube-prometheus/setup
#mv /tmp/kube-prometheus-${KUBE_PROMETHEUS_VERSION}/manifests/* ${KUBE_PROMETHEUS_DIR}/kube-prometheus/manifests
#mv ${KUBE_PROMETHEUS_DIR}/kube-prometheus/setup/0prometheus-operator-serviceMonitor.yaml ${KUBE_PROMETHEUS_DIR}/kube-prometheus/manifests/

#rm -rf /tmp/kube-prometheus-${KUBE_PROMETHEUS_VERSION}

kubectl create -f ${KUBE_PROMETHEUS_DIR}/kube-prometheus/setup

echo -n "Wait kube-prometheus started"
until kubectl get servicemonitors --kubeconfig=./cluster/config --all-namespaces > /dev/null 2>&1
do
    sleep 1;
    echo -n ".";
done

echo ". Done!"

kubectl create -f ${KUBE_PROMETHEUS_DIR}/kube-prometheus/manifests/

kubectl apply -n monitoring -f ${KUBE_PROMETHEUS_DIR}/custom-metrics-api/custom-metrics-apiserver-resource-reader-cluster-role-binding.yaml
kubectl apply -n monitoring -f ${KUBE_PROMETHEUS_DIR}/custom-metrics-api/custom-metrics-apiservice.yaml
kubectl apply -n monitoring -f ${KUBE_PROMETHEUS_DIR}/custom-metrics-api/custom-metrics-cluster-role.yaml
kubectl apply -n monitoring -f ${KUBE_PROMETHEUS_DIR}/custom-metrics-api/custom-metrics-configmap.yaml
kubectl apply -n monitoring -f ${KUBE_PROMETHEUS_DIR}/custom-metrics-api/hpa-custom-metrics-cluster-role-binding.yaml
