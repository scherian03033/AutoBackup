#!/bin/sh
#Usage incRestore.sh <tar_file> <tgt_dir>

TAR=gtar

usage() {
	echo
	echo "Usage: $0 <tar_file> <tgt_directory>" >&2
}

if [ "$#" -ne 2 ]; then
	echo "Error: incorrect number of arguments"
	usage
	exit 1
fi

if ! [ -f "$1" ]; then
	echo "Error: tar archive $1 does not exist"
	usage
	exit 1
fi

if ! [ -d "$2" ]; then
	echo "Error: tgt_directory $1 is not a directory"
	usage
	exit 1
fi

TARFILE=`pwd`/$1
TGTDIR=$2
HELPER=`pwd`/mpTarHelper.sh

cd ${TGTDIR}
${TAR} xvf ${TARFILE} -g /dev/null -M -F ${HELPER}
