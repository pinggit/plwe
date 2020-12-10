#!/bin/bash
#script to attach logs to a case
#
#usage: 
#attachcases LOGFILE-FULL-NAME
#LOGFILENAME: logs/vzlogs/2011-0102-1234WHATEVER.log
#or:
#go into the dir where files to be transfered are located
#e.g: attachcases 2011-0322*
#or attachcases "*"
#Note: "" is needed to escape shell expansion from command
#                pings@juniper.net   Mar 2011#
#
#
#other CLI email sending method
#/usr/sbin/sendmail -t <<EOF
#From: Mail testing <pings@juniper.net>            
#To: songpingemailbox@gmail.com
#Cc: itestitest@hotmail.com
#Bcc: spirentping@yahoo.com
#Subject: mail test
#----------------------------------
#This is the mail content ...
#---------------------------------
#EOF
#echo "Test" | mutt -s Hello pings@juniper.net
#echo "Test from script" | mutt -s Hello songpingemail@gmail.com

#dir="/home/ping/logs/verizon/"
#filetype='-name "*.log"'
#tofind="find \"$dir\" -type f $filetype
smtpd="smtp.juniper.net:587"
smtpd_gmail="smtp.googlemail.com:465"
smtpd_yahoo="localhost:50025"
from="pings@juniper.net"
from_gmail="songpingemail@gmail.com"
from_yahoo="spirentping@yahoo.com"
#to="songpingemail@gmail.com"
to="pings@juniper.net"
#to="support-private@juniper.net"
to_ba="1479817944@qq.com"
cc="support-private@juniper.net"
#cc="pings@juniper.net"
user="pings"
user_gmail="songpingemail@gmail.com"
user_yahoo="spirentping@yahoo.com"
pass="Juniper1@"
pass_gmail="Songping1#"
pass_yahoo="SpirenT"


logfiles=$1

echo -e "get file(s):$logfiles for case(s)\n"

#file type handling
ls $logfiles | while read afile;do
    caseid=$(basename $afile)
    caseid=${caseid%.*}   
    echo -e "##################case $caseid###############################\n"
    echo -e "get a file $afile\n"

    case $afile in
	*.log)
	    echo -e "this looks a log file $afile for case $caseid\n, check file info...\n"
	    subj="case $caseid log attachment"
	    content="attach the log info for case $caseid\n\n\nthanks!\nregards\nattachcase"
	    #if it's log file, extrace case ID, check the file, and send to case
	    echo -e "=======file info(partial): start====================="
	    echo -e "--case log file info:--"
	    stat -t $afile
	    echo -e "\n--case log tails:--"
	    tail $afile
	    echo -e "=======file info: end============================\n"
	    echo -e "\nready to send to case $caseid\n"
	    sendemail -s $smtpd -f $from 			\
		-t $to -cc $cc 					\
		-u $subj   					\
		-m $content  					\
		-xu $user -xp $pass -o tls=auto 		\
		-a $afile

	    echo -e "\nemail was sent with log file $afile to $to $cc!\n"
	    ;;

	*.jpg|*.JPG)
	    #if
	    echo -e "this looks a picture $afile\n"
	    subj="zhaopian"
	    content="zhaopian"

# 	    echo -e "watch the picture...\n"
#	    gnome-open $afile &
#	    pid=$!
#	    echo -e "pid of file $afile is $pid\n"
#	    sleep 3
#	    pkill eog
	    echo -e "try to send this file now\n"
	    sendemail -s $smtpd_yahoo -f $from_yahoo 		\
		-t $to_ba 					\
		-u $subj   					\
		-m $content  					\
		-xu $user_yahoo -xp $pass_yahoo -o tls=auto 	\
		-a $afile
	    echo -e "\nemail was sent with jpg file $afile to $to_ba!\n"
	    ;;
	*)
	    echo -e "not a supported file, don't do anything for other file types\n"
	    ;;
    esac
    #sleep 5
done

