# If we don't have a kubeconfig file, let's create one.
# (This is necessary for kube_ps1 to operate correctly.)
if ! [ -f ~/.kube/config ]; then
  # If there is a ConfigMap named 'kubeconfig',
  # extract the kubeconfig file from there.
  if kubectl get configmap kubeconfig >&/dev/null; then
    echo "✏️ Populating .kube/config with ConfigMap kubeconfig."
    kubectl get configmap kubeconfig -o json |
      jq '.data | to_entries | .[0].value' > ~/.kube/config
  else
    SADIR=/var/run/secrets/kubernetes.io/serviceaccount
    # If we have a ServiceAccount token, use it.
    if [ -r $SADIR/token ]; then
      echo "✏️ Creating default .kube/config file."
      kubectl config set-cluster shpod \
              --server=https://kubernetes.default.svc \
              --certificate-authority=/$SADIR/ca.crt
      kubectl config set-credentials shpod \
              --token=$(cat $SADIR/token )
      kubectl config set-context shpod \
              --cluster=shpod \
              --user=shpod
      kubectl config use-context shpod
    fi
  fi
fi
# Note that we could also just set the following variables:
#export KUBERNETES_SERVICE_HOST=kubernetes.default.svc
#export KUBERNETES_SERVICE_PORT=443
# ...But for some reason, that doesn't work with impersonation.
# (i.e. using "kubectl get pods --as=someone.else")

if [ -f /etc/HOSTIP ]; then
  HOSTIP=$(cat /etc/HOSTIP)
else
  HOSTIP="0.0.0.0"
fi
KUBE_PS1_PREFIX=""
KUBE_PS1_SUFFIX=""
KUBE_PS1_SYMBOL_ENABLE="false"
KUBE_PS1_CTX_COLOR="green"
KUBE_PS1_NS_COLOR="green"
PS1="\e[1m\e[31m[\$HOSTIP] \e[0m(\$(kube_ps1)) \e[34m\u@\h\e[35m \w\e[0m\n$ "

export EDITOR=vim
export PATH="$HOME/.krew/bin:$PATH"

alias k=kubectl
complete -F __start_kubectl k
. /usr/share/bash-completion/completions/kubectl.bash

export HISTSIZE=9999
export HISTFILESIZE=9999
shopt -s histappend
trap 'history -a' DEBUG
export HISTFILE=~/.history
