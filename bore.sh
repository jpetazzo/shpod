#!/bin/sh
set -eu

CONTAINER_NAME=kind-control-plane
CONTAINER_PID=$(docker inspect $CONTAINER_NAME --format '{{.State.Pid}}')

docker exec $CONTAINER_NAME touch /borens
addmount $$ /proc/$$/ns/net $CONTAINER_PID /borens

docker exec $CONTAINER_NAME sh -c '
set -e
CNI_PLUGIN=$(cat /etc/cni/net.d/10-kindnet.conflist | jq -r ".plugins[0].type")
cat /etc/cni/net.d/10-kindnet.conflist | jq ".plugins[0] + {name: .name}" |
CNI_COMMAND=ADD CNI_CONTAINERID=bore CNI_NETNS=/borens CNI_IFNAME=bore CNI_PATH=/opt/cni/bin \
/opt/cni/bin/$CNI_PLUGIN
' > /tmp/bore.json

GATEWAY=$(jq -r .ip4.gateway < /tmp/bore.json)

ip route del default via $GATEWAY
ip route add 10.244.0.0/16 via $GATEWAY
ip route add 10.96.0.0/12 via $GATEWAY
