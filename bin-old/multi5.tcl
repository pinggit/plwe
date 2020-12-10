#!/usr/bin/env expect
proc myputs {msg args} {
    if {[llength $args]} {
        set logfile [lindex $args 0]
        set h_logfile [read [open $logfile w]]
        puts $h_logfile "\[[exec date]:[lindex [info level -1] 0]:..$msg..\]"
    } else {
        puts "\[[exec date]:[lindex [info level 1] 0]:..$msg..\]"
    }
}
proc myexpect {router pattern datasent {mytimeout 60}} {
    global debug session2host host2session
    set session $host2session($router)
    set controlC \x03
    set timeout $mytimeout
    #exp_send -i $session "\r"
    #myputs "myexpect: $session send a cmd -$datasent-"
    exp_send -i $session "$datasent\r"
    #myputs "myexpect: $session get a cmd -$datasent-"
    expect  {
	-i $session -re "$pattern" {
            return $expect_out(buffer)
	}
	-i $session timeout {
            #if timeout before get the prompt, ctrl-c to break
            myputs "timeout in ${timeout}s without a match for -$pattern-!"
            myputs "won't send -$datasent-!ctrl-c to break!"
            exp_send -i $session "$controlC"

            #or , use strict rule - won't proceed if unexpected thing happen!
            exit                
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
        }
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

proc pre_collect_info {router} {
    global debug session2host host2session
    set session $host2session($router)
    exp_send -i $session "\r"; 
    myexpect $router "> $" "show system uptime"
    #myexpect $session ">" "show version invoke-on all-routing-engines | no-more"
}

proc send_cmds {router cmd_list cmd_output_array {sleep 0}} {
    global debug session2host host2session
    set session $host2session($router)
    #use p_cmd_output to refer cmd_output, and get the array really structured
    upvar $cmd_output_array p_cmd_output_array
    #exp_send -i $session "\r"
    #expect -i $session "(>|%) $"
    set i 1;
    foreach cmd $cmd_list {
        set time_now [exec date +"%s"]
        send_log "send cmd -$cmd- to router -$router- at [exec date]\n"
        #clear the previous record before set new data
        if $debug {send_log "send_cmds: before unset: cmd_output_array looks [array get p_cmd_output_array]\n"}
        array unset p_cmd_output_array $router,$i,*
        if $debug {send_log "now unset $router,$i,\n"}
        if $debug {send_log "send_cmds: after unset: cmd_output_array looks [array get p_cmd_output_array]\n"}
        set p_cmd_output_array($router,$i,$cmd,$time_now) [myexpect $router "(>|%) $" $cmd 180]
        if $debug {send_log "send_cmds: after build: cmd_output_array looks [array get p_cmd_output_array]\n"}
	#set success_login_pattern	{(% |> |# |\$ |%|>|#|\$)$}
        incr i 1;sleep $sleep
    }
    if $debug {send_log "send_cmds: cmd_output_array looks [array get p_cmd_output_array]\n"}
}

proc get_output {cmd_output_array router cmd} {
    upvar $cmd_output_array p_cmd_output_array
    return "[lindex [array get p_cmd_output_array $router*$cmd*] 1]"
}

proc get_index {cmd_output_array router cmd} {
    #get the index of data array
    global debug
    upvar $cmd_output_array p_cmd_output_array
    #set key [lindex [array get p_cmd_output_array *$cmd*] 0]
    if $debug {send_log "get_index:cmd_out_array looks:\n[array get p_cmd_output_array]\n"}
    if $debug {send_log "use -$router- and -$cmd- to get a key\n"}
    set key [lindex [array get p_cmd_output_array $router*$cmd*] 0]
    if $debug {send_log "get_index:get a key as $key\n"}
    set key [string map [list \" "" $cmd ""] $key]  
    set pattern "$router,(\\d+),,(\\d+)"
    if $debug {send_log "get_index:get a key as $key\n"}
    if [regexp $pattern $key -> id time] {
        return [list $id $time]
    } else {
        myputs "can't find record of cmd -$cmd-!"
        return 0
    }
}

proc check_flag {check flag_check_method} {
    #iterate each cmd in cmd_list, populate the data/time info 
    #  in cmd_output_array global array
    #iterate the array and execute the corresponding hander for each cmd
    #  to check the issue
    global cmd_output_array_now cmd_output_array_prev
    global debug
    upvar $check p_check
    #global check_flag

    if $debug {send_log "check_flag:get check array as:\n[array get p_check]\n"}

    #for all router and cmds, build cmd_output_array structure
    foreach router [array names p_check] {
        myputs "===========checking router $router==========="
        if $debug {send_log "check_flag:for router $router, send cmdlist to send_cmds as:\n$p_check($router)\n"}
        send_cmds $router $p_check($router) cmd_output_array_now
    }

    if $debug {send_log "check_flag:cmd_output_array_now looks:\n[array get cmd_output_array_now]\n"}

    #run handler for each cmd on each router
    #build a result_flag(router,cmd_id) structure ,0 or 1
    foreach router [array names p_check] {
        set i 1
        foreach cmd $p_check($router) {
            lassign [get_index cmd_output_array_now $router $cmd] cmd_id time_now
            if $debug {send_log "check_flag:get router:id:time as $router:$cmd_id:$time_now\n"}
            set handler proc_${router}_$cmd_id
            send_log "call handler $handler to process this cmd for router $router\n"
            set result_flag($router,$i) [$handler $router $cmd]
            incr i 1
        }
    }
    if $debug {send_log "result_flag array looks [array get result_flag]"}

    if { $flag_check_method==0 } {
        #rule1: all routers all cmds, any single flag indicate a hit
        myputs "set flag when any single stream has problem"
        foreach router [array names p_check] {
            #all flags for router1: router1,1 0 router1,2 1
            set flag_list [array get result_flag $router*]
            set cmd_num [llength p_check($router)]            ;#num of cmds for router1
            for {set i 1} {$i<=$cmd_num} {incr i 1} {       ;#any flag means a hit
                if {$result_flag($router,$i)} {
                    return 1
                }
            }
        }
    } elseif {$flag_check_method==1} {
        #rule2: customized flags combinations
        #e.g.:if 1st cmd flags and 4th cmd is good, or vice-versa, meaning c-stream
        #good and p-stream is not in-sync, this indicate the scenario that either
        #vrf traffic not put into data-mdt , or the vice versa. this can be checked
        #by an "XOR" operation
        myputs "flag only when c-stream and p-stream are not consistent"
        if $debug {send_log "flag only when c-stream and p-stream are not consistent\n"}
        foreach router [array names p_check] {
            if { ([expr $result_flag($router,1) ^ $result_flag($router,4)]) ||  \
                 ([expr $result_flag($router,2) ^ $result_flag($router,5)]) ||  \
                 ([expr $result_flag($router,3) ^ $result_flag($router,6)])     \
               } {
                myputs "  found issue:router $router:c-stream and p-stream are not in-sync!"
                myputs "  result flags looks like:\n[array get result_flag $router*]\n"
                return 1
            } else {
                myputs "  not an issue:router $router c-stream and p-stream same flag!"
            }
        }
    } else {
        myputs "unknown flag_check_method $flag_check_method!"
        exit
    }

    array unset cmd_output_array_prev
    array set cmd_output_array_prev [array get cmd_output_array_now]
    return 0
}

proc proc_sfpjar2_1 {router cmd {rate_expected 400}} {
    #this is the handler for the first cmd(proc name 1) in the data
    #array(cmd_output_array) . new proc (proc2,proc3,etc) need to be defined
    #for each cmd the proc returned lagbased on whether the issue get detected
    #(1) or not(0)
    global cmd_output_array_prev cmd_output_array_now
    global debug 
    set rate_gap_ratio_threshold 0.3

    puts "";myputs "--------parsing cmd output with defined parser:[lindex [info level 1] 0]--------"
    myputs "$router:\[$cmd\]";puts ""

    if $debug {
        set procname [lindex [info level 0] 0]
        send_log "$procname:cmd_output_array_prev looks [array get cmd_output_array_prev]\n"
        send_log "$procname:cmd_output_array_now looks [array get cmd_output_array_now]\n"
    }

    #parse previous data array
    set cmd_output_prev [get_output cmd_output_array_prev $router $cmd]
    set time_prev [lindex [get_index cmd_output_array_prev $router $cmd] 1]
    set cout_list_prev [split $cmd_output_prev "\n"]

    #parse current data array
    set cmd_output [get_output cmd_output_array_now $router $cmd]
    set time_now [lindex [get_index cmd_output_array_now $router $cmd] 1]
    set cout_list [split $cmd_output "\n"]

    set cout_llen [llength $cout_list]

    send_log "proc1:for router $router cmd --$cmd-- got curr:prev time as $time_now:$time_prev\n"
    if {($time_prev==0) || ($time_now==0) || ($time_prev==$time_now)} {
        myputs "time extraction error, exit!"
        if $debug {
            send_log "time extraction error, exit!\n"
            send_log "proc1:router -$router- cmd -$cmd- cmd_output_prev looks -$cmd_output_prev-\n"
            send_log "proc1:router -$router- cmd -$cmd- cmd_output looks -$cmd_output-\n"
            send_log "proc1:convert cmd_output_prev to list as --$cout_list_prev--\n"
            send_log "proc1:convert cmd_output to list as --$cout_list--\n"
        }
        exit
    } else {
        send_log "time extraction correct, continue\n"
    }

    #process each line for 1 cmd
    for {set i 0} {$i<$cout_llen} {incr i 1} {
        set cout_line [lindex $cout_list $i]
        set cout_line_prev [lindex $cout_list_prev $i]

        #Statistics: 2 kBps, 20 pps, 12638517 packets
        set matchok1 [regexp {(\d+) pps, (\d+) packets} $cout_line -> pps packets_now]
        set matchok2 [regexp {(\d+) pps, (\d+) packets} $cout_line_prev -> pps_prev packets_prev]

        if $debug {
            send_log "take a curr line:--$cout_line--\n"
            send_log "take a prev line:--$cout_line_prev--\n"
            send_log "regex matching results are $matchok1:$matchok2\n"
        }

        if {($matchok1==1) && ($matchok2==1)} {
            #if any traffic does not look correct, set the flag
            #use packet counter as flag
            send_log "capture succeed in both both (curr and prev) verison of cmd, start calculate!\n"
            set rate_calc [expr ($packets_now - $packets_prev) / ($time_now - $time_prev)]
            set rate_diff_with_expected [expr {abs($rate_calc - $rate_expected)}]
            set rate_diff_with_pps [expr {abs($rate_calc - $pps)}]
            #chop 0.333 to 0.33
            set rate_diff_with_expected_ratio [format %.2f [expr double($rate_diff_with_expected) / $rate_expected]]
            #turn 0.3 to 30
            set rate_diff_with_expected_perc [expr $rate_diff_with_expected_ratio * 100]
            #display 0.3 as 30%
            myputs "$router:stream#$i rate - displayed:calculated:expected = $pps:$rate_calc:$rate_expected"
            myputs "  caculated rate:($packets_now-$packets_prev)/($time_now-$time_prev) packets/seconds = ${rate_calc}pps"
            myputs "    $rate_diff_with_pps diff with pps, ${rate_diff_with_expected}($rate_diff_with_expected_perc%)diff with expected"
            
            if { $rate_diff_with_expected_ratio >= $rate_gap_ratio_threshold } {
                myputs "    found traffic loss($rate_diff_with_expected_perc% > $rate_gap_ratio_threshold)!"
                return 1       ;#return on issue detection!
            } else {
                if $debug {
                    myputs "    traffic looks normal($rate_diff_with_expected_perc% < $rate_gap_ratio_threshold, within allowed jitter range)!"
                }
            }

        } else {
            #todo: remove the extra echoed stuff in cmd_out
        }
    }
    return 0                   ;#no issue detected
}
proc proc_sfpjar2_2 {router cmd} {
    proc_sfpjar2_1 $router $cmd 300
}
proc proc_sfpjar2_3 {router cmd} {
    #skip the check to 3rd cmd for sfpjar flag check list: nypjar2 not sending traffic to data-mdt!
    #Statistics: 3 kBps, 5 pps, 148495 packets
    #"show multicast route group 239.2.3.0 source-prefix $p_s_nypjar2 extensive | match pps"
    return 0
}
proc proc_sfpjar2_4 {router cmd} {
    proc_sfpjar2_1 $router $cmd 20
}
proc proc_sfpjar2_5 {router cmd} {
    proc_sfpjar2_1 $router $cmd 30
}
proc proc_sfpjar2_6 {router cmd} {
    return 0
}

#all router chpjar1's handers, same as sfpjar2
proc proc_chpjar1_1 {router cmd} {
    proc_sfpjar2_1 $router $cmd
}
proc proc_chpjar1_2 {router cmd} {
    proc_sfpjar2_2 $router $cmd
}
proc proc_chpjar1_3 {router cmd} {
    proc_sfpjar2_3 $router $cmd
}
proc proc_chpjar1_4 {router cmd} {
    proc_sfpjar2_4 $router $cmd
}
proc proc_chpjar1_5 {router cmd} {
    proc_sfpjar2_5 $router $cmd
}
proc proc_chpjar1_6 {router cmd} {
    proc_sfpjar2_6 $router $cmd
}

#all router nypjar2's handers, same as sfpjar2
proc proc_nypjar2_1 {router cmd} {
    proc_sfpjar2_1 $router $cmd
}
proc proc_nypjar2_2 {router cmd} {
    proc_sfpjar2_2 $router $cmd
}
proc proc_nypjar2_3 {router cmd} {
    proc_sfpjar2_3 $router $cmd
}
proc proc_nypjar2_4 {router cmd} {
    proc_sfpjar2_4 $router $cmd
}
proc proc_nypjar2_5 {router cmd} {
    proc_sfpjar2_5 $router $cmd
}
proc proc_nypjar2_6 {router cmd} {
    proc_sfpjar2_6 $router $cmd
}
####################### main ########################

match_max -d 1000000

set scriptbasename [exec basename $argv0]                       ;#get script basename
regexp {(.*)\..*} $scriptbasename -> scriptbasename_pref        ;#get the prefix before "."
#config file by def is located under the folder named by the script name
set configfile "~/.$scriptbasename_pref/$scriptbasename_pref.conf"
source $configfile

################process data####################

set routers [array names collect]

#login to all routers
foreach router $routers {
    persist_login $login_script $router
}

#pre-collect some info from all routers
myputs "collect some pre-info from routers $routers..."
foreach router $routers {
    pre_collect_info $router
}

#get baseline info from all routers
myputs "take a baseline from:[array names check]..."
send_log "take a baseline from:[array names check]...\n"
foreach router [array names check] {
    myputs "take a baseline from:$router"
    send_cmds $router $check($router) cmd_output_array_prev
}
send_log "cmd_output_array_prev looks [array get cmd_output_array_prev]\n"
myputs "will re-check after ${check_intv}s..."

sleep $check_intv

set j 0
for {set i 1} {$i<=$maxrounds} {incr i 1} {

    myputs "check issue on \"flag\" routers:\[[array names check]\]..."
    send_log "check issue on \"flag\" routers:\[[array names check]\]...\n"
    
    #if flag is triggered, collect more info from all routers
    if {[check_flag check $flag_check_method]} {
        #write the issue in a seperate file
        log_file; log_file -noappend $logfile_issue
        myputs "#############issue found in round $i! collect more info############"
        #exp_send -i $session1 "\r\r"

        myputs "#############fast commands############"
        foreach router [array names collect] {
            send_cmds $router $collect($router) cmd_output_array
        }

        #myputs "#############slow commands############"
        #send_cmds $router1 $cmd_slow_list_tx cmd_output_array 10
        #send_cmds $router2 $cmd_slow_list_rx cmd_output_array 10

        myputs "#############send email about the issue########!"
        
        set logfile_data [read [open $logfile_issue r]]
        spawn -noecho ssh svl-jtac-tool02
        expect {
            -re "\\\$ $" {send "echo \"issue found\" | mail -s \"issue found\\\!\" pings@juniper.net\r"}
            #-re "\\\$ $" {send "echo $logfile_data | mail -s \"issue found\\\!\" pings@juniper.net\r"}
        }
        expect -re "\\\$ $" {send "exit\r"}

        myputs "issue is captured for $j/$maxrounds_captured round(s)!"
        incr j 1
        if {$j >= $maxrounds_captured} {
            exit
            interact -i $session1
            interact -i $session2
        }
    } else {
        #continue to check if no issue found
    }

    #catch {close $session}

    myputs "##############round $i done###############"
    send_log "##############round $i done###############\n"
    myputs "will check the next round after ${check_intv}s";puts ""
    sleep $check_intv
}

