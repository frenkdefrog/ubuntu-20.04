#!/usr/bin/env bash
DATE=$(date +%Y%m%d%H%M%S)
POOL="$(hostname)pool"
DATASETS="ROOT/ubuntu home root srv var var/cache var/cache/apt var/lib var/lib/apt var/lib/dpkg var/log var/mail var/spool"
BACKUPPATH="/var/lib/backup/$(hostname)"

[ ! -d ${BACKUPPATH} ] && mkdir -p ${BACKUPPATH}

zfs list > ${BACKUPPATH}/zfs_${DATE}.zfs

for ds in ${DATASETS};
do
        zfs snapshot ${POOL}/${ds}@backup_${DATE}
done

for ds in ${DATASETS};
do
        filename="${BACKUPPATH}/${POOL}_${ds//\//_}_${DATE}.zfs"
        poolname="${POOL}/${ds}@backup_${DATE}"
        zfs send ${poolname} > ${filename}
#       zfs send ${POOL}/${ds}@backup_${DATE} > "${BACKUPPATH}/${POOL}_${ds//\//_}_${DATE}.zfs" 
        zfs destroy ${poolname}
done
