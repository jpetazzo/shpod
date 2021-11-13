FROM golang:alpine AS builder
RUN apk add curl git
ENV CGO_ENABLED=0 \
    COMPOSE_VERSION=2.0.1 \
    HELM_VERSION=3.7.0 \
    KUBECTL_VERSION=1.22.2 \
    KUBELINTER_VERSION=0.2.5 \
    KUBESEAL_VERSION=0.16.0 \
    REGCLIENT_VERSION=0.3.9 \
    SHIP_VERSION=0.51.3

FROM builder AS compose
RUN curl -fsSL \
    https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-x86_64 \
    > /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/docker-compose

FROM builder AS helm
RUN curl -fsSL \
    https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz \
    | tar zx -C /usr/local/bin --strip-components=1 linux-amd64/helm

# This is embarrassing, but I can't get httping to compile correctly with musl.
# It reports negative times. So, I found this random binary here. Shrug.
# FIXME: I found the cause of the issue. It's fixed in Bret's branch. Backport the fix eventually.
FROM builder AS httping
RUN curl -fsSL \
    https://github.com/static-linux/static-binaries-i386/raw/4266c69990ae11315bad7b928f85b6c8e605ef14/httping-2.4.tar.gz \
    | tar zx -C /usr/local/bin --strip-components=1 httping-2.4/httping

FROM builder AS jid
RUN go install github.com/simeji/jid/cmd/jid@v0.7.6

FROM builder AS k9s
RUN curl -fsSL \
    https://github.com/derailed/k9s/releases/latest/download/k9s_$(uname -s)_$(uname -m).tar.gz \
    | tar -zxvf- -C /usr/local/bin k9s

FROM builder AS kompose
RUN curl -fsSL \
    https://github.com/kubernetes/kompose/releases/latest/download/kompose-linux-amd64 \
    >  /usr/local/bin/kompose \
    && chmod +x /usr/local/bin/kompose

FROM builder AS kubectl
RUN curl -fsSL \
    https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
    > /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

FROM builder AS kube-linter
RUN go install golang.stackrox.io/kube-linter/cmd/kube-linter@$KUBELINTER_VERSION

FROM builder AS kubeseal
RUN curl -fsSL \
    https://github.com/bitnami-labs/sealed-secrets/releases/download/v$KUBESEAL_VERSION/kubeseal-linux-amd64 \
    > /usr/local/bin/kubeseal \
    && chmod +x /usr/local/bin/kubeseal

FROM builder AS popeye
RUN curl -fsSL \
    https://github.com/derailed/popeye/releases/latest/download/popeye_$(uname -s)_$(uname -m).tar.gz \
    | tar -zxvf- -C /usr/local/bin popeye

FROM builder AS regctl
RUN curl -fsSL \
    https://github.com/regclient/regclient/releases/download/v$REGCLIENT_VERSION/regctl-linux-amd64 \
    > /usr/local/bin/regctl \
    && chmod +x /usr/local/bin/regctl

FROM builder AS ship
RUN curl -fsSL \
    https://github.com/replicatedhq/ship/releases/download/v${SHIP_VERSION}/ship_${SHIP_VERSION}_linux_amd64.tar.gz \
    | tar zx -C /usr/local/bin ship

FROM builder AS skaffold
RUN curl -fsSL \
    https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64 \
    > /usr/local/bin/skaffold \
    && chmod +x /usr/local/bin/skaffold

FROM alpine
ENV COMPLETIONS=/usr/share/bash-completion/completions
RUN apk add apache2-utils bash bash-completion curl file git jq libintl ncurses openssh openssl sudo tmux tree vim

COPY --from=compose /usr/local/bin/docker-compose /usr/local/bin
COPY --from=helm /usr/local/bin/helm /usr/local/bin
COPY --from=httping /usr/local/bin/httping /usr/local/bin
COPY --from=jid /go/bin/jid /usr/local/bin
COPY --from=kubectl /usr/local/bin/kubectl /usr/local/bin
COPY --from=kube-linter /go/bin/kube-linter /usr/local/bin
COPY --from=kubeseal /usr/local/bin/kubeseal /usr/local/bin
COPY --from=k8s.gcr.io/kustomize/kustomize:v4.4.0 /app/kustomize /usr/local/bin
COPY --from=ghcr.io/stern/stern:latest /usr/local/bin/stern /usr/local/bin
COPY --from=popeye /usr/local/bin/popeye /usr/local/bin
COPY --from=regctl /usr/local/bin/regctl /usr/local/bin
COPY --from=ship /usr/local/bin/ship /usr/local/bin
COPY --from=skaffold /usr/local/bin/skaffold /usr/local/bin
COPY --from=tiltdev/tilt /usr/local/bin/tilt /usr/local/bin

RUN set -e ; for BIN in \
    helm \
    kubectl \
    kube-linter \
    kustomize \
    regctl \
    skaffold \
    tilt \
    ; do echo $BIN ; $BIN completion bash > $COMPLETIONS/$BIN.bash ; done

RUN cd /tmp \
 && git clone https://github.com/ahmetb/kubectx \
 && cd kubectx \
 && mv kubectx /usr/local/bin/kctx \
 && mv kubens /usr/local/bin/kns \
 && mv completion/kubectx.bash $COMPLETIONS/kctx.bash \
 && mv completion/kubens.bash $COMPLETIONS/kns.bash \
 && cd .. \
 && rm -rf kubectx
RUN cd /tmp \
 && git clone https://github.com/jonmosco/kube-ps1 \
 && cp kube-ps1/kube-ps1.sh /etc/profile.d/ \
 && rm -rf kube-ps1

# Create user and finalize setup.

RUN echo k8s:x:1000: >> /etc/group \
 && echo k8s:x:1000:1000::/home/k8s:/bin/bash >> /etc/passwd \
 && echo "k8s ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/k8s \
 && mkdir /home/k8s \
 && chown -R k8s:k8s /home/k8s/
RUN mkdir /tmp/krew \
 && cd /tmp/krew \
 && curl -fsSL https://github.com/kubernetes-sigs/krew/releases/latest/download/krew-linux_amd64.tar.gz | tar -zxf- \
 && sudo -u k8s -H ./krew-linux_amd64 install krew \
 && cd \
 && rm -rf /tmp/krew
COPY --chown=1000:1000 bash_profile /home/k8s/.bash_profile
COPY --chown=1000:1000 vimrc /home/k8s/.vimrc
COPY motd /etc/motd
COPY setup-tailhist.sh /usr/local/bin

# If there is a tty, give us a shell.
# (This happens e.g. when we do "docker run -ti jpetazzo/shpod".)
# Otherwise, start an SSH server.
# (This happens e.g. when we use that image in a Pod in a Deployment.)
CMD \
  if tty >/dev/null; then \
    exec login -f k8s && \
    : ; \
  else \
    ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N "" && \
    echo k8s:${PASSWORD-k8s} | chpasswd && \
    exec /usr/sbin/sshd -D -e && \
    : ; \
  fi

EXPOSE 22/tcp
