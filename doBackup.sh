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

# Given the size of files at each tar level, pick appropriate next level
# for backup. If a backup file doesn't exist, 0 is passed as the size. This
# results in the conclusion that the incremental has gotten too big, which has
# the desired effect of triggering a new lower level backup.
# Note that it's not predictive based on change in the current
# backup cycle but reactive to how big previous backups have gotten.
# Cutoff is the percentage of the lower level backup size that this level
# has gotten, e.g. 20 means L1 is 20% as big as L0, so you might as well
# create a new L0 next time.

chooseLevel() {
	local l0=$1
	local l1=$2
	local l2=$3
	local cutoff=20
	local lvl=5							# 5 can never be returned, so placeholder
	local l2_div_l0=100
	local l1_div_l0=100
	local l2_div_l1=100

	# Check for div/0
	if [ "$l0" -ne 0 ]; then
		l2_div_l0=`perl -e "print int($l2 * 100 / $l0)" \;`
		l1_div_l0=`perl -e "print int($l1 * 100 / $l0)" \;`
	fi

	if [ "$l1" -ne 0 ]; then
		l2_div_l1=`perl -e "print int($l2 * 100 / $l1)" \;`
	fi

	# If either l1 or l2 have gotten too big relative to l0, do a new l0
	# If l2 is small compared to l0 but big compared to l1, do a new l1
	# Otherwise, just do another l2
	if [ "$l1_div_l0" -gt "$cutoff" ] || [ "$l2_div_l0" -gt "$cutoff" ]; then
		lvl=0
	elif [ "$l2_div_l1" -gt "$cutoff" ]; then
		lvl=1
	else
		lvl=2
	fi

	echo $lvl
}

# given a source directory, backup level and backup date, find the size of
# that particular backup by summing the size of all the tar chunks in it.
getBkupSize() {
	local filename=$1
	local level=$2
	local theDate=$3
#	echo "$filename $level $theDate"
	local fileList=`find ${TGT_PREFIX} -name \
		${filename}_L${level}_${theDate}.tar* -print`
	local foo=`ls -l $fileList | tr -s ' ' |cut -d ' ' -f 5`

	# take the above list of sizes and replace all intermediate spaces with +
	# then pass the string to perl for execution. Return resulting sum.
	local doo=`echo $foo | sed -e 's/ /+/g'`
	local bar=`perl -e "print $doo" \;`
	echo $bar
}

# Return 0 if any files in dir have changed since the modification of refFile
# Return 1 otherwise. This is used to decide whether to do a backup at all.
# If refFile doesn't exist at all, return 0 so that a first backup will be
# triggered.
changedSince() {
	local dir=$1
	local refFile=$2

	if [ -f $refFile ]; then
		# find all files newer than refFile in dir
		local fileList=`find $dir -newer $refFile -print |head -n 2`

		# if the result list is empty, no change
		if [ -z "${fileList// }" ]; then
			# no files have changed since $refFile
			return 1
		else
			echo "Files Changed:"
			echo $fileList
			return 0
		fi
	else
		# no reference file, act as if files have changed since reference
		echo "No tar files found, doing first backup."
		return 0
	fi
}

# Given a target directory and backup level, delete all files matching that
# pattern that are older than the cutoff number of days for that level.
# This purge is not aggressive enough to preserve disk space but I will let
# experience guide what the cutoffs should be set to.
purge() {
	local tgtDir=$1
	local level=$2
	local cutoff=0

#	L0 backups are kept a year, #L1s are kept 3 months, L2s are kept 1 month
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

	# purge tar files
	find ${TGT_PREFIX} -name "${tgtDir}_L${level}_*.tar*" \
		-mtime +${cutoff} -exec rm {} \;

	# purge snar files
	find ${TGT_PREFIX} -name "${tgtDir}_L${level}*.snar" \
		-mtime +${cutoff} -exec rm {} \;

	# purge logs older than 30 days
	find ${SCRIPTROOT} -name "*_*.log" -mtime +30 -exec rm {} \;
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

# Get list of tar files in target directory, minus leading path so only the
# actual filenames are returned. The perl program does a reverse since other
# utilities I'm used to aren't on both platforms.

files=`find ${TGT_PREFIX} -name *.tar -print |perl -ne 'chomp;print scalar \
 reverse. "\n";'|cut -d / -f 1|perl -ne 'chomp;print scalar reverse. "\n";'| \
cut -d . -f 1|sort`

# Save AutoBackup.log
DT=`date +%Y%m%d%H%M`

if [ -f $LOG_FILE ]; then
	mv $LOG_FILE ${LOG_FILE/.log/_$DT.log}
fi

# Loop over every line in the config file which looks like srcDir tgtDir
while read line; do
	L0Date=0
	L1Date=0
	L2Date=0
	L0Size=0
	L1Size=0
	L2Size=0
	SDIR=`echo $line |cut -d ' ' -f 1`
	TDIR=`echo $line |cut -d ' ' -f 2`

	# purge old backups at each level from this source directory
	purge "$SDIR" 2
	purge "$SDIR" 1
	purge "$SDIR" 0

	# if we weren't asked to backup this directory, skip it
	if [ "$SDIR" == "$SRC" ] || [ "$SRC" == "all" ]; then
		# walk the list of  tar files and save the latest dates at each
		# backup level for those that match this source. Not efficient
		# to walk the whole tar list for each source but I'm too lazy to
		# prune as we go
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

		# find the size of the latest backup at each lovel for this source
		if [ "$L0Date" -ne 0 ]; then
			L0Size=$(getBkupSize "$SDIR" 0 "$L0Date")
			echo "getBkupSize" ${SDIR}_L0_${L0Date} $L0Size
		fi
		if [ "$L1Date" -ne 0 ] && [ "$L1Date" -ge "$L0Date" ]; then
			L1Size=$(getBkupSize "$SDIR" 1 "$L1Date")
			echo "getBkupSize" ${SDIR}_L1_${L1Date} $L1Size
		fi
		if [ "$L2Date" -ne 0 ] && [ "$L2Date" -ge "$L1Date" ]; then
			L2Size=$(getBkupSize "$SDIR" 2 "$L2Date")
			echo "getBkupSize" ${SDIR}_L2_${L2Date} $L2Size
		fi

		# If level is set to auto, find the correct level for this backup with
		# chooseLevel, else just do the backup at the requested level.
		if [ "$LVL" -eq 99 ]; then
			echo "chooseLevel: L0Size " $L0Size "L1Size " $L1Size "L2Size " $L2Size
			BKUP_LVL="$(chooseLevel $L0Size $L1Size $L2Size)"
		else
			BKUP_LVL="$LVL"
		fi

		# find most recent backup date and corresponding tar file
		if [ "$L0Date" -gt "$L1Date" ]; then
			if [ "$L0Date" -gt "$L2Date" ]; then
				LASTTAR="${TGT_PREFIX}/${TDIR}/${SDIR}/L0/${SDIR}_L0_${L0Date}.tar"
			else
				LASTTAR="${TGT_PREFIX}/${TDIR}/${SDIR}/L2/${SDIR}_L2_${L2Date}.tar"
			fi
		else
			if [ "$L1Date" -gt "$L2Date" ]; then
				LASTTAR="${TGT_PREFIX}/${TDIR}/${SDIR}/L1/${SDIR}_L1_${L1Date}.tar"
			else
				LASTTAR="${TGT_PREFIX}/${TDIR}/${SDIR}/L2/${SDIR}_L2_${L2Date}.tar"
			fi
		fi

		echo "Most recent backup was ${LASTTAR}"

		# Check backups exist at lower levels before doing incremental
		if [ "$BKUP_LVL" -gt 1 ]; then
			if [ "$L1Size" -eq 0 ]; then
				echo "Missing L1 backup, exiting..."
				tellFailure
			fi
		fi
		if [ "$BKUP_LVL" -gt 0 ]; then
			if [ "$L0Size" -eq 0 ]; then
				echo "Missing L0 backup, exiting..."
				tellFailure
			fi
		fi

		# Only do backup if files changed since $LASTTAR
		changedSince ${SRC_PREFIX}/${SDIR} ${LASTTAR}
		if [ $? -eq 0 ]; then
			echo "Performing level ${BKUP_LVL} backup of ${SRC_PREFIX}/${SDIR}"
			${SCRIPTROOT}/incBackup.sh ${SRC_PREFIX}/${SDIR} ${TGT_PREFIX}/${TDIR} ${BKUP_LVL}
			if [ $? -ne 0 ]; then
				tellFailure
			fi
		else
			echo "$SDIR: no files changed, backup skipped"
		fi
	fi
	# space between logs for each row in cfg file
	echo
done < $CFG_FILE > $LOG_FILE 2>&1

if [ -d ${SYNC_DIR} ]; then
	rsync -avz --update -delete ${TGT_PREFIX}/ ${SYNC_DIR}
	tellSuccess
else
	echo "Sync Directory does not exist"
	tellFailure
fi >> $LOG_FILE 2>&1
