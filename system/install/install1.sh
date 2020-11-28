#!/bin/bash
apt update
apt -y install zfsutils-linux zfs-zed spl
export SRVNAME="ficko"
export DOMAIN="otthon.lan"
export MAC=$(cat /sys/class/net/enp0s3/address)
export IP="192.168.3.155/24"
export IFACE="lan0"
export GW="192.168.3.1"
export DNS="192.168.3.7"
export SWAPSIZE="4G"
export TZAREA="Europe"
export TZNAME="Budapest"
export LANGUAGES="en hu"
export DEFAULT_LOCALE="C.UTF-8"
export BOOT="MBR"
export BOOT="UEFI"
if [ $BOOT == "UEFI" ] ; then export PARTTYPE="EF00" ; else PARTTYPE="EF02" ; fi
export DISKS="sda sdb"
export RAID="mirror"
export POOL="${SRVNAME}pool"
source /etc/os-release 
export ID
export VERSION_CODENAME
export KERNEL="linux-image-generic"
for disk in ${DISKS} ; do sgdisk -Z -n9:-8M:0 -t9:bf07 -c9:${disk}9-Reserved -n1:1m:+512M -t1:${PARTTYPE} -c1:${disk}1-${BOOT} -n2:0:0 -t2:bf01 -c2:${disk}2-zfs /dev/${disk}; done
mkdir -p /target
PARTS=$(for disk in ${DISKS} ; do if [[ ${disk} == *"nvme"* ]]; then echo -n "/dev/${disk}p2 "; else echo -n "/dev/${disk}2 "; fi; done)
if [ $RAID == "0" ] ; then
  zpool create -f -o ashift=12 -O atime=off -O canmount=off -O compression=lz4 -O normalization=formD -O mountpoint=/ -R /target ${POOL} $(echo $PARTS | cut -d' ' -f1);
else
  zpool create -f -o ashift=12 -O atime=off -O canmount=off -O compression=lz4 -O normalization=formD -O mountpoint=/ -R /target ${POOL} ${RAID} ${PARTS};
fi

zfs create -o canmount=off -o mountpoint=none ${POOL}/ROOT
zfs create -o canmount=noauto -o mountpoint=/ -o exec=on -o setuid=on -o devices=on ${POOL}/ROOT/${ID}
zfs mount ${POOL}/ROOT/${ID}
zpool set bootfs=${POOL}/ROOT/${ID} ${POOL}
zfs set exec=off ${POOL}
zfs set setuid=off ${POOL}
zfs set devices=off ${POOL}
zfs create -o canmount=off ${POOL}/var
zfs create -o canmount=off ${POOL}/var/lib
zfs create ${POOL}/var/lib/apt
zfs create -o exec=on ${POOL}/var/lib/dpkg
zfs create ${POOL}/var/log
zfs create -o com.sun:auto-snapshot=false ${POOL}/var/tmp
zfs create -o com.sun:auto-snapshot=false ${POOL}/var/cache
zfs create -o com.sun:auto-snapshot=false ${POOL}/var/cache/apt
zfs create ${POOL}/var/spool
zfs create ${POOL}/var/mail
zfs create -o com.sun:auto-snapshot=false -o exec=on ${POOL}/tmp
zfs create -o exec=on ${POOL}/root
zfs create -o mountpoint=/home ${POOL}/home
zfs create -o mountpoint=/srv ${POOL}/srv
mount -t zfs
chmod 1777 /target/tmp
chmod 1777 /target/var/tmp
apt -y install debootstrap
debootstrap ${VERSION_CODENAME} /target
echo ${SRVNAME} > /target/etc/hostname
echo "127.0.1.1 ${SRVNAME}.${DOMAIN} ${SRVNAME}" >> /target/etc/hosts
cat <<EOF > /target/etc/systemd/network/10-persistent-net.link
[Match]
MACAddress=${MAC}

[Link]
Name=${IFACE}
EOF
cat <<EOF > /target/etc/netplan/00-lan-config.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    ${IFACE}:
      dhcp4: no
      dhcp6: no
      addresses: [${IP}]
      gateway4: ${GW}
      nameservers:
        addresses: [${DNS}]
        search: [${DOMAIN}]
EOF
cat <<EOF > /target/etc/netplan/00-lan-config.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    ${IFACE}:
      dhcp4: no
      dhcp6: no
      addresses: [${IP}]
      gateway4: ${GW}
      nameservers:
        addresses: [${DNS}]
        search: [${DOMAIN}]
EOF
grep '^deb http' /etc/apt/sources.list > /target/etc/apt/sources.list
mount --rbind /dev /target/dev
mount --rbind /proc /target/proc
mount --rbind /sys /target/sys
