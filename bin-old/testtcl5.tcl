#!/usr/bin/env expect
#!/bin/sh
# -*- tcl -*-
# The next line is executed by /bin/sh, but not tcl \
exec tclsh "$0" ${1+"$@"}
#puts "test1################"
#set a [list "#" "show int" "showint"]
#set showint "show int"
#
#foreach el $a {
#    if [info exists $el] {
#        puts "$el can be resolved further"
#    } else {
#        puts "$el is a value"
#    }
#}
#
#puts "test1################"
#array set arr1 {
#    a   b
#}
#
#proc myproc { arr } {
#    upvar $arr myarr
#    #parray myarr
#    #parray arr
#    puts "$myarr(a)"
#}
#myproc arr1
#
#puts "test1################"
#set li {li1 li2}
#set li1 {li11 "show abc"}
#set li2 "show li2"
#set li11 "show li11"
#
##"show li11" "show abc" "show li2"
#
#foreach a {1 2} {
#    puts $a
#    if {$a==1} {
#        break
#    }
#}
#
#
##puts "test1################"
##
##puts -nonewline "Enter your name: "
##flush stdout
##set name [gets stdin]
##
##puts "Hello $name"
#
#
#puts "test1################"
#spawn bash
#send_user "Enter the command array you configured: \n"
#flush stdout
#interact {
#    "yy"
#}

#set timeout 120
#set router "alecto"
##spawn telnet [set router].jtac-east.jnpr.net
#spawn [lrange $argv 0 end]         ;#this works
#expect "ogin" {send "lab\r"}
#expect "assword" {send "herndon1\r"}
#expect > {send "set cli timestamp\r"}

spawn vim tempfile.txt
send "ifoo\033:wq\r"
expect
