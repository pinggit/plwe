#!/usr/bin/env expect

spawn telnet Caesar.jtac-east.jnpr.net
expect "login:"
send "lab\r"
expect "assword:"
send "herndon1\r"
expect "caesar-re0>"
send "set cli screen-length 300\r"
expect "caesar-re0>"
send "set cli timestamp\r"
expect "caesar-re0>"

set maxrounds 1000000

for {set i 1} {$i<=$maxrounds} {incr i 1} {

    send "configure\r"
    expect "caesar-re0#"
    send "set protocols oam ethernet link-fault-management interface xe-0/0/0\r"
    expect "caesar-re0#"
    send "set protocols oam ethernet link-fault-management interface xe-0/0/0 apply-groups AG_NM_8023AH_MULTIHOME\r"
    expect "caesar-re0#"
    send "commit and-quit\r"
    expect "caesar-re0>"

    send "show ppm adjacencies remote\r"
    expect -re "LFM\\s+(\\d+).*\r\n\r\n.*\r\n\r\n.*-re0>"
    set lfm1 $expect_out(1,string)
    send "request pfe execute command \"show ppm tra\" target fpc0\r"
    expect -re "LFM\\s+(\\d+).*(\r\n.*){5,8}.*-re0>"
    set lfm2 $expect_out(1,string)

    if {$lfm1=="3000" && $lfm2=="1000"} {
        exit
    } else {
        send "configure\r"
        expect "caesar-re0#"
        send "delete protocols oam ethernet link-fault-management interface xe-0/0/0\r"
        expect "caesar-re0#"
        send "commit and-quit\r"
        expect "caesar-re0>"
    }

    puts "###########round $i done!#############"
    sleep 60

}

expect "caesar-re0>"

#   expect -i $proc_login -re "root\\s+(\\d+)\\s+.*sbin/rpd.*$" {
#       set rpd_pid $expect_out(1,string)
#       send -i $proc_login "pwd\r"
#       exp_send -i $proc_login "kill -11 $rpd_pid\r"
#   }

#pattern works
#<search for LFM from both output, check LFM value, if 1st command output LFM=3000, 2nd output LFM = 1000, stop, else, continue>
#
#Enter configure mode:
#
#Delete protocols oam ethernet link-fault-management interface xe-0/0/0
#
#Commit
#
#Return;
#
