FROM golang:alpine AS jid
RUN apk add git
RUN go get -u github.com/simeji/jid/cmd/jid
FROM alpine
ENV \
 COMPOSE_VERSION=1.29.2 \
 HELM_VERSION=3.7.0 \
 KUBECTL_VERSION=1.22.2 \
 SHIP_VERSION=0.51.3
## Alpine base ##
ENV COMPLETIONS=/usr/share/bash-completion/completions
RUN apk add bash bash-completion curl git jq libintl ncurses openssl tmux vim apache2-utils
RUN sed -i s,/bin/ash,/bin/bash, /etc/passwd
## Ubuntu base ##
#ENV COMPLETIONS=/etc/bash_completion.d
#RUN apt-get update \
# && apt-get install -y curl git jq vim apache2-utils
## Install a bunch of binaries
RUN curl -fsSL -o /usr/local/bin/docker-compose https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-Linux-x86_64 \
 && chmod +x /usr/local/bin/docker-compose
RUN curl -fsSL -o /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
 && chmod +x /usr/local/bin/kubectl
RUN kubectl completion bash > $COMPLETIONS/kubectl.bash
COPY --from=ghcr.io/stern/stern:latest /usr/local/bin/stern /usr/local/bin/stern
RUN stern --completion bash > $COMPLETIONS/stern.bash
RUN curl -fsSL https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz \
  | tar zx -C /usr/local/bin --strip-components=1 linux-amd64/helm
RUN helm completion bash > $COMPLETIONS/helm.bash
RUN curl -fsSL https://github.com/replicatedhq/ship/releases/download/v${SHIP_VERSION}/ship_${SHIP_VERSION}_linux_amd64.tar.gz \
  | tar zx -C /usr/local/bin ship
# This is embarrassing, but I can't get httping to compile correctly with musl.
# It reports negative times. So, I found this random binary here. Shrug.
RUN curl -fsSL https://github.com/static-linux/static-binaries-i386/raw/4266c69990ae11315bad7b928f85b6c8e605ef14/httping-2.4.tar.gz \
  | tar zx -C /usr/local/bin --strip-components=1 httping-2.4/httping
RUN cd /tmp \
 && git clone https://github.com/ahmetb/kubectx \
 && cd kubectx \
 && mv kubectx /usr/local/bin/kctx \
 && mv kubens /usr/local/bin/kns \
 && mv completion/*.bash $COMPLETIONS \
 && cd .. \
 && rm -rf kubectx
RUN cd /tmp \
 && git clone https://github.com/jonmosco/kube-ps1 \
 && cp kube-ps1/kube-ps1.sh /etc/profile.d/ \
 && rm -rf kube-ps1
RUN mkdir /tmp/krew \
 && cd /tmp/krew \
 && curl -fsSL https://github.com/kubernetes-sigs/krew/releases/latest/download/krew.tar.gz | tar -zxf- \
 && ./krew-linux_amd64 install krew \
 && cd \
 && rm -rf /tmp/krew \
 && echo 'export PATH=$HOME/.krew/bin:$PATH' >> /etc/profile
RUN curl -fsSL https://github.com/derailed/k9s/releases/latest/download/k9s_$(uname -s)_$(uname -m).tar.gz \
  | tar -zxvf- -C /usr/local/bin k9s
RUN curl -fsSL https://github.com/derailed/popeye/releases/latest/download/popeye_$(uname -s)_$(uname -m).tar.gz \
  | tar -zxvf- -C /usr/local/bin popeye
COPY --from=tiltdev/tilt /usr/local/bin/tilt /usr/local/bin/tilt
RUN curl -fsSLo /usr/local/bin/skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64 \
 && chmod +x /usr/local/bin/skaffold
RUN curl -fsSLo /usr/local/bin/kompose https://github.com/kubernetes/kompose/releases/latest/download/kompose-linux-amd64 \
 && chmod +x /usr/local/bin/kompose
RUN curl -fsSLo /usr/local/bin/kubeseal https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.13.1/kubeseal-linux-amd64 \
 && chmod +x /usr/local/bin/kubeseal
RUN kubectl config set-context kubernetes --namespace=default \
 && kubectl config use-context kubernetes
COPY --from=jid /go/bin/jid /usr/local/bin/jid
WORKDIR /root
RUN echo trap exit TERM > /etc/profile.d/trapterm.sh
RUN sed -i "s/export PS1=/#export PS1=/" /etc/profile
RUN echo 'alias k=kubectl' >> $HOME/.bash_completion \
 && echo 'complete -F __start_kubectl k' >> $HOME/.bash_completion \
 && echo '. $COMPLETIONS/kubectl.bash' >> $HOME/.bash_completion
ENV \
 EDITOR="vim" \
 HOSTIP="0.0.0.0" \
 KUBE_PS1_PREFIX="" \
 KUBE_PS1_SUFFIX="" \
 KUBE_PS1_SYMBOL_ENABLE="false" \
 KUBE_PS1_CTX_COLOR="green" \
 KUBE_PS1_NS_COLOR="green" \
 PS1="\e[1m\e[31m[\$HOSTIP] \e[32m(\$(kube_ps1)) \e[34m\u@\h\e[35m \w\e[0m\n$ "
ENTRYPOINT ["bash", "-l"]

