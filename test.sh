#!/bin/sh
PLATFORM=`uname -a | cut -d ' ' -f 1 | tr '[A-Z]' '[a-z]'`
# returns darwin for mac, linux for NAS
if [ "$PLATFORM" == "darwin" ]; then
	SCRIPTROOT=`pwd`
elif [ "$PLATFORM" == "linux" ]; then
	SCRIPTROOT=/var/services/homes/admin/AutoBackup
fi

source $SCRIPTROOT/platform.sh

l2=10
l0=2
#l2_div_l0=`echo $l2 '*' 100 / $l0 |bc`
l2_div_l0=`perl -e "print $l2 * 100 / $l0" \;`
echo $l2_div_l0
