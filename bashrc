# In theory, ~/.bash_profile only gets loaded for interactive login shells,
# meaning that it should run only once per session. It makes it the ideal
# place to start e.g. ssh-agent and do other one-time, expensive operations.
# On the other hand, aliases have to be defined in each shell, so they
# would typically be defined in ~/.bashrc. ~/.bashrc is also ideal for
# environment variables like PS1, or variables that we might want to redefine
# easily, since ~/.bashrc gets reloaded in each shell. Since ~/.bashrc isn't
# loaded in login shells, though, it makes sense to load it automatically
# at the end of ~/.bash_profile.
#
# With all that said, though, this will run in containers, and we can't be
# sure that there will be a proper login shell (for instance, if you run
# "kubectl exec -ti <pod> -- bash" or "docker exec -ti <container> bash"
# that will be a non-login interactive shell). Furthermore, when a shell is
# executed from code-server, it uses a kind of special script to reproduce
# the same default behavior (difference between login and non-login shells)
# but I don't know how much we can rely on that.
#
# It looks like the best course of action would be to run everything in
# ~/.bashrc, and invoke ~/.bashrc from ~/.bash_profile (or even make them
# identical with a symlink). We can revise that strategy later if needed.

###############################################################################
# First, if we don't have a kubeconfig file, let's create one.
# (This is necessary for kube_ps1 to operate correctly.)
if ! [ -f ~/.kube/config ]; then
  # If there is a ConfigMap named 'kubeconfig',
  # extract the kubeconfig file from there.
  # We need to access the Kubernetes API, so we'll do it
  # using the well-known endpoint.
  (
    # Make sure that the file will have locked-down permissions.
    # (Some tools like Helm will complain about it otherwise.)
    umask 077
    export KUBERNETES_SERVICE_HOST=kubernetes.default.svc
    export KUBERNETES_SERVICE_PORT=443
    if kubectl get configmap kubeconfig >&/dev/null; then
      echo "✏️ Downloading ConfigMap kubeconfig to .kube/config."
      kubectl get configmap kubeconfig -o json |
        jq -r '.data | to_entries | .[0].value' > ~/.kube/config
    else
      SADIR=/var/run/secrets/kubernetes.io/serviceaccount
      # If we have a ServiceAccount token, use it.
      if [ -r $SADIR/token ]; then
        echo "✏️ Generating .kube/config using ServiceAccount token."
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
  )
fi
# Note that we could also just set the following variables:
#export KUBERNETES_SERVICE_HOST=kubernetes.default.svc
#export KUBERNETES_SERVICE_PORT=443
# ...But for some reason, that doesn't work with impersonation.
# (i.e. using "kubectl get pods --as=someone.else")

###############################################################################
# Now, let's try some xterm magic to figure out if we have a light or dark
# background, and automatically set the kubecolor theme accordingly.
if [ ! "$KUBECOLOR_PRESET" ] && [ ! -f ~/.kube/color.yaml ]; then
  KUBECOLOR_PRESET=$(
    success=false
    exec < /dev/tty
    oldstty=$(stty -g)
    stty raw -echo min 0
    col=11      # background
    #          OSC   Ps  ;Pt ST
    echo -en "\033]${col};?\033\\" >/dev/tty  # echo opts differ w/ OSes
    result=
    if IFS=';' read -r -d '\' color ; then
        result=$(echo $color | sed 's/^.*\;//;s/[^rgb:0-9a-f/]//g')
        success=true
    fi
    stty $oldstty
    if $success; then
      lumaformula=$(echo $result | sed 's/rgb:\(.*\)\/\(.*\)\/\(.*\)/(2*0x\1+1*0x\2+3*0x\3)\/6\/653/')
      luma=$((lumaformula))
      if [ "$luma" -lt 25 ]; then
        echo dark
      elif [ "$luma" -gt 75 ]; then
        echo light
      else
        echo unsure
      fi
    fi
  )
  case "$KUBECOLOR_PRESET" in
  dark|light)
    echo "🎨 Automatically setting KUBECOLOR_PRESET=$KUBECOLOR_PRESET."
    export KUBECOLOR_PRESET
    ;;
  *)
    echo "🎨 Failed to detect terminal background color. KUBECOLOR_PRESET not set."
    unset KUBECOLOR_PRESET
    ;;
  esac
fi

###############################################################################
# Finally, set up prompt, PATH, completion, history... The classics :)
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

alias k=kubecolor
complete -F __start_kubectl k
. /usr/share/bash-completion/completions/kubectl.bash

export HISTSIZE=9999
export HISTFILESIZE=9999
shopt -s histappend
trap 'history -a' DEBUG
export HISTFILE=~/.history

trap exit TERM
