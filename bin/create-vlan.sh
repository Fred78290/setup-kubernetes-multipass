#!/bin/bash

echo "Create vlan0"

LINK=$(ip route get 1|awk '{print $5;exit}')

echo "Create vlan with address:$1"

cat > /etc/netplan/51-public.yaml <<EOF
network:
  version: 2
  vlans:
    vlan0:
      id: 0
      link: $LINK
      addresses: [ $1 ]
EOF

netplan apply

