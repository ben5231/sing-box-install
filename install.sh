#!/usr/bin/bash

# Initialize variables
action=
tag=
type=
go_type=
remove_type=

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

install_log_and_config() {
  if [ ! -d /var/log/sing-box ];then 
    install -d -m 700 /var/log/sing-box || echo "Error: Failed to Install: /var/log/sing-box/"
    echo "Installed: /var/log/sing-box/"
    install -m 700 /dev/null /var/log/sing-box/sing.log || echo "Error: Failed to Install: /var/log/sing-box/sing.log"
    echo "Installed: /var/log/sing-box/sing.log"
  fi
  if [ ! -d /usr/local/etc/sing-box ];then
    install -d -m 700 /usr/local/etc/sing-box || echo "Error: Failed to Install: /usr/local/etc/sing-box"
    echo "Installed: /usr/local/etc/sing-box"
    install -m 700 /dev/null /usr/local/etc/sing-box/config.json || echo "Error: Failed to Install: /usr/local/etc/sing-box/config.json"
    echo "Installed: /usr/local/etc/sing-box/config.json"
    cat <<EOF > /usr/local/etc/sing-box/config.json
{

}
EOF
  fi
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
  echo -e "Installed: /etc/systemd/system/sing-box.service"
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
  echo -e "Installed: /etc/systemd/system/sing-box@.service"
  if systemctl enable sing-box && systemctl start sing-box;then
    echo "Info: Enable and start sing-box.service"
  else
    echo "Error: Failed to enable and start sing-box.service"
    exit 1
  fi
}

# Function for go_installation
go_install() {
  if ! install_software "go" "go" ;then
    echo -e "\033[1;97mINFO: This is not a network error\033[0m
May just because your package manager don't have \"go\"
Trying use Official Install Script\
" 
    curl -sLo go.tar.gz https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
    rm -rf /usr/local/go
    tar -C /usr/local -xzf go.tar.gz
    rm go.tar.gz
    echo -e "export PATH=$PATH:/usr/local/go/bin" > /etc/profile.d/go.sh
    source /etc/profile.d/go.sh
    go version
  fi
  [[ $MACHINE == amd64 ]] && GOAMD64=v2
  if [[ $go_type == default ]];then
    echo -e "\
Use \033[38;5;208m@chika0801\033[0m's template by default.
"
    if ! CGO_ENABLED=1 GOOS=linux GOARCH=$MACHINE \
    go install -v -tags with_wireguard,with_quic,with_utls,with_reality_server github.com/sagernet/sing-box/cmd/sing-box@dev-next;then
      echo -e "Go Install Failed.\nExiting."
      exit 1
    fi
  elif [[ $go_type == custom ]]; then
    echo -e "\
Using custom config:
Tags: $tag\
"
    if ! CGO_ENABLED=1 GOOS=linux GOARCH=$MACHINE \
    go install -v -tags $tag github.com/sagernet/sing-box/cmd/sing-box@dev-next;then
      echo -e "Go Install Failed.\nExiting."
      exit 1
    fi
  fi
  ln -sf /root/go/bin/sing-box /usr/local/bin/sing-box
  echo -e "\
Installed: /usr/local/bin/sing-box
Installed: /root/go/bin/sing-box\
"
}

# Function for installation
curl_install() {
  check_root
  identify_the_operating_system_and_architecture
  if [[ $type == go ]];then
    [[ -z $go_type ]] && go_type=default
    go_install
  else
    [[ $MACHINE == amd64 ]] && CURL_MACHINE=amd64
    [[ $MACHINE == arm ]] && CURL_MACHINE=armv7
    [[ $MACHINE == arm64 ]] && CURL_MACHINE=arm64
    if [[ $CURL_MACHINE == amd64 ]] || [[ $CURL_MACHINE == arm64 ]] || [[ $CURL_MACHINE == armv7 ]]; then
      SING_VERSION=$(curl https://api.github.com/repos/SagerNet/sing-box/releases|grep -oP "sing-box-\d+\.\d+\.\d+-linux-$CURL_MACHINE"| sort -Vr | head -n 1)
      echo "Newest version found: $SING_VERSION"
      curl -o /tmp/$SING_VERSION.tar.gz https://github.com/SagerNet/sing-box/releases/latest/download/$SING_VERSION.tar.gz
      tar -xzf /tmp/$SING_VERSION.tar.gz -C /tmp
      cp -r /tmp/$SING_VERSION/sing-box /usr/local/bin/sing-box
      chmod +x /usr/local/bin/sing-box
      echo -e "\
Installed: /usr/local/bin/sing-box\
"
    else
      echo -e "\
Machine Type Not Support
Try to use \"--type=go\" to install\
"
      exit 1
    fi
  fi

  install_log_and_config
  install_service

  echo -e "\
Installation Complete\
"
  exit
}

# Function for uninstallation
uninstall() {
  check_root
  if ! ls /etc/systemd/system/sing-box.service >/dev/null 2>&1 ;then
    echo -e "Sing-box not Installed.\nExiting."
    exit 1
  fi
  if [[ $remove_type == purge ]];then
    rm -rf /usr/local/etc/sing-box /var/log/sing-box
    echo -e "\
Removed: /usr/local/etc/sing-box/
Removed: /var/log/sing-box/\
"
  fi
  rm -rf /usr/local/bin/sing-box /etc/systemd/system/sing-box.service /etc/systemd/system/sing-box@.service
  echo -e "\
Removed: /usr/local/bin/sing-box
Removed: /etc/systemd/system/sing-box.service
Removed: /etc/systemd/system/sing-box@.service\
"
  exit
}
# Show help
help() {
  echo -e "usage: $0 ACTION [OPTION]...

ACTION:
install                   Install/Update Sing-box
remove                    Remove Sing-box
help                      Show help
If no action is specified, then help will be selected

OPTION:
  install:
    --go                      If it's specified, the scrpit will use go to install Sing-box. 
                              If it's not specified, the scrpit will use curl by default.
    --tag=[Tags]              Sing-box Install tag, if you specified it, the script will use go to install Sing-box, and use your custom tags. 
                              If it's not specified, the scrpit will use \033[38;5;208m@chika0801\033[0m's template by default.
  remove:
    --purge                   Remove all the Sing-box files, include logs, configs, etc
"
  exit 0
}
# Parse command line arguments
for arg in "$@"; do
  case $arg in
    --purge)
      remove_type="purge"
      ;;
    --go)
      type="go"
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
    curl_install
    ;;
  *)
    echo "No action specified. Exiting..."
    ;;
esac

help