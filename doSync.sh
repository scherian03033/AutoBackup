#!/bin/sh
# Usage: doBackup.sh <srcDir | all> <level>
# where type is 0, 1 or 2

PLATFORM=`uname -a | cut -d ' ' -f 1 | tr '[A-Z]' '[a-z]'`
# returns darwin for mac, linux for NAS
if [ "$PLATFORM" == "darwin" ]; then
	SCRIPTROOT=`pwd`
elif [ "$PLATFORM" == "linux" ]; then
	SCRIPTROOT=/var/services/homes/admin/AutoBackup
fi

source $SCRIPTROOT/platform.sh

if [ -d ${SYNC_DIR} ]; then
	# Loop over every line in the config file which looks like srcDir tgtDir
	while read line; do
		SDIR=`echo $line |cut -d ' ' -f 1`
		TDIR=`echo $line |cut -d ' ' -f 2`
		DOSYNC=`echo $line |cut -d ' ' -f 3`

		if [ "$DOSYNC" = "true"  ]; then
			echo syncing ${TGT_PREFIX}/${TDIR} to $SYNC_DIR}/$TDIR}
			rsync -avz --update -delete ${TGT_PREFIX}/${TDIR}/ ${SYNC_DIR}/${TDIR}
		fi
	done < $CFG_FILE >> $LOG_FILE 2>&1
	echo "worked"
else
	echo "Sync Directory does not exist" >> $LOG_FILE 2>&1
	echo "failed"
fi
