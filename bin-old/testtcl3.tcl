#!/usr/bin/tclsh
set linenum 0
set charnum 0
while {[gets stdin line] >= 0} {
    puts [incr linenum]
    puts [incr charnum [string length $line]]
}
