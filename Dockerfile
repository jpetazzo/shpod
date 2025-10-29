FROM --platform=$BUILDPLATFORM golang:alpine AS builder
RUN apk add curl git make
ARG BUILDARCH TARGETARCH
ENV BUILDARCH=$BUILDARCH \
    CGO_ENABLED=0 \
    GOARCH=$TARGETARCH \
    TARGETARCH=$TARGETARCH
COPY helper-* /bin/

FROM alpine AS addmount
RUN apk add build-base
COPY addmount.c .
RUN make addmount

# https://github.com/argoproj/argo-cd/releases/latest
FROM builder AS argocd
RUN helper-curl bin argocd \
    https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-@GOARCH

# https://github.com/warpstreamlabs/bento/releases
FROM builder AS bento
ARG BENTO_VERSION=1.3.0
RUN helper-curl tar bento \
    https://github.com/warpstreamlabs/bento/releases/download/v${BENTO_VERSION}/bento_${BENTO_VERSION}_linux_@GOARCH.tar.gz

# https://github.com/coder/code-server/releases
FROM builder AS code-server
ARG CODE_SERVER_VERSION=4.105.1
RUN mkdir -p /code-server
RUN helper-curl tar "--directory=/code-server --strip-components=1" \
    https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server-${CODE_SERVER_VERSION}-linux-@CODERARCH.tar.gz

# https://github.com/docker/compose/releases
FROM builder AS compose
ARG COMPOSE_VERSION=2.40.1
RUN helper-curl bin docker-compose \
    https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-@UARCH

# https://github.com/google/go-containerregistry/tree/main/cmd/crane
FROM builder AS crane
RUN go install github.com/google/go-containerregistry/cmd/crane@latest
RUN cp $(find bin -name crane) /usr/local/bin

# https://github.com/fluxcd/flux2/releases
FROM builder AS flux
ARG FLUX_VERSION=2.7.2
RUN helper-curl tar flux \
    https://github.com/fluxcd/flux2/releases/download/v$FLUX_VERSION/flux_${FLUX_VERSION}_linux_@GOARCH.tar.gz

# https://github.com/tomnomnom/gron/releases
FROM builder AS gron
ARG GRON_VERSION=v0.7.1
RUN go install "-ldflags=-X main.gronVersion=$GRON_VERSION" github.com/tomnomnom/gron@$GRON_VERSION
RUN cp $(find bin -name gron) /usr/local/bin

# https://github.com/helmfile/helmfile/releases
FROM builder AS helmfile
ARG HELMFILE_VERSION=1.1.7
RUN helper-curl tar helmfile \
    https://github.com/helmfile/helmfile/releases/download/v${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION}_linux_@GOARCH.tar.gz

# https://github.com/helm/helm/releases
FROM builder AS helm
ARG HELM_VERSION=3.19.0
RUN helper-curl tar "--strip-components=1 linux-@GOARCH/helm" \
    https://get.helm.sh/helm-v${HELM_VERSION}-linux-@GOARCH.tar.gz

# Use emulation instead of cross-compilation for that one.
# (The source is small enough, so I don't know if cross-compilation
# would be worth the effort.)
FROM alpine AS httping
RUN apk add build-base cmake gettext git musl-libintl ncurses-dev openssl-dev
RUN git clone https://github.com/folkertvanheusden/httping
WORKDIR httping
RUN sed -i s/60/0/ utils.c
#RUN echo "target_link_options(httping PUBLIC -static)" >> CMakeLists.txt
RUN cmake .
RUN make install BINDIR=/usr/local/bin

# https://github.com/simeji/jid/releases
FROM builder AS jid
ARG JID_VERSION=0.7.6
RUN go install github.com/simeji/jid/cmd/jid@v$JID_VERSION
RUN cp $(find bin -name jid) /usr/local/bin

# https://github.com/derailed/k9s/releases
FROM builder AS k9s
RUN helper-curl tar k9s \
    https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_@GOARCH.tar.gz

# https://github.com/kubernetes-sigs/kind/releases
FROM builder AS kind
ARG KIND_VERSION=v0.30.0
RUN helper-curl bin kind \
    https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-@GOARCH

# https://github.com/kubernetes/kompose/releases
FROM builder AS kompose
RUN helper-curl bin kompose \
    https://github.com/kubernetes/kompose/releases/latest/download/kompose-linux-@GOARCH

# https://github.com/kubecolor/kubecolor/releases
FROM builder AS kubecolor
ARG KUBECOLOR_VERSION=0.5.2
RUN helper-curl tar kubecolor \
    https://github.com/kubecolor/kubecolor/releases/download/v${KUBECOLOR_VERSION}/kubecolor_${KUBECOLOR_VERSION}_linux_@GOARCH.tar.gz

# https://github.com/kubernetes/kubernetes/releases
FROM builder AS kubectl
ARG KUBECTL_VERSION=1.34.1
RUN helper-curl tar "--strip-components=3 kubernetes/client/bin/kubectl" \
    https://dl.k8s.io/v${KUBECTL_VERSION}/kubernetes-client-linux-@GOARCH.tar.gz

# https://github.com/stackrox/kube-linter/releases
FROM builder AS kube-linter
ARG KUBELINTER_VERSION=v0.7.6
RUN go install golang.stackrox.io/kube-linter/cmd/kube-linter@$KUBELINTER_VERSION
RUN cp $(find bin -name kube-linter) /usr/local/bin

# https://github.com/doitintl/kube-no-trouble/releases
FROM builder AS kubent
ARG KUBENT_VERSION=0.7.2
RUN helper-curl tar kubent \
    https://github.com/doitintl/kube-no-trouble/releases/download/${KUBENT_VERSION}/kubent-${KUBENT_VERSION}-linux-@GOARCH.tar.gz

# https://github.com/bitnami-labs/sealed-secrets/releases
FROM builder AS kubeseal
ARG KUBESEAL_VERSION=0.32.2
RUN helper-curl tar kubeseal \
    https://github.com/bitnami-labs/sealed-secrets/releases/download/v$KUBESEAL_VERSION/kubeseal-$KUBESEAL_VERSION-linux-@GOARCH.tar.gz

# https://github.com/kubernetes-sigs/kustomize/releases
FROM builder AS kustomize
ARG KUSTOMIZE_VERSION=5.7.1
RUN helper-curl tar kustomize \
    https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v$KUSTOMIZE_VERSION/kustomize_v${KUSTOMIZE_VERSION}_linux_@GOARCH.tar.gz

# https://github.com/kubernetes/minikube/releases
FROM builder AS minikube
ARG MINIKUBE_VERSION=v1.37.0
RUN git clone https://github.com/kubernetes/minikube --depth=1 --branch $MINIKUBE_VERSION
WORKDIR minikube
RUN make
RUN cp out/minikube /usr/local/bin/minikube

# https://ngrok.com/download
FROM builder AS ngrok
RUN helper-curl tar ngrok \
    https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-@GOARCH.tgz

# https://github.com/derailed/popeye/releases
FROM builder AS popeye
RUN helper-curl tar popeye \
    https://github.com/derailed/popeye/releases/latest/download/popeye_linux_@GOARCH.tar.gz

# https://github.com/regclient/regclient/releases
FROM builder AS regctl
ARG REGCLIENT_VERSION=0.9.2
RUN helper-curl bin regctl \
    https://github.com/regclient/regclient/releases/download/v$REGCLIENT_VERSION/regctl-linux-@GOARCH

# https://github.com/GoogleContainerTools/skaffold/releases
FROM builder AS skaffold
RUN helper-curl bin skaffold \
    https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-@GOARCH

# https://github.com/stern/stern/releases
FROM builder AS stern
ARG STERN_VERSION=1.33.0
RUN helper-curl tar stern \
    https://github.com/stern/stern/releases/download/v${STERN_VERSION}/stern_${STERN_VERSION}_linux_@GOARCH.tar.gz

# https://github.com/tilt-dev/tilt/releases
FROM builder AS tilt
ARG TILT_VERSION=0.35.2
RUN helper-curl tar tilt \
    https://github.com/tilt-dev/tilt/releases/download/v${TILT_VERSION}/tilt.${TILT_VERSION}.linux-alpine.@WTFARCH.tar.gz

# https://github.com/vmware-tanzu/velero/releases
FROM builder AS velero
ARG VELERO_VERSION=1.17.0
RUN helper-curl tar "--strip-components=1 velero-v${VELERO_VERSION}-linux-@GOARCH/velero" \
    https://github.com/vmware-tanzu/velero/releases/download/v${VELERO_VERSION}/velero-v${VELERO_VERSION}-linux-@GOARCH.tar.gz

# https://github.com/carvel-dev/ytt/releases
FROM builder AS ytt
ARG YTT_VERSION=0.52.1
RUN helper-curl bin ytt \
    https://github.com/carvel-dev/ytt/releases/download/v${YTT_VERSION}/ytt-linux-@GOARCH

# https://github.com/carvel-dev/kapp/releases
FROM builder AS kapp
ARG YTT_VERSION=0.64.2
RUN helper-curl bin kapp \
    https://github.com/carvel-dev/kapp/releases/download/v${YTT_VERSION}/kapp-linux-@GOARCH

FROM alpine AS shpod
ENV COMPLETIONS=/usr/share/bash-completion/completions
RUN apk add --no-cache apache2-utils bash bash-completion curl docker-cli docker-cli-compose docker-cli-buildx docker-engine file fzf gettext git iptables-legacy iputils jq libintl ncurses openssh openssl screen socat sudo tmux tree unzip vim yq

COPY --from=addmount    /addmount                     /usr/local/bin
COPY --from=argocd      /usr/local/bin/argocd         /usr/local/bin
COPY --from=bento       /usr/local/bin/bento          /usr/local/bin
COPY --from=compose     /usr/local/bin/docker-compose /usr/local/bin
COPY --from=crane       /usr/local/bin/crane          /usr/local/bin
COPY --from=flux        /usr/local/bin/flux           /usr/local/bin
COPY --from=gron        /usr/local/bin/gron           /usr/local/bin
COPY --from=helm        /usr/local/bin/helm           /usr/local/bin
COPY --from=helmfile    /usr/local/bin/helmfile       /usr/local/bin
COPY --from=httping     /usr/local/bin/httping        /usr/local/bin
COPY --from=jid         /usr/local/bin/jid            /usr/local/bin
COPY --from=k9s         /usr/local/bin/k9s            /usr/local/bin
COPY --from=kind        /usr/local/bin/kind           /usr/local/bin
COPY --from=kapp        /usr/local/bin/kapp           /usr/local/bin
COPY --from=kubectl     /usr/local/bin/kubectl        /usr/local/bin
COPY --from=kubecolor   /usr/local/bin/kubecolor      /usr/local/bin
COPY --from=kube-linter /usr/local/bin/kube-linter    /usr/local/bin
COPY --from=kubent      /usr/local/bin/kubent         /usr/local/bin
COPY --from=kubeseal    /usr/local/bin/kubeseal       /usr/local/bin
COPY --from=kustomize   /usr/local/bin/kustomize      /usr/local/bin
COPY --from=minikube    /usr/local/bin/minikube       /usr/local/bin
COPY --from=ngrok       /usr/local/bin/ngrok          /usr/local/bin
COPY --from=popeye      /usr/local/bin/popeye         /usr/local/bin
COPY --from=regctl      /usr/local/bin/regctl         /usr/local/bin
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
    helmfile \
    kapp \
    kind \
    kubectl \
    kube-linter \
    kustomize \
    minikube \
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
 && cp kube-ps1/kube-ps1.sh /etc/bash/ \
 && rm -rf kube-ps1

# Create user and finalize setup.

RUN echo k8s:x:1000: >> /etc/group \
 && echo k8s:x:1000:1000::/home/k8s:/bin/bash >> /etc/passwd \
 && sed -i 's/^docker:.*:$/\0k8s/' /etc/group \
 && echo "k8s ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/k8s \
 && mkdir /home/k8s \
 && chown -R k8s:k8s /home/k8s/ \
 && sed -i 's/#MaxAuthTries 6/MaxAuthTries 42/' /etc/ssh/sshd_config \
 && sed -i 's/AllowTcpForwarding no/AllowTcpForwarding yes/' /etc/ssh/sshd_config
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
COPY --chown=1000:1000 bashrc /home/k8s/.bashrc
COPY --chown=1000:1000 bash_profile /home/k8s/.bash_profile
COPY --chown=1000:1000 vimrc /home/k8s/.vimrc
COPY --chown=1000:1000 tmux.conf /home/k8s/.tmux.conf
COPY motd /etc/motd
COPY setup-tailhist.sh /usr/local/bin
COPY docker-socket.sh /usr/local/bin
COPY dind.sh /usr/local/bin
COPY kind.sh /usr/local/bin
COPY bore.sh /usr/local/bin
VOLUME /var/lib/docker

# Generate a list of all installed versions.
RUN ( \
    ab -V | head -n1 ;\
    argocd version --client | head -n1 ;\
    echo "bento $(bento --version | head -n1)" ;\
    bash --version | head -n1 ;\
    curl --version | head -n1 ;\
    docker version --format="Docker {{.Client.Version}}" ;\
    envsubst --version | head -n1 ;\
    flux --version ;\
    gron --version ;\
    git --version ;\
    jq --version ;\
    ssh -V ;\
    tmux -V ;\
    yq --version ;\
    docker-compose version ;\
    echo "crane $(crane version)" ;\
    echo "Helm $(helm version --short)" ;\
    echo "Helmfile $(helmfile version -o=short | head -n1)" ;\
    httping --version ;\
    jid --version ;\
    echo "k9s $(k9s version | grep Version)" ;\
    kind version ;\
    kapp --version | head -n1 ;\
    echo "kubecolor $(kubecolor --kubecolor-version)" ;\
    echo "kubectl $(kubectl version --client | head -n1)" ;\
    echo "kube-linter $(kube-linter version)" ;\
    echo "kubent $(kubent --version 2>&1)" ;\
    kubeseal --version ;\
    echo "kustomize $(kustomize version | head -n1)" ;\
    minikube version | head -n1 ;\
    ngrok version ;\
    echo "popeye $(popeye version | grep Version)" ;\
    echo "regctl $(regctl version --format={{.VCSTag}})" ;\
    echo "skaffold $(skaffold version)" ;\
    echo "stern $(stern --version | grep ^version)" ;\
    echo "tilt $(tilt version)" ;\
    echo "velero $(velero version --client-only | grep Version)" ;\
    ) > versions.txt

COPY init.sh /
CMD ["/init.sh"]
EXPOSE 22/tcp
ENV GENERATE_PASSWORD_LENGTH=20

FROM node:20-slim AS nodejslibs
WORKDIR /output
RUN for LINKER in /lib64/ld-linux-x86-64.so.2 /lib/ld-linux-aarch64.so.1 /lib/ld-linux-armhf.so.3; do \
      if [ -f "$LINKER" ]; then \
        install -D "$LINKER" "./$LINKER" ;\
      fi ;\
    done
RUN mkdir -p lib
RUN for LIBDIR in x86_64-linux-gnu aarch64-linux-gnu arm-linux-gnueabihf; do \
      if [ -d "/lib/$LIBDIR" ]; then \
        cp -a "/lib/$LIBDIR" lib ;\
      fi ;\
    done

# Define an extra build target with "code-server" (VScode in the browser) installed
FROM shpod AS vspod
COPY --from=nodejslibs /output /
COPY --from=code-server /code-server /opt/code-server
RUN ln -s /opt/code-server/bin/code-server /usr/local/bin
RUN sudo -u k8s -H code-server --install-extension ms-azuretools.vscode-docker
RUN sudo -u k8s -H code-server --install-extension ms-kubernetes-tools.vscode-kubernetes-tools
CMD sudo -u k8s -H -E code-server --bind-addr 0:1789
EXPOSE 1789

# Define the default build target
FROM shpod
