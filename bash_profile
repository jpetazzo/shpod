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
PS1="\e[1m\e[31m[\$HOSTIP] \e[32m(\$(kube_ps1)) \e[34m\u@\h\e[35m \w\e[0m\n$ "

export EDITOR=vim
export KUBERNETES_SERVICE_HOST=kubernetes.default.svc
export KUBERNETES_SERVICE_PORT=443
export PATH="$HOME/.krew/bin:$PATH"

alias k=kubectl
complete -F __start_kubectl k
. /usr/share/bash-completion/completions/kubectl.bash

export HISTSIZE=9999
export HISTFILESIZE=9999
shopt -s histappend
trap 'history -a' DEBUG
export HISTFILE=~/.history
