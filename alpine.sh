#!/bin/sh

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

# Detect the machine architecture.
ARCH=$(uname -m)

# Check machine architecture to make sure it is supported.
# If not, we exit with a non-zero status code.
if [ "$ARCH" = "x86_64" ]; then
  ARCH_ALT=amd64
elif [ "$ARCH" = "aarch64" ]; then
  ARCH_ALT=arm64
elif [ "$ARCH" = "aarch" ]; then
  ARCH_ALT=arm
elif [ "$ARCH" = "i386" ]; then
  ARCH_ALT=x86
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
    tar -xzf /tmp/apk-tools-static.apk -C /tmp/
    printf "https://dl-cdn.alpinelinux.org/alpine/v3.20/main\nhttps://dl-cdn.alpinelinux.org/alpine/v3.20/community\nhttps://dl-cdn.alpinelinux.org/alpine/edge/main\nhttps://dl-cdn.alpinelinux.org/alpine/edge/community\nhttps://dl-cdn.alpinelinux.org/alpine/edge/testing" > ${ROOTFS_DIR}/etc/apk/repositories
    /tmp/sbin/apk.static -X "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main/" -U --allow-untrusted --root $ROOTFS_DIR add proot-static
    "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/ash -c "apk add -U neofetch pulseaudio vlc nano xz unzip wget doas shadow libreoffice libreoffice-writer git code-oss sudo xvfb dbus dbus-x11 x11vnc novnc openjdk21 nodejs npm sed ca-certificates python3 py3-pip go git firefox chromium bash bash-completion curl alpine-base iproute2 alpine-sdk net-tools qbittorrent tor htop openssh torsocks proxychains-ng meek-server meek supervisor && apk update && apk upgrade && apk fix"
    
    "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / mv /etc/tor/torrc.sample /etc/tor/torrc
    "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / sed -i 's\#SOCKSPort 9050\SOCKSPort auto\ ' /etc/tor/torrc
    "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / sed -i 's\#ControlPort 9051\ControlPort auto\ ' /etc/tor/torrc
    "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / sed -i 's\#HashedControlPassword 16:872860B76453A77D60CA2BB8C1A7042072093276A3D701AD684053EC4C\HashedControlPassword 16:3478340120AB6C1C60447B55C1F1D88C91DB1850A3F094E4F64647BDAD\ ' /etc/tor/torrc
    "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / sed -i 's\#CookieAuthentication 1\CookieAuthentication 1\ ' /etc/tor/torrc
    "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / sed -i 's\#HiddenServiceDir /var/lib/tor/hidden_service/\HiddenServiceDir /var/lib/tor/hidden_service/\ ' /etc/tor/torrc
    "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / sed -i '68s\#HiddenServicePort 80 127.0.0.1:80\HiddenServicePort 22 127.0.0.1:22\ ' /etc/tor/torrc
    "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / sed -i '69 i HiddenServicePort 5999 127.0.0.1:5999' /etc/tor/torrc
    "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / sed -i '70 i HiddenServicePort 6081 127.0.0.1:6081' /etc/tor/torrc
    "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / sed -i 's\DataDirectory /var/lib/tor\#DataDirectory /var/lib/tor\ ' /etc/tor/torrc
    "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / sed -i 's\Log notice file /var/log/tor/notices.log\#Log notice file /var/log/tor/notices.log\ ' /etc/tor/torrc
    
    echo -n "Choose desktop environment (1 xfce |2 mate |3 lxqt |4 gnome |5 plasma |6 sway |) enter a number :     "
     read option
     if [ "$option" -eq "1" ]; then
        echo '\n#!/bin/bash\n\necho "add user name: "\nread user\nUSER="$user"\nadduser ${USER}\necho "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers\necho "permit nopass :wheel as root" >> /etc/doas.d/doas.conf\n\nsu - ${USER} -c "mkdir -p /home/${USER}/.vnc"\nsu - ${USER} -c "x11vnc -storepasswd /home/${USER}/.vnc/passwd"\n\nmkdir -p /etc/supervisor/conf.d/\ntouch /etc/supervisor/conf.d/supervisord.conf\ncat >> /etc/supervisor/conf.d/supervisord.conf <<END\n[supervisord]\nnodaemon=true\n\n[program:tor]\npriority=10\ncommand=/bin/bash -c "tor -f /etc/tor/torrc | tee /home/${USER}/tor.log"\nautorestart=false\n\n[program:xvfb]\npriority=20\nuser=${USER}\nenvironment=HOME="/home/${USER}",USER="${USER}"\ncommand=/usr/bin/Xvfb :0 -screen 0 1600x900x24+32\nautorestart=true\n\n[program:x11vnc]\npriority=30\nuser=${USER}\nenvironment=HOME="/home/${USER}",USER="${USER}"\ncommand=x11vnc -cursor arrow -rfbauth /home/${USER}/.vnc/passwd -display :0 -xkb -noxrecord -noxfixes -noxdamage -wait 5 -shared -rfbport 5999\nautorestart=true\n\n[program:xfce4]\npriority=40\nuser=${USER}\nenvironment=DISPLAY=":0",HOME="/home/${USER}",USER="${USER}"\ncommand=/usr/bin/xfce4-session\nautorestart=true\n\n[program:novnc]\npriority=50\nuser=${USER}\nenvironment=HOME="/home/${USER}",USER="${USER}"\ncommand=/usr/bin/novnc_server --vnc localhost:5999 --listen 6081\nautorestart=true\nEND\n\ncat >> supervisord.sh <<END\nsupervisord -c /etc/supervisor/conf.d/supervisord.conf >> /home/${USER}/supervisord.log &\nEND\n\nchmod +x supervisord.sh\n\ncat >> tor.sh <<END\n#!/bin/bash\n\nif ! [ -f /home/${USER}/tor.log ] | grep -w "Bootstrapped 100% (done): Done"\n   then cat /var/lib/tor/hidden_service/hostname\n   else echo "NOT FOUND"\nfi\nEND\nchmod +x tor.sh' >> config.sh
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/bash -c 'chmod +x config.sh && ./config.sh'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / setup-xorg-base
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / apk add xfce4 lightdm lightdm-gtk-greeter polkit
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/ash -c 'apk add $(apk search xfce4-* -q)'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/ash -c 'apk add $(apk search gvfs-* -q )'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/ash -c 'apk add $(apk search ttf-* -q)'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / rc-update add lightdm
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / apk fix
       elif [ "$option" -eq "2" ]; then
        echo '\n#!/bin/bash\n\necho "add user name: "\nread user\nUSER="$user"\nadduser ${USER}\necho "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers\necho "permit nopass :wheel as root" >> /etc/doas.d/doas.conf\n\nsu - ${USER} -c "mkdir -p /home/${USER}/.vnc"\nsu - ${USER} -c "x11vnc -storepasswd /home/${USER}/.vnc/passwd"\n\nmkdir -p /etc/supervisor/conf.d/\ntouch /etc/supervisor/conf.d/supervisord.conf\ncat >> /etc/supervisor/conf.d/supervisord.conf <<END\n[supervisord]\nnodaemon=true\n\n[program:tor]\npriority=10\ncommand=/bin/bash -c "tor -f /etc/tor/torrc | tee /home/${USER}/tor.log"\nautorestart=false\n\n[program:xvfb]\npriority=20\nuser=${USER}\nenvironment=HOME="/home/${USER}",USER="${USER}"\ncommand=/usr/bin/Xvfb :0 -screen 0 1600x900x24+32\nautorestart=true\n\n[program:x11vnc]\npriority=30\nuser=${USER}\nenvironment=HOME="/home/${USER}",USER="${USER}"\ncommand=x11vnc -cursor arrow -rfbauth /home/${USER}/.vnc/passwd -display :0 -xkb -noxrecord -noxfixes -noxdamage -wait 5 -shared -rfbport 5999\nautorestart=true\n\n[program:mate]\npriority=40\nuser=${USER}\nenvironment=DISPLAY=":0",HOME="/home/${USER}",USER="${USER}"\ncommand=/usr/bin/mate-session\nautorestart=true\n\n[program:novnc]\npriority=50\nuser=${USER}\nenvironment=HOME="/home/${USER}",USER="${USER}"\ncommand=/usr/bin/novnc_server --vnc localhost:5999 --listen 6081\nautorestart=true\nEND\n\ncat >> supervisord.sh <<END\nsupervisord -c /etc/supervisor/conf.d/supervisord.conf >> /home/${USER}/supervisord.log &\nEND\n\nchmod +x supervisord.sh\n\ncat >> tor.sh <<END\n#!/bin/bash\n\nif ! [ -f /home/${USER}/tor.log ] | grep -w "Bootstrapped 100% (done): Done"\n   then cat /var/lib/tor/hidden_service/hostname\n   else echo "NOT FOUND"\nfi\nEND\nchmod +x tor.sh' >> config.sh
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/bash -c 'chmod +x config.sh && ./config.sh'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / setup-xorg-base
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / apk add mate-desktop-environment lxdm adwaita-icon-theme faenza-icon-theme lightdm lightdm-gtk-greeter polkit font-dejavu
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/ash -c 'apk add $(apk search mate-* -q)'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/ash -c 'apk add $(apk search gvfs-* -q )'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/ash -c 'apk add $(apk search ttf-* -q)'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / rc-update add dbus
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / rc-update add lightdm
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / rc-update add lxdm
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / apk fix
       elif [ "$option" -eq "3" ]; then
        echo '\n#!/bin/bash\n\necho "add user name: "\nread user\nUSER="$user"\nadduser ${USER}\necho "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers\necho "permit nopass :wheel as root" >> /etc/doas.d/doas.conf\n\nsu - ${USER} -c "mkdir -p /home/${USER}/.vnc"\nsu - ${USER} -c "x11vnc -storepasswd /home/${USER}/.vnc/passwd"\n\nmkdir -p /etc/supervisor/conf.d/\ntouch /etc/supervisor/conf.d/supervisord.conf\ncat >> /etc/supervisor/conf.d/supervisord.conf <<END\n[supervisord]\nnodaemon=true\n\n[program:tor]\npriority=10\ncommand=/bin/bash -c "tor -f /etc/tor/torrc | tee /home/${USER}/tor.log"\nautorestart=false\n\n[program:xvfb]\npriority=20\nuser=${USER}\nenvironment=HOME="/home/${USER}",USER="${USER}"\ncommand=/usr/bin/Xvfb :0 -screen 0 1600x900x24+32\nautorestart=true\n\n[program:x11vnc]\npriority=30\nuser=${USER}\nenvironment=HOME="/home/${USER}",USER="${USER}"\ncommand=x11vnc -cursor arrow -rfbauth /home/${USER}/.vnc/passwd -display :0 -xkb -noxrecord -noxfixes -noxdamage -wait 5 -shared -rfbport 5999\nautorestart=true\n\n[program:lxqt]\npriority=40\nuser=${USER}\nenvironment=DISPLAY=":0",HOME="/home/${USER}",USER="${USER}"\ncommand=/usr/bin/lxqt-session\nautorestart=true\n\n[program:novnc]\npriority=50\nuser=${USER}\nenvironment=HOME="/home/${USER}",USER="${USER}"\ncommand=/usr/bin/novnc_server --vnc localhost:5999 --listen 6081\nautorestart=true\nEND\n\ncat >> supervisord.sh <<END\nsupervisord -c /etc/supervisor/conf.d/supervisord.conf >> /home/${USER}/supervisord.log &\nEND\n\nchmod +x supervisord.sh\n\ncat >> tor.sh <<END\n#!/bin/bash\n\nif ! [ -f /home/${USER}/tor.log ] | grep -w "Bootstrapped 100% (done): Done"\n   then cat /var/lib/tor/hidden_service/hostname\n   else echo "NOT FOUND"\nfi\nEND\nchmod +x tor.sh' >> config.sh
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/bash -c 'chmod +x config.sh && ./config.sh'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / setup-xorg-base
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / apk add lxqt-desktop lximage-qt obconf-qt pavucontrol-qt arandr sddm font-dejavu openbox elogind polkit-elogind udisks2 adwaita-qt oxygen
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/ash -c 'apk add $(apk search lxqt-* -q)'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/ash -c 'apk add $(apk search gvfs-* -q )'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/ash -c 'apk add $(apk search ttf-* -q)'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / rc-update add dbus
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / rc-update add sddm
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / rc-update add elogind
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / apk fix
       elif [ "$option" -eq "4" ]; then
        echo '\n#!/bin/bash\n\necho "add user name: "\nread user\nUSER="$user"\nadduser ${USER}\necho "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers\necho "permit nopass :wheel as root" >> /etc/doas.d/doas.conf\n\nsu - ${USER} -c "mkdir -p /home/${USER}/.vnc"\nsu - ${USER} -c "x11vnc -storepasswd /home/${USER}/.vnc/passwd"\n\nmkdir -p /etc/supervisor/conf.d/\ntouch /etc/supervisor/conf.d/supervisord.conf\ncat >> /etc/supervisor/conf.d/supervisord.conf <<END\n[supervisord]\nnodaemon=true\n\n[program:tor]\npriority=10\ncommand=/bin/bash -c "tor -f /etc/tor/torrc | tee /home/${USER}/tor.log"\nautorestart=false\n\n[program:xvfb]\npriority=20\nuser=${USER}\nenvironment=HOME="/home/${USER}",USER="${USER}"\ncommand=/usr/bin/Xvfb :0 -screen 0 1600x900x24+32\nautorestart=true\n\n[program:x11vnc]\npriority=30\nuser=${USER}\nenvironment=HOME="/home/${USER}",USER="${USER}"\ncommand=x11vnc -cursor arrow -rfbauth /home/${USER}/.vnc/passwd -display :0 -xkb -noxrecord -noxfixes -noxdamage -wait 5 -shared -rfbport 5999\nautorestart=true\n\n[program:gnome]\npriority=40\nuser=${USER}\nenvironment=DISPLAY=":0",HOME="/home/${USER}",USER="${USER}"\ncommand=/usr/bin/gnome-session\nautorestart=true\n\n[program:novnc]\npriority=50\nuser=${USER}\nenvironment=HOME="/home/${USER}",USER="${USER}"\ncommand=/usr/bin/novnc_server --vnc localhost:5999 --listen 6081\nautorestart=true\nEND\n\ncat >> supervisord.sh <<END\nsupervisord -c /etc/supervisor/conf.d/supervisord.conf >> /home/${USER}/supervisord.log &\nEND\n\nchmod +x supervisord.sh\n\ncat >> tor.sh <<END\n#!/bin/bash\n\nif ! [ -f /home/${USER}/tor.log ] | grep -w "Bootstrapped 100% (done): Done"\n   then cat /var/lib/tor/hidden_service/hostname\n   else echo "NOT FOUND"\nfi\nEND\nchmod +x tor.sh' >> config.sh
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/bash -c 'chmod +x config.sh && ./config.sh'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / setup-xorg-base
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/ash -c 'apk add $(apk info --quiet --depends gnome gnome-apps-core) gdm'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/ash -c 'apk add  $(apk search gnome-* -q)'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/ash -c 'apk add $(apk search gvfs-* -q )'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/ash -c 'apk add $(apk search ttf-* -q)'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / rc-update add gdm
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / rc-update add elogind
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / apk fix
       elif [ "$option" -eq "5" ]; then
        echo '\n#!/bin/bash\n\necho "add user name: "\nread user\nUSER="$user"\nadduser ${USER}\necho "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers\necho "permit nopass :wheel as root" >> /etc/doas.d/doas.conf\n\nsu - ${USER} -c "mkdir -p /home/${USER}/.vnc"\nsu - ${USER} -c "x11vnc -storepasswd /home/${USER}/.vnc/passwd"\n\nmkdir -p /etc/supervisor/conf.d/\ntouch /etc/supervisor/conf.d/supervisord.conf\ncat >> /etc/supervisor/conf.d/supervisord.conf <<END\n[supervisord]\nnodaemon=true\n\n[program:tor]\npriority=10\ncommand=/bin/bash -c "tor -f /etc/tor/torrc | tee /home/${USER}/tor.log"\nautorestart=false\n\n[program:xvfb]\npriority=20\nuser=${USER}\nenvironment=HOME="/home/${USER}",USER="${USER}"\ncommand=/usr/bin/Xvfb :0 -screen 0 1600x900x24+32\nautorestart=true\n\n[program:x11vnc]\npriority=30\nuser=${USER}\nenvironment=HOME="/home/${USER}",USER="${USER}"\ncommand=x11vnc -cursor arrow -rfbauth /home/${USER}/.vnc/passwd -display :0 -xkb -noxrecord -noxfixes -noxdamage -wait 5 -shared -rfbport 5999\nautorestart=true\n\n[program:plasma]\npriority=40\nuser=${USER}\nenvironment=DISPLAY=":0",HOME="/home/${USER}",USER="${USER}"\ncommand=/usr/bin/plasma_session\nautorestart=true\n\n[program:novnc]\npriority=50\nuser=${USER}\nenvironment=HOME="/home/${USER}",USER="${USER}"\ncommand=/usr/bin/novnc_server --vnc localhost:5999 --listen 6081\nautorestart=true\nEND\n\ncat >> supervisord.sh <<END\nsupervisord -c /etc/supervisor/conf.d/supervisord.conf >> /home/${USER}/supervisord.log &\nEND\n\nchmod +x supervisord.sh\n\ncat >> tor.sh <<END\n#!/bin/bash\n\nif ! [ -f /home/${USER}/tor.log ] | grep -w "Bootstrapped 100% (done): Done"\n   then cat /var/lib/tor/hidden_service/hostname\n   else echo "NOT FOUND"\nfi\nEND\nchmod +x tor.sh' >> config.sh
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/bash -c 'chmod +x config.sh && ./config.sh'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / setup-xorg-base
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / apk add ark bluedevil oxygen-sounds kde-applications-base breeze breeze-gtk dbus discover drkonqi font-noto gwenview kate kde-cli-tools kde-gtk-config kde-icons kdeplasma-addons kgamma kinfocenter kio-fuse kmenuedit konsole kscreen ksshaskpass kwallet-pam kwayland-integration pinentry-qt pipewire-alsa pipewire-pulse plasma-browser-integration plasma-desktop plasma-disks plasma-nm plasma-pa plasma-systemmonitor plasma-vault plasma-welcome plasma-workspace-wallpapers polkit-elogind polkit-kde-agent-1 powerdevil print-manager sddm-breeze sddm-kcm spectacle systemsettings udisks2 xdg-desktop-portal-kde xdg-user-dirs plasma elogind
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/ash -c 'apk add $(apk search plasma-* -q)'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/ash -c 'apk add $(apk search kde-* -q)'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/ash -c 'apk add $(apk search gvfs-* -q )'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/ash -c 'apk add $(apk search ttf-* -q)'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / rc-update add dbus
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / rc-update add sddm
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / apk fix
       elif [ "$option" -eq "6" ]; then
        echo '\n#!/bin/bash\n\necho "add user name: "\nread user\nUSER="$user"\nadduser ${USER}\necho "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers\necho "permit nopass :wheel as root" >> /etc/doas.d/doas.conf\n\nsu - ${USER} -c "mkdir -p /home/${USER}/.vnc"\nsu - ${USER} -c "x11vnc -storepasswd /home/${USER}/.vnc/passwd"\n\nmkdir -p /etc/supervisor/conf.d/\ntouch /etc/supervisor/conf.d/supervisord.conf\ncat >> /etc/supervisor/conf.d/supervisord.conf <<END\n[supervisord]\nnodaemon=true\n\n[program:tor]\npriority=10\ncommand=/bin/bash -c "tor -f /etc/tor/torrc | tee /home/${USER}/tor.log"\nautorestart=false\n\n[program:xvfb]\npriority=20\nuser=${USER}\nenvironment=HOME="/home/${USER}",USER="${USER}"\ncommand=/usr/bin/Xvfb :0 -screen 0 1600x900x24+32\nautorestart=true\n\n[program:x11vnc]\npriority=30\nuser=${USER}\nenvironment=HOME="/home/${USER}",USER="${USER}"\ncommand=x11vnc -cursor arrow -rfbauth /home/${USER}/.vnc/passwd -display :0 -xkb -noxrecord -noxfixes -noxdamage -wait 5 -shared -rfbport 5999\nautorestart=true\n\n[program:sway]\npriority=40\nuser=${USER}\nenvironment=DISPLAY=":0",HOME="/home/${USER}",USER="${USER}"\ncommand=/usr/bin/sway\nautorestart=true\n\n[program:novnc]\npriority=50\nuser=${USER}\nenvironment=HOME="/home/${USER}",USER="${USER}"\ncommand=/usr/bin/novnc_server --vnc localhost:5999 --listen 6081\nautorestart=true\nEND\n\ncat >> supervisord.sh <<END\nsupervisord -c /etc/supervisor/conf.d/supervisord.conf >> /home/${USER}/supervisord.log &\nEND\n\nchmod +x supervisord.sh\n\ncat >> tor.sh <<END\n#!/bin/bash\n\nif ! [ -f /home/${USER}/tor.log ] | grep -w "Bootstrapped 100% (done): Done"\n   then cat /var/lib/tor/hidden_service/hostname\n   else echo "NOT FOUND"\nfi\nEND\nchmod +x tor.sh' >> config.sh
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/bash -c 'chmod +x config.sh && ./config.sh'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / setup-wayland-base
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / apk add font-dejavu foot grim i3status sway swayidle swaylockd util-linux-login wl-clipboard wmenu xwayland
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/ash -c 'apk add $(apk search sway-* -q)'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/ash -c 'apk add $(apk search gvfs-* -q )'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/ash -c 'apk add $(apk search ttf-* -q)'
        "$ROOTFS_DIR"/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / apk fix
     fi
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
EOF

###########################
# Start PRoot environment #
###########################

# This command starts PRoot and binds several important directories
# from the host file system to our special root file system.
#$ROOTFS_DIR/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / supervisord -c /etc/supervisor/conf.d/supervisord.conf &
#$ROOTFS_DIR/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/ash -c "sleep 5s && $(cat tor.sh)"
$ROOTFS_DIR/usr/bin/proot.static -S "${ROOTFS_DIR}" -w / /bin/ash
