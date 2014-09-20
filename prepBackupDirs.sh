#!/bin/sh

# No need to log since it's run by a user from a shell. They can look at stdout

PLATFORM=`uname -a | cut -d ' ' -f 1 | tr '[A-Z]' '[a-z]'`
# returns darwin for mac, linux for NAS
if [ "$PLATFORM" == "darwin" ]; then
  SCRIPTROOT=`pwd`
elif [ "$PLATFORM" == "linux" ]; then
  SCRIPTROOT=/var/services/homes/admin/AutoBackup
fi

source $SCRIPTROOT/platform.sh

# holds list of directories already created
TGT_PROCD=""

# string_contains big_string substring
# returns 0 if substring is found in big_string, 1 otherwise

string_contains (){
  local instring=$1
  local seeking=$2
  local in=1

  for element in `echo $instring | sed s/:/\\ /g`; do
	   if [ "$element" == "$seeking" ]; then
	      in=0
	      break
     fi
     done
     return $in
}

# create each target directory, then add its name to TGT_PROCD
# so that subsequent loops can tell if it's already been created

while read line; do
  SDIR=`echo $line |cut -d \  -f 1`
  TDIR=`echo $line |cut -d \  -f 2`

  if string_contains ${TGT_PROCD} $TDIR; then
	   echo $TDIR "already created, skipping..."
  else
    echo "Creating directory at" $TGT_PREFIX/$TDIR
    mkdir -p $TGT_PREFIX/$TDIR

    #directory might already exist before call to prepBackupDirs
    rm -rf $TGT_PREFIX/$TDIR/*

    # append target dir to colon-separated TGT_PROCD string
	  TGT_PROCD=${TGT_PROCD}":"${TDIR}

    echo "Creating filesystem at " $TGT_PREFIX/$TDIR
  fi

  mkdir $TGT_PREFIX/$TDIR/$SDIR
  mkdir $TGT_PREFIX/$TDIR/$SDIR/L0
  mkdir $TGT_PREFIX/$TDIR/$SDIR/L1
  mkdir $TGT_PREFIX/$TDIR/$SDIR/L2
done < $CFG_FILE
