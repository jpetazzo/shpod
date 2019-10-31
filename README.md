# shpod

`shpod` is a container image based on the Alpine distribution
and embarking a bunch of tools useful when working with Kubernetes:

- kubectl
- helm
- ship
- kubectx + kubens
- kube-ps1
- stern
- compose

It also includes tmux, a custom prompt, and completion for
all of the above.

Its goal is to provide a normalized environment, to go
with the training materials at https://container.training/,
so that you can get all the tools you need regardless
of your exact Kubernetes setup.

To use it:

1. Get a Kubernetes cluster. You can use Minikube, microk8s,
   Docker Desktop, AKS, EKS, GKE, anything you like, really.

2. Deploy the shpod pod:
   ```
   kubectl apply -f https://raw.githubusercontent.com/jpetazzo/shpod/master/shpod.yaml
   ```

3. Attach to the shpod pod:
   ```
   kubecth attach --namespace=shpod -ti shpod
   ```

4. Enjoy!

To remove it, you can do a `kubectl delete` on that URL above.

You can also delete the namespace `shpod` and the ClusterRoleBinding
with the same name:

```
kubectl delete clusterrolebinding,ns shpod
```


## Internal details

The YAML file is a Kubernetes manifest for a Pod, a ServiceAccount,
a ClusterRoleBinding, and a Namespace to hold the Pod and ServiceAccount.

The Pod uses image [jpetazzo/shpod](https://hub.docker.com/r/jpetazzo/shpod)
on the Docker Hub, built from this repository (https://github.com/jpetazzo/shpod).

