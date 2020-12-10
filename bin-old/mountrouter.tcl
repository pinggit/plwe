#!/usr/bin/env expect

proc myRand { min max } {
    set maxFactor [expr [expr $max + 1] - $min]
    set value [expr int([expr rand() * 10000])]
    set value [expr [expr $value % $maxFactor] + $min]
    return $value
}

set p [myRand 50000 60000]

if $argc<1 {
   send_user "Usage: $argv0 hostname/IP routername \[account\] \r\n"
   exit -1
}
set argc [llength $argv]
set argv1 [lindex $argv 0]
set argv2 [lindex $argv 1]
set argv3 [lindex $argv 2]

set timeout 30
spawn ssh -fNL$p:$argv1:22 scooby2
expect "password:"
send "jnpr\r"
expect "\\\$ $"
spawn sshfs -p $p $argv3@localhost:/ $argv2

expect {
    "fuse: bad mount point *"   break
    ""
}
expect "password:"
send "Nina@jnpr5%\r"
expect "\\\$ $"

#ping@640g-laptop:/mnt/att-router$ attmap.sh 192.168.47.179 van4pe6-re1 jtac
#jtac@127.0.0.1's password:
#mkdir: cannot create directory `van4pe6-re1': File exists
#The authenticity of host '[localhost]:50277 ([::1]:50277)' can't be established.
#ECDSA key fingerprint is 70:6c:2b:9f:76:79:ff:1d:25:18:b3:17:c4:3c:42:65.
#Are you sure you want to continue connecting (yes/no)? yes
#jtac@localhost's password:



#DESTTG1005ME2-re0
#spawn ftp 127.0.0.1
#expect "Name"
#send "ping\r"
#expect "Password:"
#send "Songping1@\r"
#expect "> $"
#send "pwd\r"
#expect "> $"

#exec cd /mnt/att-router/
#exec pwd

#ssh -fNL10122:192.168.45.227:22 scooby2
#ssh -fNL$p:$1:22 scooby2
#sshfs -p 10122 j-tac-nz1@localhost:/ $2
#mkdir $2
