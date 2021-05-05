# shpod

**TL,DR:** `curl https://shpod.sh | sh`

If you are looking for an image that works on the ARM architecture
(like the Raspberry Pi or the Apple M1), have a look at
[BretFisher/shpod](https://github.com/BretFisher/shpod) instead.
Bret's fork is also a state-of-the-art example of a multi-arch
Dockerfile!


## What's this?

`shpod` is a container image based on the Alpine distribution
and embarking a bunch of tools useful when working with Kubernetes:

- compose
- helm
- jid
- jq
- krew
- kubectl
- kubectx + kubens
- kube-ps1
- kubeseal
- k9s
- ship
- skaffold
- stern
- tilt

It also includes tmux, a custom prompt, and completion for
all of the above.

Its goal is to provide a normalized environment, to go
with the training materials at https://container.training/,
so that you can get all the tools you need regardless
of your exact Kubernetes setup.

To use it, you need a Kubernetes cluster. You can use Minikube,
microk8s, Docker Desktop, AKS, EKS, GKE, anything you like, really.


## One-liner usage

The [shpod.sh](shpod.sh) script will:

- apply the [shpod.yaml](shpod.yaml) manifest to your cluster,
- wait for the pod `shpod` to be ready,
- attach to that pod,
- delete resources created by the manifest when you exit the pod.

To execute it:

```bash
curl https://raw.githubusercontent.com/jpetazzo/shpod/main/shpod.sh | sh
```

It's also available with short URLs:

```bash
curl https://shpod.sh | sh
curl https://shpod.me | sh
```

If you don't like `curl|sh`, and/or if you want to execute things
step by step, check the next section.


## Step-by-step usage

1. Deploy the shpod pod:
   ```
   kubectl apply -f https://raw.githubusercontent.com/jpetazzo/shpod/main/shpod.yaml
   ```

2. Attach to the shpod pod:
   ```
   kubectl attach --namespace=shpod -ti shpod
   ```

3. Enjoy!


## Clean up

If you are using the shell script above, when you exit shpod,
the script will delete the resources that were created.

If you want to delete the resources manually, you can use
`kubectl delete -f shpod.yaml`, or delete the namespace `shpod`
and the ClusterRoleBinding with the same name:

```
kubectl delete clusterrolebinding,ns shpod
```


## Internal details

The YAML file is a Kubernetes manifest for a Pod, a ServiceAccount,
a ClusterRoleBinding, and a Namespace to hold the Pod and ServiceAccount.

The Pod uses image [jpetazzo/shpod](https://hub.docker.com/r/jpetazzo/shpod)
on the Docker Hub, built from this repository (https://github.com/jpetazzo/shpod).


## Opening multiple sessions

Shpod tries to detect if it is already running; and if it's the case,
it will try to start another process using `kubectl exec`. Note that
if the first shpod process exits, Kubernetes will terminate all the
other processes.

