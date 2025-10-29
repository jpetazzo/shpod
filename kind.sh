#!/bin/sh
#
# This script tries to create a KinD cluster and then add
# a couple of routes so that the pod CIDR and the service
# CIDR are directly rechable from the local machine.
# This simplifies the Kubernetes learning experience, as
# pods and services become reachable directly from the
# local machine, without having to use port forwarding or
# other mechanisms. Note, however, that it only works on
# Linux machines!
#
kubectl config get-contexts kind-kind || kind create cluster
docker exec kind-control-plane true || docker start kind-control-plane
NODE_ADDR=$(
  docker inspect kind-control-plane |
  jq -r .[].NetworkSettings.Networks.kind.IPAddress
)
sudo ip route add 10.244.0.0/24 via $NODE_ADDR
sudo ip route add 10.96.0.0/12 via $NODE_ADDR

