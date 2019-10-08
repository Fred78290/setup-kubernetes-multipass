#!/bin/bash
echo "Deploy Kubeless"

CURDIR=$(dirname $0)
KUBELESS_RELEASE=$(curl -s https://api.github.com/repos/kubeless/kubeless/releases/latest | grep tag_name | cut -d '"' -f 4)

pushd $CURDIR/../

if [ -z "$DOMAIN_NAME" ]; then
    export DOMAIN_NAME=$(openssl x509 -noout -subject -in ./etc/ssl/cert.pem | awk -F= '{print $NF}' | sed -e 's/^[ \t]*//' | sed 's/\*\.//g')
fi

kubectl create ns kubeless --kubeconfig=./cluster/config
kubectl create secret tls kubeless -n kubeless --key ./etc/ssl/privkey.pem --cert ./etc/ssl/fullchain.pem --kubeconfig=./cluster/config
kubectl create -f https://github.com/kubeless/kubeless/releases/download/${KUBELESS_RELEASE}/kubeless-${KUBELESS_RELEASE}.yaml --kubeconfig=./cluster/config

mkdir ./data/kubeless/

cat > ./data/kubeless/test.py <<EOF
def hello_kubeless(event, context):
  print event
  return event['data']
EOF

kubeless function deploy hello-kubeless --runtime python2.7 --from-file ./data/kubeless/test.py --handler test.hello_kubeless -n kubeless
kubeless trigger http create hello-kubeless --function-name hello-kubeless --hostname hello-kubeless.$DOMAIN_NAME --tls-secret kubeless -n kubeless