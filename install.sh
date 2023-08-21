#!/usr/bin/bash

# Initialize variables
action=
tag=
type=
go_type=

identify_the_operating_system_and_architecture() {
  if [[ "$(uname)" == 'Linux' ]]; then
    case "$(uname -m)" in
      'i386' | 'i686')
        MACHINE='386'
        ;;
      'amd64' | 'x86_64')
        MACHINE='amd64'
        ;;
      'armv5tel')
        MACHINE='arm'
        ;;
      'armv6l')
        MACHINE='arm'
        grep Features /proc/cpuinfo | grep -qw 'vfp' || MACHINE='arm32-v5'
        ;;
      'armv7' | 'armv7l')
        MACHINE='arm'
        grep Features /proc/cpuinfo | grep -qw 'vfp' || MACHINE='arm32-v5'
        ;;
      'armv8' | 'aarch64')
        MACHINE='arm64'
        ;;
      'mips')
        MACHINE='mips'
        ;;
      'mipsle')
        MACHINE='mipsle'
        ;;
      'mips64')
        MACHINE='mips64'
        lscpu | grep -q "Little Endian" && MACHINE='mips64le'
        ;;
      'mips64le')
        MACHINE='mips64le'
        ;;
      'ppc64')
        MACHINE='ppc64'
        ;;
      'ppc64le')
        MACHINE='ppc64le'
        ;;
      'riscv64')
        MACHINE='riscv64'
        ;;
      's390x')
        MACHINE='s390x'
        ;;
      *)
        echo "error: The architecture is not supported."
        exit 1
        ;;
    esac
    if [[ ! -f '/etc/os-release' ]]; then
      echo "error: Don't use outdated Linux distributions."
      exit 1
    fi
    # Do not combine this judgment condition with the following judgment condition.
    ## Be aware of Linux distribution like Gentoo, which kernel supports switch between Systemd and OpenRC.
    if [[ -f /.dockerenv ]] || grep -q 'docker\|lxc' /proc/1/cgroup && [[ "$(type -P systemctl)" ]]; then
      true
    elif [[ -d /run/systemd/system ]] || grep -q systemd <(ls -l /sbin/init); then
      true
    else
      echo "error: Only Linux distributions using systemd are supported."
      exit 1
    fi
    if [[ "$(type -P apt)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='apt -y --no-install-recommends install'
      PACKAGE_MANAGEMENT_REMOVE='apt purge'
      package_provide_tput='ncurses-bin'
    elif [[ "$(type -P dnf)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='dnf -y install'
      PACKAGE_MANAGEMENT_REMOVE='dnf remove'
      package_provide_tput='ncurses'
    elif [[ "$(type -P yum)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='yum -y install'
      PACKAGE_MANAGEMENT_REMOVE='yum remove'
      package_provide_tput='ncurses'
    elif [[ "$(type -P zypper)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='zypper install -y --no-recommends'
      PACKAGE_MANAGEMENT_REMOVE='zypper remove'
      package_provide_tput='ncurses-utils'
    elif [[ "$(type -P pacman)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='pacman -Syu --noconfirm'
      PACKAGE_MANAGEMENT_REMOVE='pacman -Rsn'
      package_provide_tput='ncurses'
     elif [[ "$(type -P emerge)" ]]; then
      PACKAGE_MANAGEMENT_INSTALL='emerge -qv'
      PACKAGE_MANAGEMENT_REMOVE='emerge -Cv'
      package_provide_tput='ncurses'
    else
      echo "error: The script does not support the package manager in this operating system."
      exit 1
    fi
  else
    echo "error: This operating system is not supported."
    exit 1
  fi
}

# Function for software installation
install_software() {
  package_name="$1"
  file_to_detect="$2"
  type -P "$file_to_detect" > /dev/null 2>&1 && return
  if ${PACKAGE_MANAGEMENT_INSTALL} "$package_name" >/dev/null 2>&1; then
    echo "info: $package_name is installed."
  else
    echo "error: Installation of $package_name failed, please check your network."
    exit 1
  fi
}
# Function for check wheater user is running at root
check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "You have to use root to run this script"
    exit 1
  fi
}

curl() {
  $(type -P curl) -L -q --retry 5 --retry-delay 10 --retry-max-time 60 "$@" || echo -e "Error: Curl Failed, check your network"
}

# Function for service installation
install_service() {
  cat <<EOF > /etc/systemd/system/sing-box.service
[Unit]
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=/usr/local/etc/sing-box/
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=/usr/local/bin/sing-box run -c /usr/local/etc/sing-box/config.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
  cat <<EOF > /etc/systemd/system/sing-box@.service
[Unit]
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=/usr/local/etc/sing-box/
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=/usr/local/bin/sing-box run -c /usr/local/etc/sing-box/%i.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
}

# Function for go_installation
go_install() {
  install_software "go" "go"
  [ $MACHINE == amd64 ] && GOAMD64=v2
  if [ go_type == default ];then
    echo -e "\
Use \033[38;5;208m@chika0801\033[0m's template by default\
"
    CGO_ENABLED=1 GOOS=linux GOARCH=$MACHINE \
    go install -v -tags with_wireguard,with_quic,with_utls,with_reality_server github.com/sagernet/sing-box/cmd/sing-box@dev-next
  elif [ go_type == custom ]; then
    echo -e "\
Using custom config:
Tags: $tag\
"
    CGO_ENABLED=1 GOOS=linux GOARCH=$MACHINE \
    go install -v -tags $tag github.com/sagernet/sing-box/cmd/sing-box@dev-next
  fi
  ln -s /root/go/bin/sing-box /usr/local/bin/sing-box
  install_service
}

# Function for installation
install() {
  check_root
  if [ $type == go ];then
    [ -z $go_type ] && go_type=default
    go_install
  fi
  [ $MACHINE == amd64 ] && CURL_MACHINE=amd64
  [ $MACHINE == arm ] && CURL_MACHINE=armv7
  [ $MACHINE == arm64 ] && CURL_MACHINE=arm64
  if [ $CURL_MACHINE == amd64 ] || [ $CURL_MACHINE == arm64 ] ||[ $CURL_MACHINE == armv7 ]; then
    SING_VERSION=$(curl https://api.github.com/repos/SagerNet/sing-box/releases|grep -oP "sing-box-\d+\.\d+\.\d+-linux-'$CURL_MACHINE'"| sort -Vr | head -n 1)
    curl -o $SING_VERSION.tar.gz https://github.com/SagerNet/sing-box/releases/latest/download/$SING_VERSION.tar.gz
    tar -xzf $SING_VERSION.tar.gz -C /tmp
    SING_TMP=$(ls /tmp | grep -P 'sing-box-\d+\.\d+\.\d+-linux-amd64')
    cp /tmp/$SING_TMP/sing-box /usr/local/bin/sing-box
    chmod +x /usr/local/bin/sing-box
  else
  echo -e "\
Machine Type Not Support
Try to use \"--type=go\" to install\
"
  fi
  install_service
}

# Function for uninstallation
uninstall() {
  check_root

}
# Show help
help() {
  echo -e "\
This is a help
"
}
# Parse command line arguments
for arg in "$@"; do
  case $arg in
    --type=*)
      type="${arg#*=}"
      ;;
    --tag=*)
      tag="${arg#*=}"
      go_type=custom
      type=go
      ;;
    help)
      action="help"
      ;;
    remove)
      action="remove"
      ;;
    install)
      action="install"
      ;;
    *)
      echo "Invalid argument: $arg"
      exit 1
      ;;
  esac
done

# Perform action based on user input
case "$action" in
  help)
    help
    ;;
  remove)
    uninstall
    ;;
  install)
    install
    ;;
  *)
    echo "No action specified. Exiting..."
    ;;
esac

help