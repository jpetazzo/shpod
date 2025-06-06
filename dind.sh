#!/bin/sh
if [ $# = 0 ]; then
  if ! sudo mountpoint -q /var/lib/docker; then
    echo "/var/lib/docker doesn't seem to be a mountpoint."
    echo "Docker-in-Docker probably won't work. Aborting."
    exit 1
  fi
  if lsmod | grep -q ^iptable; then
    echo "Detected modules for legacy iptables."
    echo "Updating iptables to point to legacy binary."
    sudo ln -sf xtables-legacy-multi $(which iptables)
  fi
  echo "Starting Docker Engine in the background (logging to $HOME/docker.log)."
  nohup sudo sh -c "$0 dockerd &" >$HOME/docker.log
  exit 0
fi
#
# The rest of this script is taken verbatim from:
# https://raw.githubusercontent.com/moby/moby/refs/heads/master/hack/dind
#
set -e

# DinD: a wrapper script which allows docker to be run inside a docker container.
# Original version by Jerome Petazzoni <jerome@docker.com>
# See the blog post: https://www.docker.com/blog/docker-can-now-run-within-docker/
#
# This script should be executed inside a docker container in privileged mode
# ('docker run --privileged', introduced in docker 0.6).

# Usage: dind CMD [ARG...]

# apparmor sucks and Docker needs to know that it's in a container (c) @tianon
#
# Set the container env-var, so that AppArmor is enabled in the daemon and
# containerd when running docker-in-docker.
#
# see: https://github.com/containerd/containerd/blob/787943dc1027a67f3b52631e084db0d4a6be2ccc/pkg/apparmor/apparmor_linux.go#L29-L45
# see: https://github.com/moby/moby/commit/de191e86321f7d3136ff42ff75826b8107399497
export container=docker

# Allow AppArmor to work inside the container;
#
#     aa-status
#     apparmor filesystem is not mounted.
#     apparmor module is loaded.
#
#     mount -t securityfs none /sys/kernel/security
#
#     aa-status
#     apparmor module is loaded.
#     30 profiles are loaded.
#     30 profiles are in enforce mode.
#       /snap/snapd/18357/usr/lib/snapd/snap-confine
#       ...
#
# Note: https://0xn3va.gitbook.io/cheat-sheets/container/escaping/sensitive-mounts#sys-kernel-security
#
#     ## /sys/kernel/security
#
#     In /sys/kernel/security mounted the securityfs interface, which allows
#     configuration of Linux Security Modules. This allows configuration of
#     AppArmor policies, and so access to this may allow a container to disable
#     its MAC system.
#
# Given that we're running privileged already, this should not be an issue.
if [ -d /sys/kernel/security ] && ! mountpoint -q /sys/kernel/security; then
	mount -t securityfs none /sys/kernel/security || {
		echo >&2 'Could not mount /sys/kernel/security.'
		echo >&2 'AppArmor detection and --privileged mode might break.'
	}
fi

# Mount /tmp (conditionally)
# /tmp must be 'exec,rw', and 'dev' to allow mknod to work for the
# pkg/archive/archive_linux_test.go tests.
if ! mountpoint -q /tmp; then
	mount -t tmpfs none /tmp
fi

# cgroup v2: enable nesting
if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
	# move the processes from the root group to the /init group,
	# otherwise writing subtree_control fails with EBUSY.
	# An error during moving non-existent process (i.e., "cat") is ignored.
	mkdir -p /sys/fs/cgroup/init
	# this happens in a loop because things like "docker exec" on our dind
	# container will create new processes, which creates a race between our
	# moving everything to "init" and enabling subtree_control
	while ! {
		# move the processes from the root group to the /init group,
		# otherwise writing subtree_control fails with EBUSY.
		# An error during moving non-existent process (i.e., "cat") is ignored.
		xargs -rn1 < /sys/fs/cgroup/cgroup.procs > /sys/fs/cgroup/init/cgroup.procs || :
		# enable controllers
		sed -e 's/ / +/g' -e 's/^/+/' < /sys/fs/cgroup/cgroup.controllers \
			> /sys/fs/cgroup/cgroup.subtree_control
	}; do true; done
fi

# Change mount propagation to shared to make the environment more similar to a
# modern Linux system, e.g. with SystemD as PID 1.
mount --make-rshared /

if [ $# -gt 0 ]; then
	exec "$@"
fi

echo >&2 'ERROR: No command specified.'
echo >&2 'You probably want to run hack/make.sh, or maybe a shell?'
