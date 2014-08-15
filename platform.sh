PLATFORM=`uname -a | cut -d ' ' -f 1 | tr '[:upper:]' '[:lower:]'`
# returns darwin for mac, linux for NAS
if [ "$PLATFORM" == "darwin" ]; then
	SCRIPTROOT=`pwd`
	SRC_PREFIX=`pwd`/volume1
	TGT_PREFIX=`pwd`/volumeUSB1/usbshare/AutoBackup
	TAR=gtar
#chunk size set up for mac testing of small files
	CHUNK=2048
elif [ "$PLATFORM" == "linux" ]; then
	SCRIPTROOT=/volume1/homes/admin/AutoBackup
	SRC_PREFIX=/volume1
	TGT_PREFIX=/volumeUSB1/usbshare/AutoBackup
	TAR=tar
	NOTIFY=/usr/syno/bin/synonotify
#chunk size set up to fit on a single DVD
	CHUNK=4194304
fi

CFG_FILE=./AutoBackup.cfg
LOG_FILE=./AutoBackup.log

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
		${NOTIFY} LocalBackupFinishedMultiVersion
	fi
}

tellFailure() {
	if [ "$PLATFORM" == "darwin" ]; then
		osxnotify "Backup Failed" "Go look at logs"
	elif [ "$PLATFORM" == "linux" ]; then
		${NOTIFY} LocalBackupErrorMultiVersion
	fi
	exit 1
}
