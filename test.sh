#!/bin/sh
PLATFORM=`uname -a | cut -d ' ' -f 1 | tr '[A-Z]' '[a-z]'`
# returns darwin for mac, linux for NAS
if [ "$PLATFORM" == "darwin" ]; then
	SCRIPTROOT=`pwd`
elif [ "$PLATFORM" == "linux" ]; then
	SCRIPTROOT=/var/services/homes/admin/AutoBackup
fi

source $SCRIPTROOT/platform.sh

getBkupSize() {
	local filename=$1
	local level=$2
	local theDate=$3
#	echo "$filename $level $theDate"
	local fileList=`find ${TGT_PREFIX} -name \
		${filename}_L${level}_${theDate}.tar* -print`

	local foo=`ls -l $fileList | tr -s ' ' |cut -d ' ' -f 5 | paste -sd+ -`
# remove the trailing - in paste command above for non-OS X
	bar=`perl -e "print $foo" \;`

	echo $bar
}

blargh=$(getBkupSize NetSanjay 0 201408302148)
echo $blargh
