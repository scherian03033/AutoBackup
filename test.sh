#!/bin/sh
PLATFORM=`uname -a | cut -d ' ' -f 1 | tr '[A-Z]' '[a-z]'`
# returns darwin for mac, linux for NAS
if [ "$PLATFORM" == "darwin" ]; then
	SCRIPTROOT=`pwd`
elif [ "$PLATFORM" == "linux" ]; then
	SCRIPTROOT=/var/services/homes/admin/AutoBackup
fi

source $SCRIPTROOT/platform.sh

changedSince() {
	local dir=$1
	local refFile=$2
	# local d1=`echo $2| cut -c1-8`
	# local d2=`echo $2| cut -c9-12`
	#
	# local date=`echo "$d1 $d2"`
	# local fileList=`find $dir -newermt "$date" -print`
	# echo $date
	# echo $fileList

	local fileList=`find $dir -newer $refFile -print`
	if [ -z "${fileList// }" ]; then
		return 1
	else
		return 0
	fi
}

changedSince ${SRC_PREFIX}/NetSanjay foo
if [ $? -eq 0 ]; then
	echo "files changed"
else
	echo "no files changed"
fi
