#!/usr/bin/env bash
set -e

# If there is a tty, give us a shell.
# (This happens e.g. when we do "docker run -ti jpetazzo/shpod".)
# Otherwise, start an SSH server.
# (This happens e.g. when we use that image in a Pod in a Deployment.)

if tty >/dev/null; then
  exec login -f k8s
else
  if ! [ -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N ""
  fi
  if [ "$AUTHORIZED_KEYS" ]; then
    echo 'Environment variable $AUTHORIZED_KEYS found. Adding keys.'
    sudo -u k8s mkdir -p ~k8s/.ssh
    sudo -u k8s touch ~k8s/.ssh/authorized_keys
    while read KEY; do
      if [ "$KEY" ] && ! grep -q "$KEY" ~k8s/.ssh/authorized_keys; then
        echo "$KEY" >> ~k8s/.ssh/authorized_keys
      fi
    done <<< "$AUTHORIZED_KEYS"
  fi
  if [ "$PASSWORD" ]; then
    echo 'Environment variable $PASSWORD found. Setting user password.'
  else
    if [ ! "$AUTHORIZED_KEYS" -a "${GENERATE_PASSWORD_LENGTH-0}" -gt 0 ]; then
      echo 'Environment variable $PASSWORD not found. Generating a password.'
      PASSWORD=$(base64 /dev/urandom | tr -d +/ | head -c $GENERATE_PASSWORD_LENGTH)
      echo "PASSWORD=$PASSWORD"
    else
      echo 'Environment variable $PASSWORD not found. User password will not be set.'
    fi
  fi
  if [ "$PASSWORD" ]; then
    echo "k8s:$PASSWORD" | chpasswd
  fi
  exec /usr/sbin/sshd -D -e
fi

