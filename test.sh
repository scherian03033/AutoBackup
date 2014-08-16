#!/bin/sh
. ./platform.sh

l2=10
l0=2
#l2_div_l0=`echo $l2 '*' 100 / $l0 |bc`
l2_div_l0=`perl -e "print $l2 * 100 / $l0" \;`
echo $l2_div_l0
