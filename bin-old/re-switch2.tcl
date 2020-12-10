#!/usr/bin/env expect
#
# pings@juniper.net
#

proc myputs {msg} {
    puts "\[[exec date]:[lindex [info level 1] 0]:..$msg..\]"
}

#return a cmd list from a file
#need to test "return a list" 
proc read_flag_from_file {file cmd} {
    set ulist {}
    if [file exists $file] {
        set file [open $file r]
        while {[gets $file buf] != -1} {
            if [regexp $cmd $buf] {
               #lappend ulist $cmd
               close $file
               return 1
            }
        }
        #error "no flag found in file $file"
        myputs "no flag found in file $file"
        return 0
    } else {
        myputs "no file $file"
        return 1                ;#backward compatible
    }
}

proc write_flag_into_file {file cmd} {
    set f [open $file w]
    puts $f "$cmd"
    close $f
}

#version2: expect and then send
proc myexpect2 {router pattern datasent {mytimeout 240}} {
    global debug session2host host2session
    set session $host2session($router)
    set controlC \x03
    set timeout $mytimeout
    #exp_send -i $session "\r"
    #myputs "myexpect2: $session send a cmd -$datasent-"
    #myputs "myexpect2: $session get a cmd -$datasent-"
    expect  {
	-i $session -re "$pattern" {
            if {$datasent == "expect_out"} {
                return $expect_out(buffer)
            } else {
                exp_send -i $session "$datasent\r"
                return 1
            }
	}
	-i $session timeout {
            #if timeout before get the prompt, ctrl-c to break
            myputs "timeout in ${timeout}s without a match for -$pattern- before sending -$datasent-!"
            myputs "ctrl-c to break!"
            exp_send -i $session "$controlC"         ;#break out from current wait
            exp_send -i $session "\r"                ;#extra return to generate a new prompt
            return 0    ;# more robust, but not reliable in some case(upgrade,yes/no,etc)
            #or , use strict rule - won't proceed if unexpected thing happen!
            #exit                
	}
        -i $session -re "connection closed by foreign host" {
            myputs "connection closed by the router!"; exit
        }
        -i $session eof {
            myputs "spawned process terminated!"; exit
        }
        -i $session full_buffer {
            myputs "got full buffer!"
            exp_continue;
            return 2
        }
    }
}

proc persist_expect {router pattern datasent {mytimeout 240} {round 5}} {
    set i 1
    while {![myexpect2 $router $pattern $datasent $mytimeout]} {
        #myexpect2 $router ".*" ""
        incr i
        if {$round > $round} {return 0}
    }
    return 1
}

proc persist_login {login_script router} {
    global debug session2host host2session
    spawn -noecho $login_script $router
    if $debug {myputs "spawn_id of persist_login is $spawn_id"}
    expect {
        -i $spawn_id -re "> $" {
            #once got the "> "prompt, start to ignore whatever comes after that
            #within 3s (attn might send some pre-commands once logged in)
            set timeout 3
            expect -i "$spawn_id" -re ".+" exp_continue

            set session2host($spawn_id) $router
            set host2session($router) $spawn_id
            #if $debug {
            #    myputs "spawn id for $router is $spawn_id"
            #    myputs "host2session now looks [array get host2session]"
            #}

            return $spawn_id
        }
        #with persist feature added in login script, seems no need to duplicate from here
        -i $spawn_id "Unable to connect to remote host: Connection timed out" {
            persist_login $login_script $router
        }
        -i $spawn_id default         {
            myputs "get eof/timeout, retry"
            sleep 1
            persist_login $login_script $router
        }
    }
}

proc switchover_countdown {switchover_countdown} {
    global debug
    incr switchover_countdown 1
    if $debug {myputs "\[script:will count $switchover_countdown seconds and retry...\]"}
    if {$switchover_countdown >= 30} {
        incr switchover_countdown -30
        sleep $switchover_countdown
        if $debug {myputs "\[script:just 30 more seconds to go...\]"}
        sleep $switchover_countdown
    } else {
        sleep $switchover_countdown
    }
}

proc switchover {router {hold_interval 300} {su_password herndon1}} {
    global debug session2host host2session
    set session $host2session($router)
        
    exp_send -i $session "\r"
    myexpect2 $router "> $" "request chassis routing-engine master switch" 60
    expect -i $session "\\\[yes,no\\\] (no)" { send -i $session "yes\r"}

    expect {
        #Complete. The other routing engine becomes the master.
        #-re "\{backup\}\s+.*-re\[01]>" 
        #-re "\{backup\}\r\n.*-re\[01]>" 
        #-re "The other routing engine becomes the master.\r\n\r\n{backup}\r\n.*-re\[01]>"
        -i $session -re "routing engine becomes the master"
        {
            if $debug {myputs "\[script:detected switchover succeed! will exit current session...\]"}
            send -i $session "exit\r"
        }

        #-re "\{master\}\s+.*-re\[12]>" 
        #-re "\{master\}\r\n.*-re\[01]>" 
        -i $session -re "Command aborted. Not ready for mastership switch, try after \\d+ secs.*"
        {
            #if $debug {myputs "$expect_out(buffer)\r"}
            set switchover_countdown 240
            regexp {.*try after (.*) secs.*} $expect_out(buffer) -> switchover_countdown
            if $debug {myputs "\[script:detected switchover did not succeed...\]"}
            if {$switchover_countdown <= $hold_interval} {
                #wait and graceful switchover
                switchover_countdown $switchover_countdown
                switchover $router $hold_interval $su_password
            } else {
                if $debug {
                    myputs "\[script:required switchover interval time left(${hold_interval}s) is  \
                    less than CLI protection interval(${switchover_countdown}s left), will force   \
                    rpd restart after $hold_interval seconds...\]"
                }
                sleep $hold_interval
                #force rpd core and switchover
                restart_rpd $router "rpd" $su_password
            }
        }

        #this won't catch: closed -> spawned proc exit -> no way to expect
        -i $session -re "closed by foreign host" {
            myputs "no problem, will re-login again!"
        }

        timeout {
            myputs "something not predicted happened, exit"
            exit
        }
    }
}

proc restart_process {router process {su_password "herndon1"}} {
    global debug session2host host2session
    set session $host2session($router)

    if $debug {myputs "trying to restart $process now!"}
    exp_send -i $session "\r"
    exp_send -i $session "start shell\r"
    myexpect2 $router "% $"        "su"
    myexpect2 $router "Password:$" "$su_password"
    myexpect2 $router "% $"        "uptime\r"
    #myexpect2 $router "% $"        "ps aux | grep rpd\r"
    myexpect2 $router "% $"        "ps aux | grep $process\r"
    #expect -i $session -re "root\\s+(\\d+)\\s+.*sbin/rpd.*$"
    expect -i $session -re "root\\s+(\\d+)\\s+.*sbin/$process.*$" {
        #set rpd_pid $expect_out(1,string)
        set pid $expect_out(1,string)
        send -i $session "pwd\r"
        #exp_send -i $session "kill -6 $rpd_pid\r"
        exp_send -i $session "kill -6 $pid\r"
    }
    expect -i $session -re "% $" {send -i $session "exit\r"}
    expect -i $session -re "% $" {send -i $session "exit\r"}
}

proc pre_work {router} {
    myputs "make sure bgp state OK before processing.."
    #myexpect2 $router "> $" "show bgp summary | match 10.64.50.111" 240
    myexpect2 $router "> $" "show bgp summary | match 192.168.1.81" 240
    set buf_bgp [myexpect2 $router "> $" "expect_out" 180]
    while {![regexp {Estab} $buf_bgp]} {
        myputs "buf_bgp:$buf_bgp:Estab:[regexp {Estab} $buf_bgp]"
        myputs "wait 2 more mins for bgp session!"
        sleep 120
        myexpect2 $router ".*" ""
        #myexpect2 $router "> $" "show bgp summary | match 10.64.50.111" 240
        myexpect2 $router "> $" "show bgp summary | match 192.168.1.81" 240
        set buf_bgp [myexpect2 $router "> $" "expect_out" 180]
    }
    myputs "bgp state looks OK! go head..." 
}

proc action {router} {
    global debug session2host host2session
    set session $host2session($router)
    set captured_output [myexpect2 $router "> $" "show system uptime"]
    
    myexpect2 $router "> $" "configure"

    for {set i 601} {$i<=1100} {incr i 1} {
    #    myexpect2 $router "# $" "delete class-of-service interfaces ge-6/0/2 unit $i output-forwarding-class-map VPLS_PPCOS_class_map_10:20:30:10:10:20_out"
    #    myexpect2 $router "# $" "delete class-of-service interfaces ge-6/0/2 unit $i output-traffic-control-profile tcp-vlan-6-0-2-group-2"
    #    myexpect2 $router "# $" "delete class-of-service interfaces ge-6/0/2 unit $i output-traffic-control-profile shared-instance 100"
    #    myexpect2 $router "# $" "delete class-of-service interfaces ge-6/0/2 unit $i classifiers ieee-802.1 CE_VPLS_ieee_BA_CLASSIFIER_PPCOS_in"
        myexpect2 $router "# $" "deactivate interfaces ge-1/3/0 unit $i"
        myexpect2 $router "# $" "deactivate routing-instances 13979:333$i"
        myexpect2 $router "# $" ""
    }

        #myexpect2 $router "# $" "deactivate groups VPLS_CNTRL_WORD_ADD"
        #myexpect2 $router "# $" "delete apply-groups VPLS_CNTRL_WORD_ADD"
        #myexpect2 $router "# $" "load set vpls-no-tunnel-service.txt"
        myexpect2 $router "# $" "show | compare | last 40 | no-more"
        #myexpect2 $router "# $" "commit synchronize force"
        persist_expect $router "# $" "commit"
        #myexpect2 $router "# $" "rollback 1"
        #myexpect2 $router "# $" "show | compare | last 40 | no-more"
        #persist_expect $router "# $" "commit synchronize force"
        persist_expect $router "# $" "exit"

}

proc check {router} {

    myputs "script:start to check interfaces status..."

    sleep 10                    ;#wait for a while for all IFLs come up
    myexpect2 $router "> $" ""
    myexpect2 $router "> $" {show interfaces ge-1/3/0 | match ge-1/3/0.[16-9] | count} 240
    set buf1 [myexpect2 $router "> $" "expect_out" 180]
    myputs "buf1:$buf1:500 lines:[regexp {500 lines} $buf1]"

    myexpect2 $router ".*" ""
    myexpect2 $router "> $" "show route forwarding-table extensive | match delete" 240
    set buf2 [myexpect2 $router "> $" "expect_out" 180]
    myputs "buf2:$buf2:DELETE:[regexp {DELETE} $buf2]"

    if {([regexp {DELETED} $buf2]) || ![regexp {500 lines} $buf1]} {
        set detectionmsg "sub interface not shown issue detected!exit!"; myputs $detectionmsg
        set sendemail "echo $detectionmsg | sendthisfile.sh - pings@juniper.net $detectionmsg"
        if {[myexec $sendemail]} {
        } else {
            myputs "email notification was sent!"
        }
        exit
    }
}

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

#todo: use this proc to further simplify the pattern-action sequence
proc do_patterns_actions {router dataarray {pattern_timeout 120} {pa_intv 0}} {
    global debug
    upvar $dataarray da
#    source ~/.mylogin/nofwd1211.conf
    if $debug {myputs "start pattern-action sequence"}
    if $debug {parray da}
    if {[info exists da($router)]} {
	if $debug {myputs "pattern-action data for $router now looks:"}
	if $debug {myputs "  -$da($router)-"}
    } else {
	myputs "pattern-action data for $router doesn't exist, check your config!"
	return 1
    }

#   this won't work for duplicate patterns
#   set i 1
    #array set pa_pair $login_info($router)
#    foreach pattern [array names pa_pair] {
#	set datasent $pa_pair($pattern)
#	myexpect2 "pattern-action item $i\n" $pattern $datasent	
#	incr i
#    }
    #get a data list from data array
    set l $da($router) 
    set j 0
    #go through this data list
    for {set i 0} {$i<=[expr [llength $l]-1]} {incr i 2} {
	#get pattern/data
	set pattern [lindex $l $i]	
	set datasent  [lindex $l [expr $i+1]]
	#execute the pattern-data pairs
	myexpect2 $router $pattern $datasent $pattern_timeout	
	#if $DEBUG {myputs "pattern-action item $j"}
	#do_cmd $pattern $datasent $pattern_timeout
	incr j
	#optionally pause between each step
	sleep $pa_intv
    }

    #this is to garrantee we can get the prompt for the last cmd to finish
    #otherwise the output of it will be held unless next cmd was inputted
    #this works in most cases:
    #myexpect2 "extra return" $pattern "\r" $pattern_timeout
    #but this is better:
    myexpect2 $router ".*" "\r"
}

############## main ################
set login_script "attjlab"
set maxrounds 500
set switch_interval 120
#set dead_time [exec date +"%s" -d "Fri Jan 08 02:50:00 EST 2015"]
#set dead_time [exec date +"%s" -d "Tue Mar 18 07:50:00 EDT 2014"]
set su_password "jnpr123"

set login_interval 60
set router "alecto"
if {$argc>=1} {
    set login_script [lindex $argv 0]
}

if {$argc>=2} {
    set router [lindex $argv 1]
}

if {$argc>=3} {
    set switch_interval [lindex $argv 2]
}

if {$argc>=4} {
    set login_interval [lindex $argv 3]
}

if {$argc>=5 || $argc<=1} {
    set scriptbasename [exec basename $argv0]
    regexp {(.*)\..*} $scriptbasename -> scriptbasename_pref 
    myputs "too less or more parameters! requires 2 , 3 , or 4!"
    myputs "usage:$scriptbasename_pref LOGIN_SCRIPT ROUTERNAME \[SWITCHOVER_INTERVAL\] \[ROUTER_LOGIN_INTERVAL\]"
    myputs "or: use jtac lab router alecto: $scriptbasename_pref"
    myputs "example:$scriptbasename_pref attn DESTTG1005ME2 240 100"
    exit
}

if {$router=="alecto" || $argc == 0} {
    set su_password "herndon1"
}

match_max -d 1000000
#exp_internal 1
set flagfile "~/.flagfile"
set hold_interval [expr {$switch_interval - $login_interval}]
set timeout 300
set debug 1
#spawn -noecho attjlab alecto
#spawn $login_script $router
persist_login $login_script $router

for {set i 1} {$i<=$maxrounds} {incr i 1} {

    #timed script - stop working if reaching the customer approved time limit
    set curr_time [exec date +"%s"]
    if {[info exists dead_time]} {
        if { $curr_time > $dead_time } {
            set detectionmsg "issue not detected during test hours!exit!"; myputs $detectionmsg
            set sendemail "echo $detectionmsg | sendthisfile.sh - pings@juniper.net $detectionmsg"
            if {[myexec $sendemail]} {
            } else {
                myputs "email notification was sent!"
            }
            myputs "will recover and reload the router..."

            #myexpect2 $router "> $" ""
            #myexpect2 $router "> $" "configure"
            #myexpect2 $router "# $" "load override backup-b4-change.txt"
            #myexpect2 $router "# $" "commit"
            #myexpect2 $router "# $" "run request system reboot both-routing-engines"
            #myexpect2 $router "Reboot the system ? \[yes,no\] (no) yes" "yes"

            do_patterns_actions $router recover

            exit
        }
    }
    
    #check routing/etc before proceed
    myexpect2 $router ".*" ""
    pre_work $router                    ;#make sure bgp up before proceed

    #myexpect2 $router ".*" "\r"
    #action $router

    #toggle the config 
    myexpect2 $router ".*" ""
    myexpect2 $router "> $" "configure"
    myexpect2 $router "# $" "rollback 1" ;#toggle RIs
    myexpect2 $router "# $" "show | compare | last 40 | no-more"
    persist_expect $router "# $" "commit"

    myexpect2 $router "# $" "rollback 1" ;#toggle RIs
    myexpect2 $router "# $" "show | compare | last 40 | no-more"
    persist_expect $router "# $" "commit"

    persist_expect $router "# $" "exit"

    #restart process (rpd)
    #restart_process $router "rpd" "jnpr123"

    #check routing/etc before proceed
    myexpect2 $router "> $" ""
    pre_work $router

    #check the issue
    myexpect2 $router ".*" ""
    check $router                       ;#make sure bgp up before proceed

    #todo: pace sync on file between multiple scripts
    #if ![read_flag_from_file $flagfile "re-switchover-vpls go"] {
    #    myputs "no go detected, re-check after 20s!"
    #    sleep 20
    #}

    switchover $router $hold_interval $su_password
    #catch {close -i $proc_login}

    myputs "\[script:#####################$i round of RE switchover done!###################\]"
    if $debug {myputs "\[script:will login to the router again shortly after $login_interval seconds...\]"}
    sleep $login_interval
    #write_flag_into_file $flagfile "issuechecker go"

    persist_login $login_script $router
}
