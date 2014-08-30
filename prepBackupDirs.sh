#!/bin/sh

PLATFORM=`uname -a | cut -d ' ' -f 1 | tr '[A-Z]' '[a-z]'`
# returns darwin for mac, linux for NAS
if [ "$PLATFORM" == "darwin" ]; then
  SCRIPTROOT=`pwd`
elif [ "$PLATFORM" == "linux" ]; then
  SCRIPTROOT=/var/services/homes/admin/AutoBackup
fi

source $SCRIPTROOT/platform.sh

TGT_PROCD=""

string_contains (){
  local instring=$1
  local seeking=$2
  local in=1

#  echo instring $instring seeking $seeking

  for element in `echo $instring | sed s/:/\\ /g`; do
	   if [ "$element" == "$seeking" ]; then
	      in=0
	      break
     fi
     done
     return $in
}

while read line; do
  SDIR=`echo $line |cut -d \  -f 1`
  TDIR=`echo $line |cut -d \  -f 2`

#  echo $SDIR $TDIR

  if string_contains ${TGT_PROCD} $TDIR; then
	   echo $TDIR "already created, skipping..."
  else
    echo "Creating directory at" $TGT_PREFIX/$TDIR
    mkdir -p $TGT_PREFIX/$TDIR
    rm -rf $TGT_PREFIX/$TDIR/*
    echo "Creating filesystem at " $TGT_PREFIX/$TDIR
	  TGT_PROCD=${TGT_PROCD}":"${TDIR}
#    echo TGT_PROCD is ${TGT_PROCD}
  fi
  mkdir $TGT_PREFIX/$TDIR/$SDIR
  mkdir $TGT_PREFIX/$TDIR/$SDIR/L0
  mkdir $TGT_PREFIX/$TDIR/$SDIR/L1
  mkdir $TGT_PREFIX/$TDIR/$SDIR/L2
done < $CFG_FILE
