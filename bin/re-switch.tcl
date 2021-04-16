#!/usr/bin/env expect
#done:
# extract seconds number from expect_out, and feed in sleep     - done
# switchover via rpd crash                                      - done
#todo: 
# check interface status                                        - done
# create "all other conditions?" via timeout                    - done
# close spawn_id seems doesn't work, seems still acumulating
#     [Wed Jan  8 15:02:13 EST 2014:myputs:..spawn_id of attjlab from main is exp56..]
#     [Wed Jan  8 15:04:47 EST 2014:myputs:..spawn_id of attjlab from main is exp57..]
#todo: add forcing login (login loop)
#% Connection timed out; remote host not responding
#myexpect $proc_login "> $" "show task replication"
#
# pings@juniper.net
#

proc myputs {msg} {
    puts "\[[exec date]:[lindex [info level 1] 0]:..$msg..\]"
}

proc myexpect {proc_login pattern datasent {timeout 60}} {
    set controlC \x03
    #if pattern match, send data
    #puts "spawn_id of attjlab from [lindex [info level [info level]] 0]' proc is $spawn_id"
    expect  {
	-i $proc_login -re "$pattern" {
	    exp_send -i $proc_login "$datasent\r"
	    return $expect_out(buffer)
	}
	timeout {
            myputs "timeout without a match!"
	    #this is useful when the last cmd get stuck there and could be exited out of
	    #using some key, like "q"
            exp_send -i $proc_login "$controlC"
	    return 1
	}
        #I guess this will never be hit, but just leave it also no harm anyway
        -i $proc_login -re "connection closed by foreign host" {
            myputs "connection closed by the router!"; exit
        }
        eof {
            myputs "spawned process terminated!"; exit
        }
    }
}

proc switchover_yesno {} {
    global proc_login
    #set spawn_id $session
    exp_send -i $proc_login "\r"
    myexpect $proc_login "> $" "request chassis routing-engine master switch" 60
    expect -i $proc_login "\\\[yes,no\\\] (no)" { send -i $proc_login "yes\r"}
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

proc switchover {} {
    global hold_interval su_password debug proc_login

    switchover_yesno

    expect {
        #Complete. The other routing engine becomes the master.
        #-re "\{backup\}\s+.*-re\[01]>" 
        #-re "\{backup\}\r\n.*-re\[01]>" 
        #-re "The other routing engine becomes the master.\r\n\r\n{backup}\r\n.*-re\[01]>"
        -i $proc_login -re "routing engine becomes the master"
        {
            if $debug {myputs "\[script:detected switchover succeed! will exit...\]"}
            send -i $proc_login "exit\r"
        }

        #-re "\{master\}\s+.*-re\[12]>" 
        #-re "\{master\}\r\n.*-re\[01]>" 
        -i $proc_login -re "Command aborted. Not ready for mastership switch, try after \\d+ secs.*"
        {
            #if $debug {myputs "$expect_out(buffer)\r"}
            set switchover_countdown 240
            regexp {.*try after (.*) secs.*} $expect_out(buffer) -> switchover_countdown
            if $debug {myputs "\[script:detected switchover did not succeed...\]"}
            if {$switchover_countdown <= $hold_interval} {
                #wait and graceful switchover
                switchover_countdown $switchover_countdown
                switchover
            } else {
                if $debug {myputs "\[script:required switchover interval time left(${hold_interval}s) is less than CLI protection interval(${switchover_countdown}s left), will force rpd restart after $hold_interval seconds...\]"}
                sleep $hold_interval
                #force rpd core and switchover
                restart_rpd
            }
        }

        #this won't catch: closed -> spawned proc exit -> no way to expect
        -i $proc_login -re "closed by foreign host" 
        {
            myputs "no problem, will re-login again!"
        }

        timeout {
            myputs "something not predicted happened, exit"
            exit
        }
    }
}

proc restart_rpd {} {
    global su_password debug expect_out proc_login
    if $debug {myputs "start restarting rpd now!"}
    exp_send -i $proc_login "\r"
    exp_send -i $proc_login "start shell\r"
    myexpect $proc_login "% $"        "su"
    myexpect $proc_login "Password:$" "$su_password"
    myexpect $proc_login "% $"        "uptime\r"
    myexpect $proc_login "% $"        "ps aux | grep rpd\r"
    expect -i $proc_login -re "root\\s+(\\d+)\\s+.*sbin/rpd.*$" {
        set rpd_pid $expect_out(1,string)
        send -i $proc_login "pwd\r"
        exp_send -i $proc_login "kill -11 $rpd_pid\r"
    }
    expect -i $proc_login -re "% $"
}

proc collect_info {} {
    global interface1 interface2 proc_login
    #puts "spawn_id of attjlab from collect_info is $spawn_id"
    #myexpect "> $" "show version | no-more" $ci_timeout
    set captured_output [myexpect $proc_login "> $" "show system uptime"]
    #expect "> $"
    #myputs "captured:--$captured_output--" 
    myexpect $proc_login "> $" "show task replication"

    myexpect $proc_login "> $" "show interface $interface1 | match admin" 
    myexpect $proc_login "> $" "show interface $interface2 | match admin"
}

proc check_intf {} {
    global interface1 interface2 proc_login expect_out
    set isdown1 1
    set isdown2 2
    myputs "script:start to check interfaces status..."
    #Physical interface: ge-3/1/0, Administratively down, Physical link is Down  #<------
    set buf1 [myexpect $proc_login "> $" "show interfaces $interface1 extensive | match admin" 60]
    #regexp {.*Administratively (.*),.*} $buf1 -> isdown1
    set buf2 [myexpect $proc_login "> $" "show interfaces $interface2 extensive | match admin" 60]
    #regexp {.*Administratively (.*),.*} $buf1 -> isdown2
    #if {$isdown1=="down" || $isdown2=="down"} 

    if {[regexp {Administratively down} $buf1] || [regexp {Administratively down} $buf2]} {
        set detectionmsg "interface admin down detected!exit!"; myputs $detectionmsg

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

set login_script "attjlab"
set routername "alecto"
set su_password "jnpr123"
set maxrounds 500
set switch_interval 120
#set dead_time [exec date +"%s" -d "Fri Jan 08 02:50:00 EST 2015"]
#set dead_time [exec date +"%s" -d "Fri Jan 10 07:50:00 EST 2014"]

set interface1 ge-3/1/0
set interface2 ge-4/1/0
    #if {$isdown1=="down" || $isdown2=="down"} 

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

if {$routername=="alecto" || $argc == 0} {
    set interface1 xe-3/1/0
    set interface2 ge-1/3/0
    set su_password "herndon1"
}

set hold_interval [expr {$switch_interval - $login_interval}]
set timeout 300
#set debug 1
set debug 1
#log_file 1
#spawn -noecho attjlab alecto
spawn $login_script $routername
set proc_login $spawn_id
#stty -reset
#set session $spawn_id
for {set i 1} {$i<=$maxrounds} {incr i 1} {

#    set curr_time [exec date +"%s"]
#    if { $curr_time > $dead_time } {
#        myputs "time is up! will exit!"
#        exit
#    }
    if $debug {myputs "spawn_id of attjlab from main is $proc_login"}
    collect_info
    check_intf
    switchover
    #spawn -noecho attjlab alecto
    catch {close -i $proc_login}
    myputs "\[script:#####################$i round of RE switchover done!###################\]"
    if $debug {myputs "\[script:will login to the router again shortly after $login_interval seconds...\]"}
    sleep $login_interval
    spawn $login_script $routername
    set proc_login $spawn_id
    #set session $spawn_id
    
}

interact
