# https://github.com/docker/compose/releases
ARG COMPOSE_VERSION=2.17.2
# https://github.com/fluxcd/flux2/releases
ARG FLUX_VERSION=2.3.0
# https://github.com/helm/helm/releases
ARG HELM_VERSION=3.15.4
# https://github.com/simeji/jid/releases
ARG JID_VERSION=0.7.6
# https://github.com/carvel-dev/kapp/releases
ARG KAPP_VERSION=0.63.2
# https://github.com/kubecolor/kubecolor/releases
ARG KUBECOLOR_VERSION=0.3.3
# https://github.com/kubernetes/kubernetes/releases
ARG KUBECTL_VERSION=1.31.0
# https://github.com/stackrox/kube-linter/releases
ARG KUBELINTER_VERSION=v0.6.8
# https://github.com/doitintl/kube-no-trouble/releases
ARG KUBENT_VERSION=0.7.3
# https://github.com/bitnami-labs/sealed-secrets/releases
ARG KUBESEAL_VERSION=0.27.1
# https://github.com/kubernetes-sigs/kustomize/releases
ARG KUSTOMIZE_VERSION=5.4.3
# https://github.com/regclient/regclient/releases
ARG REGCLIENT_VERSION=0.7.1
# https://github.com/replicatedhq/ship/releases
ARG SHIP_VERSION=0.55.0
# https://github.com/stern/stern/releases
ARG STERN_VERSION=1.30.0
# https://github.com/tilt-dev/tilt/releases
ARG TILT_VERSION=0.33.19
# https://github.com/vmware-tanzu/velero/releases
ARG VELERO_VERSION=1.14.1
# https://github.com/carvel-dev/ytt/releases
ARG YTT_VERSION=0.50.0

FROM --platform=$BUILDPLATFORM golang:alpine AS builder
RUN apk add curl git
ARG BUILDARCH TARGETARCH
ENV BUILDARCH=$BUILDARCH \
    CGO_ENABLED=0 \
    GOARCH=$TARGETARCH \
    TARGETARCH=$TARGETARCH
COPY helper-* /bin/

# https://github.com/argoproj/argo-cd/releases/latest
FROM builder AS argocd
RUN helper-curl bin argocd \
    https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-@GOARCH

# https://github.com/docker/compose/releases
FROM builder AS compose
ARG COMPOSE_VERSION
RUN helper-curl bin docker-compose \
    https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-@UARCH

# https://github.com/google/go-containerregistry/tree/main/cmd/crane
FROM builder AS crane
RUN go install github.com/google/go-containerregistry/cmd/crane@latest
RUN cp $(find bin -name crane) /usr/local/bin

# https://github.com/fluxcd/flux2/releases
FROM builder AS flux
ARG FLUX_VERSION
RUN helper-curl tar flux \
    https://github.com/fluxcd/flux2/releases/download/v$FLUX_VERSION/flux_${FLUX_VERSION}_linux_@GOARCH.tar.gz

# https://github.com/helm/helm/releases
FROM builder AS helm
ARG HELM_VERSION
RUN helper-curl tar "--strip-components=1 linux-@GOARCH/helm" \
    https://get.helm.sh/helm-v${HELM_VERSION}-linux-@GOARCH.tar.gz

# Use emulation instead of cross-compilation for that one.
# (The source is small enough, so I don't know if cross-compilation
# would be worth the effort.)
FROM alpine AS httping
RUN apk add build-base cmake gettext git musl-libintl ncurses-dev
RUN git clone https://github.com/folkertvanheusden/httping
WORKDIR httping
RUN sed -i s/60/0/ utils.c
RUN cmake .
RUN make install BINDIR=/usr/local/bin

# https://github.com/simeji/jid/releases
FROM builder AS jid
ARG JID_VERSION
RUN go install github.com/simeji/jid/cmd/jid@v$JID_VERSION
RUN cp $(find bin -name jid) /usr/local/bin

# https://github.com/derailed/k9s/releases
FROM builder AS k9s
RUN helper-curl tar k9s \
    https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_@GOARCH.tar.gz

# https://github.com/kubernetes/kompose/releases
FROM builder AS kompose
RUN helper-curl bin kompose \
    https://github.com/kubernetes/kompose/releases/latest/download/kompose-linux-@GOARCH

# https://github.com/kubecolor/kubecolor/releases
FROM builder AS kubecolor
ARG KUBECOLOR_VERSION
RUN helper-curl tar kubecolor \
    https://github.com/kubecolor/kubecolor/releases/download/v${KUBECOLOR_VERSION}/kubecolor_${KUBECOLOR_VERSION}_linux_@GOARCH.tar.gz

# https://github.com/kubernetes/kubernetes/releases
FROM builder AS kubectl
ARG KUBECTL_VERSION
RUN helper-curl bin kubectl \
    https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/@GOARCH/kubectl 

# https://github.com/stackrox/kube-linter/releases
FROM builder AS kube-linter
ARG KUBELINTER_VERSION
RUN go install golang.stackrox.io/kube-linter/cmd/kube-linter@$KUBELINTER_VERSION
RUN cp $(find bin -name kube-linter) /usr/local/bin

# https://github.com/doitintl/kube-no-trouble/releases
FROM builder AS kubent
ARG KUBENT_VERSION
RUN helper-curl tar kubent \
    https://github.com/doitintl/kube-no-trouble/releases/download/${KUBENT_VERSION}/kubent-${KUBENT_VERSION}-linux-@GOARCH.tar.gz

# https://github.com/bitnami-labs/sealed-secrets/releases
FROM builder AS kubeseal
ARG KUBESEAL_VERSION
RUN helper-curl tar kubeseal \
    https://github.com/bitnami-labs/sealed-secrets/releases/download/v$KUBESEAL_VERSION/kubeseal-$KUBESEAL_VERSION-linux-@GOARCH.tar.gz

# https://github.com/kubernetes-sigs/kustomize/releases
FROM builder AS kustomize
ARG KUSTOMIZE_VERSION
RUN helper-curl tar kustomize \
    https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v$KUSTOMIZE_VERSION/kustomize_v${KUSTOMIZE_VERSION}_linux_@GOARCH.tar.gz

# https://ngrok.com/download
FROM builder AS ngrok
RUN helper-curl tar ngrok \
    https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-@GOARCH.tgz

# https://github.com/derailed/popeye/releases
FROM builder AS popeye
RUN helper-curl tar popeye \
    https://github.com/derailed/popeye/releases/latest/download/popeye_Linux_@WTFARCH.tar.gz

# https://github.com/regclient/regclient/releases
FROM builder AS regctl
ARG REGCLIENT_VERSION
RUN helper-curl bin regctl \
    https://github.com/regclient/regclient/releases/download/v$REGCLIENT_VERSION/regctl-linux-@GOARCH

# This tool is still used in the kustomize section, but we will probably
# deprecate it eventually as we only use a tiny feature that doesn't seem
# to be available anymore in more recent versions (or requires some work
# to adapt). Also, it's not available on all platforms and doesn't compile.
FROM builder AS ship
ARG SHIP_VERSION
RUN helper-curl tar ship \
    https://github.com/replicatedhq/ship/releases/download/v${SHIP_VERSION}/ship_${SHIP_VERSION}_linux_@GOARCH.tar.gz

# https://github.com/GoogleContainerTools/skaffold/releases
FROM builder AS skaffold
RUN helper-curl bin skaffold \
    https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-@GOARCH

# https://github.com/stern/stern/releases
FROM builder AS stern
ARG STERN_VERSION
RUN helper-curl tar stern \
    https://github.com/stern/stern/releases/download/v${STERN_VERSION}/stern_${STERN_VERSION}_linux_@GOARCH.tar.gz

# https://github.com/tilt-dev/tilt/releases
FROM builder AS tilt
ARG TILT_VERSION
RUN helper-curl tar tilt \
    https://github.com/tilt-dev/tilt/releases/download/v${TILT_VERSION}/tilt.${TILT_VERSION}.linux-alpine.@WTFARCH.tar.gz

# https://github.com/vmware-tanzu/velero/releases
FROM builder AS velero
ARG VELERO_VERSION
RUN helper-curl tar "--strip-components=1 velero-v${VELERO_VERSION}-linux-@GOARCH/velero" \
    https://github.com/vmware-tanzu/velero/releases/download/v${VELERO_VERSION}/velero-v${VELERO_VERSION}-linux-@GOARCH.tar.gz

# https://github.com/carvel-dev/ytt/releases
FROM builder AS ytt
ARG YTT_VERSION
RUN helper-curl bin ytt \
    https://github.com/carvel-dev/ytt/releases/download/v${YTT_VERSION}/ytt-linux-@GOARCH

# https://github.com/carvel-dev/kapp/releases
FROM builder AS kapp
ARG KAPP_VERSION
RUN helper-curl bin kapp \
    https://github.com/carvel-dev/kapp/releases/download/v${KAPP_VERSION}/kapp-linux-@GOARCH

FROM alpine AS shpod
ENV COMPLETIONS=/usr/share/bash-completion/completions
RUN apk add --no-cache apache2-utils bash bash-completion curl docker-cli file gettext git iputils jq libintl ncurses openssh openssl screen sudo tmux tree vim yq

COPY --from=argocd      /usr/local/bin/argocd         /usr/local/bin
COPY --from=compose     /usr/local/bin/docker-compose /usr/local/bin
COPY --from=crane       /usr/local/bin/crane          /usr/local/bin
COPY --from=flux        /usr/local/bin/flux           /usr/local/bin
COPY --from=helm        /usr/local/bin/helm           /usr/local/bin
COPY --from=httping     /usr/local/bin/httping        /usr/local/bin
COPY --from=jid         /usr/local/bin/jid            /usr/local/bin
COPY --from=k9s         /usr/local/bin/k9s            /usr/local/bin
COPY --from=kapp        /usr/local/bin/kapp           /usr/local/bin
COPY --from=kubectl     /usr/local/bin/kubectl        /usr/local/bin
COPY --from=kubecolor   /usr/local/bin/kubecolor      /usr/local/bin
COPY --from=kube-linter /usr/local/bin/kube-linter    /usr/local/bin
COPY --from=kubent      /usr/local/bin/kubent         /usr/local/bin
COPY --from=kubeseal    /usr/local/bin/kubeseal       /usr/local/bin
COPY --from=kustomize   /usr/local/bin/kustomize      /usr/local/bin
COPY --from=ngrok       /usr/local/bin/ngrok          /usr/local/bin
COPY --from=popeye      /usr/local/bin/popeye         /usr/local/bin
COPY --from=regctl      /usr/local/bin/regctl         /usr/local/bin
COPY --from=ship        /usr/local/bin/ship           /usr/local/bin
COPY --from=skaffold    /usr/local/bin/skaffold       /usr/local/bin
COPY --from=stern       /usr/local/bin/stern          /usr/local/bin
COPY --from=tilt        /usr/local/bin/tilt           /usr/local/bin
COPY --from=velero      /usr/local/bin/velero         /usr/local/bin
COPY --from=ytt         /usr/local/bin/ytt            /usr/local/bin

RUN set -e ; for BIN in \
    argocd \
    crane \
    flux \
    helm \
    kapp \
    kubectl \
    kube-linter \
    kustomize \
    regctl \
    skaffold \
    tilt \
    velero \
    ytt \
    ; do echo $BIN ; $BIN completion bash > $COMPLETIONS/$BIN.bash ; done ;\
    stern --completion bash > $COMPLETIONS/stern

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
 && chown -R k8s:k8s /home/k8s/ \
 && sed -i 's/#MaxAuthTries 6/MaxAuthTries 42/' /etc/ssh/sshd_config
ARG TARGETARCH
RUN \
 if [ "$TARGETARCH" != "386" ]; then \
 mkdir /tmp/krew \
 && cd /tmp/krew \
 && curl -fsSL https://github.com/kubernetes-sigs/krew/releases/latest/download/krew-linux_$TARGETARCH.tar.gz | tar -zxf- \
 && sudo -u k8s -H ./krew-linux_$TARGETARCH install krew \
 && cd \
 && rm -rf /tmp/krew \
 ; fi
COPY --chown=1000:1000 bash_profile /home/k8s/.bash_profile
COPY --chown=1000:1000 vimrc /home/k8s/.vimrc
COPY --chown=1000:1000 tmux.conf /home/k8s/.tmux.conf
COPY motd /etc/motd
COPY setup-tailhist.sh /usr/local/bin

# Generate a list of all installed versions.
RUN ( \
    ab -V | head -n1 ;\
    argocd version --client | head -n1 ;\
    bash --version | head -n1 ;\
    curl --version | head -n1 ;\
    docker version --format="Docker {{.Client.Version}}" ;\
    envsubst --version | head -n1 ;\
    flux --version ;\
    git --version ;\
    jq --version ;\
    ssh -V ;\
    tmux -V ;\
    yq --version ;\
    docker-compose version ;\
    echo "crane $(crane version)" ;\
    echo "Helm $(helm version --short)" ;\
    httping --version ;\
    jid --version ;\
    echo "k9s $(k9s version | grep Version)" ;\
    kapp --version | head -n1 ;\
    echo "kubecolor $(kubecolor --kubecolor-version)" ;\
    echo "kubectl $(kubectl version --short --client)" ;\
    echo "kube-linter $(kube-linter version)" ;\
    echo "kubent $(kubent --version 2>&1)" ;\
    kubeseal --version ;\
    kustomize version --short ;\
    ngrok version ;\
    echo "popeye $(popeye version | grep Version)" ;\
    echo "regctl $(regctl version --format={{.VCSTag}})" ;\
    echo "ship $(ship version | jq .version)" ;\
    echo "skaffold $(skaffold version)" ;\
    echo "stern $(stern --version | grep ^version)" ;\
    echo "tilt $(tilt version)" ;\
    echo "velero $(velero version --client-only | grep Version)" ;\
    ) > versions.txt

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
