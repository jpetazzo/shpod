#!/bin/sh
#
# This script is not used at the moment (as of the April 2025 changes to
# add support for devcontainers) but it might be used in the future in
# an attempt to support "docker-outside-docker" instead of "docker-in-docker".
#
sudo nohup >/dev/null sh -c "
  socat unix-listen:/var/run/docker.sock,fork,user=k8s unix-connect:/var/run/docker-host.sock &
"
