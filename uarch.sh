#!/bin/sh
case "$1" in
amd64) echo x86_64;;
arm64) echo aarch64;;
*) echo unknown;;
esac
