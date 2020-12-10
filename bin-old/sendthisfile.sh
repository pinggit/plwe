#!/bin/bash
#v1: {{{1

#this break after upgrading to 12.04LTS
#cat "$1" | uuencode "$1" | mail -s "file:$1, from ping's PC" $2 -b "pings@juniper.net"
#adding these 2 lines partially solved, but still not work, seems need some config
unset GNOME_KEYRING_CONTROL
unset GNOME_KEYRING_PID

#v2: {{{1
#usage:
#sendthisfile.sh [filename|-] [to-email] {case#}

#todo {{{2
#add usage warning {{{3
#E_WRONG_ARGS=85
#script_parameters="-a -h -m -z"
#if [ $# -ne $Number_of_expected_args ]
#then
#    echo "Usage: `basename $0` $script_parameters"
#    exit $E_WRONG_ARGS
#fi

#this always works!
smtpserver=pod51010.outlook.com:587
from="pings@juniper.net"
username="pings@juniper.net"
password="!QA2ws3e"
#to="songpingemail@gmail.com"
#to="pings@juniper.net"
bcc="pings@juniper.net"
to="$2"
filename=$1

#if casenumbe provided as $3, use it as new subject
if [ -n "$3" ]; then
    echo -e "subject provided:$3"
    subject="from:$from: attached file:$filename with message:$3"
else
    subject="from:$from: attached file:$filename"
fi

body=$subject

if [ $1 == '-' ]; then
    echo -e " - as filename, read from stdin.."
    echo -e "will send email w/o attachment"
    # Declare an array to store stdin
    #declare -a ARRAY

    #read from stdin
#    while read LINE; do
#	ARRAY[$count]=$LINE
#	((count++))
#	#insert a line return,need a better solution here
#	#ARRAY[$count]="\n"
#	#((count++))
#    done

    # echo array's content
    #echo "input texts:"
    #echo ${ARRAY[@]}
    #echo "-- contains totally ${#ARRAY[@]} lines"

    #body="${ARRAY[@]}"
    subject="from:$from: with message:$3"
    body=`cat`
    sendemail -s $smtpserver -f $from -t $to -bcc $bcc -u $subject -m "$body" -xu $username -xp $password -o tls=auto

else
    echo -e "filename provided, will attach to email"
    sendemail -s $smtpserver -f $from -t $to -bcc $bcc -u $subject -m "$body" -xu $username -xp $password -o tls=auto -a $filename
fi

