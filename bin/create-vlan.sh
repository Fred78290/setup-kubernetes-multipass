#!/bin/bash

LINK=$(ip route get 1|awk '{print $5;exit}')

echo "Create vlan $LINK.0 with address:$1"

cat > /etc/netplan/51-public.yaml <<EOF
network:
  version: 2
  vlans:
    $LINK.0:
      id: 0
      link: $LINK
      addresses: [ "$1" ]
EOF

netplan apply

