apt update
apt -y full-upgrade
apt -y install vim
debconf-set-selections <<EOF
locales locales/default_environment_locale select ${DEFAULT_LOCALE}
debconf debconf/priority select critical
debconf debconf/frontend select Noninteractive
tzdata tzdata/Areas select ${TZAREA}
tzdata tzdata/Zones/${TZAREA} select ${TZNAME}
EOF
apt -y install $(for language in ${LANGUAGES} ; do echo language-pack-${language} ; done)
echo "${TZAREA}/${TZNAME}" > /etc/timezone
ln -sf /usr/share/zoneinfo/${TZNAME} /etc/localtime
update-locale ${DEFAULT_LOCALE}
apt -y install --no-install-recommends ${KERNEL}
apt -y install gdisk dosfstools zfsutils-linux zfs-zed spl rsync
for disk in ${DISKS} ; do mkdosfs -F 32 -n UEFI-${disk^^} /dev/${disk}1; done
mkdir /boot/efi
disk1=$(echo $DISKS | cut -d' ' -f1)
echo PARTUUID=$(blkid -s PARTUUID -o value /dev/disk/by-partlabel/${disk1}1-UEFI) /boot/efi vfat defaults 0 1 >> /etc/fstab
mount /boot/efi
apt -y install grub-efi
apt -y install zfs-initramfs
update-initramfs -c -k all

update-grub
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu --recheck --no-floppy
if [ ${RAID}!="0" ] ; then 
	DISKS2=$(echo ${DISKS} | cut -d' ' -f 2-)
	for disk in ${DISKS2} ; do
		mount /dev/${disk}1 /mnt;
		rsync -a /boot/efi/ /mnt/;
		umount /mnt;
	done
fi
zfs create -V ${SWAPSIZE} -b $(getconf PAGESIZE) \
	-o compression=zle \
	-o logbias=throughput \
	-o sync=always \
	-o primarycache=metadata \
	-o secondarycache=none \
	-o com.sun:auto-snapshot=false \
	${POOL}/swap

mkswap /dev/zvol/${POOL}/swap
echo /dev/zvol/${POOL}/swap none swap defaults 0 0 >> /etc/fstab
zfs set quota=1G ${POOL}/tmp
zfs set quota=11G ${POOL}/var
zfs set quota=2G ${POOL}/var/cache
zfs set quota=1G ${POOL}/var/cache/apt
zfs set quota=512M ${POOL}/var/lib/apt
zfs set quota=512M ${POOL}/var/lib/dpkg
zfs set quota=5G ${POOL}/var/log
zfs set quota=1G ${POOL}/var/mail
zfs set quota=1G ${POOL}/var/spool
zfs set quota=1G ${POOL}/var/tmp
zfs set quota=10G ${POOL}/home
zfs set refreservation=2G ${POOL}/ROOT/${ID}
zfs set reservation=10G ${POOL}/ROOT
zfs set refquota=5G ${POOL}/ROOT/${ID}
zfs set refreservation=1G ${POOL}/root
zfs set reservation=3G ${POOL}/var
zfs set reservation=1G ${POOL}/var/lib
zfs set reservation=1G ${POOL}/var/log
zfs set acltype=posixacl ${POOL}
for file in /etc/logrotate.d/* ; do
	if grep -Eq "(^|[^#y])compress" "$file" ; then
		sed -i -r "s/(^|[^#y])(compress)/\1#\2/" "$file"
	fi
done
apt -y install ssh
apt -y install zfs-auto-snapshot
apt -y install unattended-upgrades
apt -y install snapd
zfs set autoreplace=on ${POOL}
cat <<EOF >>/etc/zfs/zed.d/zed.rc
  ##
  # Replace a device with a hot spare after N checksum errors are detected.
  # Disabled by default; uncomment to enable.
  #
  ZED_SPARE_ON_CHECKSUM_ERRORS=10
  ##
  # Replace a device with a hot spare after N I/O errors are detected.
  # Disabled by default; uncomment to enable.
  #
  ZED_SPARE_ON_IO_ERRORS=10
  EOF

