FROM golang:alpine AS jid
RUN apk add git
RUN go get -u github.com/simeji/jid/cmd/jid

FROM alpine
ENV \
 COMPOSE_VERSION=2.0.1 \
 HELM_VERSION=3.7.0 \
 KUBECTL_VERSION=1.22.2 \
 SHIP_VERSION=0.51.3
ENV COMPLETIONS=/usr/share/bash-completion/completions
RUN apk add apache2-utils bash bash-completion curl file git jq libintl ncurses openssh openssl sudo tmux tree vim

# Install a bunch of binaries, scripts, tools, etc.

RUN curl -fsSL -o /usr/local/bin/docker-compose https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-x86_64 \
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
# FIXME: I found the cause of the issue. It's fixed in Bret's branch. Backport the fix eventually.
RUN curl -fsSL https://github.com/static-linux/static-binaries-i386/raw/4266c69990ae11315bad7b928f85b6c8e605ef14/httping-2.4.tar.gz \
  | tar zx -C /usr/local/bin --strip-components=1 httping-2.4/httping
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
RUN curl -fsSL https://github.com/derailed/k9s/releases/latest/download/k9s_$(uname -s)_$(uname -m).tar.gz \
  | tar -zxvf- -C /usr/local/bin k9s
RUN curl -fsSL https://github.com/derailed/popeye/releases/latest/download/popeye_$(uname -s)_$(uname -m).tar.gz \
  | tar -zxvf- -C /usr/local/bin popeye
COPY --from=k8s.gcr.io/kustomize/kustomize:v4.4.0 /app/kustomize /usr/local/bin/kustomize
RUN kustomize completion bash > $COMPLETIONS/kustomize.bash
COPY --from=tiltdev/tilt /usr/local/bin/tilt /usr/local/bin/tilt
RUN tilt completion bash > $COMPLETIONS/tilt.bash
RUN curl -fsSLo /usr/local/bin/skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64 \
 && chmod +x /usr/local/bin/skaffold
RUN skaffold completion bash > $COMPLETIONS/skaffold.bash
RUN curl -fsSLo /usr/local/bin/kompose https://github.com/kubernetes/kompose/releases/latest/download/kompose-linux-amd64 \
 && chmod +x /usr/local/bin/kompose
RUN kompose completion bash > $COMPLETIONS/kompose.bash
RUN curl -fsSLo /usr/local/bin/kubeseal https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.16.0/kubeseal-linux-amd64 \
 && chmod +x /usr/local/bin/kubeseal
RUN set -e; \
    for BIN in regbot regctl regsync; do \
      curl -fsSLo /usr/local/bin/$BIN https://github.com/regclient/regclient/releases/download/v0.3.9/$BIN-linux-amd64 ;\
      chmod +x /usr/local/bin/$BIN ;\
      $BIN completion bash > $COMPLETIONS/$BIN.bash ;\
    done
COPY --from=jid /go/bin/jid /usr/local/bin/jid
RUN echo trap exit TERM > /etc/profile.d/trapterm.sh

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
