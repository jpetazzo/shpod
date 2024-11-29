#!/bin/sh
mkdir -p build
cp shpod.sh shpod.yaml build

cd build
helm package ../helm/shpod
helm repo index .

