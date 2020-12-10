
#issuechecker {{{1}}}
#file parsing technique
proc domainname {} {
    set file [open /etc/resolv.conf r]
    while {[gets $file buf] != -1} {
        if {[scan $buf "domain %s" name] == 1} {
            close $file
            return $name
        }
    }
    close $file
    error "no domain declaration in /etc/resolv.conf"
}
#"enhanced" put: 
#myputs "var is now $var"               ;#print a debug msg if 'debug' is set
#myputs "var is now $var" mylog.txt     ;#print the msg to a file
proc myputs {msg args} { ;#{{{2}}}
    global debug
    if {[llength $args]} {
        set logfile [lindex $args 0]
        set h_logfile [open $logfile w]
        #puts $h_logfile "\[[exec date]:[lindex [info level -1] 0]:..$msg..\]"
        puts $h_logfile "$msg"
        close $h_logfile                        ;#very important
    } else {
        if $debug {
            set procname [lindex [info level 1] 0]
        } else {
            set procname ""
        }
        puts "\[[exec date]:$procname:..$msg..\]"
    }
}

proc myexpect {router pattern datasent {mytimeout 60} {isSendFirst 1} {isPersis 1}} { ;#{{{2}}}
    global debug session2host host2session
    global login_script
    set session $host2session($router)
    set controlC \x03
    set timeout $mytimeout
    #exp_send -i $session "\r"
    #if in "send-n-expect" mode, send data before expect
    if $isSendFirst {exp_send -i $session "$datasent\r"}
    expect  {
	-i $session -re "$pattern" {
            if $isSendFirst {
                return $expect_out(buffer)
            } else {
                if {$datasent == "expect_out"} {
                    return $expect_out(buffer)
                } else {
                    #if not in "send-n-expect" mode, send data only after expect
                    exp_send -i $session "$datasent\r"
                    return 1
                }
            }
	}
	-i $session timeout {
            #if timeout before get the prompt, ctrl-c to break
            myputs "timeout in ${timeout}s without a match for -$pattern-!"
            myputs "won't send -$datasent-!ctrl-c to break!"
            exp_send -i $session "$controlC"

            #extra return to generate a new prompt more robust, but not
            #reliable in some cases (upgrade,yes/no,etc)
            #exp_send -i $session "\r"  

            #or , use strict rule - won't proceed if unexpected thing happen!
            exit                
	}
        #for console
        -i $session "Type the hot key to suspend the connection: <CTRL>Z" {
            exp_send "\r"; exp_continue
        }
        -i $session -re "connection closed by foreign host" {
            myputs "connection closed by the router!"; exit
        }
        -i $session eof {
            myputs "spawned process terminated!";
            if $isPersis {
                #if disconnected before output return, wait 30s, re-login, re-send cmd
                #and re-expect the prompt
                sleep 30
                persist_login $login_script $router
                set session $host2session($router)
                if {$debug>1} {myputs "session set to new spawn_id $session"}
                #exp_send -i $session "$datasent\r"
                #for some reason, this doesn't work - report spawn id exp7 not open
                #it looks after exp_continue the spawn_id (session) is still old value
                #exp_continue
                myexpect $router $pattern $datasent $mytimeout $isSendFirst $isPersis
            } else {
                exit
            }
        }
        -i $session full_buffer {
            myputs "got full buffer!"
            exp_continue;
        }
    }
}
proc do_patterns_actions {router dataarray {pattern_timeout 120} {pa_intv 0}} { ;#{{{2}}}
    global debug cmd_output_array addclock send_initial_cr clockcmd
    upvar $dataarray da
    #upvar $cmd_output_array p_cmd_output_array
    if $debug {myputs "start pattern-action sequence:"}
    if {$debug==3} {send_log "[parray da]\n"}
    if $send_initial_cr {send "\r"}
    if {[info exists da($router)]} {
	if $debug {myputs "pattern-action data for $router now looks:"}
	if $debug {myputs "  -$da($router)-"}
    } else {
	myputs "pattern-action data for $router doesn't exist, check your config!"
	return 1
    }

    #get a data list from data array
    set l $da($router) 
    set j 1
    #go through this data list
    for {set i 0} {$i<=[expr [llength $l]-1]} {incr i 2} {
	#get pattern/data
	set pattern [lindex $l $i]	
	set datasent  [lindex $l [expr $i+1]]
	#execute the pattern-data pairs
	#myexpect2 $router $pattern $datasent $pattern_timeout	
	if $addclock {
	    if $debug { myputs "send a clock" }
	    myexpect $router ".*" "$clockcmd" 180 1
	}
        set time_now [exec date +"%s"]
        set cmd_output_array($router,$j,$datasent,$time_now) \
            [myexpect $router $pattern $datasent 180 0]
        incr j
	sleep $pa_intv
    }
}

proc write_flag_into_file {file cmd} { ;#{{{2}}}
    set f [open $file w]
    puts $f "$cmd"
    close $f
}

#for attp, attjlab scripts
#todo: need to generilize the "login_script" string
#  telnet, ssh
proc persist_login {login_script router args} { ;#{{{2}}}
    global debug session2host host2session 
    if {$debug>1} {myputs "$login_script $router $args"}
    if {$args!=""} {                            ;#there are extra params
            set username [lindex $args 0]       ;#take them as user/pass
            set password [lindex $args 1]
            spawn -noecho $login_script $router $username $password
    } else {                                    ;#otherwise use default(lab/hernon1)
        spawn -noecho $login_script $router
    }
    if {$debug>1} {myputs "spawn_id of persist_login is $spawn_id"}
    expect {
        -i $spawn_id -re "> $" {
            #once got the "> "prompt, start to ignore whatever comes after that
            #within 3s (attn might send some pre-commands once logged in)
            if {$debug>1} {myputs "hold 3s before proceed (wait until output totally dumped)"}
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
        -i $spawn_id "Connection closed by foreign host" {
            persist_login $login_script $router
        }
        -i $spawn_id default         {
            myputs "get eof/timeout, retry"
            sleep 1
            persist_login $login_script $router
        }
    }
}

#for non-script login:telnet/ssh/...
proc persist_login2 {login_script router args} { ;#{{{2}}}
    global debug session2host host2session 
    global domain_name

    
   if [regexp {(.*)@(.*)} $router -> username router] {
       if $debug {myputs "router name $router contains username $username and router name $router"}
   }

    if [info exists domain_name] {
        set router_full "$router$domain_name"
    } else {
        set router_full $router
    }

    if {[info exists args]} {                           ;#if login_info provided
#        if {[llength $args]==2} {
#            set username [lindex $args 0]
#            set password [lindex $args 1]
#            if {($login_script == "telnet")} {
#                spawn -noecho $login_script $router_full
#            } elseif {($login_script == "ssh")} {
#                spawn -noecho $login_script $username@$router_full
#            } else {
#                #todo: other protocols
#                myputs "not ssh or telnet, exit";exit
#            }
#            if $debug {myputs "spawn_id of persist_login is $spawn_id"}
#            expect {
#                -nocase -re "username|login" {send "$username\r"; exp_continue}
#                -nocase -re "password" {send "$password\r"; exp_continue}
#                -nocase -re "> $" {
#                    set timeout 4
#                    expect -re ".+" exp_continue
#                }
#            }
#        } elseif {[llength $args]==1}
        set logininfo [lindex $args 0]                  ;#then login with the login_info
        upvar $logininfo p_login_info
        if {($login_script == "ssh")} {
            spawn -noecho $login_script -o "StrictHostKeyChecking no" $username@$router_full
        } else {
            spawn -noecho $login_script $router_full
        }
        set session2host($spawn_id) $router
        set host2session($router) $spawn_id
        do_patterns_actions $router p_login_info
    } else {                                            ;#otherwise, login with login info
        spawn -noecho $login_script $router             ;#cisco/eserials?
        set session2host($spawn_id) $router
        set host2session($router) $spawn_id
    }
    expect {
        -nocase -re "> $" {
            set timeout 4
            expect -re ".+" exp_continue
        }
    }
    return $spawn_id
}

proc pre_collect_info {router} { ;#{{{2}}}
    global debug session2host host2session
    set session $host2session($router)
    exp_send -i $session "\r"; 
    myexpect $router "> $" "show system uptime"
    #myexpect $session ">" "show version invoke-on all-routing-engines | no-more"
}

proc send_cmds {router router_cmds_array cmd_output_array {cmd_interval 0} {pa_pair 0}} { ;#{{{2}}}
    global debug session2host host2session
    global login_script
    set session $host2session($router)
    #use p_cmd_output to refer cmd_output, and get the array really structured
    upvar $cmd_output_array p_cmd_output_array
    upvar $router_cmds_array p_router_cmds_array
    #exp_send -i $session "\r"
    #expect -i $session "(>|%) $"
    set i 1;
    set cmd_list $p_router_cmds_array($router)
    
    foreach cmd $cmd_list {
        set time_now [exec date +"%s"]
        if $debug {send_log "send_cmds:-$cmd- to router -$router- at [exec date]\n"}
        #clear the previous record before set new data
        if {$debug==3} {send_log "send_cmds: before unset:      \
            cmd_output_array looks [array get p_cmd_output_array]\n"}
        array unset p_cmd_output_array $router,$i,*
        if {$debug==3} {send_log "now unset $router,$i,\n"}
        if {$debug==3} {send_log "send_cmds: after unset:       \
            cmd_output_array looks [array get p_cmd_output_array]\n"}

        if {$cmd == "GRES"} {
            #todo: not done yet
            switchover $router 300
            set p_cmd_output_array($router,$i,$cmd,$time_now) $cmd
            #sleep $login_interval
            #this seems doesn't work
            #catch {close $session;wait $session}
            send -i $session "exit\r"
            expect -i $session eof {
                myputs "will relogin in 30s"
                sleep 30
                persist_login $login_script $router
            }
        } elseif [regexp {SLEEP (\d+)} $cmd -> sleeptime] {
            if $debug {myputs "sleep for ${sleeptime}s"}
            sleep $sleeptime
            set p_cmd_output_array($router,$i,$cmd,$time_now) $cmd
        } else {
            if $debug {myputs "router \"$router\":sending cmd \"$cmd\""}
            set p_cmd_output_array($router,$i,$cmd,$time_now) \
                [myexpect $router "(>|%|#) $" $cmd 180]
        }

        if {$debug==3} {send_log "send_cmds: after build: cmd_output_array \
            looks:\n[array get p_cmd_output_array]\n"}
	#set success_login_pattern	{(% |> |# |\$ |%|>|#|\$)$}
        incr i 1;sleep $cmd_interval
    }

    if {$debug==3} {send_log "send_cmds: the final cmd_output_array \
        looks:\n[array get p_cmd_output_array]\n"}
}

proc send_routers { router_cmds_array } { ;#{{{2}}}
    global debug 
    global cmd_output_array_$router_cmds_array
    upvar $router_cmds_array p_router_cmds_array
    if [array exists p_router_cmds_array] {
        if $debug {myputs "will execute the router-cmds-array:\"$router_cmds_array\" \
            for routers:[array names p_router_cmds_array]"
        }
        if $debug {send_log "will execute the router-cmds-array:\"$router_cmds_array\" \
            for routers:[array names p_router_cmds_array]...\n"
        }
        foreach router [array names p_router_cmds_array] {
            set cmd_list $p_router_cmds_array($router)

            set pa_pair 0
            foreach cmd $cmd_list {                             ;#if any cmd contains special CH, 
                if [regexp "#|>|%" $cmd] {set pa_pair 1}        ;#treat it as a pattern(prompt)
            }
            
            if $pa_pair {                                       ;#use diff method to handle 
                if $debug {myputs "cmds list contains prompt-looking strings, go pattern-action mode!"}
                #send a return to kick off
                myexpect $router ".*" "" 0
                do_patterns_actions $router p_router_cmds_array ;#pattern-data pairs: ">" "show "
            } else {                                            ;#or just pure data:  "show1 " "show2 "
                if $debug {myputs "executing \"$router_cmds_array\" for router:\"$router\""}
                send_cmds $router p_router_cmds_array cmd_output_array_$router_cmds_array
            }
        }
    } else {
        if $debug {myputs "array \"$router_cmds_array\" not configured, skipping"}
    }
}

proc outputs_parser {cmds_array} { ;#{{{2}}}
    global debug init_handler cmd_output_array_$cmds_array
    global init_handler_copy
    #set cmd_output_array "cmd_output_array_$cmds_array"
    upvar $cmds_array p_cmds_array
    set init_handler_copy $init_handler

    array set cmd_output_array_${cmds_array}_prev [array get cmd_output_array_$cmds_array]
    #run handler for each cmd on each router
    #build a result_flag(router,cmd_id) structure ,0 or 1
    foreach router [array names p_cmds_array] {
        set i 1
        foreach cmd $p_cmds_array($router) {
            #this is not portable : lassign is only supported in 8.5+
            #lassign [get_index cmd_output_array_check $router $cmd] cmd_id time_now
            set cmd_id [lindex [get_index cmd_output_array_$cmds_array $router $cmd] 0]
            set time_now [lindex [get_index cmd_output_array_$cmds_array $router $cmd] 1]
            if {$debug==3} {send_log "outputs_parser:get router:id:time as $router:$cmd_id:$time_now\n"}

            set handler ${cmds_array}_${router}_$cmd_id

            if {[info procs $handler]!=""} {    ;#set result_flag only if proc was defined
                send_log "call handler $handler to process this cmd for router $router\n"
            } else {
                if {$debug==3} {myputs "handler proc \"$handler\" not defined in the config file!"}
                if {$debug==3} {send_log "handler proc \"$handler\" not defined in the config file!\n"}
                global ${cmds_array}_code_${router}_$cmd_id
                if [info exist ${cmds_array}_code_${router}_$cmd_id] {
                    if {$debug==3} {
                        myputs "but,${cmds_array}_code \"${cmds_array}_code_${router}_$cmd_id\" defined,  \
                            defining handler proc \"$handler\""
                        send_log "but,${cmds_array}_code \"${cmds_array}_code_${router}_$cmd_id\" defined,  \
                            defining handler proc \"$handler\"\n"
                    }

                    set handler_proc    "proc ${cmds_array}_${router}_$cmd_id \{router cmd \{var1 400\}\} \{\n"
                    append handler_proc "global init_handler_copy\n"
                    if {$debug==3} {send_log "init_handler looks before replaced by $cmds_array:\n$init_handler\n"}
                    set init_handler_copy [string map "check $cmds_array" $init_handler]
                    if {$debug==3} {send_log "init_handler_copy looks after replaced by $cmds_array:\n$init_handler_copy\n"}
                    append handler_proc "eval \$init_handler_copy\n"
                    append handler_proc "for \{set i 0\} \{\$i<\$cout_llen\} \{incr i 1\} \{\n"
                    append handler_proc "    set cout_line \[lindex \$cout_list \$i\]\n"
                    append handler_proc "    set cout_line_prev \[lindex \$cout_list_prev \$i\]\n"
                    append handler_proc "[set ${cmds_array}_code_${router}_$cmd_id]\n"
                    append handler_proc "\}\n"
                    append handler_proc "myputs \"issue not seen from -\$router:\$cmd-!\"\n"
                    append handler_proc "return 0\n"
                    append handler_proc "\}\n"

                    if {$debug==3} {send_log "handler_proc now looks:\n$handler_proc"}

                    eval $handler_proc

                    send_log "call handler $handler to process this cmd for router $router\n"
                    set a [$handler $router $cmd]
                } else {
                    if {$debug==3} {myputs "and,${cmds_array}_code not defined in the config file, won't define the handler proc dynamically"}
                }
            }
            #if user don't want to define a proc,it is OK and script won't exit
            incr i 1                            
        }
    }
    array unset cmd_output_array_${cmds_array}_prev
    array set cmd_output_array_${cmds_array}_prev [array get cmd_output_array_$cmds_array]
}

proc get_output {cmd_output_array router cmd} { ;#{{{2}}}
    upvar $cmd_output_array p_cmd_output_array
    return "[lindex [array get p_cmd_output_array $router*$cmd*] 1]"
}

proc get_index {cmd_output_array router cmd} { ;#{{{2}}}
    #get the index of data array
    global debug
    upvar $cmd_output_array p_cmd_output_array
    #set key [lindex [array get p_cmd_output_array *$cmd*] 0]
    if {$debug==3} {send_log "get_index:$cmd_output_array looks:\n[array get p_cmd_output_array]\n"}
    if {$debug==3} {send_log "use -$router- and -$cmd- to get a key\n"}
    set key [lindex [array get p_cmd_output_array $router*$cmd*] 0]
    if {$debug==3} {send_log "get_index:get a key as $key\n"}
    set key [string map [list \" "" $cmd ""] $key]  
    set pattern "$router,(\\d+),,(\\d+)"
    if {$debug==3} {send_log "get_index:get a key as $key\n"}
    if [regexp $pattern $key -> id time] {
        return [list $id $time]
    } else {
        if $debug {myputs "can't find record of cmd -$cmd-!"}
        return 0
    }
}

proc check_flag {check flag_check_method} { ;#{{{2}}}
    #iterate each cmd in cmd_list, populate the data/time info 
    #  in cmd_output_array global array
    #iterate the array and execute the corresponding hander for each cmd
    #  to check the issue
    global cmd_output_array_check cmd_output_array_check_prev
    global rule_calc rule_msg debug init_handler
    upvar $check p_check
    global data dataformat datafile
    #global check_flag

    #run handler for each cmd on each router
    #build a result_flag(router,cmd_id) structure ,0 or 1
    foreach router [array names p_check] {
        set i 1
        foreach cmd $p_check($router) {
            #this is not portable : lassign is only supported in 8.5+
            #lassign [get_index cmd_output_array_check $router $cmd] cmd_id time_now
            set cmd_id [lindex [get_index cmd_output_array_check $router $cmd] 0]
            set time_now [lindex [get_index cmd_output_array_check $router $cmd] 1]
            if {$debug==3} {send_log "check_flag:get router:id:time as $router:$cmd_id:$time_now\n"}

            set handler check_${router}_$cmd_id

            if {[info procs $handler]!=""} {    ;#set result_flag only if proc was defined
                if $debug {send_log "call handler $handler to process this cmd for router $router\n"}
                if $debug {myputs "handler $handler defined, \
                    call handler $handler to process this cmd for router $router\n"}
                set result_flag($router,$i) [$handler $router $cmd]     ;#meaning:

                #formatting and export data
                #myputs "[format "$format" $data1 $data2]" $datafile
                if [info exists dataformat] {
                    myputs "$router,$time_now,[eval format $dataformat $data]" $datafile
                }
            } else {
                if {$debug==3} {myputs "handler proc \"$handler\" not defined in the config file!"}
                global check_code_${router}_$cmd_id
                if [info exist check_code_${router}_$cmd_id] {
                    if {$debug==3} {
                        myputs "but,check_code \"check_code_${router}_$cmd_id\" defined,  \
                            defining handler proc \"$handler\""
                    }

                    set handler_proc    "proc check_${router}_$cmd_id \{router cmd \{var1 400\}\} \{\n"
                    append handler_proc "global init_handler\n"
                    append handler_proc "global data dataformat datafile\n"
                    append handler_proc "eval \$init_handler\n"
                    append handler_proc "for \{set i 0\} \{\$i<\$cout_llen\} \{incr i 1\} \{\n"
                    append handler_proc "    set cout_line \[lindex \$cout_list \$i\]\n"
                    append handler_proc "    set cout_line_prev \[lindex \$cout_list_prev \$i\]\n"
                    append handler_proc "[set check_code_${router}_$cmd_id]\n"
                    append handler_proc "\}\n"
                    append handler_proc "myputs \"issue not seen from -\$router:\$cmd-!\"\n"
                    append handler_proc "return 0\n"
                    append handler_proc "\}\n"
                    if {$debug==3} {send_log "handler_proc now looks:\n$handler_proc"}
                    eval $handler_proc                                  ;#declare/define the proc, not executed yet!

                    send_log "call handler $handler to process this cmd for router $router\n"
                    set result_flag($router,$i) [$handler $router $cmd] ;#call/execute the proc

                    #formatting and export data
                    #myputs "[format "$format" $data1 $data2]" $datafile
                    if [info exists dataformat] {
                        myputs "$router,$time_now,[eval format $dataformat $data]" $datafile
                    }

                } else {
                    if $debug {myputs "no parser \"$handler\" defined for router \"$router\"\n"}
                    if {$debug==3} {myputs "check_code not defined in the config file, won't define the handler proc dynamically"}
                }
            }
            #if user don't want to define a proc,it is OK and script won't exit
            incr i 1                            
        }
    }
    if {$debug==3} {send_log "result_flag array looks [array get result_flag]\n"}

    array unset cmd_output_array_check_prev
    array set cmd_output_array_check_prev [array get cmd_output_array_check]

    #define rules for issue detection: how do we know we detect the issue or not?
    if {[info exists rule_calc]} {
        #if issue was defined in config file, use it as the rule to detect the issue
        #e.g.:if 1st cmd flags and 4th cmd is good, or vice-versa, meaning c-stream
        #and p-stream is not in-sync, this indicate the scenario that either
        #vrf traffic not totally put into data-mdt , or the vice versa. this
        #can be checked by an "XOR" operation
        if {[info exists rule_calc]} {puts "";myputs "issue definition:$rule_msg"}
        if $debug { if {[info exists rule_calc]} { send_log "issue definition:$rule_msg\n"}}

        foreach router [array names p_check] {
            if { [eval $rule_calc] } {
                if {[info exists rule_calc]} {
                    myputs "  found issue on router $router:$rule_msg"
                    send_log "\n  found issue on router $router:$rule_msg\n" 
                }
                myputs "  result flags looks like:\n[array get result_flag $router*]\n"
                return 1
            } else {
                if {[info exists rule_calc]} {myputs "  no issue for router $router:$rule_msg"}
            }
        }
    } else {    ;#if not defined in config file, use default rule: 
        #  all routers all cmds, any single flag indicate a hit
        #if {$debug==3} {send_log "result_flag array looks [array get result_flag]\n"}
        #if {$debug==3} {send_log "check array looks [array get p_check]\n"}
        if $debug {myputs "default rule:flag will be set whichever single command indicate a problem"}
        foreach router [array names p_check] {
            #all flags for router1: router1,1 0 router1,2 1
            set flag_list [array get result_flag $router*]
            set cmd_num [llength $p_check($router)]              ;#num of cmds for a router
            for {set i 1} {$i<=$cmd_num} {incr i 1} {           ;#any flag means a hit
                if $debug {send_log "check result_flag($router,$i)"}
                if {[info exists result_flag($router,$i)]} {    ;#but only if flag exist
                    if $debug {send_log "$result_flag($router,$i)\n"}
                    if {$result_flag($router,$i)} {
                        return 1
                    }
                } else {
                    if $debug {send_log "result_flag($router,$i) not exist\n"}
                }
            }
        }
    } 

    return 0
}

proc zipfile {file maxfilesize} { ;#{{{2}}}
    set file_size [file size $file]
    if {$file_size >= $maxfilesize} {
        myputs "file $file size($file_size) exceeded the limit ($maxfilesize), zip it!"
        log_file;myexec "gzip -f $file"
        return 1
    } else {
        return 0
    }
}

proc switchover_countdown {switchover_countdown} { ;#{{{2}}}
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

proc switchover {router {hold_interval 300} {su_password herndon1}} { ;#{{{2}}}
    global debug session2host host2session
    set session $host2session($router)
        
    exp_send -i $session "\r"
    myexpect $router "> $" "request chassis routing-engine master switch" 60 0
    expect -i $session "\\\[yes,no\\\] (no)" { send -i $session "yes\r"}

    expect {
        #Complete. The other routing engine becomes the master.
        #-re "\{backup\}\s+.*-re\[01]>" 
        #-re "\{backup\}\r\n.*-re\[01]>" 
        #-re "The other routing engine becomes the master.\r\n\r\n{backup}\r\n.*-re\[01]>"
        -i $session -re "routing engine becomes the master" {
            if $debug {myputs "\[script:detected switchover succeed! will exit current session...\]"}
            #send -i $session "exit\r"
            #myexpect $router "> $" "exit" #<---this will make ssh client exit, so expect exit
        }

        #-re "\{master\}\s+.*-re\[12]>" 
        #-re "\{master\}\r\n.*-re\[01]>" 
        -i $session -re "Command aborted. Not ready for mastership switch, try after \\d+ secs.*" {
            #if $debug {myputs "$expect_out(buffer)\r"}
            set switchover_countdown 240
            regexp {.*try after (.*) secs.*} $expect_out(buffer) -> switchover_countdown
            if $debug {myputs "\[script:detected switchover did not succeed...\]"}
            if {$switchover_countdown <= $hold_interval} {
                #wait and graceful switchover
                switchover_countdown $switchover_countdown
                switchover $router $hold_interval $su_password
            } else {
                if $debug {myputs "\[script:required switchover interval time left(${hold_interval}s) is less than CLI protection interval(${switchover_countdown}s left), will force rpd restart after $hold_interval seconds...\]"}
                sleep $hold_interval
                #force rpd core and switchover
                restart_rpd $router $su_password
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

proc restart_rpd {router su_password} { ;#{{{2}}}
    global debug session2host host2session
    set session $host2session($router)

    if $debug {myputs "start restarting rpd now!"}
    exp_send -i $session "\r"
    exp_send -i $session "start shell\r"
    myexpect $router "% $"        "su"                  0
    myexpect $router "Password:$" "$su_password"        0
    myexpect $router "% $"        "uptime\r"            0
    myexpect $router "% $"        "ps aux | grep rpd\r" 0
    expect -i $router -re "root\\s+(\\d+)\\s+.*sbin/rpd.*$" {
        set rpd_pid $expect_out(1,string)
        send -i $session "pwd\r"
        exp_send -i $session "kill -11 $rpd_pid\r"
    }
    expect -i $session -re "% $"
}

proc union {args} { ;#{{{2}}}
    #eval is a "must" here
    return [lsort -unique [eval concat $args]]
}

#attp {{{1}}}
#proc myputs {msg} {
#    puts "\[[exec date]:[lindex [info level 1] 0]:..$msg..\]"
#}

#initial version, no router/session mapping, expect and send
proc myexpect5 {pattern datasent {mytimeout 60}} { ;#{{{2}}}
    set controlC \x03
    set timeout $mytimeout
    expect  {
        #for console
        "Type the hot key to suspend the connection: <CTRL>Z" {
            send "\r"; exp_continue
        }
	-re "$pattern" {
	    exp_send "$datasent\r"
	}
	timeout {
            myputs "timeout in ${timeout}s without a match! ctrl-c to break out!"
            #myputs "timeout in ${timeout}s without a match!"
            exp_send "$controlC"
	    return 1
	}
        -re "connection closed by foreign host" {
            myputs "connection closed by the router!"; exit
        }
        eof {
            myputs "spawned process terminated!"; exit
        }
        full_buffer {
            myputs "got full buffer!"
            exp_continue;
        }
    }
}

proc do_patterns_actions5 {router dataarray {pattern_timeout 120} {pa_intv 0}} { ;# {{{2}}}
    global debug cmd_output_array
    upvar $dataarray da
    #upvar $cmd_output_array p_cmd_output_array
    if $debug {myputs "start pattern-action sequence:"}
    if {$debug==3} {send_log "[parray da]\n"}
    if {[info exists da($router)]} {
	if $debug {myputs "pattern-action data for $router now looks:"}
	if $debug {myputs "  -$da($router)-"}
    } else {
	myputs "pattern-action data for $router doesn't exist, check your config!"
	return 1
    }

    #get a data list from data array
    set l $da($router) 
    set j 1
    #go through this data list
    for {set i 0} {$i<=[expr [llength $l]-1]} {incr i 2} {
	#get pattern/data
	set pattern [lindex $l $i]	
	set datasent  [lindex $l [expr $i+1]]
	#execute the pattern-data pairs
	#myexpect2 $router $pattern $datasent $pattern_timeout	
        set time_now [exec date +"%s"]
        myexpect5 $pattern $datasent 180
        incr j
	sleep $pa_intv
    }
}

proc persist_login1 {login_script router args} { ;#{{{2}}}
    global debug session2host host2session 
    if {[llength $args]} {
        set port [lindex $args 0]
        spawn -noecho $login_script $router $args
    } else {
        spawn -noecho $login_script $router
    }
    if $debug {myputs "spawn_id in att script is $spawn_id"}
    expect {
        -i $spawn_id -re "Escape character is" {
            myputs "the router is alive"
            #send "\r"
            set session2host($spawn_id) $router
            set host2session($router) $spawn_id
            return $spawn_id
        }
        -i $spawn_id -nocase "Connection timed out" {
            myputs "connection explicit timeout, try again!"
            catch {close $spawn_id;wait $spawn_id}

            if {[llength $args]} {
                set port [lindex $args 0]
                persist_login1 $login_script $router $args
            } else {
                persist_login1 $login_script $router
            }

            #persist_login $login_script $router $args
        }
        -i $spawn_id default         {
            myputs "get eof/implicit timeout, try again!"
            sleep 1
            catch {close $spawn_id;wait $spawn_id}

            #persist_login $login_script $router $args

            if {[llength $args]} {
                set port [lindex $args 0]
                persist_login1 $login_script $router $args
            } else {
                persist_login1 $login_script $router
            }
        }
    }
}


#mylogin.tcl {{{1}}}

#function to execute given system CLI(s)
#previously report file/dir doesn't exists. tcl exec really sucks!
#looks need that {expand} or eval exec story to make it work
proc myexec {cmd} { ;#{{{2}}}
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
proc mylog_file {cmd} { ;#{{{2}}}
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
proc sendanemail {caseid file emailto {emailcc "pings@juniper.net"}} { ;#{{{2}}}

    global DEBUG
    global zip
    #get file from glob (like unix)
    set files [glob $file]
    if $DEBUG {myputs "get file lists: $files"}
    #if {[file exists [glob file]]} {
	if $zip {
	    if $DEBUG {myputs "zip set, will send zipped file"}
	    set attachname "$caseid.zip"
	    set execcmd "zip -jq - {expand} [glob $file] | uuencode $attachname | mail -s \"log of case:$caseid\" -c $emailcc $emailto"
	} else {
	    set attachname [exec basename $files]
	    if $DEBUG {myputs "zip not set, will send plain text file"}
	    #looks only 1 file is support at a time with uuencode
	    #this broke after upgrading to 12.04LTS
	    #set execcmd "uuencode [glob $file] $attachname | mail -s \"log of case:$caseid\" -c $emailcc $emailto"
	    #set execcmd "sendemail -s pod51010.outlook.com:587 -f pings@juniper.net -t pings@juniper.net -u \"log of case:$caseid\" -m \"this is the log file: $file\" -xu pings@juniper.net -xp \"EMAILPASSWORD\" -o tls=auto -a [glob $file]"
	    set execcmd "sendthisfile.sh [glob $file] pings@juniper.net \"log of case:$caseid\" "
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
	    myputs "send email to $emailto (and bcc $emailcc) with logfile:$files as attachment:$attachname"
	}
#    } 
#   else {
#	myputs "log file $file doesn't exist!"
#    }
}

#use this as a more informative expect function
#return 0 if got successful map. useful for result checking purpose
proc myexpect6 {usermsg pattern datasent timeout} { ;#{{{2}}}
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
proc get_login_info {loginfile login_info} { ;#{{{2}}}
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
proc do_patterns_actions6 {host pattern_timeout dataarray pa_intv} { ;#{{{2}}}
    global DEBUG addclock send_initial_cr clockcmd
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
	myexpect6 "pattern-action item $j" $pattern $datasent $pattern_timeout	
	#if $DEBUG {myputs "pattern-action item $j"}
	#do_cmd $pattern $datasent $pattern_timeout
	incr j
	#optionally pause between each step
	sleep $pa_intv
    }

    #this is to garrantee we can get the prompt for the last cmd to finish
    #otherwise the output of it will be held unless next cmd was inputted
    #this works in most cases:
    #myexpect6 "extra return" $pattern "\r" $pattern_timeout
    #but this is better:
    myexpect6 "extra return" ".*" "\r" $pattern_timeout
}

proc repeat_patterns_actions {maxrounds host pattern_timeout dataarray pa_intv} { ;#{{{2}}}
    myputs "$maxrounds rounds of patterns_actions_list will be executed"
    set i 1
    upvar $dataarray ref
    while {$i<=$maxrounds} {
	do_patterns_actions6 $host $pattern_timeout ref $pa_intv
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
proc do_pags_original_obsolete {pags host pattern_timeout pa_intv} { ;#{{{2}}}
    
    global DEBUG NEWFEATURE
    #pass the array via upvar (ref)
    upvar $pags PAGS
    if $DEBUG {myputs "get pattern action groups from list(PAGS):-$PAGS($host)-"}

    foreach pa_group $PAGS($host) {
	#this worked, but ugly, in terms of using global var like this
	if $DEBUG {myputs "get a pa_group $pa_group"}
	if $DEBUG {myputs "executed eval global $pa_group"}
	eval global $pa_group
	
	do_patterns_actions6 $host $pattern_timeout $pa_group $pa_intv
    }
}


proc do_pags {pags host pattern_timeout pa_intv} { ;#{{{2}}}
    
    global DEBUG NEWFEATURE configfile 
    #pass the array via upvar (ref)
    upvar $pags PAGS
    if $DEBUG {myputs "get pattern action groups from :-$PAGS($host)-"}

    #source $configfile

    if {[regexp "^E_" $pags]} {
	if $DEBUG {myputs "this pa_group $pa_group is end 'leaf' node,execute it..."}
	do_patterns_actions6 $host $pattern_timeout $PAGS $pa_intv 
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
		    do_patterns_actions6 $host $pattern_timeout $pa_group $pa_intv 
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

proc repeat_pags {maxrounds pags host pattern_timeout pa_intv pags_intv} { ;#{{{2}}}
    myputs "$maxrounds rounds of pattern action groups will be executed"
    upvar $pags PAGS
    set i 1
    while {$i<=$maxrounds} {
	do_pags PAGS $host $pattern_timeout $pa_intv
	puts "\n\n..#####################################..\n"
	puts "this is rounds $i of pattern action group..\n"
	puts "..#####################################..\n\n"

	sleep $pags_intv
	
	#wanted to stop the loop anytime,this doesn't work yet
#	trap {send_user "bye"; exit} SIGINT
	incr i 
    }
}

proc do_autologin_retry {max_login_retry success_login_pattern login_timeout pa_intv} { ;#{{{2}}}
    global login_info
    set i 1
    while {$i<=$max_login_retry} {
    #check the login result to see if a retry is needed
    #again, tcl syntax: \\~ for ~ ; \\$ for $, \\\\ for \, etc.. to match ping@640g-laptop:~$
    #set success_pattern "laptop:\\~*\\$"
	set autologin_fail [myexpect6 "check if login success after retry $i" $success_login_pattern "\r" $login_timeout]
	#if failed, but still within retry limit, retry login
	if $autologin_fail {
	    puts "..last login failed..will retry $i/$max_login_retry time(s) \n"
	    do_patterns_actions6 $hostname $login_timeout login_info $pa_intv
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
proc do_cmd {pattern cmd timeout1} { ;#{{{2}}}
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

    set result [myexpect6 "checking prompt for -$cmd-" $pattern $cmd $timeout1]
    return result
}


#get cmds out of cmds file, use global var(no ref) to pass value back
proc get_cmds {cmdsfile cmds} { ;#{{{2}}}
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
proc loaddata {datafile data_type data} { ;#{{{2}}}
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
proc do_cmds {pattern cmds cmd_interval waittime} { ;#{{{2}}}
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
proc do_cmds_groups {pattern cmds_group_list cmds_groups_intv cmd_interval waittime} { ;#{{{2}}}
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

proc repeat_cmds {maxrounds pattern4cmd cmds cmds_intv cmd_timeout} { ;#{{{2}}}
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

proc do_confirm {} { ;#{{{2}}}
    myputs "you sure you want to do that?(y/n)"
    stty raw
    expect_user {
	"y" {return 1}
	"n" {return 0}
    }
}

proc do_sel {} { ;#{{{2}}}
    myputs "start sel data collections"
#    if $NEWFEATURE {
    if {[do_confirm]} {
	send "date\n"
    } else {
	myputs "sel data collections cancelled"
    }
#    }
}

proc do_showtech {} { ;#{{{2}}}
}

proc diag_on_error {} { ;#{{{2}}}
}

#interact mode,return control to user if all work done/failed
proc do_interact {code} { ;#{{{2}}}


    #hostname here is only needed when invoke script with local shell
    #zip need to be global here, otherwise "global" in sendanemail won't
    #take effect
    global configfile hostname host initlog_file zip
    global CGS

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
    if $welcome_msg {
    myputs "
    welcome to mylogin shell! it's an clone(spawn) of bash plus some new customized shortcut commands
    the intention is to help JTAC day-to-day work. But it can also be used for ANY other usual tasks 
    wherever the origin shell(e.g bash) was used, plus now we have logging, anti-timeout, and other features.
    type !i for currently available cmds, !h for most frequently used cmds, and !T for a mini tutorial
    enjoy it!

                                                              -v0.2 	ping@juniper.net"
    }

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
    #(2014-01-05) disable for a test
    #stty -raw
    #stty -reset
    #trap {
    #        set rows 
    #        set cols 
    #        stty rows $rows columns $cols < $spawn_out(slave, name)
    #} WINCH
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
	EXCUTIONS: 						ATTACHING (logs/coredump decode):                           	
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
		not generalized yet, only a/v in my PC                      (set caseid 2222-2222-2222),obsolete 
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
	    !lc CASEID (=>log name: $caseid.log) or		!da set host xo<CR>  !lC 1111-1111-1111(=>log name: $caseid$host.log)
	    !ls !lr (s)top/(r)esume (l)og recording on current logfile:$currlog_file
	    !mS pre<CR> or !ep then !eg or !eCb (=>exec CLIes) 	!eDm (=> execute dmp decode, currently only a/v on my own pc)
	    !mS scott_check<CR> (=>run scott script) 		!mS cpucheck<CR> (=>run KA34030 high CPU check)
	    
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
	    :it will also send an email after it finished (read below)
	    !eg

	    :wait until it finished, type following to send another email anytime you want the logs, 
	    :to whoever defined in \$emailme(currently is $emailme), $emailcase (currently $emailcase) in file ~/.mylogin/mylogin.conf
	    :this is convenient to (a)ttach (l)og to (me), to (c)ase, or to (b)oth
	    !alm   (or !alc)   (or !alb)

	    :sometimes its unavoidable to run some script, !mS <SCRIPT> is the command, SCRIPT need to be defined in a file under ~/.mylogin/ 
	    :here is an example to run scott's data-collection CLIes and attach the log in an email, 
	    :the SCRIPT file was ~/.mylogin/scott_check.conf, you can check that file and 
	    :just follow its simply syntax you can define your own new script file,
	    :type following and hit enter
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
		sendanemail $newcaseid "$dmp_upload_dir1*decode*" $emailme
	    } elseif {$a eq "!adc"} {
		sendanemail $newcaseid "$dmp_upload_dir1*decode*" $emailcase
	    } elseif {$a eq "!adb"} {
		sendanemail $newcaseid "$dmp_upload_dir1*decode*" $emailme $emailcase
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
	    do_cmds $pattern4cmd precmds $cmds_intv $cmd_timeout
	    unset precmds
	}

	#execute cmds
	-echo -re "!docmds|!ec" {
	    if $DEBUG {myputs "resourcing config file $configfile"}
	    if $redosource {source $configfile}
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
	    repeat_cmds $maxrounds $pattern4cmd cmds $cmds_intv $cmd_timeout
	}

	#execute cmds groups
	-echo -re "!docmdsgrps|!eg" {
	    myputs "start cmds groups"
	    if $redosource {source $configfile}
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
		do_patterns_actions6 $host $pattern_action_timeout pattern_action_list $pattern_action_intv
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

	    if { $a eq "!ra\r" } {
		if $DEBUG {myputs "round not set, use maxrounds value in config file:$maxrounds}
		set rounds $maxrounds
		repeat_patterns_actions $rounds $host $pattern_action_timeout pattern_action_list $pattern_action_intv
	    } else {
		#scan the input and find what followed "!ra " and use it as max_rounds
		if {[scan $a "!ra %d" rounds] eq 1} {
		    if $DEBUG {myputs "round is set to $rounds}
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

	    if { $a eq "!rG\r" } {
		if $DEBUG {myputs "round not set, use maxrounds value in config file:$maxrounds}
		set rounds $maxrounds
		repeat_pags $rounds PAGS $host $pattern_action_timeout $pattern_action_intv $pattern_action_groups_intv
		sendanemail $newcaseid $currlog_file $emailme 
	    } else {
		#scan the input and find what followed "!rG " and use it as max_rounds
		if {[scan $a "!rG %d" rounds] eq 1} {
		    if $DEBUG {myputs "round is set to $rounds}
		    repeat_pags $rounds PAGS $host $pattern_action_timeout $pattern_action_intv $pattern_action_groups_intv
		    sendanemail $newcaseid $currlog_file $emailme 
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
	    set pa_group 1
	    #scan the input and find what followed "!mG " and use it as pa_group
	    if {[scan $a "!mG %s" pa_group] eq 1} {
		#eval global $pa_group
		if {[lsearch -exact $PAGL($host) $pa_group] == -1} {
		    myputs "the pattern action group $pa_group is not available in PAGL!"
		    myputs "\ncurrently available pattern action groups:\n$PAGL($host)\n"
		} else {
		    #do_patterns_actions6 $host $pattern_action_timeout $pa_group $pattern_action_intv
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
		    #do_patterns_actions6 $host $pattern_action_timeout $pa_group $pattern_action_intv
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
		
	    if $redosource {source $configfile}
	    set a $interact_out(0,string)	    

	    #speical handling for coredump analysis
	    if {($a eq "!ed") || ($a eq "!eDm") || ($a eq "!eDc") || ($a eq "!eDb")} {
		if $DEBUG {myputs "caseid is now $caseid"}
		log_file
		#log to a seperated,fresh decode file(disable append)
		log_file -noappend $decodelog_file
		myputs "change log file to $decodelog_file"

		#do_patterns_actions6 $host $pattern_action_timeout pattern_action_list $pattern_action_intv
		do_pags core $host $pattern_action_timeout $pattern_action_intv 

		log_file
		log_file $currlog_file
		myputs "change log file back to $currlog_file"

		if {$a eq "!eDm"} {
		    sendanemail $caseid "$dmp_upload_dir1*decode*" $emailme
		} elseif {$a eq "!eDc"} {
		    sendanemail $caseid "$dmp_upload_dir1*decode*" $emailcase
		} elseif {$a eq "!eDb"} {
		    sendanemail $caseid "$dmp_upload_dir1*decode*" $emailme $emailcase
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
	    do_patterns_actions6 $host $pattern_action_timeout prework $pattern_action_intv
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
