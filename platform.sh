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
#chunk size set up to fit on a single DVD
	CHUNK=4194304
fi

CFG_FILE=./AutoBackup.cfg
LOG_FILE=./AutoBackup.log

#!!!! FIX PATH NAMES so that absolute paths are used
