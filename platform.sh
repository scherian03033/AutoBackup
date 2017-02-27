#!/bin/sh

# Contains all the platform-specific scripting to support NAS and OS X

# PLATFORM=`uname -a | cut -d ' ' -f 1 | tr '[A-Z]' '[a-z]'`
# returns darwin for mac, linux for NAS
if [ "$PLATFORM" == "darwin" ]; then
	SRC_PREFIX=`pwd`/volume1
	TGT_PREFIX=`pwd`/volumeUSB1/usbshare/AutoBackup
	TAR=gtar
#chunk size set up for mac testing of small files
	CHUNK=2048
elif [ "$PLATFORM" == "linux" ]; then
	SRC_PREFIX=/volume1
	TGT_PREFIX=/volumeUSB1/usbshare/AutoBackup
	TAR=tar
	NOTIFY=/usr/syno/bin/synonotify
#chunk size set up to fit on a single DVD
	CHUNK=4G
fi

CFG_FILE=${SCRIPTROOT}/AutoBackup.cfg
LOG_FILE=${SCRIPTROOT}/AutoBackup.log

osxnotify() {
	local title=$1
	local details=$2

	notify_cmd=`echo "osascript -e 'display notification \"""$details""\" with \
	 title \""${title}"\"'"`
	eval "$notify_cmd"
}

tellSuccess() {
	if [ "$PLATFORM" == "darwin" ]; then
		osxnotify "Backup Succeeded" "Happy Happy Joy Joy"
	elif [ "$PLATFORM" == "linux" ]; then
		${NOTIFY} BackupTaskFinished
	fi
}

tellFailure() {
	if [ "$PLATFORM" == "darwin" ]; then
		osxnotify "Backup Failed" "Go look at logs"
	elif [ "$PLATFORM" == "linux" ]; then
		${NOTIFY} BackupTaskFailed
	fi
	exit 1
}
