#!/bin/bash
KUBERNETES_VERSION=$1
CNI_VERSION=$2

if [ "x$KUBERNETES_VERSION" == "x" ]; then
    echo "Missing KUBERNETES_VERSION"
	KUBERNETES_VERSION="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
fi

if [ "x$CNI_VERSION" == "x" ]; then
    echo "Missing CNI_VERSION"
	CNI_VERSION="v0.7.5"
fi

KUBERNETES_MINOR_RELEASE=$(echo -n $KUBERNETES_VERSION | tr '.' ' ' | awk '{ print $2 }')

# Setup daemon.
if [ $KUBERNETES_MINOR_RELEASE -ge 14 ]; then
    mkdir -p /etc/docker

    cat > /etc/docker/daemon.json <<SHELL
{
    "exec-opts": [
        "native.cgroupdriver=systemd"
    ],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m"
    },
    "storage-driver": "overlay2"
}
SHELL

    curl https://get.docker.com | bash

    mkdir -p /etc/systemd/system/docker.service.d

    # Restart docker.
    systemctl daemon-reload
    systemctl restart docker
else
    curl https://get.docker.com | bash
fi

# On lxd container remove overlay mod test
if [ -f /lib/systemd/system/containerd.service ]; then
	sed -i  's/ExecStartPre=/#ExecStartPre=/g' /lib/systemd/system/containerd.service
	systemctl daemon-reload
	systemctl restart containerd.service
	systemctl restart docker
fi

cat >> /etc/dhcp/dhclient.conf << EOF
interface "eth0" {
}
EOF

# Setup Kube DNS resolver
mkdir /etc/systemd/resolved.conf.d/
cat > /etc/systemd/resolved.conf.d/kubernetes.conf <<SHELL
[Resolve]
DNS=10.96.0.10
Domains=cluster.local
SHELL

systemctl restart systemd-resolved.service

echo "Prepare kubernetes version ${KUBERNETES_VERSION} with CNI:${CNI_VERSION}"

mkdir -p /opt/cni/bin
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-amd64-${CNI_VERSION}.tgz" | tar -C /opt/cni/bin -xz

mkdir -p /usr/local/bin
cd /usr/local/bin
curl -L --remote-name-all https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/{kubeadm,kubelet,kubectl}
chmod +x {kubeadm,kubelet,kubectl}

if [ -f /run/systemd/resolve/resolv.conf ]; then
	echo "KUBELET_EXTRA_ARGS='--resolv-conf=/run/systemd/resolve/resolv.conf --fail-swap-on=false --authentication-token-webhook=true --authorization-mode=Webhook --read-only-port=10255 --feature-gates=VolumeSubpathEnvExpansion=true'" > /etc/default/kubelet
else
	echo "KUBELET_EXTRA_ARGS='--fail-swap-on=false --authentication-token-webhook=true --authorization-mode=Webhook --read-only-port=10255 --feature-gates=VolumeSubpathEnvExpansion=true'" > /etc/default/kubelet
fi

curl -sSL "https://raw.githubusercontent.com/kubernetes/kubernetes/${KUBERNETES_VERSION}/build/debs/kubelet.service" | sed "s:/usr/bin:/usr/local/bin:g" > /etc/systemd/system/kubelet.service
mkdir -p /etc/systemd/system/kubelet.service.d
curl -sSL "https://raw.githubusercontent.com/kubernetes/kubernetes/${KUBERNETES_VERSION}/build/debs/10-kubeadm.conf" | sed "s:/usr/bin:/usr/local/bin:g" > /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

systemctl enable kubelet && systemctl restart kubelet

# Clean all image
for img in $(docker images --format "{{.Repository}}:{{.Tag}}")
do
	echo "Delete docker image:$img"
	docker rmi $img
done

echo 'export PATH=/opt/cni/bin:$PATH' >> /etc/bash.bashrc
#echo 'export PATH=/usr/local/bin:/opt/cni/bin:$PATH' >> /etc/profile.d/apps-bin-path.sh

kubeadm config images pull --kubernetes-version=$KUBERNETES_VERSION
