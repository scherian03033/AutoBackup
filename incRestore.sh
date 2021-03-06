#!/bin/sh
#Usage incRestore.sh <tar_file> <tgt_dir>

PLATFORM=`uname -a | cut -d ' ' -f 1 | tr '[A-Z]' '[a-z]'`
# returns darwin for mac, linux for NAS
if [ "$PLATFORM" == "darwin" ]; then
	SCRIPTROOT=`pwd`
elif [ "$PLATFORM" == "linux" ]; then
	SCRIPTROOT=/var/services/homes/admin/AutoBackup
fi

source $SCRIPTROOT/platform.sh

HELPER=${SCRIPTROOT}/mpTarHelper.sh

usage() {
	echo
	echo "Usage: $0 <tar_file> <tgt_directory>" >&2
}

if [ "$#" -ne 2 ]; then
	echo "Error: incorrect number of arguments"
	usage
	exit 1
fi

TARFILE=`find ${TGT_PREFIX} -name $1 -print`

if ! [ -f "${TARFILE}" ]; then
	echo "Error: tar archive $1 does not exist"
	usage
	exit 1
fi

if ! [ -d "$2" ]; then
	echo "Error: tgt_directory $1 is not a directory"
	usage
	exit 1
fi

# Restore contents of a single tar file to $RESTOREDIR
doRestore() {
	local BKUPFILE=$1
	echo "restoring" $1
	cd ${RESTOREDIR}
	${TAR} xvf ${BKUPFILE} -g /dev/null -M -F ${HELPER}
}

# given a backup source and level and a date, find the newest date that is
# older than the given date and restore it.

restoreLatestBackup() {
	local BKUPSRC=$1
	local BKUPLEVEL=$2
	local BKUPDATE=$3

	# this line gets all matching backups and sorts it from newest to oldest
	for i in `find ${TGT_PREFIX} -name ${BKUPSRC}_L${BKUPLEVEL}_*.tar -print | sort -r`
	do
		local FDATE=`echo "$i" |cut -d '_' -f 3|cut -d '.' -f 1`
		if [ "$FDATE" -lt "$BKUPDATE" ]; then
			doRestore $i
			return
		fi
	done

	echo "ERROR: Missing backup at level ${BKUPLEVEL} for ${BKUPSRC}"
	exit 1
}

RESTOREDIR=$2

# find backup level of the tar file to be restored
TARLEVEL=`echo "$1"|cut -d '_' -f 2`
TARLEVEL=${TARLEVEL:1:2}

SRCDIR=`echo "$1"|cut -d '_' -f 1`

FILEDATE=`echo "$1"|cut -d '_' -f 3|cut -d '.' -f 1`

# restore all most recent backup at each level below this one
if [ "$TARLEVEL" -eq 1 ]; then
	restoreLatestBackup ${SRCDIR} 0 ${FILEDATE}
fi
if [ "$TARLEVEL" -eq 2 ]; then
	restoreLatestBackup ${SRCDIR} 0 ${FILEDATE}
	restoreLatestBackup ${SRCDIR} 1 ${FILEDATE}
fi

# restore the requested tar file
doRestore ${TARFILE}
