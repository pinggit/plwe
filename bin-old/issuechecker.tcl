#!/usr/bin/env expect
# 1. integrate the login info with jtaclab script
# 5. quiet mode (set debug 0)   #<------done (2014-05-03) 
# 2. test pattern-action pairs  #<------done (2014-05-19) 
#    just add a return to kick it off
# 8. add "SLEEP" keyword        #<------dirty done (2014-05-27) 
# 3. add "GRES" keyword #<------(2014-06-02) 
#    work, may need more test
# 8. support persistent send cmd - 
#    when disconnected, will reconnect and re-send        #<------done (2014-06-04) 
#    add myexpect3 to support this
#    currently only for GRES,
#    maybe extend this ability to all commands?         #<------(2014-11-08) 
#
# 4. simplify the user regex definition
# 6. complete pre-test feature, 
#    save match to each command in sth like result_flap
#    borrow result_flap logic, so 
#    proceed to "check" only if result_flap expression is true
#    use case: only check bgp when ospf is full
# 7. add deadline
# 

source ~/bin/mylib.tcl
proc usage {scriptbasename_pref} { ;#{{{1}}}
    puts "usage:"
    puts "  #to generate a example config files:"
    puts "  $scriptbasename_pref"
    puts "  #to run the script with a config file:"
    puts "  $scriptbasename_pref \[CONFIG_FILE_NAME_UNDER_CURRENT_FOLDER\]"
    puts "example:"
    puts "  $scriptbasename_pref"
    puts "  $scriptbasename_pref config1.conf"
}

set init_handler { ;#{{{1}}}
#common code-------------------------------------------------start
#these are the common codes that should be included in every handler
#it provides some default data structures that can be used for analysis

    global cmd_output_array_check_prev cmd_output_array_check
    global debug 

    set rate_gap_ratio_threshold 0.3

    puts ""
    if $debug {myputs "--------parsing cmd output with defined parser--------"}
    myputs "$router:\[$cmd\]"

    if $debug {
        set procname [lindex [info level 0] 0]
        send_log "$procname:cmd_output_array_check_prev looks [array get cmd_output_array_check_prev]\n"
        send_log "$procname:cmd_output_array_check looks [array get cmd_output_array_check]\n"
    }

    #parse previous data array
    set cmd_output_prev [get_output cmd_output_array_check_prev $router $cmd]
    set time_prev [lindex [get_index cmd_output_array_check_prev $router $cmd] 1]
    set cout_list_prev [split $cmd_output_prev "\n"]

    #parse current data array
    set cmd_output [get_output cmd_output_array_check $router $cmd]
    set time_now [lindex [get_index cmd_output_array_check $router $cmd] 1]
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
        if $debug {
            send_log "time extraction correct, continue\n"
        }
    }
    for {set i 0} {$i<$cout_llen} {incr i 1} {          ;#for each line from cmd output
        set cout_line [lindex $cout_list $i]            ;#take a line from the output list
        set cout_aline($i) $cout_line
        set cout_line_prev [lindex $cout_list_prev $i]  ;#take the same line,from the previous capture
        set cout_aline_prev($i) $cout_line_prev
    }

#common code-------------------------------------------------end
}

proc generate_config_template {config_template_file} { ;#{{{1}}}
    set config_template {
                                                            #config file

                                                            #summary:
                                                            #1. login all routers
                                                            #2. send "pre_check" cmds
                                                            #3. send "check" cmds to get a baseline
                                                            #4. sleep $check_intv
                                                            #5. go in a loop 
                                                            #   a) send "check" cmds repeatedly
                                                            #   b) calculate/analyze the "issue" (check_flag)
                                                            #   c) is the issue got detected ?
                                                            #       yes: 
                                                            #           send "collect" cmds
                                                            #           send a notification (email)
                                                            #           have recreated $maxrounds_captured? 
                                                            #               yes: exit
                                                            #               no : go to 6
                                                            #       no:
                                                            #           send "test" cmds
                                                            #           go to 5
                                                            #6. sleep $check_intv and go to 5


    ;####################################################################
    ;##1. general parameters , optional                                ##
    ;####################################################################


    set debug 1                                             ;#debug level: 1(brief), 3(verbose)

    set login_script jtaclab                                   ;#script used to login to the router
                                                            ;#attn - nina's att account
                                                            ;#attse - att se account
                                                            ;#attjtac - att jtac account
                                                            ;#jtaclab - account to login to jtac lab


    set logfile "log1_test_$runtime.txt"                  ;#log file name, optional
    set logfile_issue "log2_test_$runtime.txt"            ;#log file only after issue detected, optional
    #set flag_check_method 1                                ;#any flag indicate a hit
    set check_intv 10                                       ;#interval between each round check
    #set maxrounds 20000                                    ;#max rounds to check
    #set maxrounds_captured 10                              ;#max rounds to capture the issue
    #set maxfilesize 100000000                              ;#max size of each log file(in Bytes) before get gzipped

                                                            
                                                            
    set routers {alecto hermes}                                 ;#list of all routers, for login purpose only, optional.
                                                            ;#if not defined, will find out all routers name from cmd arrays
                                                            ;#'pre_test', 'test', 'check' and 'collect'

    set domain_name ".jtac-east.jnpr.net"

    #telnet:
    set login_info(alecto) 		{ogin lab assword herndon1}
    set login_info(hermes) 		{ogin lab assword herndon1}
    #ssh:
    set ssh_username lab
    #set login_info(alecto) 		{assword herndon1}
    #set login_info(hermes) 		{assword herndon1}

    ####################################################################
    ##2. one time info collection, before the test loops              ##
    ####################################################################

                                                            ;#pre_test: run just 1 time before the test loop starts
    set pre_test(alecto) [ list         \
        "show system uptime"                \
        "show version"                \
    ]
    set pre_test(hermes) $pre_test(alecto)



    ####################################################################
    ##3. router-cmds array: check(ROUTERNAME) :                       ##
    ##  cmds that are used to detect the issues                       ##
    ####################################################################

    set check(alecto) [ list        \
        "show interfaces ge-1/3/0.601 extensive | match pps"          \
    ]
    set check(hermes) [ list \
        "show interfaces ge-1/2/2.601 extensive | match pps"        \
    ]


                                                            #"issue" definition, optional
                                                            #  set rule_calc { expr ... }
                                                            #  if omitted, use default rule - consider to be an issue whichever 
                                                            #  command detect an issue. 

                                                            #  in this example, a complex issue definition(rule) is defined: it is
                                                            #  considered an issue only if, in any router, one of the 1st/4th, 2nd/5th or
                                                            #  3rd/6th streams does not look "consistent" (meaning like stream 1 is
                                                            #  detected to be a problem however stream 4 looks OK, so on so forth.
                                                            #  according to the check array, this means c-stream was not totally forwarded
                                                            #  into p-stream, or vice versa. In either case, it means packet loss)

    #set rule_calc {                                                         \
    #
    #    expr                                                                \
    #
    #        [expr $result_flag($router,1) ^ $result_flag($router,4)] ||     \
    #
    #        [expr $result_flag($router,2) ^ $result_flag($router,5)] ||     \
    #
    #        [expr $result_flag($router,3) ^ $result_flag($router,6)]        \
    #
    #}

    #optional: print a essage  about currently defined rule
    #set rule_msg "consider an issue only when c-stream and p-stream are not consistent"






    ####################################################################
    ##4. router-cmds array: collect(ROUTERNAME) :                     ##
    ##  cmds that will be sent everytime after the issue got detected ##
    ####################################################################

    set collect(alecto) [ list 				        \
        "show interfaces ge-1/3/0.601 extensive | no-more"          \
        "start shell"                                               \
        "sleep 10"                                                  \
        "exit"                                                      \
    ] 

    set collect(hermes) $collect(alecto)





    ####################################################################
    ##4.1 (optional) hook code:check_code_ROUTERNAME_CMDNUMBER        ##
    ##  parsing output of each {router,cmd} to detect (an) issue(s)   ##
    ####################################################################

    set check_code_alecto_1 {
        #match from the any line of the output
        set does_match [regexp {Input  packets:\s+(\d+)\s+(\d+) pps} $cout_line -> packets pps]
        #or: just match from the 1st line of the output
        #    set does_match [regexp {Input  packets:\s+(\d+)\s+(\d+) pps} $cout_aline(1) -> packets pps]
        if {($does_match)} {
            if {$pps == 0} {
                myputs "pps 0, no traffic, the issue appears!"
                return 1
            }
        }
    }


    ####################################################################
    ##4.2 (optional) cmd handler(procedure):check_ROUTERNAME_CMDNUMBER##
    ##  to parse the output of each {router,cmd} to detect any issues ##
    ####################################################################
    #proc check_alecto_1 {router cmd {var1 400}} {
    #
    #                                                        #this is the handler for the No.1 cmd (indicated in the proc name: ..."1") from
    #                                                        #the "check" command list (part 2 of this config file), which will be sent to router "sfpjar2":
    #                                                        #  "show multicast route group 239.2.3.0 source-prefix $p_s_sfpjar2 extensive | match pps"
    #                                                        #one proc (check_ROUTER1_2, check_ROUTER2_1, etc) may be (optionally) defined for
    #                                                        #each cmd.  the proc need to returned either 1 or 0, based on whether the issue get
    #                                                        #detected or not
    #
    #
    #global init_handler                                     ;#init the procedure, don't change these 2 lines
    #eval $init_handler
    #
    #
    #                                                        #some "built-in" vars available to be used in the handler proc:
    #                                                        #  cout_list           :a list that stores each line of the command output
    #                                                        #  cout_list_prev      :same, but stores command output from previous execution(for comparison)
    #                                                        #  cout_llen           :total numer of lines of the command output
    #                                                        #
    #                                                        #  cout_line           :any line in current cmd output (e.g. "show version")
    #                                                        #  cout_line_prev      :same, but take from a previous output
    #                                                        #  cout_aline(3)       :3rd line in current cmd output (e.g. "show version")
    #                                                        #  cout_aline_prev(3)  :same, but take from a previous output
    #
    #
    #                                                        #process each line for current cmd output
    #    for {set i 0} {$i<$cout_llen} {incr i 1} {          ;#for each line from cmd output
    #        set cout_line [lindex $cout_list $i]            ;#take a line from the output list
    #        set cout_line_prev [lindex $cout_list_prev $i]  ;#take the same line,from the previous capture
    #
    ##your own code-----------------------------------------------start
    #
    #                                                        #from the line,retrieve the desired counter value. in this case "pps" and "packets":
    #                                                        #  Input  packets:         839694229583              2022060 pps
    #
    #        set does_match [regexp {Input  packets:\s+(\d+)\s+(\d+) pps} $cout_line -> packets pps]
    #
    #        if {($does_match)} {                            ;#if any traffic does not look correct, set "flag"
    #            if {$pps == 0} {
    #                myputs "the issue appears!"
    #                return 1
    #            }
    #        }
    #
    ##your own code-----------------------------------------------end
    #
    #    }
    #
    #    myputs "issue not seen in cmd -$cmd-!"
    #    return 0                   ;#no issue detected
    #}



    ####################################################################
    ##5. cmds to be sent if the issue has not been reproduced yet     ##
    ####################################################################

                                                            #test:          commands ran in the test loop before 'check' commands
    set test(alecto) [ list                         \
        "configure private"                         \
        "show | compare | last 40 | no-more"        \
        "exit"                                      \
    ]


                                                            #test1~10:      run different cmds in each round
                                                            #    if any of these exist, "test" won't be executed
                                                            #run: test1 in 1st round, test2 in 2nd round, ...test4 in 4th round, 
                                                            #     test1 in 5th round ... so on so forth
    #set test1(pe12) [ list           \
    #    "configure private"         \
    #    "rollback 1" "show | compare | last 40 | no-more" \
    #    "commit"                    \
    #    "exit"                      \
    #]
    #
    #set test2(pe13) [ list           \
    #    "configure private"         \
    #    "rollback 1" "show | compare | last 40 | no-more" \
    #    "commit"                    \
    #    "exit"                      \
    #]
    #set test3(pe12) [ list           \
    #    "configure private"         \
    #    "rollback 1" "show | compare | last 40 | no-more" \
    #    "commit"                    \
    #    "exit"                      \
    #]
    #set test4(pe13) [ list           \
    #    "configure private"         \
    #    "rollback 1" "show | compare | last 40 | no-more" \
    #    "commit"                    \
    #    "exit"                      \
    #]



    #todo:
    #config_change, in defined sequence among all routers
    #set config_change(1,sfpjar2) [ list       \
    #    "configure private"                 \
    #    "exit"                              \
    #]
    #set config_change(2,chpjar1) $config_change(sfpjar2)
    #set config_change(3,nypjar2) $config_change(sfpjar2)
    #set config_change(sfpjar2) [ list       \
    #    "SWITCHOVER"                        \
    #]

    }

    myputs $config_template $config_template_file

}


proc generate_config_examples {} { ;#{{{1}}}

set issuechecker_attrouters.conf {
        set debug 0           ;#debug level: 1(brief), 3(verbose)
        set login_script attp
        set logfile "log1_973222_$runtime.txt"
        set logfile_issue "log2_973222_$runtime.txt"
        set check_intv 5              
        set routers {pe12 pe13}       
                                      
        set check(pe12) [ list        \
            "show vpls connections instance vpls:1501 remote-site 13 | no-more"         \
            "show interfaces xe-0/1/2.2100 extensive | no-more"                         \
            "show configuration apply-groups"                                           \
            {request pfe execute target fpc0 command "show jnh 0 exception terse"}  \
            {request pfe execute target fpc4 command "show jnh 0 exception terse"}  \
        ]
        set check(pe13) [ list \
            "show vpls connections instance vpls:1501 remote-site 12 | no-more"         \
            "show interfaces xe-0/1/2.2100 extensive | no-more"                         \
            "show configuration apply-groups"                                           \
            {request pfe execute target fpc0 command "show jnh 0 exception terse"}  \
            {request pfe execute target fpc4 command "show jnh 0 exception terse"}  \
        ]
    }
    set issuechecker_check.conf {
        set debug 0

        set pre_test(alecto) {
            "show version | no-more" 
            "show interfaces fxp0 terse"
        }

        set pre_test(hermes) $pre_test(alecto)

        set check(alecto) {
            "show interfaces ge-1/3/0.601 extensive | match pps"
        }
    }
    set issuechecker_dataexport.conf {
        set debug 0
        set check_intv 5

        set pre_test(alecto) {
            "show version | no-more" 
            "show interfaces fxp0 terse"
        }

        set pre_test(hermes) $pre_test(alecto)

        set check(alecto) {
            "show interfaces ge-1/3/0.601 extensive | match pps"
        }

        set check_code_alecto_1 {
            #match from any line of the output
            set does_match [regexp {Input  packets:\s+(\d+)\s+(\d+) pps} $cout_line -> packets pps]
            #or: just match from the 1st line of the output
            #    set does_match [regexp {Input  packets:\s+(\d+)\s+(\d+) pps} $cout_aline(1) -> packets pps]
            if {($does_match)} {
                if {$pps == 0} {
                    myputs "pps 0, no traffic, the issue appears!"
                    return 1
                }
            }
        }
    }
    set issuechecker_monitor_change.conf {
        set debug 1     ;#print more info about how the script is running (def 1)
        #set debug 3    ;#most verbose info, set only when sth went wrong
        set logfile "log1_pr12345.txt"     ;#log file name, optional
        #log file that record all info AFTER issue detected, optional
        set logfile_issue "log2_pr12345_$runtime.txt" 
        set maxfilesize 100000000         ;#max size of each log file(in Bytes) before get gzipped
        #set log_dir "~/att-jtac-lab-logs"
        set check_intv 5                  ;#interval between each round check
        set maxrounds 20000               ;#max rounds to check
        set maxrounds_captured 10         ;#max rounds to capture the issue
        #set flag_check_method 1           ;#any flag indicate a hit

        set pre_test(alecto) {
            "show version | no-more" 
            "show interfaces fxp0 terse"
        }
        set pre_test(hermes) $pre_test(alecto)

        set check(alecto) {
            "show interfaces ge-1/3/0.601 extensive | match pps"
            "show vpls connections instance 13979:333601"
        }
        set check(hermes) {
            "show interfaces ge-1/2/2.601 extensive | match pps"
            "show vpls connections instance 13979:333601"
        }

        #issue definition code:
        set check_code_alecto_1 {       #<------
            set does_match1 [                                   \
                regexp {Input  packets:\s+(\d+)\s+(\d+) pps}    \
                $cout_line -> packets_now pps                       \
            ]
            set does_match2 [                                   \
                regexp {Input  packets:\s+(\d+)\s+(\d+) pps}    \
                $cout_line_prev -> packets_prev pps_prev        \
            ]

            set rate_expected 6

            if {($does_match1==1) && ($does_match2==1)} {
                set rate_calc [expr ($packets_now - $packets_prev) / ($time_now - $time_prev)]
                set rate_diff_with_expected [expr {abs($rate_calc - $rate_expected)}]
                
                if { $rate_diff_with_expected >= 5} {
                    myputs "issue appears! rate changed too much!"
                    return 1       ;#return 1 to indicate issue detection!
                }
            }
        }
    }
    set issuechecker_multi.conf {
        set debug 0
        set pre_test(alecto) {"show version | no-more" "show interfaces fxp0 terse"}
        set pre_test(hermes) $pre_test(alecto)
    }
    set issuechecker_replicate_collect.conf {
        set pre_test(alecto) {
            "show version | no-more" 
            "show interfaces fxp0 terse"
        }
        set pre_test(hermes) $pre_test(alecto)

        #use these commands in alecto to check the issue
        set check(alecto) {
            "show interfaces ge-1/3/0.601 extensive | match pps"
            "show vpls connections instance 13979:333601"
        }

        #use these commands in hermes to check the issue
        set check(hermes) {
            "show interfaces ge-1/2/2.601 extensive | match pps"
            "show vpls connections instance 13979:333601"
        }

        #issue definition code: apply to 1st check cmd sent to alecto
        set check_code_alecto_1 {
            #match from any line of the output
            set does_match [                                    \
                regexp {Input  packets:\s+(\d+)\s+(\d+) pps}    \
                $cout_line -> packets pps                       \
            ]
            #or: just match from the 1st line of the output
            #    set does_match [regexp {Input  packets:\s+(\d+)\s+(\d+) pps} $cout_aline(1) -> packets pps]
            if {($does_match)} {
                if {$pps == 0} {
                    myputs "pps 0, no traffic, the issue appears!"
                    return 1
                }
            }
        }

        #if issue got replicated, take following action
        set collect(alecto) [ list 				        \
            "show interfaces ge-1/3/0.601 extensive | no-more"          \
            "file copy /var/log/messages messages-issue"                \
            "start shell pfe network"                                   \
            "show syslog messages"                                      \
            "exit"                                                      \
        ] 

        #otherwise (issue not appear), take these action and re-check
        set test(alecto) [ list                         \
            "configure private"                         \
            "rollback 1"                                \
            "show | compare | last 40 | no-more"        \
            "exit"                                      \
        ]
    }
    set issuechecker_replicate.conf {
        set pre_test(alecto) {
            "show version | no-more" 
            "show interfaces fxp0 terse"
        }
        set pre_test(hermes) $pre_test(alecto)

        set check(alecto) {
            "show interfaces ge-1/3/0.601 extensive | match pps"
            "show vpls connections instance 13979:333601"
        }
        set check(hermes) {
            "show interfaces ge-1/2/2.601 extensive | match pps"
            "show vpls connections instance 13979:333601"
        }

        #issue definition code:
        set check_code_alecto_1 {
            #match from any line of the output
            set does_match [                                    \
                regexp {Input  packets:\s+(\d+)\s+(\d+) pps}    \
                $cout_line -> packets pps                       \
            ]
            #or: just match from the 1st line of the output
            #    set does_match [regexp {Input  packets:\s+(\d+)\s+(\d+) pps} $cout_aline(1) -> packets pps]
            if {($does_match)} {
                if {$pps == 0} {
                    myputs "pps 0, no traffic, the issue appears!"
                    return 1
                }
            }
        }
    }
    set issuechecker_replicate_options.conf {
        set debug 0     ;#print more info about how the script is running (def 1)
        #set debug 3    ;#most verbose info, set only when sth went wrong
        set logfile "log1_pr12345.txt"     ;#log file name, optional
        #log file that record all info AFTER issue detected, optional
        set logfile_issue "log2_pr12345_$runtime.txt" 
        set maxfilesize 100000000         ;#max size of each log file(in Bytes) before get gzipped
        #set log_dir "~/att-jtac-lab-logs"
        set check_intv 5                  ;#interval between each round check
        set maxrounds 20000               ;#max rounds to check
        set maxrounds_captured 10         ;#max rounds to capture the issue
        #set flag_check_method 1           ;#any flag indicate a hit

        set pre_test(alecto) {
            "show version | no-more" 
            "show interfaces fxp0 terse"
        }
        set pre_test(hermes) $pre_test(alecto)

        set check(alecto) {
            "show interfaces ge-1/3/0.601 extensive | match pps"
            "show vpls connections instance 13979:333601"
        }
        set check(hermes) {
            "show interfaces ge-1/2/2.601 extensive | match pps"
            "show vpls connections instance 13979:333601"
        }

        #issue definition code:
        set check_code_alecto_1 {
            #match from any line of the output
            set does_match [                                    \
                regexp {Input  packets:\s+(\d+)\s+(\d+) pps}    \
                $cout_line -> packets pps                       \
            ]
            #or: just match from the 1st line of the output
            #    set does_match [regexp {Input  packets:\s+(\d+)\s+(\d+) pps} $cout_aline(1) -> packets pps]
            if {($does_match)} {
                if {$pps == 0} {
                    myputs "pps 0, no traffic, the issue appears!"
                    return 1
                }
            }
        }
    }
    set issuechecker_single.conf {
        set debug 0
        set pre_test(alecto) {"show version | no-more" "show interfaces fxp0 terse"}
    }
    myputs ${issuechecker_check.conf}                      "[pwd]/issuechecker_example3_check.conf"
    myputs ${issuechecker_attrouters.conf}                 "[pwd]/issuechecker_example5_attrouters.conf"
    myputs ${issuechecker_dataexport.conf}                 "[pwd]/issuechecker_example9_dataexport.conf"
    myputs ${issuechecker_monitor_change.conf}             "[pwd]/issuechecker_example8_monitor_change.conf"
    myputs ${issuechecker_multi.conf}                      "[pwd]/issuechecker_example2_multi.conf"
    myputs ${issuechecker_replicate_collect.conf}          "[pwd]/issuechecker_example7_replicate_collect.conf"
    myputs ${issuechecker_replicate.conf}                  "[pwd]/issuechecker_example4_replicate.conf"
    myputs ${issuechecker_replicate_options.conf}          "[pwd]/issuechecker_example6_replicate_options.conf"
    myputs ${issuechecker_single.conf}                     "[pwd]/issuechecker_example1_single.conf"
}
#attjlab_script {{{1}}}
set attjlab_script {#!/usr/bin/env expect
    array set HostMap {\
         pe5                192.168.43.14\
         pe6                192.168.43.17\
         pe3                192.168.43.8\
         pe1                192.168.112.101\
         pe8                192.168.112.8\
         pe9                192.168.112.9\
         pe10               192.168.112.10\
         pe11               192.168.112.11\
         pe12               192.168.112.12\
         pe13               192.168.112.13\
         pe14               192.168.112.14\
         pe15               192.168.112.15\
         pe16               192.168.112.16\
         pe17               192.168.112.17\
         pe26               192.168.112.26\
         PE26               192.168.112.26\
         pe28               192.168.112.28\
         pe32               192.168.119.32\
         pe24               192.168.119.24\
         pe40               192.168.119.40\
         pe41               192.168.112.41\
         pe42               192.168.112.42\
         pe43               192.168.112.43\
         hub1               10.144.0.126\
         hub2               10.144.0.127\
         scooby             192.168.46.146 \
        prefix-re0-con			b6tsa05:7029	\
        ravens-re0-con			b6tsa05:7030	\
        nemesis-re0-con			b6tsa05:7031	\
        nemesis-re1-con			b6tsa05:7033	\
        bajie-re0-con 			b6tsa05:7034	\
        bajie-re1-con 			b6tsa05:7035	\
        pontos-re0-con			b6tsa05:7036	\
        pontos-re1-con			b6tsa05:7037	\
        ares-re0-con			b6tsa05:7038	\
        lakers-re0-con			b6tsa05:7039	\
        lakers-re1-con			b6tsa05:7040	\
        dolphins-re0-con		b6tsa05:7041	\
        dolphins-re1-con		b6tsa05:7042	\
        donald-re0-con 			b6tsa05:7043	\
        donald-re1-con 			b6tsa05:7044	\
        mix-re0-con			b6tsa05:7046	\
        thunder-re1-con			b6tsa15:7024	\
        thunder-re0-con			b6tsa15:7023	\
        redskins-re1-con		b6tsa15:7022	\
        redskins-re0-con		b6tsa15:7021	\
        tianjin-re1-con			b6tsa15:7020	\
        tianjin-re0-con			b6tsa15:7019	\
        jaguars-re0-con			b6tsa05:7045	\
        panthers-re0-con		b6tsa17:7024	\
        mickey-re0-con   		b6tsa17:7010	\
        mickey-re1-con   		b6tsa17:7011	\
        rams-re0-con			b6tsa26:7023	\
        bills-re0-con			b6tsa26:7024	\
        bears-re0-con			b6tsb09:7013	\
        chargers-re0-con		b6tsb09:7014	\
        sphinx-re0-con			b6tsb09:7015	\
        patriots-re0-con		b6tsb09:7016	\
        bulls-re0-con			b6tsb09:7017	\
        nyx-re0-con  			b6tsb09:7018	\
        nyx-re1-con  			b6tsb09:7019	\
        atlantix-re0-con 		b6tsb09:7020	\
        atlantix-re1-con 		b6tsb09:7021	\
        8111-con 			b6tsb17:7002	\
        8112-con			b6tsb17:7003	\
        a1500-re0-con                   b6tsb17:7004\
        suns-re0-con			b6tsb17:7001	\
        rio-re0-con 			b6tsb17:7005	\
        rio-re1-con 			b6tsb17:7006	\
        maya-re0-con   			b6tsb17:7007	\
        maya-re1-con   			b6tsb17:7008	\
        steelers-re0-con		b6tsb17:7009	\
        willi-re0-con 			b6tsb25:7002	\
        willi-re1-con  			b6tsb25:7003	\
        flip-re0-con  			b6tsb17:7012	\
        flip-re1-con  			b6tsb17:7013	\
        chiefs-re0-con			b6tsb17:7014	\
        eros-re0-con			b6tsb17:7015	\
        eros-re1-con			b6tsb17:7016	\
        alecto-re0-con			b6tsb17:7021	\
        alecto-re1-con			b6tsb17:7022	\
        havlar-re0-con			b6tsb17:7034	\
        pacifix-re0-con 		b6tsb17:7035	\
        pacifix-re1-con 		b6tsb17:7036	\
        antalya-re0-con  		b6tsb17:7046	\
        antalya-re1-con  		b6tsb17:7047	\
        pheonix-re0-con			b6tsb09:7015	\
        saints-re0-con			b6tsb17:7045	\
        raiders-re0-con			b6tsb17:7044	\
        kratos-re1-con 			b6tsb17:7043	\
        kratos-re0-con 			b6tsb17:7042	\
        obelix-re0-con			b6tsb17:7041	\
        obelix-re0-con			b6tsb17:7040	\
        archer-re1-con			b6tsb17:7039	\
        archer-re0-con			b6tsb17:7038	\
        rome-re0-con 		        b6tsb23:7031	\
        x2020-re0-con 			b6tsb23:7032	\
        clippers-re0-con		b6tsb17:7017	\
        clippers-re1-con		b6tsb17:7018	\
        sonics-re0-con			b6tsb25:7024	\
        sonics-re1-con			b6tsb25:7025	\
        asterix-re0-con 		b6tsb23:7023	\
        asterix-re1-con 		b6tsb23:7024	\
        timex-re0-con   		b6tsb23:7025	\
        timex-re1-con		        b6tsb23:7026	\
        hornets-re0-con			b6tsb23:7007	\
        hornets-re1-con			b6tsb23:7008	\
        nereus-re0-con 			b6tsb23:7005	\
        nereus-re1-con 			b6tsb23:7006	\
        styx-re0-con 			b6tsb23:7009	\
        styx-re1-con 			b6tsb23:7010	\
        rhodes-re0-con			b6tsb23:7012	\
        texans-re0-con			b6tsb23:7013	\
        pluto-re0-con 			b6tsb23:7001	\
        pluto-re1-con 			b6tsb23:7002	\
        hermes-re0-con 			b6tsb23:7018	\
        hermes-re1-con 			b6tsb23:7019	\
        idefix-re0-con 			b6tsb25:7004	\
        idefix-re1-con 			b6tsb25:7005	\
        alcoholix-re0-con		b6tsb25:7006	\
        alcoholix-re1-con		b6tsb25:7007	\
        photogenix-re0-con 		b6tsb25:7008	\
        photogenix-re1-con 		b6tsb25:7009	\
        dogmatix-re0-con  		b6tsb25:7010	\
        dogmatix-re1-con  		b6tsb25:7011	\
        automatix-re0-con  		b6tsb25:7016	\
        automatix-re1-con  		b6tsb25:7017	\
        dynamix-re0-con			b6tsb23:7020	\
        gilby-re0-con			b6tsb17:7024	\
        mustang-re0-con			b6tsb17:7019	\
        camaro-re0-con			b6tsb17:7020	\
        getafix-re0-con 		b6tsb25:7012	\
        getafix-re1-con 		b6tsb25:7013	\
        botanix-re0-con 		b6tsb25:7014	\
        botanix-re1-con 		b6tsb25:7015	\
        paris-re0-con			b6tsb17:7010	\
        paris-re1-con			b6tsb17:7011	\
        knicks-re0-con			b6tsb25:7034	\
        knicks-re1-con			b6tsb25:7035	\
        seahawks-re0-con		b6tsb25:7036	\
        seahawks-re1-con		b6tsb25:7037	\
        matrix-re0-con			b6tsb25:7038	\
        matrix-re1-con			b6tsb25:7039	\
        cacophonix-re0-con		b6tsb25:7040	\
        cacophonix-re1-con		b6tsb25:7041	\
        tjure-re0-con			b6tsb25:7033	\
        mavericks-re0-con		b6tsb25:7032	\
        colts-re0-con			b6tsb25:7031	\
        snorre-re0-con			b6tsb25:7030	\
        mini-re0-con			b6tsb23:7021	\
        mini-re1-con			b6tsb23:7022	\
        wickie-re0-con			b6tsd25:7028	\
        tintin-re0-con 			b6tse25:7042	\
        tintin-re1-con 			b6tse25:7043	\
        wukong-re0-con 			b6tse25:7044	\
        wukong-re1-con 			b6tse25:7045	\
        kurt-re0-con 			b6tse23:7035	\
        kurt-re1-con 			b6tse23:7036	\
        rockets-re0-con			b6tse23:7023	\
        rockets-re1-con			b6tse23:7024	\
        earth-re0-con			b6tse25:7011	\
        earth-re1-con			b6tse25:7012	\
        deadalus-re0-con		b6tse25:7009	\
        deadalus-re1-con		b6tse25:7010	\
        holland-re0-con			b6tsb25:7026	\
        holland-re1-con			b6tsb25:7027	\
        greece-re0-con			b6tsb25:7018	\
        greece-re1-con			b6tsb25:7019	\
        turkey-re0-con			b6tsb25:7028	\
        egypt-re0-con			b6tsb25:7029	\
        vmx                                 10.85.4.17      \
        vmx-vre                             10.85.4.102     \
    }
    set domain_suffix_con jtac-west.jnpr.net
    set domain_suffix jtac-east.jnpr.net
    set debug 0
    proc getcmd {cmdfile} {
       set ulist {}
        set file [open $cmdfile r]
        while {[gets $cmdfile buf] != -1} {
            if {[scan $buf "%s" cmd] == 1} {
               lappend ulist $cmd
            }
        }
        close $file
        error "no cmd found in file $cmdfile"
    }
    proc myputs {msg} {
        puts "\[[exec date]:[lindex [info level 1] 0]:..$msg..\]"
    }
    proc myexpect {pattern datasent {mytimeout 60}} {
        set controlC \x03
        set timeout $mytimeout
        expect  {
            "Type the hot key to suspend the connection: <CTRL>Z" {
                send "\r"; exp_continue
            }
            -re "$pattern" {
                exp_send "$datasent\r"
            }
            timeout {
                myputs "timeout in ${timeout}s without a match! ctrl-c to break out!"
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
    proc do_patterns_actions {router dataarray {pattern_timeout 120} {pa_intv 0}} {
        global debug cmd_output_array
        upvar $dataarray da
        if $debug {myputs "start pattern-action sequence:"}
        if {$debug==3} {send_log "[parray da]\n"}
        if {[info exists da($router)]} {
            if $debug {myputs "pattern-action data for $router now looks:"}
            if $debug {myputs "  -$da($router)-"}
        } else {
            myputs "pattern-action data for $router doesn't exist, check your config!"
            return 1
        }
        set l $da($router) 
        set j 1
        for {set i 0} {$i<=[expr [llength $l]-1]} {incr i 2} {
            set pattern [lindex $l $i]	
            set datasent  [lindex $l [expr $i+1]]
            set time_now [exec date +"%s"]
            myexpect $pattern $datasent 180
            incr j
            sleep $pa_intv
        }
    }
    proc persist_login1 {login_script routername args} {
        global debug
        if {[llength $args]} {
            set port [lindex $args 0]
            spawn -noecho $login_script $routername $args
        } else {
            spawn -noecho $login_script $routername
        }
        if $debug {myputs "spawn_id in att script is $spawn_id"}
        expect {
            -i $spawn_id -re "Escape character is" {
                myputs "the router is alive"
                return $spawn_id
            }
            -i $spawn_id -nocase "Connection timed out" {
                myputs "connection explicit timeout, try again!"
                catch {close $spawn_id;wait $spawn_id}
                if {[llength $args]} {
                    set port [lindex $args 0]
                    persist_login1 $login_script $routername $args
                } else {
                    persist_login1 $login_script $routername
                }
            }
            -i $spawn_id default         {
                myputs "get eof/implicit timeout, try again!"
                sleep 1
                catch {close $spawn_id;wait $spawn_id}
                if {[llength $args]} {
                    set port [lindex $args 0]
                    persist_login1 $login_script $routername $args
                } else {
                    persist_login1 $login_script $routername
                }
            }
        }
    }
    if $argc<1 {
       send_tty "Usage: $argv0 hostname/IP\[:port\] \[account\] \[password\]\r\n"
       exit -1
    }
    set scriptbasename [exec basename $argv0]
    set log_dir "~/att-lab-logs"
    set jnprse_pass "Stop@jnpr#"
    set rtr_name [lindex $argv 0] 
    set rtr_name_ori $rtr_name
    if { [info exists HostMap([lindex $argv 0])] } {
       set rtr_name $HostMap([lindex $argv 0])
       if $debug {myputs "the router name is $rtr_name"}
    }
    if {$scriptbasename == "attn"} {
        set rtr_user j-tac-nz1
        set rtr_pwd Zhao\$jnpr\$
    } elseif {$scriptbasename == ".attp"} {
        set rtr_user j-tac-ps1
        set rtr_pwd Song_jtac#
        } elseif {$scriptbasename == "attse"} {
        set rtr_user jnpr-se
        set rtr_pwd EGS!@jnpr
        set rtr_pwd Juniper@jnpr@
    } elseif {$scriptbasename == "attjtac"} {
        set rtr_user jtac
        set rtr_pwd jnpr123
    } elseif {$scriptbasename == "attde"} {
        set rtr_user j-dev-5
        set rtr_pwd 5O_P5BwUT
    } elseif {$scriptbasename == ".jtaclab" || $scriptbasename == "telnet1"} {
        set rtr_user lab
        set rtr_pwd herndon1
        if {$rtr_name == "10.85.4.17"} {
            set rtr_user labroot
            set rtr_pwd lab123
        }
        set log_dir "~/att-jtac-lab-logs"
    } else {
    }
    if {[file exists $log_dir]} {
    } else {
        send_tty "dir $log_dir doesn't exist, creating one...\n"
        if [catch {file mkdir $log_dir} failed_reason] {
            send_tty "failed to creating dir $log_dir: $failed_reason\n"
            exit 1
        } else {
            send_tty "...done!\n"
        }
    }
    set port 0
    if {$scriptbasename == ".jtaclab" || $scriptbasename == "telnet1"} {
       set rtr_name_short $rtr_name
       if [regexp {(.*):(.*)} $rtr_name -> rtr_name port] {
           if $debug {myputs "router name contains port info: $port"}
           if [regexp {^\d+\.\d+.\d+\.\d+$} $rtr_name] {
               if $debug {myputs "router name is IP address, won't attach domain name"}
           } else {
               if $debug {myputs "router name is not IP address, will attach domain name"}
               append rtr_name ".$domain_suffix_con"
           }
       } else {
           if $debug {myputs "router name does not contain port info"}
           if [regexp {^\d+\.\d+.\d+\.\d+$} $rtr_name] {
               if $debug {myputs "router name is IP address, won't attach domain name"}
           } else {
               if $debug {myputs "router name is not IP address, will attach domain name"}
               append rtr_name ".$domain_suffix"
           }
       }
    }
    if $argc>1 {
       set rtr_user [lindex $argv 1]
    }
    if $argc>2 {
       set rtr_pwd [lindex $argv 2]
    }
    set timeout -1
    if {                                            \
        $scriptbasename == "attn"           ||      \
        $scriptbasename == ".attp"           ||      \
        $scriptbasename == "attse"          ||      \
        $scriptbasename == "attjtac"        ||      \
        $scriptbasename == "attde" } {              \
        set login_info($rtr_name)       [list           \
            "assword"  "$jnprse_pass"                   \
            ">$"           "$rtr_name"                  \
            "login: "      "$rtr_user"                  \
            "Password:"    "$rtr_pwd"                   \
            ">"            "set cli screen-width 300"   \
            ">"            "set cli timestamp"   \
        ]
        spawn -noecho ssh -o "StrictHostKeyChecking no" jnpr-se@12.3.167.8
        do_patterns_actions $rtr_name login_info
    } elseif { $scriptbasename == ".jtaclab" || $scriptbasename == "telnet1" } {
        set login_info($rtr_name)       [list               \
            "login: "      "$rtr_user"                  \
            "assword:"    "$rtr_pwd"                   \
            ">"             "set cli screen-width 300"      \
            ">"            "set cli timestamp"   \
        ]
        if $port {                           ;#if login_info provided
            set spawn_id [persist_login1 telnet $rtr_name $port]
            if $debug {myputs "persist_login telnet $rtr_name $port"}
        } else {
            if $debug {myputs "persist_login telnet $rtr_name"}
            set spawn_id [persist_login1 telnet $rtr_name]
        }
        expect  {
            "Type the hot key to suspend the connection: <CTRL>Z" {
                send "\r"; exp_continue
            }
            "ogin: $" {
                exp_send "$rtr_user\r";exp_continue
            }
            -re "assword:" {
                exp_send "$rtr_pwd\r";exp_continue
            }
            -re ">" {
                exp_send "set cli screen-width 300\r"
                expect ">" { exp_send "set cli timestamp\r" }
            }
            -re "(\\\$|#) $" {      #for unix CLIes
                exp_send "date\r"
            }
        }
        if {$scriptbasename == "telnet1"} {
            if $argc>1 {
               set command [lindex $argv 1]
            }
            myexpect ">" $command 180
            expect {
                -re "@\[A-Za-z0-9.-\]+>"
            }
            puts "\n"
            exit
        }
    } else {
    }
    if {$scriptbasename == ".jtaclab" || $scriptbasename == "telnet1"} {
       set rtr_name $rtr_name_short
    }
    set time                        [exec date +%Y-%m%d-%H%M-%S]
    set time                        [exec date ]
    set mylog_file                  "$log_dir/$rtr_name_ori.log"
    send_tty "current log file $mylog_file\n"
    set f [open $mylog_file a]
    puts $f "
    <<<<<<<<<<<<<<<<<<< new logs since: <<<<<<<<<<<<<<<<<<<<<<<
    < $time $env(USER) 
    <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    "
    close $f
    log_file $mylog_file
    set anti_idle_timeout 		60
    set anti_idle_string 		" \177"	
    set cmdlist {}
    interact {
        timeout $anti_idle_timeout {
            send $anti_idle_string
        }
        -echo -re "!i" {
            puts "\n"
            parray HostMap
            puts "\n"
        }
    }
}

#main {{{1}}}

#params {{{2}}}
match_max -d 1000000
set addclock 0
set send_initial_cr 0
set clockcmd "show system uptime"
set runtime [exec date "+%Y%m%d-%H%M%S"]
set flagfile "~/.flagfile"
set scriptbasename [exec basename $argv0]                       ;#get script basename
regexp {(.*)\..*} $scriptbasename -> scriptbasename_pref        ;#get the prefix before "."
#set configfile "$dirname/$scriptbasename_pref.conf"
set scriptdirname [file dirname $argv0]
set scriptrootname [file rootname $argv0]
#by def. look for config file with the same name as the scriptname, under current folder
set configfile "[pwd]/$scriptbasename_pref.conf"
set config_template_file "[pwd]/${scriptbasename_pref}_template.conf"

set debug 1                     ;#debug level: 0(quiete), 1(brief), 2(verbose), 3(extensive)

if {$argc==0} {                         
    usage $scriptbasename_pref;
    generate_config_template $config_template_file
    #puts "\na template config file:\[$config_template_file\] has been generated: "
    generate_config_examples
    puts "\na following example config files has been generated FYR: "
    puts "[system ls -l | grep example]"
    exit
}

#if config file name provided, use that file
if {$argc>=1} {                         
    #set configfile "[pwd]/[lindex $argv 0]"
    set configfile "[lindex $argv 0]"
    if {[file exists $configfile] == 0 } {
        myputs "file [lindex $argv 0] not found under current folder [pwd]!"
        exit
    }
}

if {$argc>=2} {
    myputs "too much parameters!"
    usage;exit
}

set login_script jtaclab           ;#script used to login to the router
                                ;  #attn - nina's att account
                                ;  #attse - att se account
                                ;  #attjtac - att jtac account
                                ;  #attjlab - account to login to jtac lab

#set log_dir "~/att-jtac-lab-logs"
set logfile "log1_$runtime.txt"          ;#log file name, optional
set logfile_issue "log2_$runtime.txt" ;#log file only after issue detected, optional

set flag_check_method 1         ;#any flag indicate a hit
set check_intv 20               ;#interval between each round check
set maxrounds 20000             ;#max rounds to check
set maxrounds_captured 1        ;#max rounds to capture the issue
set maxfilesize 100000000       ;#max size of each log file(in Bytes) before get gzipped
set notify_on_exit 1

#myputs "load config file $configfile ..."
source $configfile      ;#call customer config file

if {[info exists log_dir]} {
    if {[file exists $log_dir]} {
    } else {
        send_tty "dir $log_dir doesn't exist, creating one...\n"
        if [catch {file mkdir $log_dir} failed_reason] {
            send_tty "failed to creating dir $log_dir: $failed_reason\n"
            exit 1
        } else {
            send_tty "...done!\n"
        }
    }
} else {
    set log_dir "./"
}

if {[info exists logfile]} {
    log_file -noappend "$log_dir/$logfile"
    set logfile_prev "$log_dir/$logfile"
}

if {$debug>1} {myputs "log_dir is $log_dir"}

#call attjlab_script {{{2}}}
regsub -all {set log_dir "~/att-lab-logs"} $attjlab_script "set log_dir $log_dir" attjlab_script
regsub -all {set log_dir "~/att-jtac-lab-logs"} $attjlab_script "set log_dir $log_dir" attjlab_script
if {$debug==3} {send_log "attjlab_script now looks like\n$attjlab_script\n"}


if {                                \
    ($login_script == "jtaclab") || \
    ($login_script == "attse") ||   \
    ($login_script == "attjtac") || \
    ($login_script == "attp")       \
   } {
        myputs $attjlab_script "[pwd]/.jtaclab"
        myputs $attjlab_script "[pwd]/.attp"
        myputs $attjlab_script "[pwd]/.attse"
        myputs $attjlab_script "[pwd]/.attjtac"
        system chmod 755 "[pwd]/.jtaclab"
        system chmod 755 "[pwd]/.attp"
        system chmod 755 "[pwd]/.attse"
        system chmod 755 "[pwd]/.attjtac"
        if {$debug>1} {myputs "\nattjlab script generated"}
} else {
}



#login {{{2}}}

#login to all routers
#todo, not done yet
if ![info exists routers] {
    if {$debug>1} {myputs "routers not explicitly defined, will detect from all other cmd arrays"}
    set routers {}
    if [array exists pre_test] {
        set routers [union $routers [array names pre_test]]
    }
    if [array exists test] {
        set routers [union $routers [array names test]]
    }
    if [array exists pre_check] {
        set routers [union $routers [array names pre_check]]
    }
    if [array exists check] {
        set routers [union $routers [array names check]]
    }
    if [array exists collect] {
        set routers [union $routers [array names collect]]
    }
}

if {$debug>1} {myputs "routers are $routers"}

if $debug {myputs "##############logging into all routers"}
foreach router $routers {
    #if {($login_script == "telnet") || ($login_script == "ssh")} 
    
    if {$debug>1} {myputs "$router:login_script $login_script"}
    if {                                \
        ($login_script == "jtaclab") || \
        ($login_script == "attse") ||   \
        ($login_script == "attjtac") || \
        ($login_script == "attp") ||    \
        ($login_script == "attn")       \
       } {
        set login_script_hidden "[pwd]/.$login_script"
        if {$debug>1} {myputs "$router:att or jlab device"}
        if {$debug>1} {myputs "$router:will call script $login_script_hidden to login"}
        set login_proc "persist_login"
        set login "$login_proc $login_script_hidden $router"
    } elseif { ($login_script == "ssh") || ($login_script == "telnet") } {
        if {$debug>1} {myputs "$router:not att or jlab device"}
        if {$debug>1} {myputs "$router:will call $login_script client to login"}
        set login_proc "persist_login2"

        if {[array exists login_info]&&[info exists login_info($router)]} {
            if {$debug>1} {myputs "login_info configured"}
            if {($login_script == "ssh")} {
                set login "$login_proc $login_script $ssh_username@$router login_info"
            } else {
                set login "$login_proc $login_script $router login_info"
            }
        } else {
            if $debug {myputs "login_info not configured"}
            set login "$login_proc $login_script $router"
        }
    } else {
        if {$debug>1} {myputs "$router:att device"}
        if {$debug>1} {myputs "$router:will call script $login_script to login"}
        set login_proc "persist_login"
        set login "$login_proc [pwd]/$login_script $router"
    }
    if $debug {myputs "will execute $login to login"}
    eval $login

    #if {([array exists login_info]&&[info exists login_info($router)]) && ($customer!="att") && ($customer!="jlab")}
}

if $debug {myputs "##############basic info before test"}
send_routers pre_test
outputs_parser pre_test

set test_array_num 0
for {set i 1} {$i<=10} {incr i 1} {
    if [array exists test$i] {
        incr test_array_num
    }
}

#take a baseline {{{2}}}
if {[array exists check] || [array exists pre_check]} {
    if $debug { myputs "##############start to check issue on routers: [array names check]"}
    if {[array exists check]} {
        #get baseline info from all routers
        if $debug {myputs "will take a baseline from routers:[array names check]"}
        send_log "will take a baseline from routers:[array names check]\n"
        foreach router [array names check] {
            if $debug {myputs "take a baseline from router:$router"}
            set cmd_list $check($router)

            set pa_pair 0
            foreach cmd $cmd_list {                             ;#if any cmd contains special CH, 
                if [regexp "#|>|%" $cmd] {set pa_pair 1}        ;#treat it as a pattern(prompt)
            }
            
            if $pa_pair {                                       ;#use diff method to handle 
                if $debug {myputs "cmds list contains prompt-looking strings, go pattern-action mode!"}
                #send a return to kick off
                myexpect4 $router ".*" "" 10 0
                do_patterns_actions $router check ;#pattern-data pairs: ">" "show "
            } else {                                            ;#or just pure data:  "show1 " "show2 "
                if $debug {myputs "executing \"check\" for router:\"$router\""}
                send_cmds $router check cmd_output_array_check_prev
            }
        }
        if {$debug==3} {send_log "cmd_output_array_check_prev looks:\n \
            [array get cmd_output_array_check_prev]\n"
        }
        if $debug {myputs "will start a loop to re-check the issue every ${check_intv}s..."}
    }
    sleep $check_intv
} else {
    #todo: this doesn't work, reporting: can't interact with self, no big deal
    #interact
    if $debug {myputs "no check or pre_check data configured, will skip them"}
    #exit
}

#start the loop {{{2}}}
set j 1
for {set i 1} {$i<=$maxrounds} {incr i 1} {

    source $configfile      ;#reload customer config file each round (in "real time")

    if $debug {myputs "##############start a pre_check"}
    send_routers pre_check
    outputs_parser pre_check

    if $debug {myputs "##############start a checking"}
    send_routers check

    if {$debug==3} {
        send_log "cmd_output_array_check looks:\n[array get cmd_output_array_check]\n"
    }

    #if flag is triggered, collect more info from all routers
    if {[check_flag check $flag_check_method]} {        ;#found issue

        #write the issue in a seperate file based on runtime
        #populate the filename
        set runtime [exec date "+%Y%m%d-%H%M%S"]
        if $debug {myputs "re-read config file(to get logfile name to record the issue)"}
        source $configfile      ;#reload customer config file each round

        if {[info exists logfile_issue]} {
            log_file; 
            log_file -noappend "$log_dir/$logfile_issue"
            set logfile_issue_prev "$log_dir/$logfile_issue"
            if $debug {myputs "issue is being recorded in file $log_dir/$logfile_issue"}
        } else {
            if $debug {myputs "logfile_issue not configured!"}
        }

        if $debug {myputs "#############issue found in round $i! ############"}
        if $debug {send_log "\n#############issue found in round $i! ############\n"}
        #exp_send -i $session1 "\r\r"

        if [array exists collect] {
            myputs "collecting info"
            send_routers collect
            outputs_parser collect
        }

        if {[info exists maxfilesize]} {             ;#if log file size limit was set
            zipfile $logfile_issue_prev $maxfilesize ;#zip them if exceed the limit
        }

        if $debug {myputs "#############send email about the issue########!"}
        #read the logfile and can be sent to email later
        #huge file will coredump after report "unable to realloc 1099358073 bytes"
        #if {[info exists logfile_issue]} {
        #    set logfile_data [read [open $logfile_issue r]]
        #}

        ##login shell server to send email
        #spawn -noecho ssh svl-jtac-tool02
        #expect 
        #    -re "\\\$ $" {send "echo \"issue found\" | mail -s \"issue found\\\!\" pings@juniper.net\r"}
        #    #-re "\\\$ $" {send "echo $logfile_data | mail -s \"issue found\\\!\" pings@juniper.net\r"}
        #
        #expect -re "\\\$ $" {send "exit\r"}
        
        exec echo "check the log file" | mail -s "issue found" $env(USER)@juniper.net

        if $debug {myputs "issue has been captured for $j/(max $maxrounds_captured) round(s)!"}
        if {$j >= $maxrounds_captured} {
            if $debug {myputs "max issue capture times reached ($maxrounds_captured)!"}
            break
            #interact -i $session1
            #interact -i $session2
        }
        incr j 1
    } else {                                    ;#found no issue
        #if $debug {myputs "##############round $i:issue not seen(or not defined)";puts "\n"}
        myputs "##############round $i:issue not seen(or not defined)";puts "\n"
        
        #switch [expr $i % 4] {
        #    1 {send_routers test1}
        #    2 {send_routers test2}
        #    3 {send_routers test3}
        #    0 {send_routers test4}
        #}
        if $test_array_num {
            if $debug {myputs "$test_array_num of \"testN\" arrays were defined, will execute each in different round"}
            set k [expr $i % $test_array_num]
            if !$k {set k $test_array_num}
            send_routers test$k
            outputs_parser test$k
        } else {
            if $debug {myputs "no \"testN\" arrays defined, will execute just test array in each round"}
            if [array exists test] {
                myputs "will perform some tests"
                send_routers test
                outputs_parser test
            } else {
            }
        }
        

        #send_routers test
        #todo: pace sync on file between multiple scripts
        #myputs "set switchover go flag if switchover is required for the test"
        #write_flag_into_file $flagfile "re-switchover-vpls go"
        #while ![read_flag_from_file $flagfile "issuechecker go"] {
        #    myputs "no switchover go flag , wait for 20s"
        #    sleep 20
        #}
    }

    #catch {close $session}

    if $debug {myputs "##############round $i (max $maxrounds) done###############"}
    if $debug {send_log "##############round $i (max $maxrounds) done###############\n"}
    if $debug {myputs "will check again after ${check_intv}s";puts ""}

    if {[info exists maxfilesize]} {                    ;#if log file size limit was set
        if {[zipfile $logfile_prev $maxfilesize]} {     ;#if log file size exceeds limit, zip it
            set runtime [exec date "+%Y%m%d-%H%M%S"]    ;#populate a new file name only if old file
            source $configfile                          ;#  got zipped
            if {[info exists logfile]} {
                log_file; log_file -noappend $logfile   ;#start the new logfile
                set logfile_prev $logfile
            }
        }
    }

    sleep $check_intv
}

send_routers post_test

if [info exists notify_on_exit] {
    exec echo "check the log file" | mail -s "script $scriptbasename_pref exited!" $env(USER)@juniper.net
}
