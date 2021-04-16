#!/usr/bin/env expect
#this may it a bit more portable
#
#a script to (partially) simulate secureCRT funtions 
#
#main features available currently:  						#
#    anti-idle 									#
#    auto-login (with retry) 							#
#    name-to-host resolving 							#
#    quick keystroke cmds under interact mode(after a successful login) 	#
#    loggings 									#
#    	change log file in real time, 						#
#    	email current log file to user (or update case),as attachement 		#
#    	attachment can be either plain text or optionally in zip format		#
#    execution of user-defined cmds,in desired sequence 			#
# 	cmds can be grouped 							#
# 	cmds can be executed repeatedly in user-defined number of loops		#
#    	cmd lists can be modified/updated w/o disconnecting current session 	#
#    	clock(timestamp of the cmd execution) can be prefixed for each cmd 	#
#    	send logs as email attachment, right away, or at a later time 		#
#    execution of user-defined pattern-action list 				#
#       dealing with changing/arbitrary prompts 				#
#     	one example work done by this feature is the coredump analysis 		#
#     	(file search,upload,telnet,decompress,decode,reformat, 			#
#     	email to user/case, etc)	 					#
#    misc. 									#
# 	... 									#
# 	
#
#work done:
#    some basic features are done 
#
#    
#issues/concerns:
#    this script was mostly done using the corner/spare time, extended from
#    a temporary script which was not designed to do the current work, that said
#    here are the limitations/issues:
#    1) no good design from start, user commands (!NNN) are not consistent
#    	too much duplicate codes
#    2) too much dirty code to save time, make it not quite efficient
#    	(global var, test/temporary/arbitrary/shortcut codes)
#    3) no strong error detections/preventions, the script will only work
#       with the way it was supposed to...
#    4) some features are not fully tested, might be buggy
#
#
#more time is needed to rewrite with cleaner codes...
# 		pings@juniper.net 
#
# 		Sun Mar 13 16:31:55 EDT 2011
#
#the script is running good with simple jobs based on daily usage
#decision was made to stop coding unless REAL necessary
# 		Fri Apr 22 13:41:48 EDT 2011


#global vars 
global cmds login_info CGS 
global initlog_file host 
global caseid_from_argv dmpfilebasename_from_argv

#get script basename
set scriptbasename [exec basename $argv0]
#get the prefix before "."
regexp {(.*)\..*} $scriptbasename -> scriptbasename_pref 

#some tests
#puts "script full name:-$argv0-"
#puts "script base name:-$scriptbasename-"
#puts "script base name prefix:-$scriptbasename_pref-"

#config file by def is located under the folder named by the script name
set configfile "~/.$scriptbasename_pref/$scriptbasename_pref.conf"
#set configfile "~/.mylogin/mylogin.conf"


#modifed puts: add timestamp and procedure name for every user message printed on the terminal
proc myputs {msg} {
    puts "\[[exec date]:[lindex [info level 1] 0]:..$msg..\]"
}

#function to execute given system CLI(s)
#previously report file/dir doesn't exists. tcl exec really sucks!
#looks need that {expand} or eval exec story to make it work
proc myexec {cmd} { 
    if { 							\
	[catch  						\
	    {eval exec 						\
		$cmd 						\
	    }  							\
	    msg 						\
	] 							\
	} {
       myputs "Something seems to have gone wrong:"
       myputs "Information about it: $::errorInfo"
       return 1
    } else {
	return 0
    } 
}

#add some error detection to log_file func
proc mylog_file {cmd} {
    if { 							\
	[catch  						\
	    { 							\
		log_file $cmd 					\
	    } 							\
	    msg 						\
	] 							\
	} {
       myputs "log name is probably not valid: $::errorInfo"
       return 1
    } else {
	return 0
    }
}

#send an email,with caseid as title and log files as attachment
#if use zip, multiple files can be included, otherwise only 1 file is supported
    #0) use {expand} to make the globbed staff as individual parameters!!
    #  otherwise when glob get 2 file name there will be some strange errors!
    #1) glob is required here to expand unix ~ or * in exec
    #2) at least "zip"/"uuencode" and "mail" tools need to be a/v locally
    #3) -q(quiet mode) in zip is required,
    #	otherwise some error will be catched, email get sent smoothly though
    #use catch to catch/skip the error and continue
#procedure with default value,simpler than varible-length params precedure
proc sendanemail {caseid file emailto args} {

    global DEBUG
    global zip
    #get file from glob (like unix)
    set files [glob $file]
    if $DEBUG {myputs "get file lists: $files"}
    #if {[file exists [glob file]]} {
	if $zip {
	    if $DEBUG {myputs "zip set, will send zipped file"}
	    set attachname "$caseid.zip"

	    if {[llength $args]} {
		set emailcc [lindex $args 0]
		set execcmd "zip -jq - {expand} [glob $file] | uuencode $attachname | mail -s \"log of case:$caseid\" -c $emailcc $emailto"
	    } else {
		set execcmd "zip -jq - {expand} [glob $file] | uuencode $attachname | mail -s \"log of case:$caseid\" $emailto"
	    }

	} else {
	    set attachname [exec basename $files]
	    if $DEBUG {myputs "zip not set, will send plain text file"}
	    #looks only 1 file is support at a time with uuencode
	    if {[llength $args]} {
		set emailcc [lindex $args 0]
		set execcmd "uuencode [glob $file] $attachname | mail -s \"log of case:$caseid\" -c $emailcc $emailto"
	    } else {
		set execcmd "uuencode [glob $file] $attachname | mail -s \"log of case:$caseid\" $emailto"
	    }
	}

	#funny tcl rule, non-matching {} in comments seems also hit an error
#    if { 							\
#	[catch  						\
#	    {exec  						\
#		zip -jq - {expand} [glob $file]  		\
#		    | uuencode $caseid.zip  			\
#		    | mail -s "log of case:$caseid"  		\
#			-b $emailcc $emailto 			\
#	    }  							\
#	    msg 						\
#	] 							\
#	} {
#       myputs "Something seems to have gone wrong:"
#       myputs "Information about it: $::errorInfo"
# 	}
	if {[myexec $execcmd]} {
	} else {
	    if {[llength $args]} {
		set emailcc [lindex $args 0]
		myputs "send email to $emailto (and cc $emailcc) with logfile:$files as attachment:$attachname"
	    } else {
		myputs "send email to $emailto with logfile:$files as attachment:$attachname"
	    }
	}
#    } 
#   else {
#	myputs "log file $file doesn't exist!"
#    }
}


proc usage {} {
    #$argv0 as script name become a private var here in proc w/o global
    global argv0
    myputs "Usage:$argv0 ssh|telnet|ftp|... PARAMS_LISTS"
}

#use this as a more informative expect function
#return 0 if got successful map. useful for result checking purpose
proc myexpect {usermsg pattern datasent timeout} {
#if pattern match, send data
    global DEBUG
    global quitontimeout quitkey
    if $DEBUG {myputs "-$usermsg-,start expecting pattern:-$pattern- to proceed with sending -$datasent-"}
    expect {
	-re "$pattern" {
	    #looks very important. look \r is more reliable across OS.as suggested in expect books 
	    #\n is ok for my linux, but not work for win goodtech telnetd
	    send "$datasent\r"
	    if $DEBUG {myputs "get good match for -$pattern- with -$expect_out(0,string)-,sent -$datasent\\\r-"}
	    return 0
	}

	timeout {
	    if $DEBUG {myputs "timeout in $timeout seconds:no match for -$pattern-,data -$datasent- not sent"}
	    #this is useful when the last cmd get stuck there and could be exited out of
	    #using some key, like "q"
	    if $quitontimeout {
		if $DEBUG {myputs "quit last suspended cmd before preceeding"}
		send "$quitkey"
	    }

	    return 1
	}
    }
}

#use only when there are logon info for large amount of remote host, 
#when they can be put into a sperate/dedicated logon file.
#
#retrieve login info from a file and get it structured for use
#upvar (ref in tcl) is used here to pass value back from proc
#login_info is a global multi-dimensional array
# login_info(hostname1 pattern1) = data1
# login_info(hostname1 pattern2) = data2
# .
proc get_login_info {loginfile login_info} {
    #ref it
    global DEBUG
    upvar $login_info a
    myputs "grab login info from file $loginfile-"
    myputs "open file $loginfile" 
    set file [open $loginfile r]
    set cmd_no 0
    while {[gets $file line] != -1} {
	if $DEBUG {myputs "get a line from file:-$line-"}
	#save the splitted line into a list
	set l1 [split $line " "]
	if $DEBUG {
	    myputs "this line is splitted into:"
	    myputs "  -$l1-"
	}
	#get the 1st member out of the line,as hostname
	set hostname [lindex $l1 0]
	#get the remainder as login info
	set pa_pair [lrange $l1 1 end]
	#convert the login list to an array (tcl, hash in perl)
	set a($hostname) $pa_pair
    }
    close $file
#   return $cmd_no 
}

#auto login script
#here global array is used directly for simplicity, 
#saving one proc param and upvar stuff
proc do_patterns_actions {host pattern_timeout dataarray pa_intv} {
    global DEBUG addclock send_initial_cr
    upvar $dataarray da
    if $DEBUG {myputs "start pattern-action sequence"}
    if $DEBUG {parray da}
    if $send_initial_cr {send "\r"}
    if {[info exists da($host)]} {
	if $DEBUG {myputs "pattern-action data for $host now looks:"}
	if $DEBUG {myputs "  -$da($host)-"}
    } else {
	myputs "pattern-action data for $host doesn't exist, check your config!"
	return 1
    }

#   this won't work for duplicate patterns
#   set i 1
    #array set pa_pair $login_info($host)
#    foreach pattern [array names pa_pair] {
#	set datasent $pa_pair($pattern)
#	myexpect "pattern-action item $i\n" $pattern $datasent	
#	incr i
#    }
    #get a data list from data array
    set l $da($host) 
    set j 0
    #go through this data list
    for {set i 0} {$i<=[expr [llength $l]-1]} {incr i 2} {
	#get pattern/data
	set pattern [lindex $l $i]	
	set datasent  [lindex $l [expr $i+1]]
	#execute the pattern-data pairs
	if $addclock {
	    if $DEBUG { myputs "send a clock" }
	    send "$clockcmd\r"
	}
	myexpect "pattern-action item $j" $pattern $datasent $pattern_timeout	
	#if $DEBUG {myputs "pattern-action item $j"}
	#do_cmd $pattern $datasent $pattern_timeout
	incr j
	#optionally pause between each step
	sleep $pa_intv
    }

    #this is to garrantee we can get the prompt for the last cmd to finish
    #otherwise the output of it will be held unless next cmd was inputted
    #this works in most cases:
    #myexpect "extra return" $pattern "\r" $pattern_timeout
    #but this is better:
    myexpect "extra return" ".*" "\r" $pattern_timeout
}

proc repeat_patterns_actions {maxrounds host pattern_timeout dataarray pa_intv} {
    myputs "$maxrounds rounds of patterns_actions_list will be executed"
    set i 1
    upvar $dataarray ref
    while {$i<=$maxrounds} {
	do_patterns_actions $host $pattern_timeout ref $pa_intv
	myputs "\n\n..#####################################..\n"
	myputs "this is rounds $i of patterns_actions_list execution..\n"
	myputs "..#####################################..\n\n"
	
	#this doesn't work
#	trap {send_user "bye"; exit} SIGINT
	incr i 
    }
}

#set PAGS(e320-1) 		{pa_list1 pa_list2}
#set pa_list1(HRNDVA-FIOS-2) 	{# "config t" config "do show clock" config exit}
#set pa_list2(HRNDVA-FIOS-2) 	{# "config t" config "do show red" config exit}
#set pa_list1(e320-1) 		{# "config t" config "do show clock" config exit}
#set pa_list2(e320-1) 		{# "config t" config "do show red" config exit}
#this function is depressed by its new version and hence obsolete
proc do_pags_original_obsolete {pags host pattern_timeout pa_intv} {
    
    global DEBUG NEWFEATURE
    #pass the array via upvar (ref)
    upvar $pags PAGS
    if $DEBUG {myputs "get pattern action groups from list(PAGS):-$PAGS($host)-"}

    foreach pa_group $PAGS($host) {
	#this worked, but ugly, in terms of using global var like this
	if $DEBUG {myputs "get a pa_group $pa_group"}
	if $DEBUG {myputs "executed eval global $pa_group"}
	eval global $pa_group
	
	do_patterns_actions $host $pattern_timeout $pa_group $pa_intv
    }
}


proc do_pags {pags host pattern_timeout pa_intv} {
    
    global DEBUG NEWFEATURE configfile 
    #pass the array via upvar (ref)
    upvar $pags PAGS
    if $DEBUG {myputs "get pattern action groups from :-$PAGS($host)-"}

    #source $configfile

    if {[regexp "^E_" $pags]} {
	if $DEBUG {myputs "this pa_group $pa_group is end 'leaf' node,execute it..."}
	do_patterns_actions $host $pattern_timeout $PAGS $pa_intv 
    } else {
	foreach pa_group $PAGS($host) {
	    if {[regexp "^E_" $pa_group]} {
		#this worked, but ugly, in terms of using global var like this
		#
		if {[info exists pa_group($host)] == -1} {
		    myputs "the pattern action group $pa_group is not configured,check your config!"
		} else { 
		    if $DEBUG {myputs "get a pa_group $pa_group"}
		    if $DEBUG {myputs "executed eval global $pa_group"}
		    eval global $pa_group
		    if $DEBUG {myputs "this pa_group $pa_group is end 'leaf' node,execute it..."}
		    do_patterns_actions $host $pattern_timeout $pa_group $pa_intv 
		    #unset $pa_group
		}
	    } else {
		if {[info exists pa_group($host)] == -1} {
		    myputs "the pattern action group $pa_group is not configured,check your config!"
		} else { 
		    if $DEBUG {myputs "get a pa_group $pa_group"}
		    if $DEBUG {myputs "executed eval global $pa_group"}
		    eval global $pa_group
		    if $DEBUG {myputs "this pa_group $pa_group contains more sub-groups,resolve further..."}
		    do_pags $pa_group $host $pattern_timeout $pa_intv
		}
	    }
	}
    }
}

proc repeat_pags {maxrounds pags host pattern_timeout pa_intv} {
    myputs "$maxrounds rounds of pattern action groups will be executed"
    upvar $pags PAGS
    set i 1
    while {$i<=$maxrounds} {
	do_pags PAGS $host $pattern_timeout $pa_intv
	puts "\n\n..#####################################..\n"
	puts "this is rounds $i of pattern action group..\n"
	puts "..#####################################..\n\n"
	
	#wanted to stop the loop anytime,this doesn't work yet
#	trap {send_user "bye"; exit} SIGINT
	incr i 
    }
}

proc do_autologin_retry {max_login_retry success_login_pattern login_timeout pa_intv} {
    global login_info
    set i 1
    while {$i<=$max_login_retry} {
    #check the login result to see if a retry is needed
    #again, tcl syntax: \\~ for ~ ; \\$ for $, \\\\ for \, etc.. to match ping@640g-laptop:~$
    #set success_pattern "laptop:\\~*\\$"
	set autologin_fail [myexpect "check if login success after retry $i" $success_login_pattern "\r" $login_timeout]
	#if failed, but still within retry limit, retry login
	if $autologin_fail {
	    puts "..last login failed..will retry $i/$max_login_retry time(s) \n"
	    do_patterns_actions $hostname $login_timeout login_info $pa_intv
	} else {
	    #if get through, go out of loop and continue
	    set login_retry_fail 0
	    break
	}
	#if max retry is reached,go interact
	if {$ieq$max_login_retry} {
	    puts "..max login retry times($max_login_retry) reached..\n"
	    set login_retry_fail 1
	}
	incr i 
    }

    return $login_retry_fail

}

#execute a single command, with patience of a given time
proc do_cmd {pattern cmd timeout1} {
#if use do_cmd {...timeout}, then
#no need to set explicitly due to the sepcialty of var timeout in proc param
#   set timeout $timeout1 	- this is no need
#but for simplicity we can bypass this machnism and use another var name like timeout1

    global DEBUG NEWFEATURE addclock clockcmd prefix_cr_for_each_cmd
    #this is to garantee we got the right prompt before proceed
    #don't know why, but the clockcmd lose 1st CHs from time to time
    #use these non-sense stuff to feed that
    #send "!!!!"
    #
    if $prefix_cr_for_each_cmd {send "\r"}


    if $addclock {
	if $DEBUG { myputs "send a clock" }
	send "$clockcmd\r"
    }

    if $DEBUG {
	myputs "next cmd:-$cmd-"
	myputs "will check prompt for cmd -$cmd-"
    }

    set result [myexpect "checking prompt for -$cmd-" $pattern $cmd $timeout1]
    return result
}


#get cmds out of cmds file, use global var(no ref) to pass value back
proc get_cmds {cmdsfile cmds} {
    global DEBUG
    upvar $cmds a
    myputs "grab cmds from file $cmdsfile-"
    myputs "open file $cmdsfile" 
    set file [open $cmdsfile r]
    set cmd_no 0
    while {[gets $file line] != -1} {
	if ($DEBUG) {myputs "get a line from file:-$line-"}
	set a($cmd_no) $line
	incr cmd_no
    }
    close $file
    return $cmd_no 
}


#get cmds from either config file,or n/a, from another file, 
#here use global var to get value from proc
proc loaddata {datafile data_type data} {
    global DEBUG cmds login_info
    upvar $data a

    if {[array size a] eq 0} {
	if {[catch {source $datafile} msg]} {
	    #file is not in tcl syntax
	    puts "file $datafile is not with correct syntax"
	    puts "..try to read each line as pure $data_type"

	    if {$data_type eq "cmds"} {
		get_cmds $datafile cmds
	    } else {
		get_logininfo $datafile login_info
	    }

	} else {
	    puts "file $datafile is with good syntax, well loaded"
	}
    } else {
	if $DEBUG {puts "got data already(from config file),no need to read/source file $datafile"}
    }
    if $DEBUG {
	myputs "got following $data_type"
	parray a
    }
}



#executes commands in batch, with given interval bet each cmd
#use upvar(ref) to pass array as a parameter
#w/o ref seems not working
proc do_cmds {pattern cmds cmd_interval waittime} {
    global DEBUG send_initial_cr
    upvar $cmds ref
    if $DEBUG {
	myputs "start to do_following batch cmds:"
	parray ref
    }

    set i 0
    if $send_initial_cr {send "\r"}
    #by def tcl will use ascii sequence to sort the list
    #resort the array index/key w/ numerically increasing order is more convenient to control the cmd orders
    foreach cmd_no [lsort -integer [array name ref]] {
	incr i
	set onecmd $ref($cmd_no)
	#if no value, just skip and do nothing, otherwise send it
	#it looks these compare agaist empty is not necessary in tcl
	if {[string compare $onecmd ""] eq 0} {
	    if $DEBUG {myputs "NO$i:ID$cmd_no:get an empty cmd,skip it and do nothing"}
	} else {
	    if $DEBUG {myputs "NO$i:ID$cmd_no:get an cmd:$onecmd,send it"}
	    do_cmd $pattern $onecmd $waittime
	    sleep $cmd_interval
	}
    }
    #this is to garrantee we can get the prompt for the last cmd to finishe
    #otherwise the output of it will be delayed!
    do_cmd $pattern "\r" $waittime
}

#execute a list of cmds groups, recursively
proc do_cmds_groups {pattern cmds_group_list cmds_groups_intv cmd_interval waittime} {
    global DEBUG NEWFEATURE configfile
    #since CGS is a list, not an array, so passing it like a var
    #no need upvar(for array this is needed)
    #upvar $CGS ref

    if $DEBUG {myputs "start to get cmds groups from cmds_groups_list:-$cmds_group_list-"}
    #set CGS {ospf isis}
    #dirty, but working method, to get exact update of each cmd_group(ospf, isis)
    #may introduce too much unuseful vars into this proc
    source $configfile
	
    foreach cmds_group $cmds_group_list {
	
	if $DEBUG {myputs "get a group $cmds_group"}

	#this worked, but ugly, in terms of using global var like this 
	#to get cmds_group, eg. ospf, isis
	#if $DEBUG {myputs "executed eval global $cmds_group"}
	#eval global $cmds_group
	if {[regexp "^E_" $cmds_group]} {
	    if $DEBUG {myputs "$cmds_group is an end leaf node"}
	    do_cmds $pattern $cmds_group $cmd_interval $waittime
	} else {
	    if $DEBUG {myputs "$cmds_group is not an end node,resolve further..."}
	    do_cmds_groups $pattern [set $cmds_group] $cmds_groups_intv $cmd_interval $waittime
	}
	
	if $NEWFEATURE {
	foreach cmd_no [lsort -integer [array name [set cmds_group]]] {
	    #set ospf(0) 			"show ip ospf"
	    #set ospf(1) 			"show ip ospf nei"
	    #use [set var] to do some eval-like work inside some code
	    if $DEBUG {myputs "get #$cmd_no cmd:[set [set cmds_group]($cmd_no)] from the group"}
	    do_cmd $pattern [set [set cmds_group]($cmd_no)] $waittime
	    sleep $cmd_interval
	}

	sleep $cmds_groups_intv

	}
    }

}

proc repeat_cmds {maxrounds pattern4cmd cmds cmds_intv cmd_timeout} {
    myputs "$maxrounds rounds of cmds will be executed"
    set i 1
    upvar $cmds ref
    while {$i<=$maxrounds} {
	do_cmds $pattern4cmd ref $cmds_intv $cmd_timeout
	myputs "\n\n..#####################################..\n"
	myputs "this is rounds $i of cmds set..\n"
	myputs "..#####################################..\n\n"
	
	#this doesn't work
#	trap {send_user "bye"; exit} SIGINT
	incr i 
    }
}

proc repeat_cmds_groups {maxrounds pattern4cmd 				\
		CGS round_intv cmds_groups_intv 			\
		cmds_intv cmd_timeout} {
    myputs "$maxrounds rounds of cmds groups will be executed"
    set i 1
    #upvar $cmds ref
    while {$i<=$maxrounds} {
	do_cmds_groups $pattern4cmd $CGS $cmds_groups_intv $cmds_intv $cmd_timeout
	myputs "\n\n....\n"
	myputs "rounds $i/$maxrounds..will continue after $round_intv seconds...\n"
	myputs "....\n\n"
	
	#wanted to stop the loop anytime,this doesn't work yet
#	trap {send_user "bye"; exit} SIGINT
	incr i 
	sleep $round_intv
    }
}

proc do_confirm {} {
    myputs "you sure you want to do that?(y/n)"
    stty raw
    expect_user {
	"y" {return 1}
	"n" {return 0}
    }
}

proc do_sel {} {
    myputs "start sel data collections"
#    if $NEWFEATURE {
    if {[do_confirm]} {
	send "date\n"
    } else {
	myputs "sel data collections cancelled"
    }
#    }
}

proc do_showtech {} {
}

proc diag_on_error {} {
}

#interact mode,return control to user if all work done/failed
proc do_interact {code} {


    #hostname here is only needed when invoke script with local shell
    #zip need to be global here, otherwise "global" in sendanemail won't
    #take effect
    global configfile hostname host initlog_file zip CGS

    #currently no use
    global caseid_from_argv dmpfilebasename_from_argv

    #global stuff real sucks, I know, but just for simplicity for now..
    #global NEWFEATURE DEBUG CGS caseid_pattern
    #global mylog_file configfile redosource hostname pa_intv caselog_file
    #global pattern4cmd precmds cmds cmds_intv cmd_timeout maxrounds

    #most cases re-"source" config file reduces global vars
    #but it won't garentee all vars in configfile be updated correctly
    #example: in config file:
    #1)set ospf(0) abc;set ospf(1) 123
    #change ospf(0) to def, and delete ospf(1) in config file,
    #now re-"source" here only update ospf(0), but won't delete ospf(1) as expected
    source $configfile
    set n 0

#    code:
#    enter from point0: spawn a local shell
#    enter from point1: autologin fail and force into
#    enter from point2: autologin fail, user confirm to
#    enter from point3: login ok,and before batch cmds
#    enter from point4: all done
#    enter from point5: no autologin
#
    
    switch -- $code \
    0 {
	set reason "spawn a local shell"
    } 1 {
	set reason "autologin failed,force flag set to go interact"
    } 2 {
	set reason "autologin failed,user confirmed to go"
    } 3 {
	set reason "autologin succeed,flag set to go interact"
    } 4 {
	set reason "all work done, flag set to go interact"
    } 5 {
	set reason "no autologin flag set to go interact"
    }

    if $DEBUG {myputs "go to interact mode on reason:$reason"}
    myputs "
    welcome to mylogin shell! it's an clone(spawn) of bash plus some new customized shortcut commands
    the intention is to help JTAC day-to-day work. But it can also be used for ANY other usual tasks 
    wherever the origin shell(e.g bash) was used, plus now we have logging, anti-timeout, and other features.
    type !i for currently available cmds, !h for most frequently used cmds, and !T for a mini tutorial
    enjoy it!

                                                              -v0.2 	pings@juniper.net"

    #start currlog_file value from initlog_file, which, was acquired in the very beginning
    #moment of the config file reading when the script was just running
    #this is to avoid the dynamic nature of the config file, especially the timebased file naming
    #so source config file again won't change currlog_file anymore
    set currlog_file $initlog_file

    set log_started $log_when_start

    #initially newcaseid is same as caseid in config file, but it will change per user cmds
    set newcaseid $caseid
    #initial caseid and caselog were preserved for some use:mostly to generate full name 
    #of a new log file by replacing initcaseid with a new caseid, based on 
    #full name of the initial caselog file
    set initcaseid $caseid
    set initcaselog_file $caselog_file

    set newdmpfilebasename $dmpfilebasename
    
    stty -raw
    interact {
	#wait for match from user, if timeout then send a blank then delete it
	#this bring an anti-idle feature
	timeout $anti_idle_timeout {
	    send $anti_idle_string
	}
	#
	#under interact mode, use some keystroke cmds to instruct
	#script to do some other automations
	#-echo make keystokes matching listed patterns also display
	#side effect is duplicate display if partial pattern were being inputted
	#use ! to make these patterns unlikely to be accidently duplicated with other cmds for spawned app
	
	-echo -re "!i" {
	puts "\navailable cmds under interact mode:"
	puts "
	EXCUTIONS: 							ATTACHING (logs/coredump decode):                           	
	    --execute precmds--                                         !alx(x:m/c/b)	(a)ttach curr (l)og:$currlog_file 
		!eP 	(e)xcute actions in '(p)rework'                     with caseid $caseid (via email)
		pattern-action-list                                     !alm 	email to me($emailme) only
	    !ep 	(e)xecute cmds in (p)recmds list            	!alc 	email to case($emailcase) only
		(term len/width/etc)                                    !alb 	email to both $emailme and $emailcase
									!alt a@b email to a@b.com, t.b.c
	    --execute/repeat(and email logs of) commands--              !adx	(A)ttach decoded coredump 
	    --in 'cmds','CGS'--                                             files under /mnt/coredumps/$caseid (via email)
	    !ec  	(e)xecute whatever in '(c)mds'                                                                      
	    !eCx (x:m/c/b) same,also e(m)ail logs                  ABBREVIATIONS:
		with caseid $caseid                                     !b<KEY>. send the corresponding long 
	    !rc          same,but (r)epeatedly                           cmd strings based on the key defined in 
	    !eg          (e)xecute whatever in 'CGS',recursively       	ABB(KEY) array
	    !rg          same, but repeatedly                                                                               
								    LOGGINGS:
	    --execute/repeat(and email logs of) cmds in--               !lf  	change (l)og file based on 
	    ---'pattern-action-list','PAGS'--                               caseid specified in config (f)ile:$caselog_file
	    !ea       	(e)xecute 'pattern_action_list'             	!lc CASEID ..based on (c)aseid ,
	    !eAx (x:m/c/b) same, plus emails                                e,g: 1111-1111-1111.log
	    !eG 	(e)xecute PAGS,recursive                       	!lC CASEID ..based on (c)aseid plus 
	    !ra<CR>	same as !ea, (r)epeat $maxrounds            	    host name $caseid-$host.log
	    !ra N<CR> 	same, N rounds                              	!li	stop current (l)og, 
	    !rG<CR> 	(r)epeat PAGS for $maxrounds                        return to (i)nitial log:$initlog_file
	    !rG N	(r)epeat PAGS for N rounds              	!la NAME<CR> change (l)og file to an 
									    (a)rbitrary name (!la mylog<CR>) under $log_dir
	    --execute or execute recursively cmds in                    !lA FULLPATH<CR> change (l)og file to another 
	    --user-defined cmd groups or PA groups--                        full path name logfile:!lA /a/b/c.txt
	    !mlx(x:c/p/s) (l)list currently a/v groups            	!ls  	(s)top (l)og recording on 
		(cmd,pa,pa group for SHELL),from CGL,PAGL                   current logfile:$currlog_file
	    !mg CMD_GROUP<CR> (e)xecute one cmd grp,no recursive        !lr  	same, resume it
	    !mG PA_GROUP<CR> (e)xecute 1 PA group,recursively           !lS 	(S)how current (l)ogfile 
	    !mS PA_GROUP<CR> same,as host SHELL,recursively                 name:$currlog_file
	    !Hl 	(h)ost (l)ist                              MISC:
	                    						!h  	this (h)elp
	    --execute/email coredump--                                  !dd 	(d)efine a new (d)mp file 
	    !ed        	(e)xecute core(d)ump analysis                       name:$dmpfilebasename,obsolete 
	    !eDx (x:m/c/b) same, plus sending emails                    !da 	set arbitary values,
		                                                            (set caseid 2222-2222-2222),obsolete 
									!T  a mini tutorial
									!h  a list of most frequently used commands

	    --not finished features--
	    !t HOSTNAME<CR> !s HOSTNAME<CR>:  telnet/ssh login to HOSTNAME, which will be resolved to HOST(IP addres)
	    	the intention here is to remove dependency on /etc/hosts, which is not changable without root priv.  
	ver 0.2
    "
	}

	-echo -re "!h" {
	puts "\nfrequently used cmds under interact mode:"
	puts "
	    --frequently used cmds--
	    --logs--
	    !lc CASEID (=>log name: $caseid.log) or		!da set host xo<CR>  !lC 1111-1111-1111(=>log name: $caseid$host.log)
	    !ls !lr (s)top/(r)esume (l)og recording on current logfile:$currlog_file

	    --user-defined script--
	    !mS pre<CR> (prepare term len/wid/shell) 
	    !eg or !eCb (=>exec user-defined CLIes) 	                                                             
	    !mS scott_check<CR> (=>run scott script) 		!mS cpucheck<CR> (=>run KA34030 high CPU check)
	    !eDm !eDc !eDb (=>coredump decode, send email, upload to de folder,etc)
	    
	    type !T for a mini tutorial
	    type !i for more info/cmds
	    ver 0.2
    "
	}
	
	-echo -re "!T" {
	puts "\na quick tutorial for most frequently used commdands:"
	puts "
	    :by default, once started, everything will be logged in a file under \$log_dir(current:$log_dir), 
	    :in a filename defined in \$mylogfile (current:$mylog_file), to change the log file name
	    :to current case number, type following command. 

	    :this will change the logfile to a filename defined in \$caselog_file (current:$caselog_file)
	    :under a folder \$caselog_dir (current:$caselog_dir) these VARs are define in file:~/.mylogin/coredump.conf
	    !lc 2011-0511-0012

	    :this is normal telnet(ssh) command to login remote system
	    telnet 1.1.1.1
	    ...//..username,password,jumpstations,token,etc..//...
	    :assume we are now in privilidge mode of E320
	    ABC-VFTTP-120#

	    :type following, then hit enter (<CR>), this will adjust the term width/len/acquire a shell session and exit
	    !mS pre
	    :type following, no need enter, this will start some frequently used CLIes (not vxShell), defined under ~/.mylogin/cmds-data.conf
	    !eg

	    :wait until it finished, type following to send an email, to whoever defined in \$emailme(currently is $emailme) in file ~/.mylogin/mylogin.conf
	    :this is convenient to (a)ttach (l)og to (me), to (c)ase, or to (b)oth
	    !alm   (or !alc)   (or !alb)

	    :exit this session and start a new mylogin instance to handle the coredump
	    $ mylogin.tcl 
	    
	    :to deal with coredump, 2 parameters are needed, 1) caseid 2) dmpfilebasename
	    :they are defined in ~/.mylogin/coredump.conf, go change it to your caseid and filename,then run following command:
	    :it will (e)xecute (D)ump file handling task and mail to (m)e (in your case it's you)
	    !eDm
	    :wait until it finished, you will get an email with the decoded log attached.
	    :if you want the script also attach the decoded file to your case, run following instead:
	    :both commands will create a subfolder with the caseid as folder name in wf-ccstage, 
	    :and upload both the original dmp file and the decoded text file to DE
	    !eDb
	    

	    :sometimes its unavoidable to run some script, !mS <SCRIPT> is the command, SCRIPT need to be defined in a file under ~/.mylogin/ 
	    :here is an example to run scott's data-collection CLIes, the file was ~/.mylogin/scott_check.conf, type following and hit enter
	    !mS scott_check

	    :there are some other misc commands/features available, in some cases they are useful
	    :to stop the logging
	    !ls
	    :to resume
	    !lr

	    type !h for a brief list of most frequently used commands
	    type !i for more info/cmds
	    "
	}

	#log stop
	-echo "!ls" {
	    if $log_started {
		myputs "stopped log recording on file $currlog_file"
		log_file
		set log_started 0
	    } else {
		myputs "nothing to stop, log not started yet"
	    }
	}

	#log show
	-echo "!lS" {
	    if $log_started {
		myputs "current log file:$currlog_file"
	    } else {
		myputs "currently no log has been started yet"
	    }
	}

	#log view, not done yet
	-echo "!lv" {
	    if $log_started {
		myputs "viewing current log file:$currlog_file"
		myexec "less [glob $currlog_file]"
	    } else {
		myputs "currently no log has been started yet"
	    }
	}
	
	#log resume/start
	-echo "!lr" {
	    #expect:need to stop first in order to "resume" it
	    log_file
	    log_file $currlog_file
	    myputs "resume log recording to file $currlog_file"
	    set log_started 1
	}

	#log change per config file
	-echo "!lf" {
	    #get new caselog_file name from config(which is based on caseid)
	    if $redosource {source $configfile}
	    #expect:need to stop first in order to "resume" it
	    log_file
	    log_file $caselog_file
	    set currlog_file $caselog_file
	    myputs "resume log recording to file $currlog_file"
	    set log_started 1
	}
	
	#log return to initial file
	-echo "!li" {
	    #get new caselog_file name from config(which is based on caseid)
	    if $redosource {source $configfile}
	    #expect:need to stop first in order to "resume" it
	    log_file
	    log_file $initlog_file
	    myputs "stop log on $currlog_file, resume on initial log file $initlog_file"
	    set currlog_file $initlog_file
	    set log_started 1
	}

	#log change to caseid
	-echo -re "!lc $caseid_pattern|!lC $caseid_pattern" {
	    #if $redosource {source $configfile}
	    #get user input
	    set a $interact_out(0,string)	    
	    #scan the input and find what followed "!l " and use it as newcaseid
	    if {[regexp {^(!l.) (.*)} $a -> cmd_pref newcaseid] eq 1} {
	    #if {[scan $a "!lc %s" newcaseid] eq 1} 
		if $DEBUG {myputs "get new caseid $newcaseid"}
		#stop old log and start on the new file name
		log_file
	    	if {$cmd_pref == "!lc"} {
		    #replace caseid in the caselog_file full name and get new caselogfile name
		    set newcaselog_file [string map [list $caseid $newcaseid] $caselog_file]
		} elseif {$cmd_pref == "!lC"} {
		    set newcaselog_file [string map [list $caseid "$newcaseid-$host"] $caselog_file] 
		} else {
		    #place holder
		}
		log_file $newcaselog_file
		myputs "stop logging on:$currlog_file,continue on:$newcaselog_file"
		set currlog_file $newcaselog_file
		#because other cmd also my do re-source beforehand, following may not work
		#myputs "use newcaseid:$newcaseid instead of old caseid:$caseid"
		#set caseid newcaseid
		set log_started 1
	    } else {
		myputs "nothing found in inputted string"
	    }
	}


	#dummy codes, for test purpose only
	-echo -re "!zl." {
	    set a $interact_out(0,string)	    
	    if {[string compare $a "!zl1"] eq 0} {
		myputs "tests:ch followed !zl is 1"
	    } elseif {[string compare $a "!zl2"] eq 0} {
		myputs "tests:ch followed !zl is 2"
	    } else {
		myputs "tests:ch followed !zl is not 1 or 2"
	    }
	}

	#log attach
	-echo -re "!al." {
	    #get new caselog_file name from config(which is based on caseid)
	    if $redosource {source $configfile}
	    #update the caseid,if ever changed (via !lc)
	    set caseid $newcaseid


#	    if $DEBUG {myputs "value of zip is $zip"}
	    if $log_started {	    
		set a $interact_out(0,string)	    
		if $DEBUG {myputs "newcaseid:$newcaseid;currlog:$currlog_file"}

		if {[string compare $a "!alm"] eq 0} {
		    sendanemail $newcaseid $currlog_file $emailme 
		} elseif {[string compare $a "!alc"] eq 0} {
		    sendanemail  $newcaseid $currlog_file $emailcase
		} elseif {[string compare $a "!alb"] eq 0} {
		    sendanemail $newcaseid $currlog_file $emailme $emailcase
		} else {
		    myputs "currently only support !alm(me) !alc(case) !alb(both)"
		}

		#t.b.d: send curr log to any other emailaddress
		if $NEWFEATURE {
		-echo -re "!alt .*@.*\r" {
		    #if $redosource {source $configfile}
		    #get user input
		    set a $interact_out(0,string)	    
		    #scan the input and find what followed "!v " and use it as newcaseid
		    set tclcmd [string range $a 4 end]
		    #if {[string compare $tclcmd ""] eq 0}
		    if {[string match {*[a-zA-Z]*} $tclcmd]} {
			if $DEBUG {myputs "\nget tclcmd $tclcmd"}
			if {[catch {eval $tclcmd} msg]} {
			    myputs "wrong syntax with the inputed command!"
			    myputs "the error is:$::errorInfo"
			}
			
			if $DEBUG {myputs "caseid is now $caseid"}
			#replace caseid in the caselog_file full name and get new caselogfile name
		    } else {
			myputs "nothing found in inputted string"
		    }
		}
		}
	    } else {
		myputs "log has not been started yet, nothing to send!"
	    }
	} 

	#log(decoded dump file) attach
	-echo -re "!ad." {
	    #get new caselog_file name from config(which is based on caseid)
	    if $redosource {source $configfile}
	    #update the caseid,if ever changed (via !L)
	    set caseid $newcaseid

	    set a $interact_out(0,string)	    
	    if {$a eq "!adm"} {
		sendanemail $newcaseid "$dmp_upload_dir*decode*" $emailme
	    } elseif {$a eq "!adc"} {
		sendanemail $newcaseid "$dmp_upload_dir*decode*" $emailcase
	    } elseif {$a eq "!adb"} {
		sendanemail $newcaseid "$dmp_upload_dir*decode*" $emailme $emailcase
	    } else {
		myputs "currently only support !adm(me) !adc(case) !adb(both)"
	    }
	}

	-echo "!q" {
	    myputs " uit interact mode"
	    return
	}

	
	#dumpfile define
	-echo -re "!dd .*\r" {
	    #if $redosource {source $configfile}
	    #get user input
	    set a $interact_out(0,string)	    
	    #scan the input and find what followed "!d " and use it as newcaseid
	    if {[scan $a "!dd %s" newdmpfilebasename] eq 1} {
		if $DEBUG {myputs "\nget newdmpfilebasename $newdmpfilebasename"}
		
	    } else {
		myputs "nothing found in inputted string"
	    }
	}

	#define arbitrary things (using tcl systax)
	-echo -re "!da set.*\r" {
	    #if $redosource {source $configfile}
	    #get user input
	    set a $interact_out(0,string)	    
	    #scan the input and find what followed "!v " and use it as newcaseid
	    set tclcmd [string range $a 4 end]
	    #if {[string compare $tclcmd ""] eq 0}
	    if {[string match {*[a-zA-Z]*} $tclcmd]} {
		if $DEBUG {myputs "\nget tclcmd $tclcmd"}
		if {[catch {eval $tclcmd} msg]} {
		    myputs "wrong syntax with the inputed command!"
		    myputs "the error is:$::errorInfo"
		}
		
		if $DEBUG {myputs "caseid is now $caseid"}
		#replace caseid in the caselog_file full name and get new caselogfile name
	    } else {
		myputs "nothing found in inputted string"
	    }
	}


	#log with arbitrary name, and...
	#clean the log (remove escape, backspace, etc) doesn't work well yet
	-echo -re "!la .*\r|!lA .*\r" {
	    #if $redosource {source $configfile}
	    #get user input
	    set a $interact_out(0,string)	    
	    set newlogbasename 1
	    set cmd_pref 1
	    #extract cmd string,a blank,everything until (but excluding the end ^M--don't know why)
	    if {[regexp {^(!l.) (.*).} $a -> cmd_pref newlogbasename] eq 1} {
		if $DEBUG {
		    myputs "get new logfile:$newlogbasename"
		    myputs "initcaseid:$initcaseid,initcaselog_file:$initcaselog_file"
		}
		if {$cmd_pref == "!la"} {
		    #in initial caselog_file full name, replace caseid part with the newly 
		    #acquired newlogbasename and get new caselogfile full name
		    set newcaselog_file [string map [list $initcaseid $newlogbasename] $initcaselog_file]
		} elseif {$cmd_pref == "!lA"} {
		    set newcaselog_file $newlogbasename
		} else {
		    myputs "currently only !la and !lA are supported!"
		}
		
		#now change log to newcaselog_file
		log_file 	
		if {[mylog_file $newcaselog_file] == 0} {
		    myputs "stop logging on:$currlog_file,continue on:$newcaselog_file"
		    set currlog_file $newcaselog_file
		    set log_started 1 
		} else {
		    myputs "command failed,restore old logs"
		    log_file $currlog_file
		} 
	    } else {
		myputs "nothing found in inputted string"
	    }

	    if $NEWFEATURE {
	    incr n
	    if { 							\
		[catch  						\
		    {exec 						\
			screen -X scrollback [exec wc -l [glob $currlog_file]];  	\
		    }  							\
		    msg 						\
		] 							\
		} {
	       myputs "Something seems to have gone wrong:"
	       myputs "Information about it: $::errorInfo"
	    }

	    if { 							\
		[catch  						\
		    {exec 						\
			cat [glob $currlog_file];			\
		    }  							\
		    msg 						\
		] 							\
		} {
	       myputs "Something seems to have gone wrong:"
	       myputs "Information about it: $::errorInfo"
	    }
	    if { 							\
		[catch  						\
		    {exec 						\
			screen -X hardcopy -h [glob $currlog_file]-clean$n.log \
		    }  							\
		    msg 						\
		] 							\
		} {
	       myputs "Something seems to have gone wrong:"
	       myputs "Information about it: $::errorInfo"
	    }
	    myputs "log file $currlog_file is now cleaned as $currlog_file-clean$n.log"
	    }
	}

	#execute precmds
	-echo -re "!doprecmds|!ep" {
	    if $redosource {source $configfile}
	    log_user 1
	    do_cmds $pattern4cmd precmds $cmds_intv $cmd_timeout
	    unset precmds
	}

	#execute cmds
	-echo -re "!docmds|!ec" {
	    if $DEBUG {myputs "resourcing config file $configfile"}
	    if $redosource {source $configfile}
	    log_user 1
	    do_cmds $pattern4cmd cmds $cmds_intv $cmd_timeout 
	    if $DEBUG {myputs "commands finished"}
	    #clear the array after done, give next execution a fresh start
	    #this is useful when you want to remove a command out of cmds
	    unset cmds
	}

	#same as !ec but send emails
	-echo -re "!eC." {
	    set a $interact_out(0,string)	    
	    if { ($a eq "!eCm") || ($a eq "!eCc") || ($a eq "!eCb") 	\
		} {
		if $DEBUG {myputs "resourcing config file $configfile"}
		if $redosource {source $configfile}
		log_user 1
		do_cmds $pattern4cmd cmds $cmds_intv $cmd_timeout 
		if $DEBUG {myputs "commands finished,destruct cmds"}
		unset cmds
	    } else {
	    }

	    #send email
	    set a $interact_out(0,string)	    
	    if {[string compare $a "!eCm"] eq 0} {
		sendanemail $newcaseid $currlog_file $emailme 
	    } elseif {[string compare $a "!eCc"] eq 0} {
		sendanemail  $newcaseid $currlog_file $emailcase
	    } elseif {[string compare $a "!eCb"] eq 0} {
		sendanemail $newcaseid $currlog_file $emailme $emailcase
	    } else {
		myputs "currently only support !eCm(me) !eCc(case) !eCb(both)"
	    }
	}

	#repeat cmds
	-echo -re "!repcmds|!rc" {
	    if $redosource {source $configfile}
	    log_user 1
	    repeat_cmds $maxrounds $pattern4cmd cmds $cmds_intv $cmd_timeout
	}

	#execute cmds groups
	-echo -re "!docmdsgrps|!eg" {
	    myputs "start cmds groups"
	    if $redosource {source $configfile}
	    log_user 1
	    do_cmds_groups $pattern4cmd $CGS $cmds_groups_intv $cmds_intv $cmd_timeout 
	    #send email
	    sendanemail $newcaseid $currlog_file $emailme 

	    #foreach cmds_group $CGS {
	#	unset $cmds_group
	#    }
	    unset CGS
	}

	#repeat cmds groups
	-echo -re "!rg" {
	    myputs "repeat cmds groups"
	    if $redosource {source $configfile}
	    log_user 1
	    repeat_cmds_groups $maxrounds $pattern4cmd $CGS $round_intv $cmds_groups_intv $cmds_intv $cmd_timeout 
	}

	#execute pattern-action pairs and optionally send email
	-echo -re "!dopa|!ea|!eA." {
	    if {$host eq "SHELL"} {
		myputs "host is $host"
		myputs "warning: dump analysis requirs special filename other than the currlog_file:$currlog_file"
		myputs " so better use !ed !eDx to do dump analysis under local shell"
	    }

	    if $redosource {source $configfile}
	    set a $interact_out(0,string)	    
	    #it looks:
	    #1) string compare can be as simple as $a eq "a", string compare is also ok
	    #2) || looks doesn't work with '\'
	    if { ($a eq "!ea") || ($a eq "!eAm") || ($a eq "!eAc") || ($a eq "!eAb") 	\
		} {
		log_user 1
		do_patterns_actions $host $pattern_action_timeout pattern_action_list $pattern_action_intv
	    } else {
		myputs "invalid cmd $a,currently only support !eAm(me) !eAc(case) !eAb(both)"
	    }
	    
	    #also send emails with these cmds
	    if { ($a eq "!eAm") || ($a eq "!eAc") || ($a eq "!eAb")		\
		} {

		if {[string compare $a "!eAm"] eq 0} {
		    sendanemail $newcaseid $currlog_file $emailme
		} elseif {[string compare $a "!eAc"] eq 0} {
		    sendanemail $newcaseid $currlog_file $emailcase
		} elseif {[string compare $a "!eAb"] eq 0} {
		    sendanemail $newcaseid $currlog_file $emailme $emailcase
		} else {
		    myputs "invalid cmd $a,currently only support !eAm(me) !eAc(case) !eAb(both) "
		}

	    }

	    #destruct/fresh the data when done
	    unset pattern_action_list
	}

	#repeat pattern_action_list for $maxrounds
	#or repeat it for given rounds
	-echo -re {!ra\r|!ra [0-9]+\r} {
	    if {$host eq "SHELL"} {
		myputs "host is $host"
		myputs "warning: better use !ed !eDx to do dump analysis under local shell"
	    }

	    if $redosource {source $configfile}
	    set rounds 1
	    set a $interact_out(0,string)	    
	    log_user 1

	    if { $a eq "!ra\r" } {
		if $DEBUG {myputs "round not set, use maxrounds value in config file:$maxrounds"}
		set rounds $maxrounds
		repeat_patterns_actions $rounds $host $pattern_action_timeout pattern_action_list $pattern_action_intv
	    } else {
		#scan the input and find what followed "!ra " and use it as max_rounds
		if {[scan $a "!ra %d" rounds] eq 1} {
		    if $DEBUG {myputs "round is set to $rounds"}
		    repeat_patterns_actions $rounds $host $pattern_action_timeout pattern_action_list $pattern_action_intv
		} else {
		    myputs "rounds of actions are wrong!-$rounds/should be integer-"
		}
	    }

	    #destruct/fresh the data when done
	    unset pattern_action_list
	}

	-echo -re {!rG\r|!rG [0-9]+\r} {
	    if {$host eq "SHELL"} {
		myputs "host is $host"
		myputs "warning: better use !ed !eDx to do dump analysis under local shell"
	    }

	    if $redosource {source $configfile}
	    set rounds 1
	    set a $interact_out(0,string)	    
	    log_user 1

	    if { $a eq "!rG\r" } {
		if $DEBUG {myputs "round not set, use maxrounds value in config file:$maxrounds"}
		set rounds $maxrounds
		repeat_pags $rounds PAGS $host $pattern_action_timeout $pattern_action_intv
	    } else {
		#scan the input and find what followed "!rG " and use it as max_rounds
		if {[scan $a "!rG %d" rounds] eq 1} {
		    if $DEBUG {myputs "round is set to $rounds"}
		    repeat_pags $rounds PAGS $host $pattern_action_timeout $pattern_action_intv
		} else {
		    myputs "rounds of actions are wrong!-$rounds/should be integer-"
		}
	    }

	    #destruct/fresh the data when done
	    unset PAGS
	}

	-echo "!eG" {
	    if {$host eq "SHELL"} {
		myputs "host is $host"
		myputs "warning: better use !ed !eDx to do dump analysis under local shell"
	    }

	    set host1 $host
	    set host "SHELL"
	    if $redosource {source $configfile}
	    log_user 1
	    do_pags PAGS $host $pattern_action_timeout $pattern_action_intv
	    set host $host1
	}

	    
	-echo "!mlc" {
	    if $redosource {source $configfile}
	    myputs "\ncurrently available command groups:\n$CGL\n"
	    unset CGL
	}

	-echo "!mlp" {
	    if $redosource {source $configfile}
	    myputs "\ncurrently available pattern action groups for $host:\n$PAGL($host)\n"
	    unset CGL
	}

	-echo "!mls" {
	    if $redosource {source $configfile}
	    set host1 $host
	    set host SHELL
	    myputs "\ncurrently available pattern action groups for SHELL:\n$PAGL($host)\n"
	    set host $host1
	    unset CGL
	}

	-echo -re "!mg .*\r" {
	    if $redosource {source $configfile}
	    set a $interact_out(0,string)
	    set cmd_group 1
	    log_user 1
	    #scan the input and find what followed "!e " and use it as new caseid
	    if {[scan $a "!mg %s" cmd_group] eq 1} {
		#eval global $pa_group
		if {[lsearch -exact $CGL $cmd_group] == -1} {
		    myputs "the command group $cmd_group is not available in CGL!"
		    myputs "\ncurrently available command groups:\n$CGL\n"
		} else {
		    do_cmds $pattern4cmd $cmd_group $cmds_intv $cmd_timeout
		}
	    } else {
		myputs "nothing found in inputted string"
	    }
	}


	-echo -re "!mG .*\r|!mS .*\r" {
	    if $redosource {source $configfile}

	    set a $interact_out(0,string)
	    log_user 1
	    set pa_group 1
	    #scan the input and find what followed "!mG " and use it as pa_group
	    if {[scan $a "!mG %s" pa_group] eq 1} {
		#eval global $pa_group
		if {[lsearch -exact $PAGL($host) $pa_group] == -1} {
		    myputs "the pattern action group $pa_group is not available in PAGL!"
		    myputs "\ncurrently available pattern action groups:\n$PAGL($host)\n"
		} else {
		    #do_patterns_actions $host $pattern_action_timeout $pa_group $pattern_action_intv
		    do_pags $pa_group $host $pattern_action_timeout $pattern_action_intv
		    #unset $pa_group
		}

	    } elseif {[scan $a "!mS %s" pa_group] eq 1} {
		#for !mR, execute what is configured for host "SHELL", regardless of hostname
		#backup curent hostname
		set host1 $host
		#treat host as if SHELL
		set host "SHELL"
		#do same as !mG
		if {[lsearch -exact $PAGL($host) $pa_group] == -1} {
		    myputs "the pattern action group $pa_group is not available in PAGL!"
		    myputs "\ncurrently available pattern action groups:\n$PAGL($host)\n"
		} else {
		    #do_patterns_actions $host $pattern_action_timeout $pa_group $pattern_action_intv
		    do_pags $pa_group $host $pattern_action_timeout $pattern_action_intv
		    #unset $pa_group
		}
		
		#send email
		sendanemail $newcaseid $currlog_file $emailme 

		#when done, recover hostname back 
		set host $host1 
	    } else {
		myputs "nothing found in inputted string"
	    } 
	}

	-echo "!Hl" {
	    if $redosource {source $configfile}
	    puts "\nhost table:\n"
	    parray host2name
	    puts "\nlogin info\n"
	    parray login_info
	}

	-echo -re "!b.*\\." {
	    if $redosource {source $configfile}

	    set a $interact_out(0,string)
	    set abbkey 1
	    #two ways to extract string/CHs: it looks regexp is the best way!
	    #regexp {c((.*)g)(.*)} "abcdefghi" matched sub1 sub2 sub3
	    #if {[scan $a "!b%s\." abbkey] eq 1} 
	    #match string $a with a pattern, all matched part goes to special var "->"
	    #then extract sub-string from matched part into $abbkey using () and regex
	    if {[regexp {!b(.*)\.} $a -> abbkey] eq 1} {
		#eval global $pa_group
		if {[lsearch -exact [array names ABB] $abbkey] == -1} {
		    myputs "abbreviation key:$abbkey is not configured in ABB, please double check!"
		    myputs "\ncurrently available abbreviation keys are:\n"
		    parray ABB
		} else {
		    send_user "=>"
		    send "$ABB($abbkey)"
		}
	    } else {
		myputs "inputted $a is a wrong command!"
	    }

	    unset ABB
	}
	
	#new shell commands to auto-resolve the name to host
	#not finished, it doesn't work, for unknown reason
	-echo -re "!t .*\r|!s .*\r" {
	    set a $interact_out(0,string)
	    #scan the input and find what followed "!s " or "!t " and use it as hostname
	    if {[regexp {^(!.) (.*)} $a -> protocol hostname] eq 1} {
		if $DEBUG {myputs "get protocol -$protocol- and hostname -$hostname-"}

		if {[info exists host2name($hostname)]} {
		    set host $host2name($hostname)
		    if $DEBUG {myputs "get resolved for $hostname to $host"}
		    
		    if {$protocol == "!t"} {
			send "\rtelnet $host" 
		    } elseif {$protocol == "!s"} {
			#this is not good supported, considering login name ..
			send "\rssh $host"
		    } else {
			myputs "currently only resolve name for telnet/ssh..."
		    }
		} else {
		    myputs "\nhostname not resolved for -$hostname-, please use original telnet/ssh cmds"
		    if $DEBUG {
			parray host2name
		    }
		}
	    } else {
		myputs "nothing found in inputted string"
	    } 
	}


	#coredump handling, one of the specialized action under local shell mode
	-echo -re "!dodump|!ed|!eD." {

	    if {$host ne "SHELL"} {
		myputs "host is $host"
		myputs "currently only support dump analysis under local shell"
		return 1
	    }
		
	    #if $redosource {source $configfile}
	    set a $interact_out(0,string)	    

	    #speical handling for coredump analysis
	    if {($a eq "!ed") || ($a eq "!eDm") || ($a eq "!eDc") || ($a eq "!eDb")} {
		if $DEBUG {myputs "caseid is now $caseid"}

		#depress or show the interactions to user
		log_user $no_depress_dmp_interaction 
		log_file
		#log to a seperated,fresh decode file(disable append)
		#log to file no matter log_user enabled or depressed
		log_file -a -noappend $decodelog_file1
		myputs "change log file to $decodelog_file1"
		
		#these are no much use currently, looks hard to pass param from argv
		#too much to do in the coredump.conf
		#set caseid $caseid_from_argv
		#set dmpfilebasename $dmpfilebasename_from_argv

		#myputs "dmpf is detected as $dmpf"
		#myputs "caseid is now $caseid"


		#do_patterns_actions $host $pattern_action_timeout pattern_action_list $pattern_action_intv
		do_pags core $host $pattern_action_timeout $pattern_action_intv 

		log_file
		log_file $currlog_file
		myputs "change log file back to $currlog_file"

		if {$a eq "!eDm"} {
		    sendanemail $caseid "$caselog_dir/*$caseid*$dmpfilebasename*decode*" $emailme
		} elseif {$a eq "!eDc"} {
		    sendanemail $caseid "$caselog_dir/*decode*" $emailcase
		} elseif {$a eq "!eDb"} {
		    sendanemail $caseid "$caselog_dir/*decode*" $emailme $emailcase
		} else {
		    
		}

	    } else {
		myputs "invalid cmd $a,currently only support !ed !eDm !eDc !eDb"
	    }

	    unset pattern_action_list
	}

	#execute preworks
	-echo -re "!eP" {
	    #some pre-work, might be useful for interactions
	    if $redosource {source $configfile}
	    if $DEBUG {myputs "do some interactions here"}
	    log_user 1
	    do_patterns_actions $host $pattern_action_timeout prework $pattern_action_intv
	    unset prework
	}

	#execute a block of tcl code
	-echo -re "!eb" {
	    if $redosource {source $configfile}
	    myputs "going to eval code:-$tclblock-"
	    set temp [eval $tclblock]
	}

	
#	-reset "\032" {
#	    exec kill -STOP 0
#	}

#	-o
#	"error" {
#	    myputs "!some errors were found!want to run diag?(y/n)"
#	    diag_on_error
#	}
	
    }
}

##############################main program###################################
#include('source' in tcl context) config and lib files
#check if file is readable before hand
#set files  [ list $configfile $libfile ] 
set files  [ list $configfile ] 

foreach file $files {
    if {[file readable $file]} {
	puts "\[[exec date]: sourcing file $file\]"
	source $file
    } else {
	puts "\[[exec date]: file $file doesn't exists\n"
	exit 1
    }
}
if $DEBUG {myputs "checking log_dir $log_dir ...\n"}
if {[file exists $log_dir]} {
    if $DEBUG {send_user "...existing!\n"}
} else {
    send_user "dir $log_dir didn't exist, creating one...\n"
    if [catch {file mkdir $log_dir} failed_reason] {
	send_user "failed to creating dir $log_dir: $failed_reason\n"
	exit 1
    } else {
	send_user "...done!\n"
    }
}

if $DEBUG {myputs "checking log_dir $caselog_dir ...\n"}
if {[file exists $caselog_dir]} {
    if $DEBUG {send_user "...existing!\n"}
} else {
    send_user "dir $caselog_dir didn't exist, creating one...\n"
    if [catch {file mkdir $caselog_dir} failed_reason] {
	send_user "failed to creating dir $caselog_dir: $failed_reason\n"
	exit 1
    } else {
	send_user "...done!\n"
    }
}

set initlog_file $mylog_file
#start logging
if $log_when_start {
    log_file $mylog_file
    if $DEBUG {myputs "start logging on initial log_file:$initlog_file"}
} else {
    if $DEBUG {myputs "log_when_start flag not set, log not enabled"}
}


if $do_log_user {
    
} else {
    myputs "depress the interaction details"
    log_user 0
}

#this is not well designed yet
set code 1

#retrieve logon info from another file,only if not in config file, to the global array
loaddata $loginfile "logininfo" login_info

#simple paramaters handling,omit params for quick test
if {$argc==0} {
    #to spawn another shell
    spawn $env(SHELL)
    set code 0
    #set hostname to "shell" since no remote host is involved here
    if $DEBUG {myputs "no parameter followed, set hostname to 'shell'"}
    set host SHELL

} elseif {$argc==1} {
    usage
    if $DEBUG {myputs "no parameter followed the protocol, set hostname to 'localhost'"}
    if $DEBUG {myputs "this is just for quick test"}
    set hostname "localhost"
    spawn [lindex $argv 0] $hostname

} else {
    #get hostname from command line
    set first_p [lindex $argv 0]
    if $DEBUG {myputs "detected first param:$first_p"}

    #for telnet,hostname can be retrieved from 2nd argv
    if {$first_p=="telnet"} {
	set proto $first_p
	set host [lindex $argv 1]
	if $DEBUG {myputs "detected host:$host in $proto session"}
	
	#spawn telnet/ssh/ftp/rsync/whatever tools,followed by their native params
	#this is one of the way in tcl/expect to support more params
	#w/o 'eval' this won't work

	#name resolving function: check if host can be resolved from config file
	#use the resolved info if possible
	if {[info exists host2name($host)]} {
	    set hostname $host2name($host)
	    if $DEBUG {myputs "get resolved for $host to $hostname"}
	    eval spawn [lrange $argv 0 [expr $argc-2]] $hostname
	} else {
	    
	    if $DEBUG {
		parray host2name
		myputs "hostname not resolved for $host,use original"}
	    eval spawn [lrange $argv 0 end]
	}

    } elseif {$first_p=="ssh"} {
	set proto $first_p
	#for ssh, just get the last param
	#this is safe only if host entry has been well configured in .ssh/config
	set lastparam [lindex $argv [expr $argc - 1] ]
	if $DEBUG {myputs "detected host:$lastparam in $proto session"}
	#in theory, need more work here to handle other ssh usage: 
	# e.g.: ssh ping@host, ssh host -l ping, ...
	set host $lastparam

	#spawn telnet/ssh/ftp/rsync/whatever tools,followed by their native params
	#this is one of the way in tcl/expect to support more params
	#w/o 'eval' this won't work

	#name resolving function: check if host can be resolved from config file
	#use the resolved info if possible
	if {[info exists host2name($host)]} {
	    set hostname $host2name($host)
	    if $DEBUG {myputs "get resolved for $host to $hostname"}
	    eval spawn [lrange $argv 0 [expr $argc-2]] $hostname
	} else {
	    
	    if $DEBUG {
		parray host2name
		myputs "hostname not resolved for $host,use original"}
	    eval spawn [lrange $argv 0 end]
	}

    } elseif {[regexp $caseid_pattern $first_p]} {
	if $DEBUG {myputs "detected caseid:$first_p"}
	set caseid_from_argv $first_p
	set dmpfilename_from_argv [lindex $argv 1]
	regexp {(.*)\..*} $dmpfilename_from_argv -> dmpfilebasename_from_argv 

	if $DEBUG {myputs "got caseid $caseid_from_argv, dmp file $dmpfilename_from_argv, ready to do coredump decoding
	    Note: dmp file must be either under:
	    your juniper home, subfolder pubic_html,
	    ftp incoming folder, with or without a caseid subfolder!"
	}

	spawn $env(SHELL)
	#set hostname to "shell" since no remote host is involved here
	if $DEBUG {myputs "only for coredump decoding, set hostname to 'shell'"}
	set host SHELL

    } else {
	myputs "1st parameter looks neither a protocol (telnet/ssh), nor a valid caseid!"
	exit 1
    }

}

#use these to prefix all cmd output with a timestamp, not well done yet
if $NEWFEATURE {
expect_background -re "\[^ \]+\n" {
    send_user "following output was caught at [exec date]\n$expect_out(0,string)"
}
}


#different branches based on where we are
if {$code=="0"} {
    #if spawn a local shell, no need autologin, go interact
    if {$doprework=="0"} {
	do_interact 0
    } 
} else {
    #otherwise, check if autologin feature is enabled
    #if yes,try autologin
    if $autologin {
	if $DEBUG {myputs "autologin flag set, try autologin"}
	do_patterns_actions $host $login_timeout login_info $pattern_action_intv


	#autologin retry feature, not well done yet
	#if spawned process failed, looks the whole script exit
	
	set autologin_fail [myexpect "check if login success for the 1st time" $success_login_pattern "\r" $login_timeout]
	
	#if autologin failed, check if retry feature is enabled
	if $autologin_fail {
	    #if yes, do retry
	    set login_retry_fail [do_autologin_retry $max_login_retry $success_login_pattern $login_timeout $pattern_action_intv]

	    #if retry also failed, based on ...
	    #not sure this part of logic is correct or not
	    if $login_retry_fail {
		#if set, force(no need user confirm) interact mode when login not succeed
		if $interact_force_login_nok {
		    puts "interact_force_login_nok set, force to interace mode"
		    do_interact 1
		} else {
		    #failover to manual retry feature: if auto logon failed, continue to do it manually
		    #looks {} is not necessary here for if
		    myputs "auto login failed..\n..want to retry manually?(y/n)"
		    #raw mode for a while
		    stty raw
		    expect_user {
			"y" {
				myputs "go interact mode on user's request"
				do_interact 2
				#stty -raw
			    }
			"n" {
				myputs "..exit on no..\n"
				exit 1
			    }
			default {
				myputs "..exit on default..\n"
				exit
			}
		    }

		}
	    } else {
		myputs "auto login succeed after retry"
	    }
	} else {
	    myputs "auto login succeed"
	}
	

    } else {
	#if autologin not enabled, go interact(manual login)
	myputs "autologin not set, go interact"
	do_interact 5
    }
}

loaddata $cmdsfile "cmds" cmds

if $doprework {
}

#base on config, go interact or auto mode after success login
if $interact_after_login_ok {
    #go interact mode on login, if flag set
    do_interact 3
} else {
    #otherwise proceed with automode
    #some pre-set commands for every login
    #  show clock, term wid/length, etc
    puts "\nsome pre-checkings..\n"
    if $DEBUG {parray precmds}
    #executes all CLIes in precmds@2s interval, each wait 10s for outputs
    do_cmds $pattern4cmd precmds 2 5

    #executes pre-defined cmds for configured rounds
    repeat_cmds $maxrounds $pattern4cmd cmds $cmds_intv $cmd_timeout

    #if all done,handover control to user if configured
    if $interact_after_alldone {
	do_interact 4
    } else {
	exit
    }
}

#capture eol from spawn when session exit
#this feature doesn't work yet
if $NEWFEATURE {

expect {
    eol 	{puts "eol received and exit"}
}

}

#		send "got <$expect_out(buffer)>"
#		send "but only <$expect_out(0,string)> was expected"	


