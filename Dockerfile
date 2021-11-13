FROM --platform=$BUILDPLATFORM golang:alpine AS builder
RUN apk add curl git
ARG BUILDARCH TARGETARCH
ENV BUILDARCH=$BUILDARCH \
    CGO_ENABLED=0 \
    COMPOSE_VERSION=2.1.1 \
    GOARCH=$TARGETARCH \
    HELM_VERSION=3.7.1 \
    JID_VERSION=0.7.6 \
    KUBECTL_VERSION=1.22.2 \
    KUBELINTER_VERSION=0.2.5 \
    KUBESEAL_VERSION=0.16.0 \
    KUSTOMIZE_VERSION=4.4.1 \
    REGCLIENT_VERSION=0.3.9 \
    SHIP_VERSION=0.51.3 \
    STERN_VERSION=1.20.1 \
    TARGETARCH=$TARGETARCH \
    TILT_VERSION=0.23.0
COPY helper-* /bin

FROM builder AS compose
RUN helper-curl bin docker-compose \
    https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-@UARCH

FROM builder AS helm
RUN helper-curl tar "--strip-components=1 linux-@GOARCH/helm" \
    https://get.helm.sh/helm-v${HELM_VERSION}-linux-@GOARCH.tar.gz

FROM alpine AS httping
RUN apk add build-base gettext git musl-libintl
RUN git clone https://salsa.debian.org/debian/httping
WORKDIR httping
RUN sed -i s/60/0/ utils.c
RUN make install BINDIR=/usr/local/bin

FROM builder AS jid
RUN go install github.com/simeji/jid/cmd/jid@v$JID_VERSION
RUN cp $(find bin -name jid) /usr/local/bin

FROM builder AS k9s
RUN helper-curl tar k9s \
    https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_@WTFARCH.tar.gz

FROM builder AS kompose
RUN helper-curl bin kompose \
    https://github.com/kubernetes/kompose/releases/latest/download/kompose-linux-@GOARCH

FROM builder AS kubectl
RUN helper-curl bin kubectl \
    https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/@GOARCH/kubectl 

FROM builder AS kube-linter
RUN go install golang.stackrox.io/kube-linter/cmd/kube-linter@$KUBELINTER_VERSION
RUN cp $(find bin -name kube-linter) /usr/local/bin

FROM builder AS kubeseal
RUN helper-curl bin kubeseal \
    https://github.com/bitnami-labs/sealed-secrets/releases/download/v$KUBESEAL_VERSION/kubeseal-@KSARCH

FROM builder AS kustomize
RUN helper-curl tar kustomize \
    https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v$KUSTOMIZE_VERSION/kustomize_v${KUSTOMIZE_VERSION}_linux_@GOARCH.tar.gz

FROM builder AS popeye
RUN helper-curl tar popeye \
    https://github.com/derailed/popeye/releases/latest/download/popeye_Linux_@WTFARCH.tar.gz

FROM builder AS regctl
RUN helper-curl bin regctl \
    https://github.com/regclient/regclient/releases/download/v$REGCLIENT_VERSION/regctl-linux-@GOARCH

FROM builder AS ship
RUN helper-curl tar ship \
    https://github.com/replicatedhq/ship/releases/download/v${SHIP_VERSION}/ship_${SHIP_VERSION}_linux_@GOARCH.tar.gz

FROM builder AS skaffold
RUN helper-curl bin skaffold \
    https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-@GOARCH

FROM builder AS stern
RUN helper-curl tar "--strip-components=1 stern_${STERN_VERSION}_linux_@GOARCH/stern" \
    https://github.com/stern/stern/releases/download/v${STERN_VERSION}/stern_${STERN_VERSION}_linux_@GOARCH.tar.gz

FROM builder AS tilt
RUN helper-curl tar tilt \
    https://github.com/tilt-dev/tilt/releases/download/v${TILT_VERSION}/tilt.${TILT_VERSION}.linux.@WTFARCH.tar.gz

FROM alpine
ENV COMPLETIONS=/usr/share/bash-completion/completions
RUN apk add apache2-utils bash bash-completion curl docker-cli file git jq libintl ncurses openssh openssl sudo tmux tree vim

COPY --from=compose     /usr/local/bin/docker-compose /usr/local/bin
COPY --from=helm        /usr/local/bin/helm           /usr/local/bin
COPY --from=httping     /usr/local/bin/httping        /usr/local/bin
COPY --from=jid         /usr/local/bin/jid            /usr/local/bin
COPY --from=kubectl     /usr/local/bin/kubectl        /usr/local/bin
COPY --from=kube-linter /usr/local/bin/kube-linter    /usr/local/bin
COPY --from=kubeseal    /usr/local/bin/kubeseal       /usr/local/bin
COPY --from=kustomize   /usr/local/bin/kustomize      /usr/local/bin
COPY --from=popeye      /usr/local/bin/popeye         /usr/local/bin
COPY --from=regctl      /usr/local/bin/regctl         /usr/local/bin
COPY --from=ship        /usr/local/bin/ship           /usr/local/bin
COPY --from=skaffold    /usr/local/bin/skaffold       /usr/local/bin
COPY --from=stern       /usr/local/bin/stern          /usr/local/bin
COPY --from=tilt        /usr/local/bin/tilt           /usr/local/bin

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
