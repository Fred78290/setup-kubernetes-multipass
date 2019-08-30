#/bin/bash

# This script create every thing to deploy a simple kubernetes autoscaled cluster with multipass.
# It will generate:
# Custom multipass image with every thing for kubernetes
# Config file to deploy the cluster autoscaler.
set -e

CURDIR=$(dirname $0)

export CUSTOM_IMAGE=YES
export CLUSTER_NAME="$(hostname | tr '[:upper:]' '[:lower:]')"
export CPUS="4"
export MEMORY="4G"
export DISK="10G"
export SSH_KEY=$(cat ~/.ssh/id_rsa.pub)
export KUBERNETES_VERSION=$(curl -sSL https://dl.k8s.io/release/stable.txt)
export KUBERNETES_PASSWORD=$($CURDIR/create-password.sh)
export KUBECONFIG=$HOME/.kube/config
export TARGET_IMAGE=$HOME/.local/multipass/cache/bionic-k8s-$KUBERNETES_VERSION-amd64.img
export CNI_VERSION="v0.7.5"
export MAXTOTALNODES=3
export OSDISTRO=$(uname -s)
export PACKAGE_UPGRADE="false"
export VLAN_BASE_ADDRESS=10.254.253
export VLAN_BASE_MASK=24

TEMP=$(getopt -o c:d:m:n: --long upgrade,disk:,cpus:,memory:,name:,no-custom-image,image:,ssh-key:,cni-version:,password:,kubernetes-version:,max-nodes-total: -n "$0" -- "$@")

eval set -- "$TEMP"

# extract options and their arguments into variables.
while true; do
	case "$1" in
	-c | --cpus)
		CPUS="$2"
		shift 2
		;;
	-d | --disk)
		DISK="$2"
		shift 2
		;;
	-m | --memory)
		MEMORY="$2"
		shift 2
		;;
	-n | --name)
		CLUSTER_NAME="$2"
		shift 2
		;;
	--no-custom-image)
		CUSTOM_IMAGE="NO"
		shift 1
		;;
	--image)
		TARGET_IMAGE="$2"
		shift 2
		;;
	--ssh-key)
		SSH_KEY="$2"
		shift 2
		;;
	--cni-version)
		CNI_VERSION="$2"
		shift 2
		;;
	--password)
		KUBERNETES_PASSWORD="$2"
		shift 2
		;;
	--kubernetes-version)
		KUBERNETES_VERSION="$2"
		TARGET_IMAGE="$HOME/.local/multipass/cache/bionic-k8s-$KUBERNETES_VERSION-amd64.img"
		shift 2
		;;
	--max-nodes-total)
		MAXTOTALNODES="$2"
		shift 2
		;;
	--upgrade)
		PACKAGE_UPGRADE="true"
		shift 1
		;;
	--)
		shift
		break
		;;
	*)
		echo "$1 - Internal error!"
		exit 1
		;;
	esac
done

# Force update/upgrade
if [ "$OSDISTRO" != "Linux" ]; then
    PACKAGE_UPGRADE=true
fi

function multipass_mount {
    echo -n "Mount point $1 to $2"
while :
do
	echo -n "."
	multipass mount $1 $2 > /dev/null 2>&1 && break
	sleep 1
done
    echo
}

KUBERNETES_USER=$(cat <<EOF
[
    {
        "name": "kubernetes",
        "primary_group": "kubernetes",
        "groups": [
            "adm",
            "users"
        ],
        "lock_passwd": false,
        "passwd": "$KUBERNETES_PASSWORD",
        "sudo": "ALL=(ALL) NOPASSWD:ALL",
        "shell": "/bin/bash",
        "ssh_authorized_keys": [
            "$SSH_KEY"
        ]
    }
]
EOF
)

pushd $CURDIR/../

[ -d config ] || mkdir -p config
[ -d cluster ] || mkdir -p cluster
[ -d kubernetes ] || mkdir -p kubernetes

export PATH=$CURDIR:$PATH

if [ ! -f ./etc/ssl/privkey.pem ]; then
	mkdir -p ./etc/ssl/
	openssl genrsa 2048 >./etc/ssl/privkey.pem
	openssl req -new -x509 -nodes -sha1 -days 3650 -key ./etc/ssl/privkey.pem >./etc/ssl/cert.pem
	cat ./etc/ssl/cert.pem ./etc/ssl/privkey.pem >./etc/ssl/fullchain.pem
	chmod 644 ./etc/ssl/*
fi

export DOMAIN_NAME=$(openssl x509 -noout -subject -in ./etc/ssl/cert.pem | awk -F= '{print $NF}' | sed -e 's/^[ \t]*//' | sed 's/\*\.//g')

./bin/delete-masterkube.sh ${CLUSTER_NAME}

if [ "$OSDISTRO" == "Linux" ]; then

    if [ "$CUSTOM_IMAGE" == "YES" ]; then
        # Check if target image exists
        if [ ! -f $TARGET_IMAGE ]; then
            echo "Create multipass preconfigured image $TARGET_IMAGE"

            [ -d "$HOME/.local/multipass/cache/" ] || mkdir -p $HOME/.local/multipass/cache/

            create-image.sh --password=$KUBERNETES_PASSWORD \
                --cni-version=$CNI_VERSION \
                --custom-image=$TARGET_IMAGE \
                --kubernetes-version=$KUBERNETES_VERSION
        fi

        echo "Launch custom VM instance with $TARGET_IMAGE"

        cat <<EOF | tee ./config/cloud-init-master.json | python2 -c "import json,sys,yaml; print yaml.safe_dump(json.load(sys.stdin), width=500, indent=4, default_flow_style=False)" >./config/cloud-init-master.yaml
        {
            "package_update": $PACKAGE_UPGRADE,
            "package_upgrade": $PACKAGE_UPGRADE,
            "users": $KUBERNETES_USER,
            "ssh_authorized_keys": [
                "$SSH_KEY"
            ],
            "runcmd": [
                "echo '#!/bin/bash' > /usr/local/bin/kubeimage",
                "echo '/usr/local/bin/kubeadm config images pull --kubernetes-version=${KUBERNETES_VERSION}' >> /usr/local/bin/kubeimage",
                "chmod +x /usr/local/bin/kubeimage"
            ],
            "group": [
                "kubernetes"
            ]
        }
EOF

        LAUNCH_IMAGE_URL=file://$TARGET_IMAGE
    else
        LAUNCH_IMAGE_URL="bionic"
    fi
else
    LAUNCH_IMAGE_URL="bionic"
fi

if [ "$LAUNCH_IMAGE_URL" == "bionic" ]; then
    echo "Launch standard VM bionic"

    cat <<EOF | tee ./config/cloud-init-master.json | python2 -c "import json,sys,yaml; print yaml.safe_dump(json.load(sys.stdin), width=500, indent=4, default_flow_style=False)" >./config/cloud-init-master.yaml
    {
        "package_update": ${PACKAGE_UPGRADE},
        "package_upgrade": ${PACKAGE_UPGRADE},
        "packages": [
            "jq",
            "socat",
            "nfs-common"
        ],
        "runcmd": [
            "echo '#!/bin/bash' > /usr/local/bin/kubeimage",
            "echo '/usr/local/bin/kubeadm config images pull --kubernetes-version=${KUBERNETES_VERSION}' >> /usr/local/bin/kubeimage",
            "chmod +x /usr/local/bin/kubeimage"
        ],
        "users": $KUBERNETES_USER,
        "ssh_authorized_keys": [
            "$SSH_KEY"
        ],
        "group": [
            "kubernetes"
        ]
    }
EOF
fi

cat > cluster/hosts.tmpl <<EOF

#VM in initial cluster on vlan0
EOF

for INDEX in $(seq 0 $MAXTOTALNODES)
do
    if [ $INDEX -eq 0 ]; then
	    VMNAME="master-${CLUSTER_NAME}"
    else
	    VMNAME="worker-${CLUSTER_NAME}-$INDEX"
    fi

    echo "${VLAN_BASE_ADDRESS}.$(($INDEX+100))  ${VMNAME} ${VMNAME}.$DOMAIN_NAME" >> cluster/hosts.tmpl
done

for INDEX in $(seq 0 $MAXTOTALNODES)
do
    VLANADDRESS=${VLAN_BASE_ADDRESS}.$((${INDEX}+100))/${VLAN_BASE_MASK}

    if [ $INDEX -eq 0 ]; then
	    VMNAME="master-${CLUSTER_NAME}"
    else
	    VMNAME="worker-${CLUSTER_NAME}-$INDEX"
    fi

    echo "Create VM $VMNAME"

    multipass launch -n ${VMNAME} -m $MEMORY -c $CPUS -d $DISK --cloud-init=./config/cloud-init-master.yaml $LAUNCH_IMAGE_URL

    # Due bug in multipass MacOS, we need to reboot manually the VM after apt upgrade
    if [ "$PACKAGE_UPGRADE" == "true" ] && [ "$OSDISTRO" != "Linux" ]; then
        multipass stop ${VMNAME}
        multipass start ${VMNAME}
    fi

    multipass_mount $PWD/bin ${VMNAME}:/masterkube/bin
    multipass_mount $PWD/templates ${VMNAME}:/masterkube/templates
    multipass_mount $PWD/etc ${VMNAME}:/masterkube/etc
    multipass_mount $PWD/cluster ${VMNAME}:/etc/cluster
    multipass_mount $PWD/data ${VMNAME}:/data

    echo "Prepare ${VMNAME} instance"

    multipass exec ${VMNAME} -- sudo /masterkube/bin/create-vlan.sh "${VLANADDRESS}"
    multipass exec ${VMNAME} -- sudo /bin/bash -c "cat /etc/cluster/hosts.tmpl >> /etc/hosts"
    multipass exec ${VMNAME} -- sudo /bin/bash -c "cat /etc/cluster/hosts.tmpl >> /etc/cloud/templates/hosts.debian.tmpl"

    if [ "$OSDISTRO" != "Linux" ]; then
        multipass exec ${VMNAME} -- sudo /bin/bash -c "/masterkube/bin/install-kubernetes.sh ${KUBERNETES_VERSION} ${CNI_VERSION}"
    else
        multipass exec ${VMNAME} -- sudo /bin/bash -c /usr/local/bin/kubeimage
    fi

    multipass exec ${VMNAME} -- sudo usermod -aG docker multipass
    multipass exec ${VMNAME} -- sudo usermod -aG docker kubernetes

    if [ $INDEX -eq 0 ]; then
        echo "Start kubernetes ${VMNAME} instance master node"
    
        multipass_mount $PWD/kubernetes ${VMNAME}:/etc/kubernetes

        multipass exec ${VMNAME} -- sudo /masterkube/bin/create-cluster.sh flannel ${KUBERNETES_VERSION}

        MASTER_IP=$(cat ./cluster/manager-ip)
        TOKEN=$(cat ./cluster/token)
        CACERT=$(cat ./cluster/ca.cert)

        kubectl label nodes ${VMNAME} master=true --overwrite --kubeconfig=./cluster/config
        kubectl create secret tls kube-system -n kube-system --key ./etc/ssl/privkey.pem --cert ./etc/ssl/fullchain.pem --kubeconfig=./cluster/config

        HOSTS_DEF=$(multipass info ${VMNAME} | grep IPv4 | awk "{print \$2 \"    ${VMNAME}.$DOMAIN_NAME ${VMNAME}-minio.$DOMAIN_NAME ${VMNAME}.$DOMAIN_NAME ${VMNAME}-minio.$DOMAIN_NAME ${VMNAME}-dashboard.$DOMAIN_NAME\"}")
    else
        echo "Start kubernetes ${VMNAME} instance worker node"
    
        multipass exec ${VMNAME} -- sudo /masterkube/bin/join-master.sh
        HOSTS_DEF=$(multipass info ${VMNAME} | grep IPv4 | awk "{print \$2 \"    ${VMNAME}.$DOMAIN_NAME\"}")
    fi

    if [ "$OSDISTRO" == "Linux" ]; then
        sudo sed -i "/${VMNAME}/d" /etc/hosts
        sudo bash -c "echo '$HOSTS_DEF' >> /etc/hosts"
    else
        sudo sed -i '' "/${VMNAME}/d" /etc/hosts
        sudo bash -c "echo '$HOSTS_DEF' >> /etc/hosts"
    fi

done

./bin/kubeconfig-merge.sh master-${CLUSTER_NAME} cluster/config

./bin/create-nfs-provisioner.sh
./bin/create-minio.sh
./bin/create-ingress-controller.sh
./bin/create-dashboard.sh
./bin/create-influxdb.sh
./bin/create-heapster.sh
./bin/create-helloworld.sh

popd
