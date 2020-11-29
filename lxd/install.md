# Install LXD environment
## Prerequisites
### Update the system
```sudo apt update && apt -y full-upgrade ```

 ### Install snap
```sudo apt install snapd```

### Install lxd from snap
```sudo snap install lxd```
### Create a separated zfs dataset for lxd
```sudo zfs create -o mountpoint=none <pool>/lxd```
### Add user to lxd group for convenient using lxc command
```sudo adduser <username> lxd```

## Initialize lxd environment

### Create br-lan
```sudo vim /etc/netplan/00-lan-config.yaml ```
```
network:
  version: 2
  renderer: networkd
  ethernets:
    iface:
      dhcp4: no
      dhcp6: no
  bridges:
    br-lan:
      interfaces: [iface]
      dhcp4: no
      dhcp6: no
      parameters:
        stp: no
        forward-delay: 0
      addresses: [ip/mask]
      gateway4: ip
      nameservers:
        addresses: [ip]
        search: [domain]

```


### Run init script

```lxd init```
```
root@pandora:~# lxd init
Would you like to use LXD clustering? (yes/no) [default=no]: 
Do you want to configure a new storage pool? (yes/no) [default=yes]: yes
Name of the new storage pool [default=default]: lxd1
Name of the storage backend to use (lvm, zfs, ceph, btrfs, dir) [default=zfs]: 
Create a new ZFS pool? (yes/no) [default=yes]: no
Name of the existing ZFS pool or dataset: datapool/lxd
Would you like to connect to a MAAS server? (yes/no) [default=no]: no
Would you like to create a new local network bridge? (yes/no) [default=yes]: no
Would you like to configure LXD to use an existing bridge or host interface? (yes/no) [default=no]: yes
Name of the existing bridge or host interface: br-lan
Would you like LXD to be available over the network? (yes/no) [default=no]: no
Would you like stale cached images to be updated automatically? (yes/no) [default=yes] yes
Would you like a YAML "lxd init" preseed to be printed? (yes/no) [default=no]: no
```
---
## Working with a container

### Creating and launching a new container
```lxc launch ubuntu:18.04 filesrv```

### Getting a shell
```lxc exec <container> /bin/bash```

### Limit memory
``` lxc config set <container> limits.memory 2048MB ```
### Limit CPU
``` lxc config set <container> limits.cpu 4```

``` lxc config set <container> limits.cpu.allowance 80%```

### Limit disk
#### Limit generally all container's root size
```lxc profile device set default root size 10GB```

#### Limit generally all container's disk I/O read
```lxc config device set <container> root limits.read 10MB```

#### Limit generally all container's disk I/O write
```lxc config device set <container> root limits.write 10MB```

#### Override the root disk first
``` lxc config device override <container> root```
#### Limit the root disk size 
``` lxc config device set <container> root size 10GB```

### Add new disk to container
``` lxc config device add <container> <disk given name> disk source=<source path> path=<dest path in the container>```

### Restart a container
``` lxc restart <container>```

### Send any file to a container
``` lxc file push <file-to-push> <container>/<path>```

### Pull any file from container
``` lxc file pull <container>/<path> <where-to-pull-in-host>```

---

## Snapshots

### Snapshot a container
``` lxc snapshot <container> <name-of-snapshot>```

### Check snapshots of a container
``` lxc info filesrv --verbose```

### How to create own image
``` lxc publish <container>/<snapthoname> --alias <new_container_name>```

### Export an image then use on another servers
``` lxc image export <alias> <filename>```

### Import from file
``` lxc image import <filename-to-import> --alias <containername>```

---
## Get information
### Info about the system
``` lxc info```

### Get log info of a container
``` lxc info <container> --show-log```

### List containers
```lxc list```

### Get info about the lxc storage
```lxc storage info lxd1```

### Get image list from localhost
```lxc image list```

### Get online repository
``` lxc image list ubuntu: ```

``` lxc image list images:alpine```

### Show config of a container
```lxc config show <container>```

```lxc config show --expanded <container>```

### Get device list of a container
```lxc config device list <container>```