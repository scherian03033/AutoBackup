#!/bin/sh
#Usage incBackup.sh <source_dir> <tgt_dir> <level>

source ./platform.sh

usage() {
  echo
  echo "Usage: $0 <src_directory> <tgt_directory> <backup_level>" >&2
  echo "  where backup_level is between 0 and 2 inclusive" >&2
}

if [ "$#" -lt 3 ]; then
  echo "Error: too few arguments"
  usage
  tellFailure
fi
if [ "$#" -gt 3 ]; then
  echo "Error: too many arguments"
  usage
  tellFailure
fi
if ! [ -d "$1" ]; then
  echo "Error: $1 is not a directory"
  usage
  tellFailure
fi
if ! [ -d "$2" ]; then
  echo "Error: $2 is not a directory"
  usage
  tellFailure
fi

if [ "$3" -gt 2 ] || [ "$3" -lt 0 ]; then
  echo "Error: <backup_level> was $3; must be an integer value between 0 and 2"
  usage
  tellFailure
fi

SRC=$1
TGT=$2
LVL=$3
DATE=`date +%Y%m%d%H%M`
STRIP_SRC=`echo $SRC | perl -ne 'chomp;print scalar reverse. "\n";' | \
  cut -d/ -f1 | perl -ne 'chomp;print scalar reverse. "\n";'`

# Create backup directory if it doesn't exist
if  ! [ -d $TGT/${STRIP_SRC}/L${LVL} ]; then
  echo "L${LVL} directory does not exist:" ${TGT}/${STRIP_SRC}/L${LVL} ", Creating..."
  mkdir ${TGT}/${STRIP_SRC}/L${LVL}
fi

# For Level 0 backups, save snar file if it exists. An L1 or L2 may
# depend on it.

if [ $LVL -eq 0 ]; then
  echo "level 0 backup"
  if [ -f ${TGT}/${STRIP_SRC}/${STRIP_SRC}_L${LVL}.snar ]; then
#    rm ${TGT}/${STRIP_SRC}/${STRIP_SRC}_L${LVL}.snar
    mv ${TGT}/${STRIP_SRC}/${STRIP_SRC}_L${LVL}.snar \
     ${TGT}/${STRIP_SRC}/${STRIP_SRC}_L${LVL}_${DATE}.snar
  fi
  SNAR_LVL=${LVL}

# For L1 or L2 backups, they will build on the snar file of the lower
# level, so set SNAR_LVL accordingly.
elif [ $LVL -eq 1 ]; then
  echo "level 1 backup"
  SNAR_LVL=`expr ${LVL} - 1`
elif [ $LVL -eq 2 ]; then
  echo "level 2 backup"
  SNAR_LVL=`expr ${LVL} - 1`
else
  echo "unknown backup level $3, exiting..."
  tellFailure
fi

#echo $SRC $TGT $LVL $SNAR_LVL $DATE $STRIP_SRC

# If L0 backup, a new snar file is being created. If L1 or L2
if [ "$SNAR_LVL" -ne "$LVL" ]; then
# if snar file exists at LVL, save it to a new name before overwriting it.
  if [ -f ${TGT}/${STRIP_SRC}/${STRIP_SRC}_L${LVL}.snar ]; then
    mv ${TGT}/${STRIP_SRC}/${STRIP_SRC}_L${LVL}.snar \
     ${TGT}/${STRIP_SRC}/${STRIP_SRC}_L${LVL}_${DATE}.snar
  fi
  cp ${TGT}/${STRIP_SRC}/${STRIP_SRC}_L${SNAR_LVL}.snar \
   ${TGT}/${STRIP_SRC}/${STRIP_SRC}_L${LVL}.snar
fi

${TAR} -g ${TGT}/${STRIP_SRC}/${STRIP_SRC}_L${LVL}.snar -M -L ${CHUNK} -F ./mpTarHelper.sh -cvpf ${TGT}/${STRIP_SRC}/L${LVL}/${STRIP_SRC}_L${LVL}_${DATE}.tar ${SRC}

echo "incBackup Done"
