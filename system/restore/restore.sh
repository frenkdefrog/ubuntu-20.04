export POOL=alphapool
export BOOT="UEFI"
DIR=$1
TIME=$2

for disk in ${DISKS} ; do sgdisk -Z -n9:-8M:0 -t9:bf07 -c9:${disk}9-Reserved -n1:1m:+512M -t1:${PARTTYPE} -c1:${disk}1-${BOOT} -n2:0:0 -t2:bf01 -c2:${disk}2-zfs /dev/${disk}; done
mkdir -p /target
PARTS=$(for disk in ${DISKS} ; do if [[ ${disk} == *"nvme"* ]]; then echo -n "/dev/${disk}p2 "; else echo -n "/dev/${disk}2 "; fi; done)
if [ $RAID == "0" ] ; then
  zpool create -f -o ashift=12 -O atime=off -O canmount=off -O compression=lz4 -O normalization=formD -O mountpoint=/ -R /target ${POOL} $(echo $PARTS | cut -d' ' -f1);
else
  zpool create -f -o ashift=12 -O atime=off -O canmount=off -O compression=lz4 -O normalization=formD -O mountpoint=/ -R /target ${POOL} ${RAID} ${PARTS};
fi

zfs create -o canmount=off -o mountpoint=none ${POOL}/ROOT
zfs receive -o canmount=noauto -o mountpoint=/ -o exec=on -o setuid=on -o devices=on ${POOL}/ROOT/ubuntu < ${DIR}/${POOL}_ROOT_ubuntu_${TIME}.zfs
#zfs mount ${POOL}/ROOT/ubuntu
zpool set bootfs=${POOL}/ROOT/ubuntu ${POOL}
zfs set exec=off ${POOL}
zfs set setuid=off ${POOL}
zfs set devices=off ${POOL}
zfs receive -o canmount=off ${POOL}/var < ${DIR}/${POOL}_var_${TIME}.zfs
zfs receive -o canmount=off ${POOL}/var/lib < ${DIR}/${POOL}_var_lib_${TIME}.zfs
zfs receive ${POOL}/var/lib/apt < ${DIR}/${POOL}_var_lib_apt_${TIME}.zfs
zfs receive -o exec=on ${POOL}/var/lib/dpkg < ${DIR}/${POOL}_var_lib_dpkg_${TIME}.zfs
zfs receive ${POOL}/var/log < ${DIR}/${POOL}_var_log_${TIME}.zfs
zfs create -o com.sun:auto-snapshot=false ${POOL}/var/tmp
zfs receive -o com.sun:auto-snapshot=false ${POOL}/var/cache < ${DIR}/${POOL}_var_cache_${TIME}.zfs
zfs receive -o com.sun:auto-snapshot=false ${POOL}/var/cache/apt < ${DIR}/${POOL}_var_cache_apt_${TIME}.zfs
zfs receive ${POOL}/var/spool < ${DIR}/${POOL}_var_spool_${TIME}.zfs
zfs receive ${POOL}/var/mail < ${DIR}/${POOL}_var_mail_${TIME}.zfs
zfs create -o com.sun:auto-snapshot=false -o exec=on ${POOL}/tmp
zfs receive -o exec=on ${POOL}/root < ${DIR}/${POOL}_root_${TIME}.zfs
zfs receive -o mountpoint=/home ${POOL}/home < ${DIR}/${POOL}_home_${TIME}.zfs
zfs receive -o mountpoint=/srv ${POOL}/srv < ${DIR}/${POOL}_srv_${TIME}.zfs
#mount -t zfs
chmod 1777 /target/tmp
chmod 1777 /target/var/tmp
#${DIR}/${POOL}${TIME}.zfs
mount --rbind /dev /target/dev
mount --rbind /proc /target/proc
mount --rbind /sys /target/sys

