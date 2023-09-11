# sing-box-install

Bash script for installing sing-box in operating systems such as Arch / CentOS / Debian / OpenSUSE that support systemd.

[Filesystem Hierarchy Standard (FHS)](https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard) 

Upstream URL: 
[sing-box](https://github.com/SagerNet/sing-box/) 

```
Installed: /etc/systemd/system/sing-box.service
Installed: /etc/systemd/system/sing-box@.service

Installed: /usr/local/bin/sing-box
```
```
Will be Install after sing-box run:
/usr/local/share/sing-box/geoip.db
/usr/local/share/sing-box/geosite.db
```

## Basic Usage

**Install sing-box**

```
 bash -c "$(curl -L https://sing-box.vercel.app)" @ install
```

**Remove sing-box**

```
 bash -c "$(curl -L https://sing-box.vercel.app)" @ remove
```
## Advance

**Install sing-box Pre-release version**

```
 bash -c "$(curl -L https://sing-box.vercel.app)" @ install --beta
```

**Install sing-box Using GO**

```
 bash -c "$(curl -L https://sing-box.vercel.app)" @ install --go
```

**Install sing-box and set environment variable `CGO_ENABLED=1` while compling**

```
 bash -c "$(curl -L https://sing-box.vercel.app)" @ install --cgo
```

**Complie sing-box for windows**

```
 bash -c "$(curl -L https://sing-box.vercel.app)" @ install --win
```

**Install sing-box Using GO with custom Tags**

```
 bash -c "$(curl -L https://sing-box.vercel.app)" @ install --tag=with_gvisor,with_dhcp --go
```

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=chise0713/sing-box-Install&type=Timeline)](https://star-history.com/#chise0713/sing-box-Install&Timeline)

## Thanks
[@chika0801](https://github.com/chika0801)
