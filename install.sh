#!/bin/bash

#############################
# Alpine Linux Installation #
#############################

# Define the root directory to /home/container.
# We can only write in /home/container and /tmp in the container.

mkdir alpine 
cd alpine
ROOTFS_DIR="$(dirname "$(readlink -f "${0}")")"


# Define the Alpine Linux version we are going to be using.
ALPINE_VERSION="3.20"
ALPINE_FULL_VERSION="3.20.3"
APK_TOOLS_VERSION="2.14.4-r1" # Make sure to update this too when updating Alpine Linux.
PROOT_VERSION="5.3.0" # Some releases do not have static builds attached.

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

# Download & decompress the Alpine linux root file system if not already installed.
if [ ! -e $ROOTFS_DIR/.installed ]; then
    # Download Alpine Linux root file system.
    curl -Lo /tmp/rootfs.tar.gz \
    "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/${ARCH}/alpine-minirootfs-${ALPINE_FULL_VERSION}-${ARCH}.tar.gz"
    # Extract the Alpine Linux root file system.
    tar -xzf /tmp/rootfs.tar.gz -C $ROOTFS_DIR
fi

################################
# Package Installation & Setup #
################################

# Download static APK-Tools temporarily because minirootfs does not come with APK pre-installed.
if [ ! -e $ROOTFS_DIR/.installed ]; then
    # Download the packages from their sources.
    curl -Lo /tmp/apk-tools-static.apk "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main/${ARCH}/apk-tools-static-${APK_TOOLS_VERSION}.apk"
    curl -Lo $ROOTFS_DIR/usr/local/bin/proot "https://github.com/proot-me/proot/releases/download/v${PROOT_VERSION}/proot-v${PROOT_VERSION}-${ARCH}-static"
    # Extract everything that needs to be extracted.
    tar -xzf /tmp/apk-tools-static.apk -C /tmp/
    # Install base system packages using the static APK-Tools.
    printf "https://dl-cdn.alpinelinux.org/alpine/v3.20/main\nhttps://dl-cdn.alpinelinux.org/alpine/v3.20/community\nhttps://dl-cdn.alpinelinux.org/alpine/edge/main\nhttps://dl-cdn.alpinelinux.org/alpine/edge/community\nhttps://dl-cdn.alpinelinux.org/alpine/edge/testing" > ${ROOTFS_DIR}/etc/apk/repositories
    /tmp/sbin/apk.static -X "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main/" -U --allow-untrusted --root $ROOTFS_DIR add alpine-base apk-tools alpine-sdk net-tools xz libssl3 icu-data-full ninja-build g++ gcc binutils ca-certificates python3-dev python3 py3-pip go git make cmake build-base sudo nodejs npm sed wget curl nano doas dbus openblas-dev unzip htop bash bash-completion shadow libstdc++-dev openssh-client alpine-sdk libstdc++ yarn ttyd util-linux libc6-compat

    chmod 755 $ROOTFS_DIR/usr/local/bin/proot

    $ROOTFS_DIR/usr/local/bin/proot -S . apk update
    $ROOTFS_DIR/usr/local/bin/proot -S . apk upgrade
    $ROOTFS_DIR/usr/local/bin/proot -S . apk fix
    $ROOTFS_DIR/usr/local/bin/proot -S . addgroup alpine
    $ROOTFS_DIR/usr/local/bin/proot -S . adduser -h /home/alpine -s /bin/bash -S -D alpine
    $ROOTFS_DIR/usr/local/bin/proot -S . echo 'alpine:AliAly032230' | chpasswd
    $ROOTFS_DIR/usr/local/bin/proot -S . echo 'alpine ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
    $ROOTFS_DIR/usr/local/bin/proot -S . echo "permit nopass :wheel as root" >> /etc/doas.d/doas.conf

fi

# Clean-up after installation complete & finish up.
if [ ! -e $ROOTFS_DIR/.installed ]; then
    # Add DNS Resolver nameservers to resolv.conf.
    printf "nameserver 1.1.1.1\nnameserver 1.0.0.1" > ${ROOTFS_DIR}/etc/resolv.conf
    # Wipe the files we downloaded into /tmp previously.
    rm -rf /tmp/apk-tools-static.apk /tmp/rootfs.tar.gz /tmp/sbin
    # Create .installed to later check whether Alpine is installed.
    touch $ROOTFS_DIR/.installed
fi

# Print some useful information to the terminal before entering PRoot.
# This is to introduce the user with the various Alpine Linux commands.
clear && cat << EOF
             				                        
               █████╗ ██╗    ██████╗████╗██   ███   
              ██╔══██╗██║    ██╔══██╗██╔╝██╔═████╗  
              ███████║██║    ██████╔╝██║ ██║██ ██║  
              ██╔══██║██╚═══╗██╔═══╝ ██╚╗████║ ██║  
              ██║  ██║██████║██║    ████║███║║ ██║  
              ╚═╝  ╚═╝╚═════╝╚═╝     ╚══╝ ╚═╝╝═══╝  
 
 Welcome to Alpine Linux minirootfs!
 This is a lightweight and security-oriented Linux distribution that is perfect for running high-performance applications.
 
 Here are some useful commands to get you started:
 
    apk add [package] : install a package
    apk del [package] : remove a package
    apk update : update the package index
    apk upgrade : upgrade installed packages
    apk search [keyword] : search for a package
    apk info [package] : show information about a package
    ttyd -p [server-port] -w /home/alpine -W ash : share your terminal
 
EOF

###########################
# Start PRoot environment #
###########################

# This command starts PRoot and binds several important directories
# from the host file system to our special root file system.
$ROOTFS_DIR/usr/local/bin/proot \
--rootfs="${ROOTFS_DIR}" \
--link2symlink \
--kill-on-exit \
--root-id \
--cwd=/home/alpine \
--bind=/proc \
--bind=/dev \
--bind=/sys \
--bind=/tmp \
/bin/ash
