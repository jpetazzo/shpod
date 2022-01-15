#!/bin/sh
# For more information about shpod, check it out on GitHub:
# https://github.com/bretfisher/shpod
if [ -f shpod.yaml ]; then
  YAML=shpod.yaml
else
  YAML=https://k8smastery.com/shpod.yaml
fi
if [ "$(kubectl get pod --namespace=shpod shpod --ignore-not-found -o jsonpath='{.status.phase}')" = "Running" ]; then
  echo "Shpod is already running. Starting a new shell with 'kubectl exec'."
  echo "(Note: if the main invocation of shpod exits, all others will be terminated.)"
  kubectl exec -ti --namespace=shpod shpod -- bash -l
  if [ $? = 137 ]; then
    echo "Shpod was terminated by SIGKILL. This will happen when the main invocation"
    echo "of shpod exits (all processes started by 'kubectl exec' are then terminated)."
  fi
  exit 0
fi
echo "Applying YAML: $YAML..."
kubectl apply -f $YAML
echo "Waiting for pod to be ready..."
kubectl wait --namespace=shpod --for condition=Ready pod/shpod
echo "Attaching to the pod..."
kubectl attach --namespace=shpod -ti shpod </dev/tty
echo "Deleting pod..."
echo "
Note: it's OK to press Ctrl-C if this takes too long and you're impatient.
Clean up will continue in the background. However, if you want to restart
shpod, you might have to wait a bit (about 30 seconds).
"
kubectl delete -f $YAML --now
echo "Done."
