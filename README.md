# [WIP]
# Sing-box-Install

Bash script for installing Sing-box in operating systems such as Arch / CentOS / Debian / OpenSUSE that support systemd.

[Filesystem Hierarchy Standard (FHS)](https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard) 

Upstream URL: 
[Sing-box](https://github.com/SagerNet/sing-box/) 

```
installed: /etc/systemd/system/sing-box.service
installed: /etc/systemd/system/sing-box@.service

installed: /usr/local/bin/sing-box

installed: /var/log/sing-box/sing.log
```

## Usage

**Install Sing-box**

```
 bash -c "$(curl -L https://github.com/KoinuDayo/Sing-box-Install/raw/master/install.sh)" -- install
```

**Install Sing-box Using GO**

```
 bash -c "$(curl -L https://github.com/KoinuDayo/Sing-box-Install/raw/master/install.sh)" -- install --go
```

**Install Sing-box Using GO with custom Tags**

```
 bash -c "$(curl -L https://github.com/KoinuDayo/Sing-box-Install/raw/master/install.sh)" -- install --tag=with_gvisor,with_dhcp --go
```

**Remove Sing-box**

```
 bash -c "$(curl -L https://github.com/KoinuDayo/Sing-box-Install/raw/master/install.sh)" -- remove
```

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=KoinuDayo/Sing-box-Install&type=Timeline)](https://star-history.com/#KoinuDayo/Sing-box-Install&Timeline)
