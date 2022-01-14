#!/bin/sh
set -ex
mkdir /tmp/tailhist
cd /tmp/tailhist
WEBSOCKETD_VERSION=0.4.1
wget https://github.com/joewalnes/websocketd/releases/download/v$WEBSOCKETD_VERSION/websocketd-$WEBSOCKETD_VERSION-linux_amd64.zip
unzip websocketd-$WEBSOCKETD_VERSION-linux_amd64.zip
curl https://raw.githubusercontent.com/jpetazzo/container.training/main/prepare-vms/lib/tailhist.html > index.html
kubectl patch service shpod --namespace shpod -p "
spec:
  ports:
  - name: tailhist
    port: 1088
    targetPort: 1088
    nodePort: 30088
    protocol: TCP
"
./websocketd --port=1088 --staticdir=. sh -c "
  tail -n +1 -f $HOME/.history ||
  echo 'Could not read history file. Perhaps you need to \"chmod +r .history\"?'
  "  
