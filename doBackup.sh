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

usage() {
	echo
	echo "Usage: $0 <source dir | all> <backup_level | auto>"
	echo "  where backup_level is between 0 and 2 inclusive" >&2
	tellFailure
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
		l2_div_l0=`perl -e "print $l2 * 100 / $l0" \;`
		l1_div_l0=`perl -e "print $l1 * 100 / $l0" \;`
	fi

	if [ "$l1" -ne 0 ]; then
		l2_div_l1=`perl -e "print $l2 * 100 / $l1" \;`
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
	local fileList=`find ${TGT_PREFIX} -name \
		${filename}_L${level}_${theDate}.tar* -print`
	foo=`ls -l $fileList | tr -s ' ' |cut -d ' ' -f 5 | paste -sd+ -| bc`
# remove the trailing - in paste command above for non-OS X
	echo $foo
}

purge() {
	local tgtDir=$1
	local level=$2
	local cutoff=0

	if [ "$level" == 0 ]; then
		cutoff=365
	elif [ "$level" == 1 ]; then
		cutoff=90
	elif [ "$level" == 2 ]; then
		cutoff=30
	else
		echo "purge: invalid level"
		tellFailure
	fi

	find ${TGT_PREFIX} -name ${tgtDir}_L${level}_*.tar* -mtime +${cutoff} -exec echo "removing " {} \;
}

### Main Code
###

if [ "$#" -lt 2 ]; then
	echo "Error: too few arguments"
	usage
	tellFailure
fi
if [ "$#" -gt 2 ]; then
	echo "Error: too many arguments"
	usage
	tellFailure
fi
if ! [ -d "${SRC_PREFIX}/$1" ] && ! [ "$1" == "all" ]; then
	echo "Error: ${SRC_PREFIX}/$1 is not a directory"
	usage
	tellFailure
fi

if isNumber "$2"; then
	if [ "$2" -gt 2 ] || [ "$2" -lt 0 ]; then
		echo "Error: <backup_level> was $2; must be an integer value between \
					0 and 2 or use the word auto"
		usage
		tellFailure
	fi
	LVL=$2
elif [ "$2" == "auto" ]; then
	echo "auto backup level invoked"
	LVL=99
else
	echo "Error: <backup_level> was $2; must be an integer value between \
				0 and 2 or use the word auto"
	usage
	tellFailure
fi

SRC=$1

files=`find ${TGT_PREFIX} -name *.tar -print |perl -ne 'chomp;print scalar \
 reverse. "\n";'|cut -d / -f 1|perl -ne 'chomp;print scalar reverse. "\n";'| \
cut -d . -f 1|sort`

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
		FILESRC=`echo "$i"|cut -d '_' -f 1`
		if [ ${FILESRC} ]; then
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
					tellFailure
				fi
			fi
		fi
	done
	if [ "$L0Date" -ne 0 ]; then
		L0Size=$(getBkupSize "$SDIR" 0 "$L0Date")
		echo ${SDIR}_L0_${L0Date} $L0Size
	fi
	if [ "$L1Date" -ne 0 ] && [ "$L1Date" -ge "$L0Date" ]; then
		L1Size=$(getBkupSize "$SDIR" 1 "$L1Date")
		echo ${SDIR}_L1_${L1Date} $L1Size
	fi
	if [ "$L2Date" -ne 0 ] && [ "$L2Date" -ge "$L1Date" ]; then
		L2Size=$(getBkupSize "$SDIR" 2 "$L2Date")
		echo ${SDIR}_L2_${L2Date} $L2Size
	fi
	chooseLevel $L0Size $L1Size $L2Size
	blvl="$?"
	if [ "$LVL" -eq 99 ]; then
		LVL="$blvl"
	fi

	if [ "$SDIR" == "$SRC" ] || [ "$SRC" == "all" ]; then
		echo "Performing level ${LVL} backup of ${SRC_PREFIX}/${SDIR}"
		purge "$SDIR" "${LVL}"
		${SCRIPTROOT}/incBackup.sh ${SRC_PREFIX}/${SDIR} ${TGT_PREFIX}/${TDIR} ${LVL}
	fi
done < $CFG_FILE > $LOG_FILE 2>&1

tellSuccess
