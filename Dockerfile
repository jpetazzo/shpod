FROM golang:alpine AS jid
RUN apk add git
# build jid for later
RUN go get -u github.com/simeji/jid/cmd/jid

# main image with all the tools
FROM alpine
ARG TARGETPLATFORM
ARG BUILDPLATFORM
RUN echo "I am running on $BUILDPLATFORM, building for $TARGETPLATFORM" > /log
ENV \
 COMPOSE_VERSION=1.29.1 \
 # https://github.com/docker/compose/releases
 HELM_VERSION=3.5.4 \
 # https://github.com/helm/helm/releases
 KUBECTL_VERSION=1.21.0 \
 # https://dl.k8s.io/release/stable.txt
 KUBECTX_VERSION=0.9.3 \
 # https://github.com/ahmetb/kubectx/releases
 STERN_VERSION=1.15.0
 # https://github.com/stern/stern/releases
ENV COMPLETIONS=/usr/share/bash-completion/completions
RUN apk add bash bash-completion curl git jq libintl ncurses openssl tmux vim apache2-utils

# docker-compose
# FIXME: sadly only x64 builds are prebuilt
#        arm versions are usable with pip, but this image doesn't have Python (for size mostly)
#        the future is "compose-cli" so the TODO here is to just add that instead
# TODO: add compose-cli
RUN echo compose; \
    if [[ ${TARGETPLATFORM} == "linux/amd64" ]] ; then \
      (curl -sSLo /usr/local/bin/docker-compose https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-Linux-x86_64 \
      && chmod +x /usr/local/bin/docker-compose) \
    fi

# TODO: add docker cli

# kubectl https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
RUN echo kubectl; \
    case ${TARGETPLATFORM} in \
         "linux/amd64")  ARCH=amd64  ;; \
         "linux/arm64")  ARCH=arm64  ;; \
         "linux/arm/v7") ARCH=arm  ;; \
    esac \
    && curl -sSLo /usr/local/bin/kubectl https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl \
    && chmod +x /usr/local/bin/kubectl
RUN kubectl completion bash > $COMPLETIONS/kubectl.bash
RUN kubectl config set-context kubernetes --namespace=default \
    && kubectl config use-context kubernetes

# stern https://github.com/stern/stern
RUN echo stern; case ${TARGETPLATFORM} in \
         "linux/amd64")  ARCH=amd64  ;; \
         "linux/arm64")  ARCH=arm64  ;; \
         "linux/arm/v7") ARCH=arm  ;; \
    esac \
    && curl -sSL https://github.com/stern/stern/releases/download/v${STERN_VERSION}/stern_${STERN_VERSION}_linux_${ARCH}.tar.gz \
    | tar -zxo -C /usr/local/bin/ --strip-components=1 stern_${STERN_VERSION}_linux_${ARCH}/stern
RUN stern --completion bash > $COMPLETIONS/stern.bash

# helm https://github.com/helm/helm
RUN echo helm; case ${TARGETPLATFORM} in \
         "linux/amd64")  ARCH=amd64  ;; \
         "linux/arm64")  ARCH=arm64  ;; \
         "linux/arm/v7") ARCH=arm  ;; \
    esac \
    && curl -sSL https://get.helm.sh/helm-v${HELM_VERSION}-linux-${ARCH}.tar.gz \
    | tar zxo -C /usr/local/bin --strip-components=1 linux-${ARCH}/helm
RUN helm completion bash > $COMPLETIONS/helm.bash

# httping https://github.com/BretFisher/httping-docker
COPY --from=bretfisher/httping /usr/local/bin/httping /usr/local/bin/httping

# kubectx and kubens https://github.com/ahmetb/kubectx
RUN echo kubectx; case ${TARGETPLATFORM} in \
         "linux/amd64")  ARCH=x86_64  ;; \
         "linux/arm64")  ARCH=arm64  ;; \
         "linux/arm/v7") ARCH=armhf  ;; \
    esac \
    && curl -sSL https://github.com/ahmetb/kubectx/releases/download/v${KUBECTX_VERSION}/kubectx_v${KUBECTX_VERSION}_linux_${ARCH}.tar.gz \
    | tar -zxo -C /usr/local/bin/ kubectx \
    && curl -sSL https://github.com/ahmetb/kubectx/releases/download/v${KUBECTX_VERSION}/kubens_v${KUBECTX_VERSION}_linux_${ARCH}.tar.gz \
    | tar -zxo -C /usr/local/bin/ kubens \
    && curl -sSLo ${COMPLETIONS}/kubectx.bash https://github.com/ahmetb/kubectx/releases/download/v${KUBECTX_VERSION}/kubectx \
    && curl -sSLo ${COMPLETIONS}/kubens.bash https://github.com/ahmetb/kubectx/releases/download/v${KUBECTX_VERSION}/kubens

# kube-ps1 https://github.com/jonmosco/kube-ps1
RUN echo kube-ps1; curl -sSLo /etc/profile.d/kube-ps1.sh https://raw.githubusercontent.com/jonmosco/kube-ps1/master/kube-ps1.sh

# krew https://github.com/kubernetes-sigs/krew
RUN echo krew; case ${TARGETPLATFORM} in \
         "linux/amd64")  ARCH=amd64  ;; \
         "linux/arm64")  ARCH=arm64  ;; \
         "linux/arm/v7") ARCH=arm  ;; \
    esac \
    && mkdir /tmp/krew \
    && cd /tmp/krew \
    && curl -sSL https://github.com/kubernetes-sigs/krew/releases/latest/download/krew.tar.gz \
    | tar -zxf- \
    && ./krew-linux_${ARCH} install krew \
    && cd \
    && rm -rf /tmp/krew \
    && echo export 'PATH=$HOME/.krew/bin:$PATH' >> .bashrc

# TODO: add ship (no arm support). 
# It's superseded by Kots:
# TODO: add https://github.com/replicatedhq/kots

# k9s https://github.com/derailed/k9s
RUN echo k9s; case ${TARGETPLATFORM} in \
         "linux/amd64")  ARCH=x86_64  ;; \
         "linux/arm64")  ARCH=arm64  ;; \
         "linux/arm/v7") ARCH=arm  ;; \
    esac \
    && curl -sSL https://github.com/derailed/k9s/releases/latest/download/k9s_v0.24.10_Linux_${ARCH}.tar.gz \
    | tar -zxo -C /usr/local/bin/ k9s

# popeye https://github.com/derailed/popeye 
RUN echo popeye; case ${TARGETPLATFORM} in \
         "linux/amd64")  ARCH=x86_64  ;; \
         "linux/arm64")  ARCH=arm64  ;; \
         "linux/arm/v7") ARCH=arm  ;; \
    esac \
    && curl -sSL https://github.com/derailed/popeye/releases/latest/download/popeye_Linux_${ARCH}.tar.gz \
    | tar -zxo -C /usr/local/bin popeye

# tilt https://github.com/tilt-dev/tilt
RUN echo tilt; case ${TARGETPLATFORM} in \
         "linux/amd64")  ARCH=x86_64  ;; \
         "linux/arm64")  ARCH=arm64_ALPHA  ;; \
         "linux/arm/v7") ARCH=arm_ALPHA  ;; \
    esac \
    && curl -sSL https://github.com/tilt-dev/tilt/releases/download/v0.19.0/tilt.0.19.0.linux.${ARCH}.tar.gz \
    | tar -zxo -C /usr/local/bin tilt

# skaffold https://skaffold.dev 
# FIXME: wait for arm/v7 support and update
        #  "linux/arm/v7") ARCH=arm  ;; \
        # https://github.com/GoogleContainerTools/skaffold/issues/5610
RUN echo skaffold; case ${TARGETPLATFORM} in \
         "linux/amd64")  ARCH=amd64  ;; \
         "linux/arm64")  ARCH=arm64  ;; \
    esac \ 
    && if [[ ${ARCH} != "arm" ]] ; \
    then \
      curl -sSLo /usr/local/bin/skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-${ARCH} \
      && chmod +x /usr/local/bin/skaffold ; \
    fi

# kompose https://github.com/kubernetes/kompose
RUN echo kompose; case ${TARGETPLATFORM} in \
         "linux/amd64")  ARCH=amd64  ;; \
         "linux/arm64")  ARCH=arm64  ;; \
         "linux/arm/v7") ARCH=arm  ;; \
    esac \
    && curl -sSLo /usr/local/bin/kompose https://github.com/kubernetes/kompose/releases/latest/download/kompose-linux-${ARCH} \
    && chmod +x /usr/local/bin/kompose

#kubeseal https://github.com/bitnami-labs/sealed-secrets
RUN echo kubeseal; case ${TARGETPLATFORM} in \
         "linux/amd64")  ARCH=linux-amd64  ;; \
         "linux/arm64")  ARCH=arm64  ;; \
         "linux/arm/v7") ARCH=arm  ;; \
    esac \ 
    && curl -sSLo /usr/local/bin/kubeseal https://github.com/bitnami-labs/sealed-secrets/releases/download/latest/kubeseal-${ARCH} \
    && chmod +x /usr/local/bin/kubeseal

# jid https://github.com/simeji/jid
COPY --from=jid /go/bin/jid /usr/local/bin/jid

# final shell environment prep
WORKDIR /root
RUN echo trap exit TERM > /etc/profile.d/trapterm.sh
RUN sed -i "s/export PS1=/#export PS1=/" /etc/profile
RUN sed -i s,/bin/ash,/bin/bash, /etc/passwd
ENV \
 HOSTIP="0.0.0.0" \
 TERM="xterm-256color" \
 KUBE_PS1_PREFIX="" \
 KUBE_PS1_SUFFIX="" \
 KUBE_PS1_SYMBOL_ENABLE="false" \
 KUBE_PS1_CTX_COLOR="green" \
 KUBE_PS1_NS_COLOR="green" \
 PS1="\e[1m\e[31m[\$HOSTIP] \e[32m(\$(kube_ps1)) \e[34m\u@\h\e[35m \w\e[0m\n$ "
CMD ["bash", "-l"]
