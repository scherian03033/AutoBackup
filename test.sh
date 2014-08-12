#!/bin/sh

TGT_PREFIX=./volumeUSB1/usbshare/AutoBackup

purge() {
	local tgtDir=$1
	local level=$2
	local cutoff=0

	if [ "$level" == 0 ]; then
		cutoff=`date -v '-1y' +%Y%m%d`
	elif [ "$level" == 1 ]; then
		cutoff=`date -v '-3m' +%Y%m%d`
	elif [ "$level == 2 " ]; then
		cutoff=`date -v '-1m' +%Y%m%d`
	else
		echo "purge: invalid level"
		exit 1
	fi

	for i in `find ${TGT_PREFIX} -name ${tgtDir}_L${level}_*.tar* -print`
	do
		fileDate=`echo $i|cut -d '/' -f 8|cut -d '.' -f 1|cut -d '_' -f 3|\
								cut -c'1-8'`
		# echo $fileDate $i
		if [ "$fileDate" -lt "$cutoff" ]; then
			echo "rm $i"
		else
			echo "$i newer than $cutoff, skipping"
		fi
	done
}
# cutoff=`date -v '-3m' +%Y%m%d`

purge NetSanjay 2
