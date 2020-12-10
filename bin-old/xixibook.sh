#!/bin/bash - 
#===============================================================================
#
#          FILE: xixibook.sh
# 
#         USAGE: ./xixibook.sh 
# 
#   DESCRIPTION: 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: ping
#  ORGANIZATION: Juniper Network
#       CREATED: 05/24/2013 11:57:00 AM EDT
#      REVISION:  ---
#===============================================================================
#
# :TODO:05/23/2013 06:29:44 PM EDT:: asking question and read input
#      if folder exist, ask user whether delete or not
#

set -o nounset                              # Treat unset variables as an error

#vars {{{1
count2=0
pair=0
montage_dir="composite2"
montagefile_prefix="c2"
existstatus_old=0
existstatus_new=0
alsocombine=1

checkemptyfolder() { #{{{1
    dir=$1 
    if find "$dir" -maxdepth 0 -empty | read; then
       echo "dir $dir is empty"
       return 0
    else
       echo "there are files in $dir, please check it"
       return 1
    fi
}

checkfolderstatus() { #{{{1
    # check if the montage folder exists (if yes if its empty) {{{1
    if [[ ! -d "$1" ]]; then 
       echo -e "no folder named $1 exists, create one."
       return 0
    else
       echo -e "a folder named $1 exists"
       checkemptyfolder $1
       if [ $? -eq 1 ]; then
           echo -e "and the folder is not empty"
           return 2
       else
           echo -e "but the folder is empty"
           return 1
       fi
    fi
}

checkfolderstatus "$montage_dir"
existstatus_old=$?

if [ $existstatus_old -eq 0 ]; then
   mkdir $montage_dir
elif [ $existstatus_old -eq 1 ]; then
   echo -e "OK to use"
elif [ $existstatus_old -eq 2 ]; then
   echo -e "won't operate on non-empty folders, exit"
   exit
fi

# composite/montage {{{1
for picture in *.pdf; do

    if test "${picture#*prefix}" = "$picture"; then
        # the file is not a prefix file

       count2=`expr $count2 + 1`
        
       if [ $count2 -eq 1 ] ; then
           picture1=$picture 
           #echo -e "get first picture $picture1"

           continue

       elif [ $count2 -eq 2 ] ; then
           picture2=$picture
           #echo -e "get 2nd picture $picture2"

           montage $picture1 $picture2 -geometry '612x792+1+1>' -frame 5 -set label '%f' -title "xixi's arts" $montage_dir/$montagefile_prefix-$pair.pdf

           #echo -e "generate combined picture in $picture1"
           pair=`expr $pair + 1`
           count2=0

       fi

    else
        # the file is a prefix file, don't combine
        cp $picture $montage_dir/
        continue
    fi

done

if [ $pair -ge 1 ] && [ $count2 -eq 1 ]; then
    echo -e "copy the last single page into $montage_dir"
    cp $picture1 $montage_dir/
fi

echo -e "............\nmontage done!\n............"

# combine/pdftk {{{1
if [ $alsocombine -eq 1 ]; then
    pdftk $montage_dir/* cat output $montage_dir/$montage_dir-all-in-one.pdf
fi

#clearning up folders {{{1
checkfolderstatus "$montage_dir"
existstatus_new=$?

if [ $existstatus_new -eq 0 ] ; then
    echo -e "nothing changed"

elif [ $existstatus_new -eq 1 ] && [ $existstatus_old -eq 0 ] ; then
    echo -e "folder $montage_dir created but empty, delete it"
    rm -rf $montage_dir

elif [ $existstatus_new -eq 2 ] ; then
    echo -e "files are generated in new folder $montage_dir, please check"
fi

