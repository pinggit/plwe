#!/bin/bash - 
#===============================================================================
#
#          FILE: printver.sh
# 
#         USAGE: ./printver.sh 
# 
#   DESCRIPTION: 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Dr. Fritz Mehner (fgm), mehner.fritz@fh-swf.de
#  ORGANIZATION: FH Südwestfalen, Iserlohn, Germany
#       CREATED: 11/22/2014 14:37
#      REVISION:  ---
#===============================================================================

set -o nounset                              # Treat unset variables as an error

ver=`login -H -q -c "show version | no-more" $1 | grep -i "base os boot" | awk '{print \$5}'`
echo "router $1 is running software versoin: $ver"

