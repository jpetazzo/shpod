#!/bin/sh
if [ -f shpod.yaml ]; then
  YAML=shpod.yaml
else
  YAML=https://raw.githubusercontent.com/jpetazzo/shpod/master/shpod.yaml
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
shpod, you need to wait a bit (about 30 seconds).
"
kubectl delete -f $YAML --now
echo "Done."
