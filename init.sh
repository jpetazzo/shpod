#!/bin/sh
set -e

# If there is a tty, give us a shell.
# (This happens e.g. when we do "docker run -ti jpetazzo/shpod".)
# Otherwise, start an SSH server.
# (This happens e.g. when we use that image in a Pod in a Deployment.)

if tty >/dev/null; then
  exec login -f k8s
else
  ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N ""
  if [ "$PASSWORD" ]; then
    echo 'Environment variable $PASSWORD found. Using it.'
  else
    echo 'Environment variable $PASSWORD not found. Generating a password.'
    PASSWORD=$(base64 /dev/urandom | tr -d +/ | head -c 20)
    echo "PASSWORD=$PASSWORD"
  fi
  echo "k8s:$PASSWORD" | chpasswd
  exec /usr/sbin/sshd -D -e
fi

