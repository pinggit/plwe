#!/usr/bin/env expect
#basically done, still some minor issues
#todo: need enhance persist mode
#   1) in att script: handle all low level situations
#   2) in upgrade script: only return spawnid when get expected prompt 
#todo: monitor the issue of getting stuck in some command.workaround maybe:
#   1) enhance myexpect, whenever timeout :
#     close current session and make a new spawn?
#   2) then need to overide previous spawn_id used by rest of the script
#   
proc myputs {msg} {
    puts "\[[exec date]:[lindex [info level 1] 0]:..$msg..\]"
}
proc myexpect {proc_login pattern datasent {mytimeout 60}} {
    set controlC \x03
    set timeout $mytimeout
    expect  {
	-i $proc_login -re "$pattern" {
	    exp_send -i $proc_login "$datasent\r"
	    return $expect_out(buffer)
	}
	-i $proc_login timeout {
            myputs "timeout in ${timeout}s without a match for -$pattern-!"
            myputs "won't send -$datasent-!"
            myputs "timeout in ${timeout}s without a match!ctrl-c to break"
            exp_send -i $proc_login "$controlC"
	}
        -i $proc_login -re "connection closed by foreign host" {
            myputs "connection closed by the router!"; exit
        }
        -i $proc_login eof {
            myputs "spawned process terminated!"; exit
        }
        -i $proc_login full_buffer {
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

proc upgrade_pre {proc_login} {
    #pre-upgrade work
    exp_send -i $proc_login "\r"
    myexpect $proc_login "> $"  "configure"
    myexpect $proc_login "# $"  "deactivate chassis redundancy    "
    myexpect $proc_login "# $"  "deactivate system commit fast-synchronize  "
    myexpect $proc_login "# $"  "deactivate routing-options nonstop-routing"
    myexpect $proc_login "# $"  "deactivate system switchover-on-routing-crash"
    myexpect $proc_login "# $"  "show | compare"

    #check if config was changed, commit only if yes
    #and proceed only if commit success
    expect { 
        -i $proc_login -re "show \\\| compare \r\n\[a-zA-Z]+\r\n" {
            exp_send -i $proc_login "commit\r"
            expect {
                -i $proc_login -re "failed" {
                    myputs "commit failed, need to check, exit!"
                    exit
                }
            }
        }
        -i $proc_login -re "show \\\| compare \r\n\r\n" {
           myputs "nothing changed, no need to commit!" 
        }
        -i $proc_login timeout {
           myputs "some unexpected patterns,exit!" ; exit
       }
    }
    myexpect $proc_login "# $"  "exit  "
    #todo: add more check
    #    lab@alecto-re1# exit 
    #    The configuration has been changed but not committed
    #    Exit with uncommitted changes? [yes,no] (yes)
    expect {
        -i $proc_login -re "uncommited changes" {
            myputs "commit failed, exit!";exit
        }
        -i $proc_login -re "> $" {
            exp_send -i $proc_login "\r"
        }
    }
}

proc upgrade {proc_login rel} {
    global su_password debug expect_out

    #prepare for the upgrade
    upgrade_pre $proc_login

    #upgrade backup RE 
    expect -i $proc_login -re "(\[01])> $" {
        set reA $expect_out(1,string)
        exp_send -i $proc_login "request routing-engine login other-routing-engine\r"
    }
    #check and make sure it really logged in to the other RE before proceed
    expect -i $proc_login -re "(\[01])> $" {
        set reB $expect_out(1,string)
        if {$reA==$reB} {
            myputs "login the other re failed, exit!";exit
        } else {
            myputs "login the other re succeed, continue!"
            exp_send -i $proc_login "\r"
        }
        upgrade_re $proc_login $rel
    }
    
    #upgrade master RE 
    #expect -i $proc_login -re "going down IMME(.*\r\n){3,7}(rlogin: connection closed.*)" 
    expect {
        -i $proc_login "going down IMMEDIATELY" {exp_continue -continue_timer}
        -i $proc_login "rlogin: connection closed"  {exp_continue -continue_timer}
        -i $proc_login -re "(\[01])> $" {
            set reC $expect_out(1,string)
            if {$reA==$reC} {
                myputs "seeing RE$reC , back to master, will upgrade master now"
                #sleep 5
                exp_send -i $proc_login "\r"
                upgrade_re $proc_login $rel
            } else {
                myputs "seeing RE$reC, still not back to master, wait"
                exp_continue -continue_timer
            }
        }
        -i $proc_login default {
            myputs "some unexpected conditions(still not back to master), exit!"
            exit
        }
    }
    #above can also be re-written as:
    #set buf ""
    #expect -i $proc_login -re ".+" {
    #    append buf $expect_out(buffer)
    #    exp_continue
    #}

    #if [regexp "$reA> $" $buf] {
    #    myputs "seeing RE$reC , back to master, will upgrade master now"
    #    #sleep 5
    #    exp_send -i $proc_login "\r"
    #    upgrade_re $proc_login $rel
    #} else {
    #    myputs "seeing RE$reC, still not back to master, wait"
    #    exp_continue -continue_timer
    #}

    #expect -i $proc_login -re "> $"
    expect -i $proc_login -re "going down IMMEDIATELY"
}

proc upgrade_re {proc_login rel} {
    #global timeout
    set timeout 300
    myexpect $proc_login "> $"  "set cli screen-width 300"
    myexpect $proc_login "> $"  "request system software add $rel validate force"
    expect {
        -i $proc_login "Installation failed" {
            myputs "system software adding failed, exit!"; exit
        }
        -i $proc_login "Saving state for rollback" {
            myputs "system software adding succeed, continue to reboot!"
            myexpect $proc_login "re\[01]>"  "request system reboot"
            myexpect $proc_login "\\\(no\\\) +$" "yes"
        }
        -i $proc_login "ERROR: Another package installation in progress:" {
            myputs "will retry in 5s"
            sleep 5
            myexpect $proc_login "> $"  "request system software add $rel validate force"
            exp_continue
        }
        -i $proc_login default {
            myputs "unexpected: neither fail nor success"
            myputs "will retry again when timeout"
            exp_continue
        }
    }
    set timeout 60
    #exp_internal 1
    #set timeout $old_timeout
    #myputs "restore old timeout $timeout"
    #exp_internal 0
}

proc persist_login {login_script routername} {
    global debug
    spawn $login_script $routername
    if $debug {myputs "upgrade:spawn_id of persist_login is $spawn_id"}
    expect {
        -i $spawn_id -re "> $" {
            return $spawn_id
        }
        #with persist feature added in login script, seems no need to duplicate from here
        -i $spawn_id "upgrade:Unable to connect to remote host: Connection timed out" {
            persist_login $login_script $routername
        }
        -i $spawn_id default         {
            myputs "upgrade:get eof/timeout, retry"
            sleep 1
            persist_login $login_script $routername
        }
    }
}

proc do_test {proc_login} {
    global su_password debug expect_out rel
    upgrade $proc_login $rel1
}

proc hold {proc_login} {
    set timeout 2; 
    expect -i $proc_login ".+" {exp_continue -continue_timer}; 
    exp_send -i $proc_login "\r"; 
    set timeout 60
}

proc pre_collect_info {proc_login} {
    exp_send -i $proc_login "\r"; 
    myexpect $proc_login "> $" "show system uptime"
    myexpect $proc_login "> $" "show task replication"
    #myexpect $proc_login ">" "show version invoke-on all-routing-engines | no-more"
}

proc post_collect_info {proc_login} {
}

proc check_issue {proc_login} {
    global expect_out
    send -i $proc_login "\r"
    #myexpect $proc_login "> $" "show version invoke-on all-routing-engines | no-more"  
    myexpect $proc_login "> $" "show chassis routing-engine | no-more"
    myexpect $proc_login "> $" "show system storage | no-more"
    myexpect $proc_login "> $" "show chassis hardware | no-more"
    if 0 {
        set sendemail "echo $detectionmsg | sendthisfile.sh - pings@juniper.net $detectionmsg"
	if {[myexec $sendemail]} {
	} else {
	    myputs "email notification was sent!"
	}
        exit
    }
}

set login_script "attjlab"
set routername "alecto"
set su_password "jnpr123"
set maxrounds 1000
set switch_interval 120
set rel "/var/tmp/jinstall64-12.3X30-D20-domestic-signed.tgz"
set rel1 "jinstall-12.3I20131202_2000_bhaskerr-domestic-signed.tgz"
set rel2 "/var/tmp/jinstall-11.4-20121119_dev_x_114sx_att.0-domestic-signed.tgz"

set login_interval 60

if {$argc>=1} {
    set login_script [lindex $argv 0]
}
if {$argc>=2} {
    set routername [lindex $argv 1]
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
    myputs "example:$scriptbasename_pref attn DESTTG1005ME2 240 100"
    exit
}

set hold_interval [expr {$switch_interval - $login_interval}]
set timeout 300
set debug 0

#set expect buffer (for pattern match) for all later spawned process
match_max -d 10000
#turn off parity
parity -d 0

#turn on expect debug
#exp_internal 1
for {set i 1} {$i<=$maxrounds} {incr i 1} {
    set proc_login [persist_login $login_script $routername]
    if $debug {myputs "spawn_id of attjlab from main is $proc_login"}

    myputs "#############collect info now...#############"
    pre_collect_info $proc_login

    myputs "#############upgrade now...##############"
    upgrade $proc_login $rel1
    catch {close $proc_login}

    sleep 300
    myputs "#############login again to check the issue now...#############"
    #todo: need to make sure to login AFTER router has reloaded!
    set proc_login [persist_login $login_script $routername]
    #start persistlogin only after being sure router did go down, garenteed by
    #seeing "connection timeout" once
    #expect {
    #    -i $proc_login -nocase -re "Connection timed out" {
    #        myputs "upgrade:reouter is not up yet,start persist login"
    #        set proc_login [persist_login $login_script $routername]
    #    }
    #}
    check_issue $proc_login
    catch {close $proc_login}

    myputs "#############downgrade now...##############"
    set proc_login [persist_login $login_script $routername]
    upgrade $proc_login $rel2
    catch {close $proc_login}

    sleep 300
    myputs "#############login again to check the issue now...#############"
    set proc_login [persist_login $login_script $routername]
    check_issue $proc_login
    catch {close -i $proc_login}

    myputs "\[script:#############$i round of software upgrade done!#############\]"
    if $debug {myputs "\[script:will login to the router again shortly after $login_interval seconds...\]"}
    sleep $login_interval
}
interact -i $spawn_id
