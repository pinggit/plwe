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

source ~/bin/mylib.tcl
proc usage {} {
    #$argv0 as script name become a private var here in proc w/o global
    global argv0
    myputs "Usage:$argv0 ssh|telnet|ftp|... PARAMS_LISTS"
}

#global vars 
global cmds login_info CGS 
global initlog_file host 

#get script basename
set scriptbasename [exec basename $argv0]
#get the prefix before "."
regexp {(.*)\..*} $scriptbasename -> scriptbasename_pref 

#config file by def is located under the folder named by the script name
set configfile "~/.$scriptbasename_pref/$scriptbasename_pref.conf"
#set configfile "~/.mylogin/mylogin.conf"

#main {{{1}}}
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
    set proto [lindex $argv 0]
    if $DEBUG {myputs "detected protocol:$proto"}

    #for telnet,hostname can be retrieved from 2nd argv
    if {$proto=="telnet"} {
	set host [lindex $argv 1]
	if $DEBUG {myputs "detected host:$host in $proto session"}

    } elseif {$proto=="ssh"} {
	#for ssh, just get the last param
	#this is safe only if host entry has been well configured in .ssh/config
	set lastparam [lindex $argv [expr $argc - 1] ]
	if $DEBUG {myputs "detected host:$lastparam in $proto session"}
	#in theory, need more work here to handle other ssh usage: 
	# e.g.: ssh ping@host, ssh host -l ping, ...
	set host $lastparam
    } else {
	myputs "probably protocols excepts telnet/ssh are not tested at this moment!"
    }

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
	do_patterns_actions6 $host $login_timeout login_info $pattern_action_intv


	#autologin retry feature, not well done yet
	#if spawned process failed, looks the whole script exit
	
	set autologin_fail [myexpect6 "check if login success for the 1st time" $success_login_pattern "\r" $login_timeout]
	
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


