#!/bin/bash

ROOTFS_DIR="$(dirname "$(readlink -f "${0}")")"

VSCODE_VERSION="4.92.2"
# Detect the machine architecture.
ARCH=$(uname -m)

# Check machine architecture to make sure it is supported.
# If not, we exit with a non-zero status code.
if [ "$ARCH" = "x86_64" ]; then
  ARCH_ALT=amd64
elif [ "$ARCH" = "aarch64" ]; then
  ARCH_ALT=arm64
else
  printf "Unsupported CPU architecture: ${ARCH}"
  exit 1
fi

if which curl > /dev/null 2>&1; then
    ## CURL ##
    curl -LO https://github.com/coder/code-server/releases/download/v${VSCODE_VERSION}/code-server-${VSCODE_VERSION}-linux-${ARCH_ALT}.tar.gz
else
    ## WGET ##
    wget https://github.com/coder/code-server/releases/download/v${VSCODE_VERSION}/code-server-${VSCODE_VERSION}-linux-${ARCH_ALT}.tar.gz
fi

tar -xf *.tar.gz
rm -rf *.tar.gz

mv code-server-${VSCODE_VERSION}-linux-${ARCH_ALT} VSCODE
sed -n '2'p $ROOTFS_DIR/server.properties >> VSCODE.sh
sed -i 's\server-port=\./VSCODE/bin/code-server --bind-addr 0.0.0.0:\ ' $ROOTFS_DIR/VSCODE.sh

chmod +x VSCODE.sh
./VSCODE.sh
