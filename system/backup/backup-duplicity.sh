#!/usr/bin/env bash

function log_message() {
	echo '{"date":"'$(date "+%Y-%m-%d %H:%M:%S")'","hostname":"'$(hostname)'","message":"'$@'"}'
}

function fail(){
	log_message "Exiting due to error: $@"
	exit 1
}

umask 077

export PASSPHRASE=Skjehxh0712lkjsfd72lk
ROOTPATH="datapool/data/filesrv/"
DATE=$(date +%Y%m%d%H%M%S)
DATASETS=$(/usr/sbin/zfs list -o name | grep ${ROOTPATH})
DUPLICITY_ARCHIVE_DIR="/var/cache/duplicity"
TARGET_ROOT='/srv/backup/data/'
RCLONE="onedrive:backup-duplicity"
#test if target root directory exists
test -d ${TARGET_ROOT} || fail "Duplicity target directory to backup can not be found! Exiting..."
TARGET_DIR="file://${TARGET_ROOT}$(hostname)/"
NICE="nice -n 19"
VOLSIZE=500
FULL="30D"
KEEP=3


#check if the duplicity backup script is still runing
test -f /run/backup.pid && test -d /proc/$(cat /run/backup.pid) && fail "The previous run is not finished yet, please try again later..."
echo $$ > /run/backup.pid

log_message "Backup started...."


for ds in ${DATASETS}
do
       log_message "Creating snapshot: $ds"
       /usr/sbin/zfs snapshot ${ds}@duplicity_${DATE}	
done

for ds in ${DATASETS}
do
      log_message "Backing up dataset: ${ds}"
      CURR_DS=$(echo ${ds} | cut -d/ -f4)
      MOUNTPOINT=$(/usr/sbin/zfs get mountpoint -o value ${ds} | sed -n '1!p')/.zfs/snapshot/duplicity_${DATE}/
      ${NICE} duplicity -v0 --no-print-statistics --archive-dir ${DUPLICITY_ARCHIVE_DIR}/${CURR_DS} --volsize=${VOLSIZE} --asynchronous-upload --full-if-older-than ${FULL} --allow-source-mismatch  ${MOUNTPOINT} ${TARGET_DIR}/${CURR_DS}
      STATUS=$?
     
      if [ $STATUS -ne 0 ]; then
      	fail "Error when saving ${CURR_DS}, error code: ${STATUS}"
      else
        log_message "Verifying the result of the backup: ${ds}"
	DIFFERENCE=$(${NICE} duplicity verify --archive-dir ${DUPLICITY_ARCHIVE_DIR}/${CURR_DS}  ${TARGET_DIR}/${CURR_DS} ${MOUNTPOINT} | grep -oP '(?<=compared,\s)\d(?=\s+differences)')
	if [ ${DIFFERENCE} -eq 0 ]; then
		log_message "Destroying the dataset after successfull backup:${ds}"
		/usr/sbin/zfs destroy ${ds}@duplicity_${DATE}
	else
		fail "There was some error during the verification. Please, check the datasets, and re run this script!"
        fi
      fi
done
log_message "Syncing with remote storage: rclone"
rclone sync ${TARGET_ROOT} ${RCLONE}
#rclone sync /srv/duplicity-backup/data/ onedrive:duplicity-backup
log_message "Calling cleanup functions, after backup...."
rm -r /run/backup.pid
