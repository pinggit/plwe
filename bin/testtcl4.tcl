#!/usr/bin/tclsh
puts "argv is $argv"
proc test { p1 {a 100}} {
    global argv
    if {$a==100} {
        set a $argv
    }
    puts "a is $a"
    puts "p1 is $p1"
}

test p1

