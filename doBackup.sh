#!/bin/sh
# Usage: doBackup.sh <srcDir | all> <level>
# where type is 0, 1 or 2

# Remove "." for real application
SRC_PREFIX=./volume1
TGT_PREFIX=./volumeUSB1/usbshare/AutoBackup
CFG_FILE=./AutoBackup.cfg
LOG_FILE=./AutoBackup.log

usage() {
	echo
	echo "Usage: $0 <source dir | all> <backup_level | auto>"
	echo "  where backup_level is between 0 and 2 inclusive" >&2
	exit 1
}

isNumber() {
	local inVar=$1

	if [ "$inVar" -eq "$inVar" ] 2>/dev/null; then
		return 0
	else
		return 1
	fi
}

chooseLevel() {
	local l0=$1
	local l1=$2
	local l2=$3
	local cutoff=20
	local lvl=5

	# echo chooseLevel called with $1 $2 $3

	local l2_div_l0=100
	local l1_div_l0=100
	local l2_div_l1=100

	if [ "$l0" -ne 0 ]; then
		l2_div_l0=`echo $l2 '*' 100 / $l0 |bc`
		l1_div_l0=`echo $l1 '*' 100 / $l0 |bc`
	fi

	if [ "$l1" -ne 0 ]; then
		l2_div_l1=`echo $l2 '*' 100 / $l1 |bc`
	fi

	# echo $l1_div_l0 $l2_div_l0 $l2_div_l1

	if [ "$l1_div_l0" -gt "$cutoff" ] || [ "$l2_div_l0" -gt "$cutoff" ]; then
		lvl=0
	elif [ "$l2_div_l1" -gt "$cutoff" ]; then
		lvl=1
	else
		lvl=2
	fi

	return $lvl
}

getBkupSize() {
	local filename=$1
	local level=$2
	local theDate=$3
#	echo "$filename $level $theDate"
	local fileList=`find ${TGT_PREFIX} -name ${filename}_L${level}_${theDate}.tar* \
						-print`
	foo=`ls -l $fileList | tr -s ' ' |cut -d ' ' -f 5 | paste -sd+ -| bc`
# remove the trailing - in paste command above for non-OS X
	echo $foo
}

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
			echo "$i newer than $cutoff, not purged"
		fi
	done
}

### Main Code
###

if [ "$#" -lt 2 ]; then
	echo "Error: too few arguments"
	usage
	exit 1
fi
if [ "$#" -gt 2 ]; then
	echo "Error: too many arguments"
	usage
	exit 1
fi
if ! [ -d "${SRC_PREFIX}/$1" ] && ! [ "$1" == "all" ]; then
	echo "Error: ${SRC_PREFIX}/$1 is not a directory"
	usage
	exit 1
fi

if isNumber "$2"; then
	if [ "$2" -gt 2 ] || [ "$2" -lt 0 ]; then
		echo "Error: <backup_level> was $2; must be an integer value between \
					0 and 2 or use the word auto"
		usage
		exit 1
	fi
	LVL=$2
elif [ "$2" == "auto" ]; then
	echo "auto backup level invoked"
	LVL=99
else
	echo "Error: <backup_level> was $2; must be an integer value between \
				0 and 2 or use the word auto"
	usage
	exit 1
fi

SRC=$1

files=`find ${TGT_PREFIX} -name *.tar -print |rev|cut -d / -f 1|rev|cut -d . \
				-f 1|sort`

while read line; do
	L0Date=0
	L1Date=0
	L2Date=0
	L0Size=0
	L1Size=0
	L2Size=0
	SDIR=`echo $line |cut -d ' ' -f 1`
	TDIR=`echo $line |cut -d ' ' -f 2`

	for i in $files; do
		if [ "$SDIR" == `echo "$i"|cut -d '_' -f 1` ]; then
			thisLevel=`echo "$i"|cut -d '_' -f 2`
			thisDate=`echo "$i"|cut -d '_' -f 3`
			if [ "$thisLevel" == "L0" ]; then
				if [ "$thisDate" -gt "$L0Date" ]; then
					L0Date="$thisDate"
				fi
			elif [ "$thisLevel" == "L1" ]; then
				if [ "$thisDate" -gt "$L1Date" ]; then
					L1Date="$thisDate"
				fi
			elif [ "$thisLevel" == "L2" ]; then
				if [ "$thisDate" -gt "$L2Date" ]; then
					L2Date="$thisDate"
				fi
			else
				echo "Filename with bad level $thisLevel"
				exit 1
			fi
		fi
	done
	if [ "$L0Date" -ne 0 ]; then
		L0Size=$(getBkupSize "$SDIR" 0 "$L0Date")
		# theFile=`find ${TGT_PREFIX} -name ${SDIR}_L0_${L0Date}.tar -print`
		# L0Size=`ls -l "$theFile"|tr -s ' ' |cut -d ' '  -f 5`
		echo ${SDIR}_L0_${L0Date} $L0Size
	fi
	if [ "$L1Date" -ne 0 ] && [ "$L1Date" -ge "$L0Date" ]; then
		L1Size=$(getBkupSize "$SDIR" 1 "$L1Date")
		# theFile=`find ${TGT_PREFIX} -name ${SDIR}_L1_${L1Date}.tar -print`
		# L1Size=`ls -l "$theFile"|tr -s ' ' |cut -d ' '  -f 5`
		echo ${SDIR}_L1_${L1Date} $L1Size
	fi
	if [ "$L2Date" -ne 0 ] && [ "$L2Date" -ge "$L1Date" ]; then
		L2Size=$(getBkupSize "$SDIR" 2 "$L2Date")
		# theFile=`find ${TGT_PREFIX} -name ${SDIR}_L2_${L2Date}.tar -print`
		# L2Size=`ls -l "$theFile"|tr -s ' ' |cut -d ' '  -f 5`
		echo ${SDIR}_L2_${L2Date} $L2Size
	fi
	chooseLevel $L0Size $L1Size $L2Size
	blvl="$?"
	if [ "$LVL" -eq 99 ]; then
		LVL="$blvl"
	fi

	if [ "$SDIR" == $SRC ] || [ "$SRC" == "all" ]; then
		echo "Performing level ${LVL} backup of ${SRC_PREFIX}/${SDIR}"
		purge "$SDIR" "${LVL}"
		./incBackup.sh ${SRC_PREFIX}/${SDIR} ${TGT_PREFIX}/${TDIR} ${LVL}
	fi
done < $CFG_FILE
