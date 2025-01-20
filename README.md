# shpod

**⚠️ Please listen carefully, as our ~~menu options~~
installation instructions have changed.**

~~Old instructions: `curl https://shpod.in | sh`~~

New instructions: use the Helm chart!

To get a shell in your Kubernetes cluster, with `cluster-admin` privileges:

```bash
helm upgrade --install --repo https://shpod.in/ shpod shpod \
  --set rbac.cluster.clusterRoles="{cluster-admin}"
kubectl wait deployment shpod --for=condition=Available
kubectl exec -ti deployment/shpod -- login -f k8s
```

## What's this?

Shpod ("Shell in a pod") is a tool to get a shell session with a ton
of tools useful when working with containers, Docker, and Kubernetes.

It's composed of two parts:

- a container image holding all the tools,
- a Helm chart making it easy to deploy it on Kubernetes.

Its goal is to provide a normalized environment, to go
with the training materials at https://container.training/,
so that you can get all the tools you need regardless
of your exact Kubernetes setup.


## The shpod image

It's available as `jpetazzo/shpod` or `ghcr.io/jpetazzo/shpod`.

It's based on Alpine, and includes:

- ab (ApacheBench)
- bash
- bento
- crane
- curl
- Docker CLI
- Docker Compose
- envsubst
- fzf
- git
- gron
- Helm
- jid
- jq
- kubectl
- kubectx + kubens
- kube-linter
- kube-ps1
- kubeseal
- kustomize
- ngrok
- popeye
- regctl
- ship
- skaffold
- skopeo
- SSH
- stern
- tilt
- tmux
- yq
- ytt

It also includes completion for most of these tools.

When this image starts, it will behave differently depending on whether
it has a pseudo-terminal or not.

If it has a pseudo-terminal, it will spawn a shell.
You can access that shell by attaching to the container,
without having to bother with networking or password configuration.
You can see that mode in action by running one of the following commands:

```bash
docker run -ti jpetazzo/shpod
kubectl run --rm -ti shpod --image jpetazzo/shpod
```

If it does not have a pseudo-terminal, it will run an SSH server.
Depending on the values of some environment variables, it will
use a provided password or generate one, or use SSH public key
authentication (see below, "SSH access configuration").

You can see that mode in action by running the following command:

```bash
docker run jpetazzo/shpod
```

However, that mode will likely be more useful on Kubernetes, for instance:
```bash
kubectl create deployment shpod --image jpetazzo/shpod
kubectl expose deployment shpod --port 22 --type=NodePort
kubectl logs deployment/shpod
```

The last command should show you the password that was generated
for the `k8s` user:

```
Generating public/private rsa key pair.
Your identification has been saved in /etc/ssh/ssh_host_rsa_key
Your public key has been saved in /etc/ssh/ssh_host_rsa_key.pub
The key fingerprint is:
SHA256:xEZav2W/XkJ45KaZvxVLNfudttmVwzvAbd8v/b8jkA0 root@shpod-5965cbcfc9-f5p8m
The key's randomart image is:
+---[RSA 3072]----+
|        o        |
|       = .       |
|      . + . o ...|
|       o   E =  +|
|        S . * B+ |
|           o @o+B|
|            = =OO|
|             +o*@|
|              =B%|
+----[SHA256]-----+
Environment variable $PASSWORD not found. Generating a password.
PASSWORD=BlVweGRkEf1PQNdrhpjg
chpasswd: password for 'k8s' changed
Server listening on 0.0.0.0 port 22.
Server listening on :: port 22.
```

In both cases, you can also access shpod by executing a new shell
in the existing container.

With Docker:
```bash
docker exec -ti <container-id> login -f k8s
```

With Kubernetes:
```bash
kubectl exec -ti deployment/shpod -- login -f k8s
```


## Multi-arch support

Shpod supports both Intel and ARM 64 bits architectures. The Dockerfile
in this repository should be able to support other architectures fairly
easily. If a given tool isn't available on the target architecture,
a dummy placeholder will be installed instead.


## SSH access configuration

The user is always `k8s` - this is currently hard-coded.

It is possible to log in either by using a password, or SSH public key
authentication.

If the `$PASSWORD` variable is set, it will define the password for
the `k8s` user.

If the `$AUTHORIZED_KEYS` variable is set, it should hold one or multiple
SSH public keys (one per line), and these keys will be added to the
`~/.ssh/authorized_keys` file.

If neither `$PASSWORD` nor `$AUTHORIZED_KEYS` are set, then a random
password will be generated. By default, that password will be 20 characters
long, using digits, lowercase, and uppercase letters.

It is possible to change the length of the generated password by setting
the variable `$GENERATE_PASSWORD_LENGTH`. If that variable is set to `0`,
no password will be generated.

⚠️ When a password is generated, it is displayed on stdout. This means
that if someone has access to the logs of the container, they will be
able to see that password.

⚠️ If the container restarts for any reasons, a new password will be
generated. This is considered to be a feature.

When using shpod as part of a larger system, it is advised to set the
password (or the SSH keys) to avoid both warnings above.


## Kubernetes permissions

Shpod is meant to be used inside Kubernetes clusters. Once you are
running inside shpod, Kubernetes commands (like `kubectl` or `helm`)
will use "in-cluster configuration"; in other words, these commands
will use the ServiecAccount of the Pod that runs shpod.

By default, on most clusters, that ServiceAccount won't have much
permissions, meaning that you will get errors like the following one:

```console
$ kubectl get pods
Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:default:default" cannot list resource "pods" in API group "" in the namespace "default"
```

If you want to use Kubernetes commands within shpod, you need
to give permissions to that ServiceAccount.

Assuming that you are running shpod in the `default` namespace
and with the `default` ServiceAccount, you can run the following
command to give `cluster-admin` privileges (=all privileges) to
the commands running in shpod:

```bash
kubectl create clusterrolebinding shpod \
        --clusterrole=cluster-admin \
        --serviceaccount=default:default
```


## Special handling of kubeconfig

If you have a ConfigMap named `kubeconfig` in the Namespace
where shpod is running, it will extract the first file from
that ConfigMap and use it to populate `~/.kube/config`.

This lets you inject a custom kubeconfig file into shpod.


## Helm chart

Since November 2024, shpod also has a Helm chart!

This Helm chart offers the following features:

- enable or disable the SSH server (depending on your needs)
- put the `k8s` user home directory on a Persistent Volume
- list Roles and ClusterRoles to bind to the ServiceAccount

Here's an example of how to use it:

```bash
helm upgrade --install --repo https://shpod.in/ shpod shpod \
  --set service.type=NodePort \
  --set resources.requests.cpu=0.1 \
  --set resources.requests.memory=500M \
  --set resources.limits.cpu=1 \
  --set resources.limits.memory=500M \
  --set persistentVolume.enabled=true \
  --set "rbac.cluster.clusterRoles={cluster-admin}" \
  --set ssh.authorized_keys="$(cat ~/.ssh/*.pub)" \
  #
```


## I don't like Helm charts!

You can also use the following YAML manifest:

```bash
kubectl apply -f https://shpod.in/shpod.yaml
```

Then attach to the shpod pod:

```bash
kubectl attach --namespace=shpod -ti shpod
```

But you really should use the Helm chart instead.


## Why should I use the Helm chart?

I'm using shpod when teaching Kubernetes classes. I deploy a Kubernetes
cluster for each student, and they access the cluster by connecting with
SSH. In some cases, I deploy the clusters with `kubeadm` on top of "raw"
VMs, and the students connect directly to the nodes. In some cases, I'm
using managed Kubernetes clusters, and SSH access to the nodes may or
may not be possible; in any case, it will require different steps for
each cloud provider. To simplify things, I built shpod, and use it to
run an SSH server that the students connect to.

This approach works great for most Kubernetes classes, but there are a
few scenarios that are problematic; specifically, when the Node running
shpod is starved for resources, the shpod Pod might get evicted. This
causes all the files in the container to be deleted, which is not great
when it happens during a class.

The solution to that problem has multiple layers:

1. Specify resource requests and limits, in particular for memory, to
   avoid the pod being evicted by memory pressure on the node.
2. Place the `k8s` user home directory on a Persistent Volume, so that
   the content of the home directory isn't lost if the Pod gets evicted
   anyway or the underlying Node crashes or gets removed for any reason.
3. Make that Persistent Volume optional, so that shpod still works on
   clusters that don't have a Storage Class providing dynamic volume
   provisioning. In that case, fall back gracefully to an `emptyDir`
   volume, to prevent pod eviction by `kubectl drain` or by the cluster
   autoscaler, and to persist files across container restarts.

The Helm chart lets you pick easily which configuration works best for
you: with or without the SSH server, with or without a password or SSH
public keys, with or without a Persistent Volume, with or without
resource requests and limits...

## Experimental stuff

You can enable code-server (basically "VScode used from a browser")
and expose it over a `NodePort` like so:

```bash
helm upgrade --install --repo https://shpod.in/ shpod shpod \
  --set codeServer.enabled=true \
  --set persistentVolume.enabled=true \
  --set rbac.cluster.clusterRoles="{cluster-admin}" \
  --set resources.requests.cpu=0.1 \
  --set resources.requests.memory=500M \
  --set resources.limits.cpu=1 \
  --set resources.limits.memory=500M \
  --set service.type=NodePort \
  --set ssh.password=codeserver.support.is.beta.and.will.break
kubectl wait deployment shpod --for=condition=Available
```

This is super experimental; I'd like to refactor the image and the
Helm chart before going further. So if you use this, you should expect
it to break in the near future.

